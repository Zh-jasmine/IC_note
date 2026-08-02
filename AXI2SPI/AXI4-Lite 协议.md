---
tags: #AMBA #AXI #协议
---

# AXI4-Lite 协议

AXI4-Lite 是面向 memory-mapped control/status register 的轻量级 AXI 协议，保留 AXI 的五通道 VALID/READY 解耦握手、读写独立和 `WSTRB` 字节选通，但去掉 burst、ID 和乱序能力，适合低带宽寄存器配置场景。

在 AXI-LITE2SPI 项目里，AXI4-Lite 的职责是把 CPU 侧配置事务送进 DUT。SPI mode、SCK 分频、word length、片选时序和 MOSI 数据都通过 AXI 写寄存器完成；`START` 寄存器写 1 后，SPI master 使用当前寄存器配置发起串行传输。

## 时钟与复位

AXI4-Lite 是同步协议，所有通道都在 `ACLK` 上采样。`ARESETN` 是低有效复位，复位为低时，slave 输出需要回到已知状态。对验证来说，reset 检查至少包含两类行为：

| 检查点             | 含义                                                         |
| --------------- | ---------------------------------------------------------- |
| reset 期间输出 idle | `AWREADY/WREADY/BVALID/ARREADY/RVALID` 等 slave 输出不能保持旧事务状态 |
| reset 后可恢复      | 复位释放后，新的 AXI 事务和 SPI 传输还能正常执行                              |

当前项目用 `axi_sva_checker` 检查 AXI reset 行为，用 `reset_mid_test` 和 `reset_sva_test` 覆盖传输中 reset。

## VALID-READY 握手

AXI 每个通道都用 `VALID` 和 `READY` 表示一次传输是否完成。发送方把 payload 放稳后拉高 `VALID`，接收方可以接收时拉高 `READY`。在某个时钟上升沿，`VALID && READY` 同时为 1，这个通道的一次传输完成。

握手允许三种时序：

| 时序 | 说明 |
|---|---|
| VALID 先到 | 发送方先准备好，等待接收方 READY |
| READY 先到 | 接收方提前准备好，等待发送方 VALID |
| 同拍到达 | 发送和接收同一拍完成 |

`VALID` 拉高后，在握手完成前 payload 必须保持稳定。验证 AXI slave 时，需要覆盖不同到达顺序，确认 slave 不会因为地址和数据错开而丢事务。

当前 DUT 的写接收逻辑比较保守：只有 `AWVALID` 和 `WVALID` 同时有效时，才会同时拉起 `AWREADY` 和 `WREADY`。`axi_handshake_test` 通过 `aw_delay` 和 `w_delay` 覆盖 AW 先到、W 先到、同拍到达和长延迟场景。

## 五个通道

AXI4-Lite 有五个独立通道。写事务使用 AW、W、B 三个通道；读事务使用 AR、R 两个通道。

| 通道  | 方向              | 主要信号                        | 作用       |
| --- | --------------- | --------------------------- | -------- |
| AW  | master -> slave | `AWADDR/AWVALID/AWREADY`    | 写地址      |
| W   | master -> slave | `WDATA/WSTRB/WVALID/WREADY` | 写数据和字节选通 |
| B   | slave -> master | `BRESP/BVALID/BREADY`       | 写响应      |
| AR  | master -> slave | `ARADDR/ARVALID/ARREADY`    | 读地址      |
| R   | slave -> master | `RDATA/RRESP/RVALID/RREADY` | 读数据和读响应  |

写地址和写数据在协议上属于独立通道，可以错开到达。slave 需要在内部保存地址和数据，等一笔写事务完整后更新寄存器并返回 B 响应。当前 DUT 选择同时接收 AW/W，因此验证重点是 driver 能保持 `VALID` 和 payload，直到 DUT 同时接收。

读事务的顺序更直接：AR 握手给出地址，R 通道返回数据和响应。

## WSTRB

`WSTRB` 是写字节选通。32-bit AXI 数据总线有 4 个 byte lane，`WSTRB[i]` 表示 `WDATA[8*i +: 8]` 是否写入目标寄存器。

| WSTRB | 写入 byte |
|---|---|
| `4'b0001` | byte0，`WDATA[7:0]` |
| `4'b0010` | byte1，`WDATA[15:8]` |
| `4'b0100` | byte2，`WDATA[23:16]` |
| `4'b1000` | byte3，`WDATA[31:24]` |
| `4'b1111` | 四个 byte 全写 |

寄存器写逻辑必须只更新被 `WSTRB` 选中的 byte。`axi_wstrb_test` 用单 byte lane 和 sparse mask 检查这个行为。RM 对 `MOSI_DATA` 也按 `WSTRB` 更新 `mosi_data_shadow`，这样 expected SPI 数据和 AXI 字节写语义保持一致。

## 响应

AXI response 表示 slave 对事务的处理结果。

| 响应值 | 名称 | 含义 |
|---|---|---|
| `2'b00` | OKAY | 正常完成 |
| `2'b01` | EXOKAY | 独占访问成功，AXI4-Lite 项目中不用 |
| `2'b10` | SLVERR | slave 错误 |
| `2'b11` | DECERR | 地址解码错误 |

当前 DUT 固定返回 OKAY。RM 会检查 `BRESP/RRESP` 是否为 `2'b00`。非法地址读写在当前项目中按设计意图豁免：写非法地址保持原值，读未实现地址返回 0。

## 地址映射

AXI4-Lite 按 byte address 寻址。当前 DUT 地址总线宽度为 6 bit，可以覆盖 64 byte。数据总线宽度为 32 bit，每个寄存器占 4 byte，所以寄存器地址按 4 对齐。

RTL 中：

```text
ADDR_LSB = 2
OPT_MEM_ADDR_BITS = 3
寄存器选择 = addr[5:2]
```

地址表：

|     地址 | `addr[5:2]` | RTL 寄存器    | AXI 访问 | SPI 连接 / 语义                      |
| -----: | ----------: | ---------- | ------ | -------------------------------- |
| `0x00` |      `4'h0` | `slv_reg0` | WO     | `start_i = slv_reg0[0]`，写 1 触发传输 |
| `0x04` |      `4'h1` | `slv_reg1` | RO     | `busy_o -> slv_reg1[0]`          |
| `0x08` |      `4'h2` | `slv_reg2` | WO     | `spi_mode_i = slv_reg2[1:0]`     |
| `0x0C` |      `4'h3` | `slv_reg3` | WO     | `sck_speed_i = slv_reg3[1:0]`    |
| `0x10` |      `4'h4` | `slv_reg4` | WO     | `word_len_i = slv_reg4[1:0]`     |
| `0x14` |      `4'h5` | `slv_reg5` | WO     | `IFG_i = slv_reg5[7:0]`          |
| `0x18` |      `4'h6` | `slv_reg6` | WO     | `CS_SCK_i = slv_reg6[7:0]`       |
| `0x1C` |      `4'h7` | `slv_reg7` | WO     | `SCK_CS_i = slv_reg7[7:0]`       |
| `0x20` |      `4'h8` | `slv_reg8` | WO     | `mosi_data_i = slv_reg8[31:0]`   |
| `0x24` |      `4'h9` | `slv_reg9` | RO     | `miso_data_o -> slv_reg9[31:0]`  |


配置寄存器是 WO，是因为 DUT 的读译码只返回 `0x04 busy` 和 `0x24 miso_data`。配置值可以通过 AXI 写入并驱动 SPI master，但 frontdoor 读这些地址会返回 0。RAL 因此用 frontdoor write + backdoor peek 检查配置寄存器物理值。

所有配置寄存器复位值为 0。默认配置对应 Mode0、默认分频、32-bit word length 和默认时序。直接写 `MOSI_DATA` 再写 `START` 也能触发一帧默认配置下的 SPI 传输。

## 验证关注点

| 类别 | 检查内容 | 当前测试 |
|---|---|---|
| 握手 | AW/W 同拍、AW 先到、W 先到、长延迟 | `axi_handshake_test` |
| 字节写 | 单 byte lane、sparse mask | `axi_wstrb_test` |
| 状态 | 传输中 busy=1，结束 busy=0 | `axi_busy_test` |
| 并发 | 写流发帧期间读 busy | `axi_concurrent_test` |
| 响应 | `BRESP/RRESP` 为 OKAY | driver + RM |
| reset | reset 期间 AXI 输出 idle，reset 后恢复 | SVA + reset tests |
| RAL | WO frontdoor write + backdoor peek，RO frontdoor read | `ral_test` |

AXI4-Lite 在这个项目里的验证重点集中在寄存器访问语义、握手稳定性、WSTRB 字节更新、读写通道互不阻塞，以及这些 AXI 输入事务能否正确驱动后端 SPI 行为。

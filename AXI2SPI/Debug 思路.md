# AXI-LITE2SPI Debug 思路

AXI-LITE2SPI 的 debug 目标是把 scoreboard 报出的端到端不一致拆回到可观察的协议事件。日志给出失败 test、失败时间点、expected 和 actual；波形负责证明错误来自 AXI 寄存器写入、DUT 内部状态、SPI 引脚行为，还是 monitor/reference model/scoreboard 的建模路径。

## 日志入口

`all_test` 后先从日志定位失败 test。每个 test 都有独立日志和独立 FSDB，失败 test 决定需要打开哪一个波形文件。

```bash
cd ~/Desktop/vcs_sync/AXI_Lite2SPI/UVMTB/sim
grep -RniE "UVM_ERROR|SCB_MISMATCH|SCB_UNEXP_SPI|SCB_FAIL|WSTRB mismatch|failed at" sim_*.log
```

日志中的 scoreboard mismatch 一般包含三类信息：

```text
sim_axi_busy_test.log:95:
UVM_ERROR scoreboard/tb_scoreboard.sv(45) @ 1715000:
uvm_test_top.env.scb [SCB_MISMATCH]
FAIL: expected 0xa5 != actual 0xb4
```

| 字段 | 含义 |
|---|---|
| `sim_axi_busy_test.log` | 失败 test |
| `@ 1715000` | 失败发生的仿真时间点 |
| `expected 0xa5` | reference model 根据 AXI 配置事务生成的期望 SPI 数据 |
| `actual 0xb4` | SPI monitor 从 SPI 引脚采样并组包得到的实际数据 |

打开对应 FSDB：

```bash
verdi -dbdir simv.daidir -ssf fsdb_axi_busy_test.fsdb &
```

进入 Verdi 后跳到日志时间点之前，例如 `1715000` 报错可以先观察 `1600000 ~ 1750000`。

## 端到端定位链路

Scoreboard mismatch 不能直接说明 DUT 错。`expected` 和 `actual` 分别来自两条路径，debug 需要先确认哪条路径失真。

```text
AXI write/read transaction
        |
        +--> reference model shadow register --> expected SPI item
        |
        +--> DUT register/state --> SPI pins --> SPI monitor --> actual SPI item
```

因此定位顺序固定为：

1. AXI 是否完成了目标地址的有效写入。
2. `WSTRB` 是否允许对应 byte 更新。
3. DUT 寄存器值是否符合 AXI 写入结果。
4. SPI mode、word length、SCK/CS 时序配置是否符合 test 预期。
5. MOSI/MISO 引脚上的 bit 序列是否符合 DUT 寄存器和 SPI mode。
6. SPI monitor 的采样边沿和组包方向是否符合协议。

## AXI 侧检查

AXI4-Lite 的一次写事务由 AW、W、B 三条通道组成。地址和数据通道可以错开到达，真正完成传输的条件是在 `ACLK` 上升沿同时满足 `VALID && READY`。

| 检查对象 | 观察内容 |
|---|---|
| AW 通道 | `AWVALID && AWREADY` 同拍时的 `AWADDR` |
| W 通道 | `WVALID && WREADY` 同拍时的 `WDATA/WSTRB` |
| B 通道 | `BVALID && BREADY` 同拍时写响应完成 |
| 寄存器 | `slv_reg*` 是否在写事务完成后更新 |

调试 MOSI 数据错误时，优先确认 `0x20` 地址写入。`0x20` 对应 `slv_reg8`，是 SPI master 的 `mosi_data_i`。

```text
AWADDR = 0x20
WDATA  = 0x000000a5
WSTRB  = 4'b1111
slv_reg8 -> 0x000000a5
```

调试字节选通错误时，`WSTRB` 是关键证据。32-bit 数据总线中，`WSTRB[2]` 控制 `WDATA[23:16]` 是否写入目标寄存器。若 test 期望 byte2 更新，波形上需要同时看到 `WSTRB[2]=1` 和目标寄存器 byte2 发生变化。

## SPI 侧检查

SPI 侧需要先确定 mode 和 word length，再按对应采样边沿读 MOSI/MISO。`spi_mode_i[1]` 对应 `CPOL`，`spi_mode_i[0]` 对应 `CPHA`；`word_len_i` 决定一帧采样多少 bit。

| 配置 | 含义 |
|---|---|
| `spi_mode_i = 0` | Mode0，`CPOL=0`，`CPHA=0`，上升沿采样 |
| `word_len_i = 2` | 8-bit word |
| `CS=0` | SPI frame 有效 |
| `SCLK` 采样边沿 | 按 mode 选择上升沿或下降沿 |

以 Mode0、8-bit、MOSI 数据 `0xa5` 为例，`CS` 拉低后一帧内，按 SCLK 上升沿读到的 MOSI 应为：

```text
1 0 1 0 0 1 0 1 = 0xa5
```

若 AXI 写入、DUT 寄存器和 MOSI 引脚都显示 `0xa5`，scoreboard 的 `actual` 仍与 `expected` 不一致，错误范围收敛到 SPI monitor 的采样边沿、采样时刻或 shift 组包逻辑。

## 常用信号

```text
tb_top.axi_vif.ACLK
tb_top.axi_vif.ARESETN
tb_top.axi_vif.AWVALID
tb_top.axi_vif.AWREADY
tb_top.axi_vif.AWADDR
tb_top.axi_vif.WVALID
tb_top.axi_vif.WREADY
tb_top.axi_vif.WDATA
tb_top.axi_vif.WSTRB
tb_top.axi_vif.BVALID
tb_top.axi_vif.BREADY

tb_top.DUT.AXI_SPI_n_regs0.slv_reg2
tb_top.DUT.AXI_SPI_n_regs0.slv_reg4
tb_top.DUT.AXI_SPI_n_regs0.slv_reg8

tb_top.spi_vif.CS
tb_top.spi_vif.SCLK
tb_top.spi_vif.MOSI
tb_top.spi_vif.MISO
```

## 错误归类

| 现象 | 优先怀疑方向 |
|---|---|
| AXI 写入地址或数据错误 | sequence、driver、AW/W 通道握手 |
| `WSTRB` 有效但寄存器 byte 未更新 | DUT 寄存器写逻辑 |
| DUT 寄存器正确但 SPI 引脚错误 | SPI master RTL、mode/word length 配置 |
| SPI 引脚正确但 scoreboard actual 错误 | SPI monitor 采样边沿或组包 |
| expected 与 test 预期不一致 | reference model shadow register 或 AXI monitor 事务重建 |
| reset 后出现旧事务比较 | scoreboard FIFO 清理或 monitor reset abort |

## 复盘表述

面试中可以把 debug 过程压缩成一条完整证据链：

```text
scoreboard 在 axi_busy_test 中报 expected 0xa5、actual 0xb4。
根据日志时间点打开对应 FSDB，先确认 AXI 在 0x20 地址完成写入，WDATA 为 0xa5，WSTRB 为 4'hf。
随后检查 DUT 内部 slv_reg8，确认寄存器值为 0xa5。
再按 SPI Mode0 的上升沿采样 MOSI，波形显示实际传输 bit 序列为 1010_0101。
因此 DUT 传输路径正确，错误范围收敛到 SPI monitor 的采样/组包路径。
```

# AXI-LITE2SPI 验证计划

## 0. 当前状态

| 项目 | 状态 |
|---|---|
| DUT | AXI4-Lite Slave -> SPI Master 桥接 IP |
| 验证范围 | AXI-Lite 寄存器/协议 + SPI 功能/时序 + 复位 + RM/SCB |
| 回归规模 | 20 个主回归 test，覆盖 24 个核心检查点 |
| 主要结果 | 功能覆盖率 100%；项目自定义 SVA 覆盖率 100% |
| 剩余事项 | 主要剩余项为异常/负向场景和更细的时序断言，可作为后续增强 |

图例：`完成` 表示已由回归覆盖；`豁免` 表示符合设计意图或低收益；`待办` 表示可选后续工作。

说明：20 个 test 是 `Makefile` 中 `all_test` 的主回归入口数；按下方覆盖矩阵统计，共 24 个核心检查点。`ral_test` 保留为独立冒烟测试，不计入简历主口径。

---

## 1. 覆盖矩阵

| 模块/接口 | 检查点 | 状态 | 测试 / 实现 |
|---|---|---:|---|
| AXI-Lite | 寄存器 frontdoor 写 | 完成 | 通用配置 sequence + 定向测试 |
| AXI-Lite | 可读寄存器（`busy`, `miso_data`） | 完成 | `axi_busy_test`、MISO 回读测试 |
| AXI-Lite | write-only 配置写入生效 | 完成 | 配置寄存器写入后，通过 SPI 输出端到端体现 |
| AXI-Lite | AW/W 握手时序 | 完成 | `axi_handshake_test`：同时、AW 先到、W 先到、长延迟场景 |
| AXI-Lite | WSTRB 字节选通 | 完成 | `axi_wstrb_test`：单 byte lane + sparse mask |
| AXI-Lite | busy/status 状态 | 完成 | `axi_busy_test`：传输中 busy=1，结束后 busy=0 |
| AXI-Lite | BRESP/RRESP OKAY 路径 | 完成 | driver 捕获响应；DUT 固定返回 OKAY |
| AXI-Lite | 读写并发事务 | 完成 | `axi_concurrent_test`：写流发帧期间持续读 busy |
| SPI | Mode 0/1/2/3 | 完成 | `spi_mode_test`、`spi_random_test` |
| SPI | 字长 32/16/8/4 | 完成 | `spi_word_len_test`、`spi_random_test` |
| SPI | SCK 四档分频 | 完成 | `spi_sck_speed_test`、功能覆盖 |
| SPI | MOSI 数据模式 | 完成 | 全 0、全 1、0x55/0xAA、随机数据 |
| SPI | MISO 回读 | 完成 | `spi_miso_read_test`、全 0、全 1 |
| SPI | 背靠背多帧 | 完成 | `spi_burst_test` |
| SPI | 约束随机回归 | 完成 | `spi_random_test`：80 帧约束随机 |
| SPI 时序 | CS->SCK 延迟 | 完成 | `spi_cs_sck_test` 定向 sweep |
| SPI 时序 | SCK 周期 | 完成 | `spi_sck_speed_test` 定向 sweep |
| SPI 时序 | SCK->CS 延迟 | 完成 | `spi_sck_cs_test` 定向 sweep |
| SPI 时序 | IFG 帧间隔 | 完成 | `spi_ifg_test` |
| 复位 | AXI 复位期间保持空闲 | 完成 | `UVMTB/sva/axi_sva_checker.sv` |
| 复位 | SPI 引脚复位期间保持 idle | 完成 | `UVMTB/sva/spi_sva_checker.sv` |
| 复位 | 传输中复位与恢复 | 完成 | `reset_mid_test`、`reset_sva_test` |
| RM/SCB | AXI 输入事务生成期望 SPI 输出 | 完成 | `spi_ref_model.sv` |
| RM/SCB | expected/actual SPI 顺序比较 | 完成 | `tb_scoreboard.sv` |

---

## 2. 回归测试清单

| # | 测试名 | 目的 |
|---:|---|---|
| 1 | `spi_word_len_test` | 32/16/8/4-bit 字长 |
| 2 | `spi_mode_test` | SPI mode 0/1/2/3 |
| 3 | `spi_cs_sck_test` | CS 到 SCK 的启动延迟 |
| 4 | `spi_sck_cs_test` | SCK 到 CS 释放延迟 |
| 5 | `spi_ifg_test` | 帧间隔 IFG |
| 6 | `spi_sck_speed_test` | SCK 分频 / 周期 |
| 7 | `axi_busy_test` | busy/status 行为 |
| 8 | `axi_handshake_test` | AXI AW/W 握手时序变化 |
| 9 | `axi_wstrb_test` | WSTRB 字节选通 |
| 10 | `axi_concurrent_test` | AXI 读写并发压力 |
| 11 | `spi_burst_test` | SPI 背靠背多帧 |
| 12 | `spi_alternating_test` | MOSI 0x55 / 0xAA 交替模式 |
| 13 | `spi_data_all_0_test` | MOSI 全 0 数据 |
| 14 | `spi_data_all_1_test` | MOSI 全 1 数据 |
| 15 | `reset_mid_test` | 传输中复位 |
| 16 | `spi_miso_read_test` | MISO 回读 0x5A |
| 17 | `spi_miso_all_0_test` | MISO 全 0 |
| 18 | `spi_miso_all_1_test` | MISO 全 1 |
| 19 | `spi_random_test` | 80 帧约束随机回归 |
| 20 | `reset_sva_test` | 复位 SVA 多场景测试 |

---

## 3. SVA 计划

| 文件 | 断言 / cover | 检查内容 |
|---|---|---|
| `UVMTB/sva/spi_sva_checker.sv` | `SPI_RESET_CHK` | 复位期间 SPI 引脚保持 idle |
| `UVMTB/sva/axi_sva_checker.sv` | `AXI_RESET_CHK`, `AXI_RESET_RELEASE_CHK` | 复位期间和复位释放后的 AXI slave 输出空闲行为 |
| `UVMTB/sva/axi_sva_checker.sv` | `AXI_AW_STABLE_CHK`, `AXI_W_STABLE_CHK`, `AXI_AR_STABLE_CHK` | AW/W/AR 通道在 `VALID` 拉高且 `READY` 未到时保持 `VALID` 与 payload 稳定 |
| `UVMTB/sva/axi_sva_checker.sv` | `AXI_WRITE_RESP_CHK` | 写请求被接收后，在限定周期内返回 B 响应 |

---

## 4. RAL 保留项

项目中保留 `UVMTB/ral/axi_spi_reg_block.sv`、`UVMTB/ral/axi_spi_reg_adapter.sv` 和 `UVMTB/test/ral/ral_test.sv`，用于寄存器模型 frontdoor/backdoor 冒烟检查。简历主线聚焦 AXI-Lite 协议、SPI 功能/时序、RM/SCB 和 SVA，因此 `ral_test` 不计入主回归数量。

---

## 5. 覆盖率总结

| 覆盖类型 | 目标 | 结果 / 说明 |
|---|---:|---|
| 功能覆盖率 | 100% | `cg_spi_frame` cross bins 全命中 |
| SVA / assertion | 100% | 项目自定义 SVA 已覆盖 |
| DUT 行覆盖率 | 约 90% | 剩余项记录为 waiver |
| DUT 分支覆盖率 | 约 90% | 剩余项记录为 waiver |

Waiver 示例：

- 配置类 write-only 寄存器按设计不可通过 frontdoor 读回。
- 非法地址/default 分支收益较低，当前项目中按设计意图豁免。
- UVM 库内部无 attempt 的断言不计入项目自定义 SVA 覆盖缺口。

---

## 6. 剩余 / 可选工作

| 优先级 | 项目 | 原因 |
|---:|---|---|
| P1 | 异常/负向访问 | 非法地址、非法/边界寄存器写、busy 期间重复 start 等，可提高鲁棒性 |
| P2 | MISO model 扩展 | 当前定向 MISO 测试已满足项目展示；后续可扩展到更多数据模式 |
| P2 | 固定延时改事件等待 | 提升 test 鲁棒性，例如用 CS/busy 事件替代硬编码 `#` 延时 |

当前结论：作为实习导向的验证项目，关键功能、协议、时序、复位、RM/SCB 与 SVA 已覆盖。剩余项属于进一步打磨，不影响当前项目完整性。

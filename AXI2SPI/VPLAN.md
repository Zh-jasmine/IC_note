# AXI-LITE2SPI 验证计划

## 当前状态

AXI-LITE2SPI 是一个 AXI4-Lite slave 到 SPI master 的桥接 IP。验证环境从 AXI 总线侧产生寄存器访问，从 SPI 侧观察真实串行输出，再由 reference model 产生期望 SPI item，scoreboard 做 expected 和 actual 的顺序比较。

当前回归包含 21 个 test。功能覆盖 `cg_spi_frame` 已达到 100%。代码覆盖中，SPI master 主体覆盖较高，寄存器模块的条件覆盖和 toggle 覆盖仍有缺口，主要来自非法地址、未翻转响应位、保守地址译码和部分低收益分支。

| 项目 | 状态 |
|---|---|
| DUT | AXI4-Lite Slave -> SPI Master 桥接 IP |
| 验证范围 | AXI-Lite 寄存器/协议 + SPI 功能/时序 + 复位 + RAL |
| 回归规模 | `UVMTB/sim/Makefile` 中 21 个测试 |
| 回归结果 | `21/21 PASS` |
| 功能覆盖 | `cg_spi_frame = 100%` |
| 总覆盖 | `74.13%`，受 UVM 库和低收益 RTL 分支影响 |
| 剩余事项 | 异常访问、busy 期间重复 start、更细的 SPI FSM transition |

图例：`完成` 表示已有回归覆盖；`豁免` 表示符合设计意图或收益较低；`后续` 表示可继续增强。

## 覆盖矩阵

| 模块/接口 | 检查点 | 状态 | 测试 / 实现 |
|---|---|---:|---|
| AXI-Lite | 寄存器 frontdoor 写 | 完成 | 通用配置 sequence + 定向测试 |
| AXI-Lite | 可读寄存器 `busy` / `miso_data` | 完成 | `axi_busy_test`、MISO 测试、`ral_test` |
| AXI-Lite | write-only 寄存器行为 | 完成 | RAL frontdoor write + backdoor peek |
| AXI-Lite | AW/W 握手时序 | 完成 | `axi_handshake_test`：AW 先到、W 先到、同时到、长延迟 |
| AXI-Lite | WSTRB 字节选通 | 完成 | `axi_wstrb_test`：单 byte lane + sparse mask |
| AXI-Lite | busy/status 状态 | 完成 | `axi_busy_test`：传输中 busy=1，结束后 busy=0 |
| AXI-Lite | BRESP/RRESP OKAY 路径 | 完成 | driver 捕获响应，RM 检查 OKAY |
| AXI-Lite | 读写并发事务 | 完成 | `axi_concurrent_test`：写流发帧期间持续读 busy |
| AXI-Lite | 非法地址读写 | 豁免 | DUT 默认保持原值 / 返回 0，当前项目展示价值较低 |
| SPI | Mode 0/1/2/3 | 完成 | `spi_mode_test`、`spi_random_test` |
| SPI | 字长 32/16/8/4 | 完成 | `spi_word_len_test`、`spi_random_test` |
| SPI | SCK 四档分频 | 完成 | `spi_sck_speed_test`、功能覆盖 |
| SPI | MOSI 数据模式 | 完成 | 全 0、全 1、0x55/0xAA、随机数据 |
| SPI | MISO 回读 | 完成 | `spi_miso_read_test`、全 0、全 1 |
| SPI | 背靠背多帧 | 完成 | `spi_burst_test` |
| SPI | 约束随机回归 | 完成 | `spi_random_test`：80 帧约束随机 |
| SPI 时序 | CS -> SCK 延迟 | 完成 | `spi_cs_sck_test`、SVA |
| SPI 时序 | SCK 周期 | 完成 | `spi_sck_speed_test`、SVA |
| SPI 时序 | SCK -> CS 延迟 | 完成 | `spi_sck_cs_test`、SVA |
| SPI 时序 | IFG 帧间隔 | 完成 | `spi_ifg_test` |
| 复位 | AXI 复位期间保持空闲 | 完成 | `axi_reset_sva.sv` |
| 复位 | SPI 引脚复位期间保持 idle | 完成 | `spi_reset_sva.sv` |
| 复位 | 传输中复位与恢复 | 完成 | `reset_mid_test`、`reset_sva_test` |
| RM/SCB | 输入事务生成期望 SPI 输出 | 完成 | `spi_ref_model.sv` |
| RM/SCB | expected/actual SPI 比较 | 完成 | `tb_scoreboard.sv` |
| RAL | 寄存器模型 + adapter | 完成 | `axi_spi_reg_block.sv`、`axi_spi_reg_adapter.sv` |
| RAL | frontdoor/backdoor 冒烟测试 | 完成 | `ral_test` |

## 回归测试清单

| # | 测试名 | 目的 | 文件分类 |
|---:|---|---|---|
| 1 | `spi_word_len_test` | 32/16/8/4-bit 字长 | `test/spi/` |
| 2 | `spi_mode_test` | SPI mode 0/1/2/3 | `test/spi/` |
| 3 | `spi_cs_sck_test` | CS 到 SCK 的启动延迟 | `test/spi/` |
| 4 | `spi_sck_cs_test` | SCK 到 CS 释放延迟 | `test/spi/` |
| 5 | `spi_ifg_test` | 帧间隔 IFG | `test/spi/` |
| 6 | `spi_sck_speed_test` | SCK 分频 / 周期 | `test/spi/` |
| 7 | `axi_busy_test` | busy/status 行为 | `test/axi/` |
| 8 | `axi_handshake_test` | AXI AW/W 握手时序变化 | `test/axi/` |
| 9 | `axi_wstrb_test` | WSTRB 字节选通 | `test/axi/` |
| 10 | `axi_concurrent_test` | AXI 读写并发压力 | `test/axi/` |
| 11 | `spi_burst_test` | SPI 背靠背多帧 | `test/spi/` |
| 12 | `spi_alternating_test` | MOSI 0x55 / 0xAA 交替模式 | `test/spi/spi_data_pattern_tests.sv` |
| 13 | `spi_data_all_0_test` | MOSI 全 0 数据 | `test/spi/spi_data_pattern_tests.sv` |
| 14 | `spi_data_all_1_test` | MOSI 全 1 数据 | `test/spi/spi_data_pattern_tests.sv` |
| 15 | `reset_mid_test` | 传输中复位 | `test/reset/` |
| 16 | `spi_miso_read_test` | MISO 回读 0x5A | `test/miso/spi_miso_tests.sv` |
| 17 | `spi_miso_all_0_test` | MISO 全 0 | `test/miso/spi_miso_tests.sv` |
| 18 | `spi_miso_all_1_test` | MISO 全 1 | `test/miso/spi_miso_tests.sv` |
| 19 | `spi_random_test` | 80 帧约束随机回归 | `test/spi/` |
| 20 | `reset_sva_test` | 复位 SVA 多场景测试 | `test/reset/` |
| 21 | `ral_test` | RAL frontdoor/backdoor 冒烟测试 | `test/ral/` |

## 检查架构

当前检查链路分成三层。

```text
AXI monitor
  -> spi_ref_model.axi_fifo
  -> spi_ref_model.expected_spi_item
  -> scoreboard.expected_spi_fifo

SPI monitor
  -> scoreboard.actual_spi_fifo

scoreboard
  -> compare expected SPI item and actual SPI item
```

`spi_ref_model` 从 AXI monitor 接收 AW/W/B/AR/R 通道事件，恢复完整写事务。它维护 `word_len_shadow` 和 `mosi_data_shadow`，在 `START_ADDR` 写入 `data[0]=1` 时生成期望 SPI item。这个规则对应 DUT 行为：配置和 MOSI 数据先写入寄存器，start 写 1 才触发 SPI master 发帧。

`tb_scoreboard` 只比较 RM 输出的 expected SPI item 和 SPI monitor 捕获的 actual SPI item。reset 到来时，RM 清 AXI 暂存队列和 shadow 寄存器，scoreboard 清 expected/actual FIFO，避免 reset 前未完成的帧影响 reset 后比较。

## SVA 计划

| 文件 | 断言 / cover | 检查内容 |
|---|---|---|
| `UVMTB/sva/spi_sva_checker.sv` | SPI reset / 时序类检查 | SPI 引脚复位 idle、CS/SCK 关系、SCK 周期 |
| `UVMTB/sva/axi_sva_checker.sv` | AXI reset 类检查 | 复位期间 AXI slave 输出保持空闲，复位释放后保持稳定 |

项目自定义 assertion 当前无失败。覆盖率报告中 UVM 库内部无 attempt 的 assertion 不计入项目自定义 SVA 缺口。

## RAL 计划

| 寄存器组 | 访问属性 | 验证方法 |
|---|---|---|
| `start`、配置寄存器、`mosi_data` | WO | RAL frontdoor write + backdoor peek |
| `busy` | RO | 空闲状态下 RAL frontdoor read |
| `miso_data` | RO | RAL backdoor poke/read 路径冒烟 |

实现文件：

- 寄存器模型：`UVMTB/ral/axi_spi_reg_block.sv`
- Adapter：`UVMTB/ral/axi_spi_reg_adapter.sv`
- 测试：`UVMTB/test/ral/ral_test.sv`
- 接入方式：`reg_model.map.set_sequencer(env.axi_agt.axi_sqr, adapter)`

## 覆盖率总结

| 覆盖类型 | 结果 | 说明 |
|---|---:|---|
| Total score | 74.13% | 包含 UVM 库和所有编译进来的模块 |
| Line | 43.66% | UVM 库和部分低收益 RTL 分支拉低总分 |
| Condition | 64.29% | 主要缺口在 `AXI_SPI_n_regs` 地址译码和条件组合 |
| Toggle | 66.30% | AXI 地址低位、prot、resp 等信号未充分翻转 |
| FSM | 75.00% | SPI master 有少量 transition 未覆盖 |
| Branch | 69.63% | RTL default / 异常分支仍有缺口 |
| Assert | 100.00% | 项目有效 assertion 无失败 |
| Functional group | 100.00% | `cg_spi_frame` 全覆盖 |

主要模块：

| 模块 | Score | Line | Cond | Toggle | FSM | Branch |
|---|---:|---:|---:|---:|---:|---:|
| `AXI_SPI_n_regs` | 72.51% | 92.00% | 52.38% | 50.55% | - | 95.12% |
| `SPI_master` | 88.00% | 87.44% | 100.00% | 91.18% | 75.00% | 86.36% |
| `AXI_slave_top` | 82.55% | - | - | 82.55% | - | - |

功能覆盖明细：

| Coverpoint / cross | 结果 |
|---|---:|
| `cp_mode` | 4/4 |
| `cp_wlen` | 4/4 |
| `cp_speed` | 4/4 |
| `cp_data` | 2/2 |
| `x_mode_wlen` | 16/16 |
| `x_mode_speed` | 16/16 |

## 剩余工作

| 优先级 | 项目 | 原因 |
|---:|---|---|
| P1 | busy 期间重复 start | 能检查 DUT 对重入触发的处理，适合补强鲁棒性 |
| P1 | 非法地址 / 边界地址 | 能提高 `AXI_SPI_n_regs` 条件和分支覆盖 |
| P2 | MISO model 扩展 | 当前定向 MISO 测试足够展示，后续可扩展到更多 mode/word_len 组合 |
| P2 | 固定延时改事件等待 | 用 CS/busy 事件替代硬编码 `#` 延时，提高 test 稳定性 |
| P2 | SPI FSM transition 定向测试 | 用特定 reset/start 间隔打到剩余 transition |

当前结论：项目已经覆盖核心功能、协议、时序、复位和 RAL。后续增强集中在异常场景和代码覆盖 closure，不影响当前项目作为实习展示项目的完整性。

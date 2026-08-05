# Verdi 常用操作

Verdi 用 FSDB 波形文件还原仿真时序，用编译生成的 KDB/`simv.daidir` 建立源码、层次和信号之间的关联。调试时先从日志定位失败 test 和失败时间点，再打开对应 FSDB，在同一时间窗口里观察 DUT、interface、monitor 和 scoreboard 相关信号。

## 打开 FSDB

AXI-LITE2SPI 的仿真在临时构建目录中运行，FSDB 由 `tb_top.sv` 中的 `$fsdbDumpfile("tb_top.fsdb")` 生成。`make all_test` 会循环运行多个 test，每个 test 的原始波形名都叫 `tb_top.fsdb`，因此 Makefile 会把它拷贝成带 test 名的文件，避免被后续 test 覆盖。

在仿真目录打开指定 test 的波形：

```bash
cd ~/Desktop/vcs_sync/AXI_Lite2SPI/UVMTB/sim
verdi -ssf fsdb_spi_data_all_0_test.fsdb &
```

同时加载源码：

```bash
cd ~/Desktop/vcs_sync/AXI_Lite2SPI/UVMTB/sim
verdi -ssf fsdb_spi_data_all_0_test.fsdb -sv ../tb_top.sv &
```

使用 KDB/`simv.daidir` 打开层次和源码关联：

```bash
cd ~/Desktop/vcs_sync/AXI_Lite2SPI/UVMTB/sim
verdi -dbdir simv.daidir -ssf fsdb_spi_data_all_0_test.fsdb &
```

如果在临时构建目录中调试：

```bash
cd /tmp/AXI-LITE2SPI/UVMTB
verdi -dbdir simv.daidir -ssf tb_top.fsdb &
```

## FSDB 文件选择

| 文件 | 含义 | 使用场景 |
|---|---|---|
| `tb_top.fsdb` | 最近一次仿真的固定波形名 | 单 test 快速查看，或查看 `all_test` 最后一个 test |
| `fsdb_<test>.fsdb` | 按 test 名保存的波形副本 | `all_test` 后查看指定失败 test |
| `/tmp/AXI-LITE2SPI/UVMTB/tb_top.fsdb` | 临时构建目录中的原始波形 | 直接在构建目录中调试 |

`all_test` 后先从日志找失败 test，再打开同名 FSDB：

```bash
grep -RniE "UVM_ERROR|SCB_MISMATCH|SCB_UNEXP_SPI|SCB_FAIL|WSTRB mismatch|failed at" sim_*.log
verdi -ssf fsdb_<test>.fsdb -sv ../tb_top.sv &
```

例子：

```bash
verdi -ssf fsdb_spi_mode_test.fsdb -sv ../tb_top.sv &
verdi -ssf fsdb_axi_wstrb_test.fsdb -sv ../tb_top.sv &
verdi -ssf fsdb_reset_sva_test.fsdb -sv ../tb_top.sv &
```

## 跳转时间点

UVM 日志中的 `@ 1685000` 是仿真时间点。打开 FSDB 后在 Verdi 的时间输入框跳到该时间附近，再向前留出一段窗口观察请求、响应和采样过程。

```text
日志时间点: @ 1685000
建议观察范围: 1600000 ~ 1700000
```

## 窗口

| 操作 | 菜单 | 快捷键 |
|---|---|---|
| 打开 Instance 树 | View -> Instance | Ctrl+1 |
| 打开波形窗口 | View -> Waveform | Ctrl+4 |
| 打开源码窗口 | View -> Source Code | Ctrl+5 |
| 打开 Schematic | View -> Schematic | Ctrl+3 |

## 波形操作

| 操作 | 说明 | 快捷键 |
|---|---|---|
| 放大 | 水平放大波形 | `i` |
| 缩小 | 水平缩小波形 | `o` |
| 缩放到全屏 | 显示全部波形 | `f` |
| 放大选中区域 | 拖选区域后放大 | `z` |
| 添加 marker | 添加时间标记 | `m` |
| 下一个跳变沿 | 移到下一个值变化 | `n` |
| 上一个跳变沿 | 移到上一个值变化 | `p` |

## 信号操作

| 操作 | 说明 |
|---|---|
| 添加信号到波形 | 从 Instance/Source 选中信号，右键 Add to Waveform |
| 查看信号值 | 鼠标悬停或使用 marker/cursor |
| 搜索信号 | Waveform 窗口按 `/` 输入信号名 |
| 改显示格式 | 选中信号，右键 Radix -> Hex/Dec/Bin/ASCII |
| 分组信号 | 选中多个信号，右键 Group |
| 取消分组 | 右键组名，选择 Ungroup |

## AXI-LITE2SPI 常看信号

```text
tb_top.spi_vif.CS
tb_top.spi_vif.SCLK
tb_top.spi_vif.MOSI
tb_top.spi_vif.MISO

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
tb_top.axi_vif.ARVALID
tb_top.axi_vif.ARREADY
tb_top.axi_vif.RVALID
tb_top.axi_vif.RREADY
tb_top.axi_vif.RDATA

tb_top.DUT.AXI_SPI_n_regs0.slv_reg8
```

## 调试顺序

日志先给出失败 test、失败时间点和错误类型。波形负责回答错误来自 expected 生成、DUT 输出，还是 monitor/scoreboard 采样与组包。

```text
sim_<test>.log -> fsdb_<test>.fsdb -> 失败时间点 -> AXI 写入 -> DUT 寄存器 -> SPI 引脚 -> monitor 采样
```

Scoreboard mismatch 的定位顺序：

1. 在日志里记录 expected、actual 和时间点。
2. 打开对应 `fsdb_<test>.fsdb`。
3. 跳到日志时间点之前。
4. 确认 AXI 写寄存器事务是否完成。
5. 确认 DUT 寄存器值是否符合 AXI 写入。
6. 确认 SPI 引脚在 frame 内实际输出的 bit 序列。
7. 对比 monitor 采样点与 MOSI 变化关系。

## 保存/恢复波形设置

```text
File -> Save Session
File -> Restore Session
```

## 其他

| 操作 | 说明 |
|---|---|
| nWave -> Signal -> Value Radix | 批量改信号显示格式 |
| Tools -> Preferences -> Font | 改字体大小 |
| Tools -> Preferences -> Color | 改波形颜色 |
| Tools -> Waveform Calculate | 做简单计算 |

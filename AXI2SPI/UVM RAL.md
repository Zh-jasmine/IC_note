# UVM RAL

> 对照代码：`UVMTB/ral/axi_spi_reg_block.sv`、`UVMTB/ral/axi_spi_reg_adapter.sv`、`UVMTB/test/ral/ral_test.sv`

RAL 把 DUT 里的寄存器建模成 UVM 对象。test 访问寄存器时，可以调用 `reg.write()`、`reg.read()`、`peek()`、`poke()`，由 RAL map 和 adapter 把寄存器操作转换成 AXI transaction。这样 test 写的是寄存器语义，driver 仍然负责真实 AXI-Lite 时序。

在这个项目里，RAL 的主要价值是验证 AXI frontdoor 写路径和 backdoor 物理寄存器路径同时可用。配置寄存器通过 AXI 写入后会影响 SPI master，但 DUT 的 frontdoor 读译码只返回 `busy` 和 `miso_data`，所以多数配置寄存器在 RAL 中按 WO 建模。

## 结构

```text
ral_test.sv
  -> reg_model.<reg>.write/read/peek/poke()
  -> axi_spi_reg_block.sv
  -> axi_spi_reg_adapter.sv
  -> axi_seq_item
  -> axi_sequencer
  -> axi_driver
  -> AXI-Lite bus
  -> DUT
```

RAL 里有三类对象：

| 对象 | 责任 | 项目文件 |
|---|---|---|
| `uvm_reg` | 描述单个寄存器的字段、位宽、访问属性、复位值 | `reg_start`、`reg_status` 等 |
| `uvm_reg_block` | 收集 10 个寄存器，建立地址 map 和 HDL backdoor path | `axi_spi_reg_block` |
| `uvm_reg_adapter` | 在 RAL 请求和 AXI item 之间转换 | `axi_spi_reg_adapter` |

## 寄存器访问属性

DUT 有 10 个 32-bit `slv_reg`，地址范围 `0x00` 到 `0x24`。地址按 4 字节对齐，RTL 用 `addr[5:2]` 选择寄存器。

| 地址 | RAL 名称 | RTL 寄存器 | RAL access | 原因 |
|---:|---|---|---|---|
| `0x00` | `start` | `slv_reg0` | WO | 写 bit0 触发 SPI 传输，frontdoor 读不返回配置值 |
| `0x04` | `status` | `slv_reg1` | RO | `busy` 由 SPI master 硬件更新 |
| `0x08` | `spi_mode` | `slv_reg2` | WO | 配置可写，frontdoor 读回 0 |
| `0x0C` | `sck_speed` | `slv_reg3` | WO | 配置可写，frontdoor 读回 0 |
| `0x10` | `word_len` | `slv_reg4` | WO | 配置可写，frontdoor 读回 0 |
| `0x14` | `ifg` | `slv_reg5` | WO | 配置可写，frontdoor 读回 0 |
| `0x18` | `cs_sck` | `slv_reg6` | WO | 配置可写，frontdoor 读回 0 |
| `0x1C` | `sck_cs` | `slv_reg7` | WO | 配置可写，frontdoor 读回 0 |
| `0x20` | `mosi_data` | `slv_reg8` | WO | 待发送数据可写，frontdoor 读回 0 |
| `0x24` | `miso_data` | `slv_reg9` | RO | MISO 接收数据由硬件更新，frontdoor 可读 |

这个 access policy 必须按 DUT 的可观察行为建模。配置寄存器虽然物理上存在，也能被 AXI 写进去，但 frontdoor 读译码没有返回这些寄存器，所以 RAL 用 WO。验证写入是否成功时，用 frontdoor write 走真实总线，再用 backdoor peek 读物理寄存器。

## uvm_reg

单个寄存器类继承 `uvm_reg`。它描述字段位宽、最低位、访问属性、volatile 属性和复位值。

```systemverilog
class reg_word_len extends uvm_reg;
    `uvm_object_utils(reg_word_len)
    rand uvm_reg_field wlen;

    function new(string name = "reg_word_len");
        super.new(name, 32, UVM_NO_COVERAGE);
    endfunction

    virtual function void build();
        wlen = uvm_reg_field::type_id::create("wlen");
        wlen.configure(this, 2, 0, "WO", 0, 2'h0, 1, 1, 1);
    endfunction
endclass
```

`configure()` 的关键参数：

| 参数 | 项目里的含义 |
|---|---|
| `size` | 字段位宽，例如 `word_len` 是 2 bit，`mosi_data` 是 32 bit |
| `lsb_pos` | 字段最低位位置，本项目字段都从 bit0 开始 |
| `access` | `WO` 或 `RO`，按 DUT frontdoor 可观察行为填写 |
| `volatile` | 硬件会主动变化的 RO 字段设为 1，例如 `busy`、`miso_data` |
| `reset` | DUT 复位后的字段值 |
| `has_reset` | RAL 是否记录复位值 |
| `is_rand` | 字段是否参与寄存器随机化 |

## uvm_reg_block

`axi_spi_reg_block` 收集所有寄存器对象，并建立地址映射。

```systemverilog
map = create_map("map", 32'h0, 4, UVM_LITTLE_ENDIAN, 1);
map.add_reg(start,     32'h00, "WO");
map.add_reg(status,    32'h04, "RO");
map.add_reg(spi_mode,  32'h08, "WO");
map.add_reg(sck_speed, 32'h0C, "WO");
map.add_reg(word_len,  32'h10, "WO");
map.add_reg(ifg,       32'h14, "WO");
map.add_reg(cs_sck,    32'h18, "WO");
map.add_reg(sck_cs,    32'h1C, "WO");
map.add_reg(mosi_data, 32'h20, "WO");
map.add_reg(miso_data, 32'h24, "RO");
```

`create_map("map", 32'h0, 4, UVM_LITTLE_ENDIAN, 1)` 表示：

| 参数 | 含义 |
|---|---|
| `32'h0` | 寄存器块基地址 |
| `4` | 总线每次访问 4 byte |
| `UVM_LITTLE_ENDIAN` | 小端映射 |
| `1` | byte addressing |

`lock_model()` 在 build 末尾调用，表示寄存器结构已经固定。后续 test 可以访问模型，不能继续修改寄存器层次和 map。

## Backdoor path

backdoor 访问需要 RAL 知道 HDL 里的物理路径。项目里 block 级 root path 指向 DUT 内部寄存器模块，每个 reg 再绑定到对应 `slv_regN`。

```systemverilog
add_hdl_path("tb_top.DUT.AXI_SPI_n_regs0");
word_len.add_hdl_path_slice("slv_reg4", 0, 32);
mosi_data.add_hdl_path_slice("slv_reg8", 0, 32);
```

完整路径会组合成：

```text
tb_top.DUT.AXI_SPI_n_regs0.slv_reg4
tb_top.DUT.AXI_SPI_n_regs0.slv_reg8
```

`peek()` 底层调用 `uvm_hdl_read()`，`poke()` 底层调用 `uvm_hdl_deposit()`。这条路径绕过 AXI 总线，直接访问仿真层级里的 HDL 信号。

## Frontdoor 和 Backdoor

| 访问方式 | 调用 | 路径 | 仿真时间 | 当前用途 |
|---|---|---|---|---|
| frontdoor write | `reg.write(status, value)` | RAL -> adapter -> AXI driver -> DUT | 需要 AXI 握手 | 验证真实总线写路径 |
| frontdoor read | `reg.read(status, value)` | RAL -> adapter -> AXI driver -> DUT | 需要 AXI 握手 | 读取 `busy`、`miso_data` |
| backdoor peek | `reg.peek(status, value)` | `uvm_hdl_read` 直接读 RTL 信号 | 不推进总线事务 | 检查 WO 配置寄存器物理值 |
| backdoor poke | `reg.poke(status, value)` | `uvm_hdl_deposit` 直接写 RTL 信号 | 不推进总线事务 | 演示 / 快速设置 / 特殊检查 |

配置寄存器的典型检查流程：

```text
frontdoor write spi_mode = 2
  -> AXI driver 发起真实写事务
  -> DUT slv_reg2 被写入
  -> backdoor peek slv_reg2
  -> 比较 peek 值是否等于 2
```

这条检查同时覆盖两件事：AXI 写路径可用，物理寄存器确实更新。

## Adapter

adapter 把 RAL 的 `uvm_reg_bus_op` 转成项目自己的 `axi_seq_item`。

```systemverilog
virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
    axi_seq_item item;
    item = axi_seq_item::type_id::create("axi_reg_item");
    item.kind  = AXI_CH_REQ;
    item.write = (rw.kind == UVM_WRITE);
    item.addr  = rw.addr;
    item.wdata = rw.data;
    item.wstrb = rw.byte_en;
    if (item.wstrb == 4'h0) item.wstrb = 4'hF;
    return item;
endfunction
```

`bus2reg()` 把 driver 执行后的 AXI item 转回 RAL 结果：

```systemverilog
rw.kind   = item.write ? UVM_WRITE : UVM_READ;
rw.addr   = item.addr;
rw.data   = item.write ? item.wdata : item.rdata;
rw.status = ((item.write && item.bresp == 2'b00) ||
             (!item.write && item.rresp == 2'b00)) ? UVM_IS_OK : UVM_NOT_OK;
```

当前 adapter 设置：

| 字段 | 值 | 含义 |
|---|---:|---|
| `supports_byte_enable` | 1 | RAL 可以把 byte enable 传给 `wstrb` |
| `provides_responses` | 1 | driver 执行后提供 response，adapter 根据 `bresp/rresp` 设置 RAL status |

`reg2bus()` 中如果 `rw.byte_en` 为 0，会把 `wstrb` 补成 `4'hF`。这样普通寄存器写默认是全字节写。

## ral_test

`ral_test` 是 RAL 冒烟测试，不触发 SPI 传输，也不依赖 scoreboard 判断 pass/fail。它验证 RAL 模型、adapter、frontdoor 和 backdoor 路径能连通。

测试流程：

```text
1. 等 reset 释放
2. backdoor peek 检查 WO 配置寄存器复位值为 0
3. WO 寄存器 frontdoor write
4. backdoor peek 同一个寄存器，确认物理值等于写入值
5. frontdoor read status，确认 idle 时 busy=0
6. 对 miso_data 做 poke/read 路径演示
```

`ral_test` 在 `connect_phase` 中把 RAL map 接到现有 AXI sequencer：

```systemverilog
reg_model.map.set_sequencer(env.axi_agt.axi_sqr, adapter);
reg_model.map.set_auto_predict(1);
```

`set_auto_predict(1)` 表示 frontdoor 操作完成后，RAL 自动更新 mirror。当前项目没有单独接 predictor，因此 auto predict 是最简洁的选择。

## Mirror 和物理寄存器

RAL mirror 是 UVM 模型内部维护的一份影子值。它代表 RAL 认为寄存器当前应该是什么值。物理寄存器是 DUT RTL 里的 `slv_regN`。

在本项目中，配置寄存器的验证重点是物理寄存器：

```text
reg.write()
  -> mirror 可被 auto_predict 更新
  -> DUT 物理寄存器也应该被 AXI 写入
  -> backdoor peek 检查物理值
```

只看 mirror 会漏掉 adapter、driver、地址映射或 RTL 写路径问题。frontdoor write + backdoor peek 能检查真实写入是否落到对应 `slv_regN`。

## 当前边界

- RAL 已完成寄存器建模、adapter 接入、frontdoor/backdoor 冒烟测试。
- 当前普通 SPI 功能测试仍主要使用 `axi_spi_cfg_seq`，没有全面迁移成 RAL sequence。
- RAL register coverage 没单独打开，功能覆盖由 `tb_coverage::cg_spi_frame` 负责。
- `miso_data` 由硬件刷新，`poke()` 后很快会被 RTL 重新赋值，所以 `ral_test` 只把它作为 backdoor 调用链演示。

面试时可以这样讲：

```text
这个项目里的 RAL 用来建模 AXI-Lite 寄存器。
配置寄存器按 WO 建模，因为 DUT frontdoor 读译码只返回 busy 和 miso_data。
测试时用 frontdoor write 走真实 AXI 总线，再用 backdoor peek 检查 slv_reg 物理值。
adapter 负责把 uvm_reg_bus_op 转成 axi_seq_item，并根据 bresp/rresp 返回 RAL status。
```

# interface 基本写法

[[SV&UVM#^sv-interface-basic|返回原处]]

## 原代码

```verilog
interface apb_if(input logic clk, input logic rst_n);
    logic        psel;
    logic        penable;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pwrite;
endinterface
```

## interface 解决什么问题

interface 用来封装一组协议相关信号。没有 interface 时，一个 APB/AXI 端口可能要在 DUT、driver、monitor、top 之间重复声明和连接大量信号。

interface 的价值：

- 减少模块端口连接数量。
- 把协议相关信号集中管理。
- 可以放 `clocking block`、`modport`、task、function、assertion。
- 通过 `virtual interface` 连接 UVM class 世界和 module 世界。

## 逐行语法

```verilog
interface apb_if(input logic clk, input logic rst_n);
```

定义一个名为 `apb_if` 的 interface 类型，并声明两个端口：`clk` 和 `rst_n`。

这里的 `clk/rst_n` 通常来自 testbench top：

```verilog
apb_if apb_vif(.clk(clk), .rst_n(rst_n));
```

```verilog
logic        psel;
logic        penable;
logic [31:0] paddr;
```

这些是接口内部信号。DUT 可以连接它们，driver 可以驱动它们，monitor 可以采样它们。

```verilog
endinterface
```

结束 interface 定义。

## 在 top 中实例化

```verilog
module tb_top;
    logic clk;
    logic rst_n;

    apb_if apb_vif(
        .clk(clk),
        .rst_n(rst_n)
    );

    dut u_dut(
        .clk    (clk),
        .rst_n  (rst_n),
        .psel   (apb_vif.psel),
        .penable(apb_vif.penable),
        .paddr  (apb_vif.paddr),
        .pwdata (apb_vif.pwdata),
        .prdata (apb_vif.prdata),
        .pwrite (apb_vif.pwrite)
    );
endmodule
```

interface 是静态结构，必须在 module 层实例化。

## modport

```verilog
modport dut_mp (
    input  clk,
    input  rst_n,
    input  psel,
    input  penable,
    input  paddr,
    input  pwdata,
    input  pwrite,
    output prdata
);
```

modport 定义访问方向。对 DUT 来说，`psel/paddr/pwdata` 是输入，`prdata` 是输出。

modport 的意义不是创建新信号，而是限制不同角色能怎样访问 interface。

## clocking block

```verilog
clocking drv_cb @(posedge clk);
    default input #1step output #1ns;
    output psel, penable, paddr, pwdata, pwrite;
    input  prdata;
endclocking
```

clocking block 定义 testbench 驱动和采样的时序，减少 race condition。

driver 可以这样使用：

```verilog
@(vif.drv_cb);
vif.drv_cb.psel  <= 1'b1;
vif.drv_cb.paddr <= tr.addr;
```

## virtual interface

UVM driver 是 class，不能直接实例化 interface，所以需要保存一个 virtual interface handle：

```verilog
class apb_driver extends uvm_driver #(apb_item);
    virtual apb_if vif;
endclass
```

top 或 test 把真实 interface 实例传给 UVM：

```verilog
uvm_config_db#(virtual apb_if)::set(
    null,
    "uvm_test_top.env.apb_agent",
    "vif",
    apb_vif
);
```

## 易错点

- interface 是静态结构，在 module 层实例化。
- class 中只能保存 `virtual interface`，不能直接声明普通 interface 实例。
- modport 是方向视图，不是复制一份信号。
- driver 和 monitor 最好使用不同 clocking block。
- 多接口环境不要用 `"*"` 乱传 vif。

## 面试说法

可以这样答：

interface 用来封装协议相关信号，降低端口连接复杂度。它可以包含 modport、clocking block、task 和 assertion。UVM class 不能直接访问 module 层 interface 实例，所以通常在 top 中实例化 interface，再通过 `uvm_config_db` 把它作为 `virtual interface` 传给 driver 和 monitor。


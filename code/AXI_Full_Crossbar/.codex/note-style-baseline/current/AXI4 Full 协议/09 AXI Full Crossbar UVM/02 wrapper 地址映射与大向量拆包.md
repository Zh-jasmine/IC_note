# 02 wrapper 地址映射与大向量拆包

文件：

```text
10_uvm_work/tb/top/axi_crossbar_2m3s_wrapper.sv
```

`axi_crossbar` DUT 为了支持参数化多主多从，没有把端口写死成：

```text
s0_awaddr, s1_awaddr, ...
m0_awaddr, m1_awaddr, m2_awaddr, ...
```

而是把同类 AXI 信号合成大向量：

```text
s_axi_awaddr = {S1_awaddr, S0_awaddr}
m_axi_awaddr = {M2_awaddr, M1_awaddr, M0_awaddr}
```

然后 DUT 内部用切片处理每一路：

```text
s_axi_awaddr[i*ADDR_WIDTH +: ADDR_WIDTH]
m_axi_awaddr[j*ADDR_WIDTH +: ADDR_WIDTH]
```

所以 wrapper 的作用就是：

1. 把 `axi_if[]` 的字段打包成 DUT 需要的大向量
2. 再把 DUT 输出的大向量拆回 `axi_if[]`
3. 配置地址窗口和连接矩阵

## 地址映射

master 的基地址由 wrapper 配置：

| M 侧端口 | 地址范围 | 对应 UVM slave |
| --- | --- | --- |
| M0 | `0x0000_0000 - 0x0000_0FFF` | `slave_agent0` |
| M1 | `0x0001_0000 - 0x0001_0FFF` | `slave_agent1` |
| M2 | `0x0002_0000 - 0x0002_0FFF` | `slave_agent2` |

对应配置：

```systemverilog
localparam [M_COUNT*ADDR_WIDTH-1:0] M_BASE_ADDR = {
    32'h0002_0000,
    32'h0001_0000,
    32'h0000_0000
};

localparam [M_COUNT*32-1:0] M_ADDR_WIDTH = {M_COUNT{32'd12}};
```

`32'd12` 表示每个窗口是 `2^12 = 4096 byte = 4KB`。

## 理解要点

- `s_axi_if[]` 接 UVM master agent。
- `m_axi_if[]` 接 UVM slave agent memory model。
- wrapper 只是桥接和配置，不是功能 DUT。

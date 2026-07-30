# 01 axi_crossbar 顶层参数和端口

文件：

```text
00_core_dut/rtl/axi_crossbar.v
```

## 顶层参数

| 参数 | 含义 | 说明 |
| --- | --- | --- |
| `S_COUNT` | crossbar 输入侧接口数量 | 外部 master 数量 |
| `M_COUNT` | crossbar 输出侧接口数量 | 外部 slave 数量 |
| `DATA_WIDTH` | 数据总线位宽 | 决定 `WDATA/RDATA` 和 `WSTRB` |
| `ADDR_WIDTH` | 地址位宽 | 决定地址空间 |
| `STRB_WIDTH` | `DATA_WIDTH/8` | 每个 byte lane 一个 strobe |
| `S_ID_WIDTH` | S 侧 ID 宽度 | master 发起请求时的 ID 宽度 |
| `M_ID_WIDTH` | M 侧 ID 宽度 | crossbar 转发到 slave 时的 ID 宽度 |
| `M_BASE_ADDR` | 每个 M 侧 slave 的基地址 | 地址 decode 核心配置 |
| `M_ADDR_WIDTH` | 每个地址窗口大小 | 决定每个 slave 占多大范围 |
| `M_CONNECT_READ` | 读连接矩阵 | 哪些 master 可以读哪些 slave |
| `M_CONNECT_WRITE` | 写连接矩阵 | 哪些 master 可以写哪些 slave |

最重要的 ID 关系：

```systemverilog
M_ID_WIDTH = S_ID_WIDTH + $clog2(S_COUNT)
```

原因：crossbar 发给 slave 的 ID 里需要附加来源 master 信息。slave 返回 `BID/RID` 时，crossbar 才知道响应应该送回哪个 S 侧 master。

## 五通道方向

| 通道 | S 侧方向 | M 侧方向 | 说明 |
| --- | --- | --- | --- |
| AW | master -> crossbar | crossbar -> slave | 写地址 |
| W | master -> crossbar | crossbar -> slave | 写数据 |
| B | crossbar -> master | slave -> crossbar | 写响应 |
| AR | master -> crossbar | crossbar -> slave | 读地址 |
| R | crossbar -> master | slave -> crossbar | 读数据响应 |

## 端口信号分组

S 侧端口：外部 master 访问 crossbar 的入口。

| 通道 | S 侧端口信号 |
| --- | --- |
| AW | `s_axi_awid`, `s_axi_awaddr`, `s_axi_awlen`, `s_axi_awsize`, `s_axi_awburst`, `s_axi_awlock`, `s_axi_awcache`, `s_axi_awprot`, `s_axi_awqos`, `s_axi_awuser`, `s_axi_awvalid`, `s_axi_awready` |
| W | `s_axi_wdata`, `s_axi_wstrb`, `s_axi_wlast`, `s_axi_wuser`, `s_axi_wvalid`, `s_axi_wready` |
| B | `s_axi_bid`, `s_axi_bresp`, `s_axi_buser`, `s_axi_bvalid`, `s_axi_bready` |
| AR | `s_axi_arid`, `s_axi_araddr`, `s_axi_arlen`, `s_axi_arsize`, `s_axi_arburst`, `s_axi_arlock`, `s_axi_arcache`, `s_axi_arprot`, `s_axi_arqos`, `s_axi_aruser`, `s_axi_arvalid`, `s_axi_arready` |
| R | `s_axi_rid`, `s_axi_rdata`, `s_axi_rresp`, `s_axi_rlast`, `s_axi_ruser`, `s_axi_rvalid`, `s_axi_rready` |

M 侧端口：crossbar 访问外部 slave 的出口。

| 通道 | M 侧端口信号 |
| --- | --- |
| AW | `m_axi_awid`, `m_axi_awaddr`, `m_axi_awlen`, `m_axi_awsize`, `m_axi_awburst`, `m_axi_awlock`, `m_axi_awcache`, `m_axi_awprot`, `m_axi_awqos`, `m_axi_awregion`, `m_axi_awuser`, `m_axi_awvalid`, `m_axi_awready` |
| W | `m_axi_wdata`, `m_axi_wstrb`, `m_axi_wlast`, `m_axi_wuser`, `m_axi_wvalid`, `m_axi_wready` |
| B | `m_axi_bid`, `m_axi_bresp`, `m_axi_buser`, `m_axi_bvalid`, `m_axi_bready` |
| AR | `m_axi_arid`, `m_axi_araddr`, `m_axi_arlen`, `m_axi_arsize`, `m_axi_arburst`, `m_axi_arlock`, `m_axi_arcache`, `m_axi_arprot`, `m_axi_arqos`, `m_axi_arregion`, `m_axi_aruser`, `m_axi_arvalid`, `m_axi_arready` |
| R | `m_axi_rid`, `m_axi_rdata`, `m_axi_rresp`, `m_axi_rlast`, `m_axi_ruser`, `m_axi_rvalid`, `m_axi_rready` |

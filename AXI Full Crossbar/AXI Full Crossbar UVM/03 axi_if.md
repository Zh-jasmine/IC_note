# 03 axi_if 

文件：

```text
10_uvm_work/tb/interfaces/axi_if.sv
```

## 五通道字段

| 通道 | 信号 | 含义 |
| --- | --- | --- |
| AW | `awid/awaddr/awlen/awsize/awburst/.../awvalid/awready` | 写地址握手 |
| W | `wdata/wstrb/wlast/wvalid/wready` | 写数据 beat |
| B | `bid/bresp/bvalid/bready` | 写响应 |
| AR | `arid/araddr/arlen/arsize/arburst/.../arvalid/arready` | 读地址握手 |
| R | `rid/rdata/rresp/rlast/rvalid/rready` | 读数据 beat |

## 两个初始化任务

```text
init_master_outputs()
  清零 master 主动驱动 AW/W/AR 请求信号，以及 BREADY/RREADY。

init_slave_outputs()
  清零 slave 主动驱动 AWREADY/WREADY/ARREADY，以及 B/R valid信号。
```


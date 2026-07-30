# 03 axi_if 五通道与角色初始化

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
  master 主动驱动 AW/W/AR 请求信号，以及 BREADY/RREADY。

init_slave_outputs()
  slave 主动驱动 AWREADY/WREADY/ARREADY，以及 B/R 响应信号。
```

## 角色和主动驱动信号

| 角色 | 主动驱动什么 |
| --- | --- |
| master | `AWVALID/WVALID/ARVALID/BREADY/RREADY` 和请求 payload |
| slave | `AWREADY/WREADY/ARREADY/BVALID/RVALID` 和响应 payload |

## 记忆方式

- 谁发送，谁出 `valid`
- 谁接收，谁出 `ready`

所以：

- `AW/W/AR` 通道里 master 是发送方
- `B/R` 通道里 master 是接收方

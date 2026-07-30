# 06 axi_monitor 通道级采样

文件：

```text
10_uvm_work/tb/axi_agent/axi_monitor.svh
```

monitor 的任务：观察总线，不主动驱动信号。

## 核心采样原则

```systemverilog
if (VALID && READY) sample();
```

为什么必须这样：

- `VALID=1` 只表示发送方有东西
- `READY=1` 只表示接收方能接
- 只有 `VALID && READY` 同时成立，才说明这拍真正完成 transfer

## S 侧和 M 侧

```text
is_m_side == 0:
  monitor 使用 s_vif
  观察 master -> crossbar 以及 crossbar -> master

is_m_side == 1:
  monitor 使用 m_vif
  观察 crossbar -> slave 以及 slave -> crossbar
```

## monitor item 内容

| kind | 来源通道 | item 保存字段 |
| --- | --- | --- |
| `AXI_MON_AW` | AW | `id/addr/len/size/burst` |
| `AXI_MON_W` | W | `data/strb/last` |
| `AXI_MON_B` | B | `id/resp` |
| `AXI_MON_AR` | AR | `id/addr/len/size/burst` |
| `AXI_MON_R` | R | `id/data/resp/last` |

当前 monitor 的粒度是通道级 item，不是完整 transaction。

所以：

- 一个 burst 写事务会产生 1 个 AW item、多个 W item、1 个 B item
- 一个 burst 读事务会产生 1 个 AR item、多个 R item
- 后续 scoreboard 要把这些 item 重新组合起来

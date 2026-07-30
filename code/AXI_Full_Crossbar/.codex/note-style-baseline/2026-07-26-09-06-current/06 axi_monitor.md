# 06 axi_monitor 

文件：

```text
10_uvm_work/tb/axi_agent/axi_monitor.svh
```

`axi_monitor` 不驱动任何 AXI 信号。它在时钟边沿观察接口，把已经完成的通道握手转换成 `axi_mon_item`，再通过 analysis port 广播给 scoreboard 和 coverage。


AXI 的 payload 只有在 `VALID && READY` 的那个时钟边沿才被接收。所以只有两者同时为1才代表数据已传输。单独观察 `VALID` 或 `READY` 都不能代表一次传输：前者可能只是发送方保持等待，后者可能只是接收方提前声明可以接收。

因此两个采样 task 都遵循同一条规则：

```text
等待 aresetn == 1
每个 posedge aclk:
  AWVALID && AWREADY -> 生成 AW item
  WVALID  && WREADY  -> 生成 W item
  BVALID  && BREADY  -> 生成 B item
  ARVALID && ARREADY -> 生成 AR item
  RVALID  && RREADY  -> 生成 R item
```

五个 `if` 独立判断各通道的握手状态。同一个时钟边沿可以同时完成多个通道的握手。

## TLM 连接

工程中 master agent 连接 S 侧接口，slave agent 连接 M 侧接口；因此 agent 名称和 monitor 的 `is_m_side` 含义要分开看：

| 创建位置 | `is_m_side` | 读取的 virtual interface | `port_index` 含义 | 下游 FIFO |
| --- | ---: | --- | --- | --- |
| `master_agent[i].mon` | `0` | `axi_s_vif_t s_vif` | 第 `i` 个 S 端口 | `scb.s_fifo[i]` |
| `slave_agent[i].mon` | `1` | `axi_m_vif_t m_vif` | 第 `i` 个 M 端口 | `scb.m_fifo[i]` |

配置链路是：`tb_top` 为每个 agent 设置 `vif`，`axi_env` 设置 `port_index`，agent 在 build phase 为 monitor 设置 `is_m_side`。monitor 再根据这个 bit 选择 `s_vif` 或 `m_vif`，所以采样逻辑只写一份。

```text
tb_top: vif[i]
       |
axi_env: port_index=i
       |
agent: is_m_side
       |
axi_monitor: 选择 s_vif / m_vif
       |
ap.write(axi_mon_item)
       +--> scoreboard FIFO
       +--> coverage subscriber
```

`build_phase` 取不到对应类型的 virtual interface 时会立即 `uvm_fatal`。这是必要的，因为没有绑定到真实接口的 monitor 继续运行只会产生误导性的空观测。

## `axi_mon_item` 保存的信息

`base_item()` 先填入所有事件共有的元数据：

| 字段 | 作用 |
| --- | --- |
| `kind` | 区分 AW/W/B/AR/R |
| `port_index` | 标识第几个 S/M 端口 |
| `is_m_side` | 标识事件来自 S 侧还是 M 侧 |

随后各 `publish_*()` 只填当前通道的字段：

| `kind` | 采样字段 |
| --- | --- |
| `AXI_MON_AW` | `id / addr / len / size / burst` |
| `AXI_MON_W` | `data / strb / last` |
| `AXI_MON_B` | `id / resp` |
| `AXI_MON_AR` | `id / addr / len / size / burst` |
| `AXI_MON_R` | `id / data / resp / last` |

这与 AXI 的协议结构一致：AW、W、B 和 AR、R 是独立通道，不能假设地址、数据和响应在同一拍出现。于是一次 burst 会产生：

```text
写：1 AW + (AWLEN + 1) 个 W + 1 B
读：1 AR + (ARLEN + 1) 个 R
```

monitor 只记录每次通道握手的信息，暂时不把这些 item 配成完整事务。配对必须放在更高层完成：写侧至少要把 AW 上下文与后续 W beat、B 响应关联起来；读侧要把 AR 上下文与一串 R beat 关联起来。尤其要注意，AXI4 的 W 通道没有 ID，不能只靠一个 W item 自己完成归属判断。

## S/M 两侧观察到的 ID

S 侧 interface 使用 `AXI_S_ID_WIDTH`，M 侧使用更宽的 `AXI_M_ID_WIDTH`。因此同一个 `axi_mon_item.id` 在两侧的含义不同：

- S 侧看到的是 master 原始 ID。
- M 侧看到的是 crossbar 扩展后的 ID，通常还携带 source master 信息。

scoreboard 不能直接把两侧 ID 当作同一命名空间比较；它需要结合 `port_index` 和 crossbar 的 ID 映射规则，验证响应是否回到了发起请求的 S 端口。

## 当前实现的边界

- item 没有保存 `AW/AR` 的 lock、cache、prot、qos、user，也没有保存 `B/R` 的 user；如果这些字段需要验证，必须扩展 `axi_mon_item` 和各 `publish_*()`。
- monitor 只在启动时等待一次 `aresetn` 释放。运行中再次 reset 时，它不会清空上下文，也不会发出 reset 边界事件；事务级 scoreboard 需要自行处理这一点。
- 当前接口没有 clocking block。现有 driver 使用非阻塞赋值、在时钟边沿推进信号，通常可以按握手边沿采到正确值；若以后混入不同调度区域的 DUT/driver，最好统一 clocking block 或明确采样区域，避免竞态。
- monitor 本身不检查协议错误，例如 `VALID` 拉高后 payload 是否保持稳定、`WLAST/RLAST` 是否落在正确 beat。这些属于 SVA 或事务级 checker 的职责。

当前 monitor 负责提供总线事件。下一层工作的重点是按端口、ID 和通道上下文重组事务，再交给 scoreboard 做路由、数据、响应和顺序检查。

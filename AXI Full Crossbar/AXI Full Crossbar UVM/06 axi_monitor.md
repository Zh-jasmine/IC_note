# 06 axi_monitor

文件：

```text
10_uvm_work/tb/axi_agent/axi_monitor.svh
```

`axi_monitor` 负责把 AXI interface 上已经完成的通道传输记录下来，并把这些记录交给后面的检查和覆盖率使用。`axi_monitor` 在每个时钟边沿判断 AW、W、B、AR、R 哪些通道发生了有效传输（握手）；每发生一次传输，就创建一条 `axi_mon_item`，记录这次传输所属的通道、端口位置、接口侧别，以及这一通道携带的 payload 字段。后续 scoreboard 能够拿这些记录恢复读写事务，coverage 能够拿这些记录统计通道行为，monitor 这一层的核心价值就在于把总线上的离散事件稳定保存下来。

AXI 的写地址、写数据、写响应、读地址、读数据分在五条独立通道上。一次 burst write 在接口上会展开成 1 次 AW 传输、若干次 W beat、最后 1 次 B 响应；一次 burst read 会展开成 1 次 AR 传输和若干次 R beat。monitor 的任务因此天然是逐通道、逐拍记录。它先把每条已经成立的通道传输保存成一条记录，再由 scoreboard 根据端口、ID、通道顺序和 `last` 信息恢复更大的读写上下文。

## 整体结构

monitor 的工作链路可以先看成下面这条链：

```text
build_phase()
  读取 port_index / is_m_side / vif
  绑定 s_vif 或 m_vif

run_phase()
  if is_m_side
    sample_m_side()
  else
    sample_s_side()

sample_s_side() / sample_m_side()
  wait reset release
  every posedge aclk:
    check AW/W/B/AR/R handshakes
    call publish_*()

publish_aw_*() / publish_w_*() / publish_b_*() / publish_ar_*() / publish_r_*()
  base_item(kind)
  fill channel payload
  ap.write(item)
```

monitor 先在 `sample_s_side()` 或 `sample_m_side()` 里判断这一拍哪些通道完成了 `VALID && READY` 握手；某个通道握手成立后，就调用对应的 `publish_*()` 创建一条 `axi_mon_item`。这条 item 先由 `base_item()` 填入公共信息，包括 `kind`、`port_index` 和 `is_m_side`；随后 `publish_*()` 再填入当前通道自己的 payload，比如 AW 的 `id/addr/len/size/burst`，或者 W 的 `data/strb/last`。字段填完后，`ap.write(item)` 把这条记录送给 scoreboard 和 coverage。这样分开以后，整套代码就围绕一条清晰的链路展开，后面再看握手判断、字段填充和 S/M 侧切换都会更顺。

## 采样规则

AXI payload 在 `VALID && READY` 同时成立的时钟边沿完成传输。`VALID` 表示发送方当前提供有效 payload，`READY` 表示接收方当前可以接收 payload；两者在同一个上升沿同时为 1，这一拍的 payload 才进入协议意义上的 transfer。

所以 `sample_s_side()` 和 `sample_m_side()` 的结构都很直接：先等待 reset 释放，然后在每个 `posedge aclk` 分别检查五个通道的握手条件。五个通道用五个独立 `if` 判断，因为同一个时钟边沿可以同时发生多条通道传输。

```text
等待 aresetn == 1
每个 posedge aclk:
  AWVALID && AWREADY -> publish_aw_*()
  WVALID  && WREADY  -> publish_w_*()
  BVALID  && BREADY  -> publish_b_*()
  ARVALID && ARREADY -> publish_ar_*()
  RVALID  && RREADY  -> publish_r_*()
```

`publish_*()` 函数负责把这一拍采到的信号值放进 `axi_mon_item`。例如 AW 通道会保存 `id / addr / len / size / burst`，W 通道会保存 `data / strb / last`，B 通道会保存 `id / resp`。函数最后调用 `ap.write(item)`，把这条记录通过 analysis port 发出去。

## 记录格式

所有通道都使用同一个 `axi_mon_item` 类型。统一 item 类型让 monitor 的出口保持简单：`ap` 只需要声明成 `uvm_analysis_port #(axi_mon_item)`，scoreboard 和 coverage 也只需要接收一种对象。为了让下游知道一条 item 应该按哪个通道解释，item 里放了一个 `kind` 字段。

```systemverilog
typedef enum int {
    AXI_MON_AW,
    AXI_MON_W,
    AXI_MON_B,
    AXI_MON_AR,
    AXI_MON_R
} axi_mon_kind_e;
```

`axi_mon_kind_e` 定义了一组通道标签。底层类型是 `int`，变量值使用 `AXI_MON_AW`、`AXI_MON_W`、`AXI_MON_B`、`AXI_MON_AR`、`AXI_MON_R` 这些名字表达通道含义。`kind` 是普通枚举值，用来标识当前 item 来自哪条 AXI 通道。

`base_item()` 集中完成每条记录共有的初始化：

```systemverilog
function axi_mon_item base_item(axi_mon_kind_e kind);
    axi_mon_item item = axi_mon_item::type_id::create("item");
    item.kind = kind;
    item.port_index = port_index;
    item.is_m_side = is_m_side;
    return item;
endfunction
```

`axi_mon_item item` 是 class 句柄变量，`axi_mon_item::type_id::create("item")` 创建真实对象并返回句柄。`base_item()` 把这个句柄返回给调用方，所以 `axi_mon_item item = base_item(AXI_MON_AW);` 的含义是取得一条已经创建好、已经填好公共字段的 monitor 记录。后续 `publish_aw_s()` 再把 AW 通道自己的字段补进去。

| `kind`       | 当前记录保存的 payload                  |
| ------------ | -------------------------------- |
| `AXI_MON_AW` | `id / addr / len / size / burst` |
| `AXI_MON_W`  | `data / strb / last`             |
| `AXI_MON_B`  | `id / resp`                      |
| `AXI_MON_AR` | `id / addr / len / size / burst` |
| `AXI_MON_R`  | `id / data / resp / last`        |

`port_index` 和 `is_m_side` 是每条记录的位置信息。`port_index` 说明事件来自第几个端口，`is_m_side` 说明 monitor 当前观察 S 侧接口还是 M 侧接口。下游拿到 item 后，先看 `is_m_side` 和 `port_index` 定位事件来源，再看 `kind` 解释 payload 字段。

## S 侧和 M 侧

同一个 `axi_monitor` 类服务两类接口。master agent 里的 monitor 观察 crossbar 的 S 侧接口，slave agent 里的 monitor 观察 crossbar 的 M 侧接口。agent 在 build phase 给 monitor 写入 `is_m_side`，monitor 再根据这个 bit 选择 `s_vif` 或 `m_vif`。

| 创建位置                  | `is_m_side` | virtual interface   | `port_index` | 连接到                                     |
| --------------------- | ----------: | ------------------- | -----------: | --------------------------------------- |
| `master_agent[i].mon` |         `0` | `axi_s_vif_t s_vif` |          `i` | `scb.s_fifo[i]` 和 `cov.analysis_export` |
| `slave_agent[i].mon`  |         `1` | `axi_m_vif_t m_vif` |          `i` | `scb.m_fifo[i]` 和 `cov.analysis_export` |

配置链路分成三段。`tb_top` 把 `s_axi_if[idx]` 配给对应 master agent，把 `m_axi_if[idx]` 配给对应 slave agent；`axi_env` 给每个 agent 设置 `port_index`；agent 创建 monitor 后设置 `is_m_side`。monitor 的 `build_phase` 读取这些配置，取得正确类型的 virtual interface，`run_phase` 再进入对应侧的采样 task。

```text
tb_top 设置 vif
  -> axi_env 设置 port_index
  -> agent 设置 is_m_side
  -> monitor 选择 s_vif 或 m_vif
  -> ap.write(item)
  -> scoreboard FIFO / coverage
```

`build_phase` 取不到 virtual interface 时直接 `uvm_fatal`。monitor 的后续采样依赖真实接口句柄，接口绑定失败时继续运行会产生无效观测。

## ID 视角

S 侧和 M 侧的 ID 宽度不同。`s_axi_if` 使用 `AXI_S_ID_WIDTH`，`m_axi_if` 使用 `AXI_M_ID_WIDTH`，其中 `AXI_M_ID_WIDTH = AXI_S_ID_WIDTH + $clog2(AXI_S_COUNT)`。crossbar 会在 M 侧 ID 中携带更多来源信息，方便响应回来时找到原始 master 端口。

因此 `axi_mon_item.id` 在 S 侧表示 master 原始 ID，在 M 侧表示 crossbar 扩展后的 ID。scoreboard 做两侧比对时需要结合 `is_m_side`、`port_index` 和 ID 映射规则，才能判断请求和响应的路由关系。

## 当前边界

- `axi_mon_item` 当前保存 AW、W、B、AR、R 的核心字段，还没有保存 lock、cache、prot、qos、user 等扩展属性。后续检查这些属性时，需要扩展 item 字段和对应 `publish_*()`。
- monitor 在启动时等待一次 `aresetn` 释放。运行中再次 reset 时，当前代码没有额外发布 reset 边界记录。
- 当前接口没有 clocking block。现有 driver 的调度方式通常能让 monitor 在握手边沿采到稳定值；后续引入更复杂的调度组织时，采样区域需要明确下来。
- monitor 当前负责记录总线事件。payload 稳定性、`WLAST/RLAST` beat 位置、响应顺序等协议检查可以由 assertion 或 scoreboard/checker 继续完成。

# 07 axi_scoreboard

文件：

```text
10_uvm_work/tb/env/axi_scoreboard.sv
```

`axi_scoreboard` 负责把 monitor 发来的通道记录恢复成跨端口的读写请求路径，并检查 crossbar 是否保持了地址路由、ID 扩展、写数据、读数据和响应返回关系。monitor 每次只发布一个已经握手完成的 AW、W、B、AR、R 事件；scoreboard 需要把这些离散事件放回同一次 AXI 事务里：AW/AR 建立请求，W/R beat 补齐数据，B/R 响应完成返回检查。当前代码把事务上下文集中在 `axi_scb_req`，再用几组按路径命名的队列保存等待中的请求。

`axi_ref_model` 是 scoreboard 的期望行为模型。它负责地址 decode、S ID 到 M ID 的扩展、burst beat 地址计算，以及写入后读回的 memory 内容。scoreboard 观察 DUT 的实际接口行为，再向 reference model 取期望路由、期望 ID 和期望读数据。这样 checker 的主逻辑集中在“实际值和期望值比较”，地址规则和 memory 规则集中在 reference model。

验证环境的数据流可以先看成下面这条链：

```text
monitor ap.write(item)
  -> s_fifo[i] / m_fifo[j]
  -> process_fifo_items()
  -> handle_s_item() / handle_m_item()
  -> axi_scb_req queues
  -> axi_ref_model expected route / id / memory data
  -> compare DUT actual item with RM expected value
  -> report_phase()
```

`process_fifo_items()` 是 scoreboard 的主消费入口。它在一个线程里轮询所有 S 侧和 M 侧 FIFO，把当前 FIFO 中可用的 item 依次取出并处理。这样 scoreboard 的状态更新保持串行，后续队列只会被这一个流程修改。

## 整体结构

scoreboard 的执行结构：

```text
build_phase()
  create s_fifo[AXI_S_COUNT]
  create m_fifo[AXI_M_COUNT]
  bind axi_ref_model

run_phase()
  forever:
    process_fifo_items()
    if no item was processed:
      wait 1ns

process_fifo_items()
  for each S fifo:
    try_get all available items
    s_item_count++
    handle_s_item(port, item)

  for each M fifo:
    try_get all available items
    m_item_count++
    handle_m_item(port, item)

report_phase()
  check all request queues are empty
  print observed item count and check count
```

S 侧 FIFO 保存 master agent monitor 观察到的入口侧事件，M 侧 FIFO 保存 slave agent monitor 观察到的出口侧事件。`process_fifo_items()` 先处理 S 侧，再处理 M 侧；S 侧 AW/AR 通常先建立预期，随后 M 侧 AW/AR 用这些预期完成路由比对。

`try_get(item)` 是 `uvm_tlm_analysis_fifo` 的非阻塞读取方法。FIFO 里有 item 时，它把 item 取出来并返回 1；FIFO 暂时为空时，它返回 0，代码继续检查下一个 FIFO。这里的 `try_get()` 属于 scoreboard 里的 FIFO，不属于 monitor 的 analysis port。monitor 侧负责 `ap.write(item)`，scoreboard 侧通过 FIFO 的 `try_get(item)` 取记录。

## Reference Model

reference model 分成一层 SystemVerilog wrapper 和一层 C 模型：

| 文件 | 责任 |
| --- | --- |
| `10_uvm_work/tb/env/axi_ref_model.sv` | UVM object wrapper，给 scoreboard 提供 SV 方法 |
| `10_uvm_work/tb/env/axi_ref_model.c` | DPI-C 后端，保存 expected memory 并计算地址/ID |

`axi_env` 创建一个 `axi_ref_model rm`，再把它交给 scoreboard：

```systemverilog
rm = axi_ref_model::type_id::create("rm");
scb = axi_scoreboard::type_id::create("scb", this);
scb.set_ref_model(rm);
```

reference model 当前提供四类期望值：

| RM 方法 | 作用 |
| --- | --- |
| `addr_to_m_port()` | 根据地址窗口计算期望 M 侧端口 |
| `expand_id()` | 根据 S port 和 S ID 计算 M 侧扩展 ID |
| `write_beat()` | 按 burst 地址和 `WSTRB` 更新 expected memory |
| `read_beat()` | 从 expected memory 计算期望 `RDATA` |

monitor 仍然只记录真实接口事件；coverage 仍然统计真实事件。reference model 只负责根据输入侧事务生成期望行为，不直接采样 DUT。

## 请求对象

`axi_scb_req` 表示一次从 S 侧发起的读请求或写请求。它保存地址相位信息、路由结果、ID 映射结果，以及后续数据 beat 的累计状态。

| 字段                    | 作用                              |
| --------------------- | ------------------------------- |
| `op`                  | 区分读请求和写请求                       |
| `s_port`              | 请求进入 crossbar 的 S 侧端口           |
| `m_port`              | 地址命中后应该到达的 M 侧端口                |
| `addr_hit`            | 地址是否命中 wrapper 配置的 4KB 窗口       |
| `sid`                 | S 侧原始 ID                        |
| `mid`                 | M 侧扩展 ID                        |
| `addr/len/size/burst` | AW/AR 定义的 burst 上下文             |
| `s_wdata/s_wstrb`     | S 侧 W beat                      |
| `m_wdata/m_wstrb`     | M 侧 W beat                      |
| `s_r_count/m_r_count` | S/M 两侧已经检查的 R beat 数            |
| `s_w_done/m_w_done`   | S/M 两侧是否已经看到 `WLAST`            |
| `write_done`          | 写数据已经完成 S/M 比对并写入 RM memory |

`beat_count()` 统一计算事务需要的 beat 数：

```systemverilog
function int unsigned beat_count();
    return int'(len) + 1;
endfunction
```

AXI 的 `AxLEN` 表示 beat 数减 1。scoreboard 检查 W/R beat 时都用 `len + 1` 作为期望 beat 数。读事务的完成状态由 `s_r_count == beat_count()` 或 `m_r_count == beat_count()` 推出。

## 请求队列

队列名按 AXI 路径命名。每个队列都对应一个明确的等待点。

| 队列 | 保存内容 | 消费位置 |
| --- | --- | --- |
| `s_write_q[s]` | S 侧 AW 已到达，等待 S 侧 W beat | `handle_s_w()` |
| `m_write_exp_q[m]` | S 侧 AW 已建立，等待 M 侧 AW 路由结果 | `handle_m_aw()` |
| `m_write_q[m]` | M 侧 AW 已匹配，等待 M 侧 W/B | `handle_m_w()` / `handle_m_b()` |
| `s_b_q` | S 侧写请求已建立，等待 S 侧 B | `handle_s_b()` |
| `m_read_exp_q[m]` | S 侧 AR 已建立，等待 M 侧 AR 路由结果 | `handle_m_ar()` |
| `m_read_q[m]` | M 侧 AR 已匹配，等待 M 侧 R | `handle_m_r()` |
| `s_r_q` | S 侧读请求已建立，等待 S 侧 R | `handle_s_r()` |

这些队列覆盖当前 checker 真正需要保存的关系：S 侧请求、M 侧路由、写响应、读响应。代码没有为 FIFO 调度顺序再加额外暂存队列，核心状态就只剩请求本身和请求所在的等待位置。

`push_back(req)` 是 SystemVerilog queue 的尾部插入方法。scoreboard 在 S 侧 AW 到来时，把同一个 `req` 句柄放入几个不同的等待队列：

```systemverilog
s_write_q[idx].push_back(req);
s_b_q.push_back(req);
if (req.addr_hit) m_write_exp_q[req.m_port].push_back(req);
```

这三次插入代表同一次写请求接下来要等待三类事件：S 侧 W beat、S 侧 B 响应、M 侧 AW 路由结果。队列里保存的是 class 句柄，所以这些队列引用的是同一个 `axi_scb_req` 对象；后续 W beat、路由匹配和响应检查都会更新同一个请求上下文。

## 路由与 ID

地址窗口由 RM 的 `addr_to_m_port()` 描述：

| 地址范围 | M 侧端口 |
| --- | --- |
| `0x0000_0000 - 0x0000_0FFF` | M0 |
| `0x0001_0000 - 0x0001_0FFF` | M1 |
| `0x0002_0000 - 0x0002_0FFF` | M2 |
| 其他地址 | decode error |

S 侧 AW/AR 到来时，`new_req()` 创建 `axi_scb_req`，并向 RM 查询路由和扩展 ID：

```systemverilog
req.m_port = rm.addr_to_m_port(item.addr);
req.addr_hit = (req.m_port >= 0);
req.mid = req.addr_hit ? rm.expand_id(port, req.sid) : '0;
```

M 侧 ID 使用 source port 扩展：

```text
mid = sid | (s_port << AXI_S_ID_WIDTH)
sid = mid[AXI_S_ID_WIDTH-1:0]
s_port = mid >> AXI_S_ID_WIDTH
```

生成扩展 ID 的规则在 RM 中实现。scoreboard 保留 `mid_sid()` 和 `mid_s_port()`，用于检查 M 侧响应 ID 是否能还原出原始 S 端口和 S ID。

M 侧 AW/AR 到来时，`take_m_write_exp()` 或 `take_m_read_exp()` 从期望队列里取出匹配请求。匹配条件集中在 `addr_matches()`：

```text
M port matches decoded port
M ID matches expanded ID
addr / len / size / burst match S-side request
```

匹配成功后，写请求进入 `m_write_q[m]`，读请求进入 `m_read_q[m]`。

## 写检查

写路径从 S 侧 AW 开始：

```text
handle_s_aw()
  new_req(AXI_WRITE)
  -> s_write_q[s]
  -> s_b_q
  -> m_write_exp_q[m] if addr_hit
```

S 侧 W beat 由 `handle_s_w()` 收集。它从 `s_write_q[s]` 找到还没看到 `WLAST` 的请求，把 `beat_data/beat_strb` 放入 `s_wdata/s_wstrb`，再调用 `check_last()` 检查 beat 位置。

M 侧 AW 由 `handle_m_aw()` 匹配路由预期。匹配成功后，M 侧 W beat 由 `handle_m_w()` 收集到 `m_wdata/m_wstrb`。

`check_last()` 检查 W/R beat 的结束位置：

```text
beat >= len + 1      -> too many beats
final beat last = 0  -> missing LAST
early beat last = 1  -> early LAST
```

S 侧和 M 侧都看到 `WLAST` 后，`finish_write()` 调用 `compare_write()` 比对两侧写数据：

```text
S WDATA/WSTRB[beat] == M WDATA/WSTRB[beat]
```

比对后，`commit_write()` 把每个 M 侧写数据 beat 交给 RM：

```text
for each beat:
  rm.write_beat(addr, len, size, burst, beat, WDATA, WSTRB)
```

RM 里的 C 模型覆盖 `FIXED`、`INCR`、`WRAP` 三种 burst，并按 byte 地址保存 expected memory。`WSTRB` 为 1 的 byte lane 才会更新。

写响应分两侧检查。M 侧 B 由 `handle_m_b()` 检查扩展 ID、source port 反解和 `OKAY` 响应；S 侧 B 由 `handle_s_b()` 检查原始 ID和响应值。地址命中时，S 侧期望 `OKAY`；地址未命中时，S 侧期望 `DECERR`。

## 读检查

读路径从 S 侧 AR 开始：

```text
handle_s_ar()
  new_req(AXI_READ)
  -> s_r_q
  -> m_read_exp_q[m] if addr_hit
```

M 侧 AR 由 `handle_m_ar()` 匹配路由预期。匹配成功后，请求进入 `m_read_q[m]`，后续 M 侧 R beat 通过 `mid` 找到这个请求。

S 侧 R 和 M 侧 R 都使用 `check_read_beat()`：

```text
beat = s_r_count or m_r_count
expected_last = beat == len
expected_resp = addr_hit ? OKAY : DECERR
expected_data = addr_hit ? rm.read_beat(addr, len, size, burst, beat) : 0
```

M 侧 R 检查扩展 ID，S 侧 R 检查原始 ID。两侧都检查 `RRESP`、`RDATA` 和 `RLAST`。检查完成后，代码递增对应的 `*_r_count`；计数达到 `beat_count()` 时，请求从 `s_r_q` 或 `m_read_q[m]` 删除。

## 函数对应

| 函数 | 责任 |
| --- | --- |
| `process_fifo_items()` | 单线程轮询 S/M FIFO，处理当前可用的 monitor item |
| `set_ref_model()` | 把 env 创建的 reference model 交给 scoreboard |
| `new_req()` | 用 S 侧 AW/AR 建立请求上下文 |
| `rm.addr_to_m_port()` | 按 wrapper 地址窗口计算 M 侧端口 |
| `rm.expand_id()` | 生成 M 侧扩展 ID |
| `mid_sid()` / `mid_s_port()` | 从 M 侧扩展 ID 还原 S 侧信息 |
| `handle_s_aw()` / `handle_s_ar()` | 建立写/读请求，并登记 M 侧路由期望 |
| `handle_m_aw()` / `handle_m_ar()` | 匹配 M 侧地址相位和路由结果 |
| `handle_s_w()` / `handle_m_w()` | 收集写数据 beat，检查 `WLAST` |
| `handle_s_b()` / `handle_m_b()` | 检查写响应 |
| `handle_s_r()` / `handle_m_r()` | 检查读响应 beat |
| `check_last()` | 检查 `LAST` 的 beat 位置 |
| `compare_write()` | 比对 S/M 两侧写数据和 strobe |
| `commit_write()` | 调用 RM 更新 expected memory |
| `check_read_beat()` | 调用 RM 取得期望读数据并比较 |
| `report_phase()` | 检查队列是否清空，并汇总计数 |

## 当前边界

- scoreboard 当前用单线程轮询 FIFO。这个结构降低了状态数量，也让代码更容易读；M 侧 item 需要在同一轮或后一轮找到已经建立的 S 侧预期。
- M 侧 B 当前按 `m_write_q[m][0]` 检查，适合当前 slave driver 的按接收顺序返回模型。后续如果 slave 支持不同 ID 写响应乱序返回，需要把 M 侧 B 改成按 `mid` 查找。
- checker 只使用 monitor item 里已有的 `id/addr/len/size/burst/beat_data/beat_strb/last/resp` 字段。lock、cache、prot、qos、user 等字段还没有进入比对。
- C RM 通过 DPI-C 接入。`run.do` 会先用 `gcc` 编译 `axi_ref_model.c`，再用 `vsim -sv_lib` 加载动态库。
- 当前本机没有 `vlog/vsim/xrun/vcs/verilator/iverilog/slang`，这版 SV/UVM 代码还需要在仿真器里编译并跑 smoke test。

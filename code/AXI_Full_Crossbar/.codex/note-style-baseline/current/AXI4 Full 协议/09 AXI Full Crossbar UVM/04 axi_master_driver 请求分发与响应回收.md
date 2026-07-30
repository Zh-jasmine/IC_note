# 04 axi_master_driver 请求分发与响应回收

文件：

```text
10_uvm_work/tb/axi_agent/axi_master_driver.svh
```

## 角色

`master driver` 负责把 sequence 给出的 `axi_txn` 拆成 AXI 五通道上的时序行为。

当前这版已经不是最早那种“发一笔、等一笔”的串行写法，而是：

- 请求通道独立：`AW/W/AR`
- 响应通道独立：`B/R`
- `AW` 和 `W` 可以形成 `AW先/W先/同时` 三种相对顺序

## 整体结构

```text
run_phase()
  init_master_outputs()
  wait reset release
  fork
    drive_ready()
    dispatch_requests()
    drive_aw_channel()
    drive_w_channel()
    drive_ar_channel()
    collect_b_responses()
    collect_r_responses()
  join
```

## 请求分发

`dispatch_requests()` 从 sequencer 取一笔 `req_tr`。

写事务：

- 只创建一次 `write_req_tr`
- 这是对 `req_tr` 的独立快照
- 同一个 `write_req_tr` 句柄同时放进：
  - `aw_request_mb`
  - `w_request_mb`
  - `b_res_id[id]`

读事务：

- 只创建一次 `read_req_tr`
- 这是对 `req_tr` 的独立快照
- 同一个 `read_req_tr` 句柄同时放进：
  - `ar_request_mb`
  - `r_res_id[id]`

这里 mailbox 的作用就是把“事务分发线程”和“具体通道驱动线程”解耦开。

这里有两个点要分清：

1. 为什么还要 copy 一次  
   不能直接把 sequencer 给的 `req_tr` 原句柄长期挂出去，因为 `item_done()` 之后，sequence 侧完全可能复用这个对象句柄。

2. 为什么 copy 一次后又可以多个地方共用同一个句柄  
   因为后面的 `AW/W/AR/B/R` 线程只是“读这个快照里的字段”，不会回头改它，所以一个快照句柄可以安全地被多个消费者引用。

## 为什么 `AW` 和 `W` 不是写死顺序

因为 `drive_aw_channel()` 和 `drive_w_channel()` 是两个独立线程：

- `AW` 线程自己从 `aw_request_mb` 取事务
- `W` 线程自己从 `w_request_mb` 取事务
- 每个线程还可以各自先随机等几拍

所以自然会出现：

- `AW` 先
- `W` 先
- `AW/W` 同拍附近到达

这更符合 AXI4 对写地址通道和写数据通道解耦的要求。

## 响应回收

写响应：

```text
collect_b_responses()
  等 BVALID && BREADY
  用 BID 去 b_res_id[BID] 里取最早那笔等待中的写请求信息
  直接复用这笔写请求快照
  把 BRESP/BID 等响应字段补进去
  最后通过 seq_item_port.put(...) 回给 sequence
```

读响应：

```text
collect_r_responses()
  等 RVALID && RREADY
  用 RID 去 r_res_id[RID] 里取最早那笔等待中的读请求信息
  直接复用这笔读请求快照
  按 beat 收 RDATA/RRESP/RLAST
  最后通过 seq_item_port.put(...) 回给 sequence
```

## `drive_ready()`

这个线程持续驱动：

- `BREADY`
- `RREADY`

默认可以一直 ready，也可以通过 delay 参数制造 backpressure。

## 当前理解重点

读完这一节至少要能回答：

1. 为什么 `AW` 和 `W` 要拆成两个线程。
2. mailbox 在这里起的是什么作用。
3. 为什么 `B/R` 回来时，不是直接把原来的 `req_tr` 当响应对象。
4. `b_res_id` / `r_res_id` 里保存的为什么是“等待响应的信息”，不是最终响应本身。
5. 为什么这里可以“一次 copy，多处共用”，但不能“完全不 copy”。

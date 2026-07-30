# 04 axi_master_driver

文件：

```text
10_uvm_work/tb/axi_agent/axi_master_driver.svh
```


最抽象的一层。driver 的职责是：
1. 从 sequencer 拿事务
2. 把事务翻译成接口级时序信号
3. 按协议完成握手
4. 在需要时收集响应
5. 把响应回给 sequence
6. 处理 reset / 空闲态

因此
AXI master driver 的核心作用，就是把 sequence 送下来的 transaction 翻译成 AXI 总线上的时序信号。先从最朴素的情况看，如果不考虑 AXI4 的任何并发能力，那么一笔事务其实就是一个串行过程：先把请求发出去，再等待响应回来，响应回来以后这笔事务才真正结束。

比如写事务里，`AW` 和 `W` 完成握手，只能说明写地址和写数据已经发出去了，但这时候写事务还没有真正完成，因为还必须继续等待 `B` 通道把写响应返回来，只有当 `BVALID && BREADY` 也完成握手以后，这笔写事务才算彻底结束；读事务也是同样的逻辑，`AR` 完成握手只是说明读请求发出去了，真正结束还要等 `R` 通道把数据和响应全部返回来。

但是 AXI4 不是只支持这种串行模式，它本身支持读写分离和 outstanding。所谓读写分离，就是写事务的进行不应该阻塞读事务，读事务的进行也不应该阻塞写事务。为了实现并发，driver 会用 mailbox 来做线程间解耦：前端负责取 transaction 并分发，后端的请求线程负责各自阻塞等待对应 mailbox 里的事务。

通过一个 `dispatch_requests()` 线程，专门不断从 sequencer 取 transaction，取到以后判断它是读还是写，如果是写就分发给写相关的 mailbox，如果是读就分发给读相关的 mailbox，然后这个线程立刻回去继续取下一笔 transaction，而不会阻塞在某一笔具体事务上。

回到读写 task，只需要阻塞等待 mailbox 里有 txn，便可以继续读写事务。同理，由于 AXI4 同时地址和数据也是独立的，所以也一样分离出各自的 mailbox，进入不同的 task——`drive_aw_channel()`、`drive_w_channel()` 和 `drive_ar_channel()`，就能实现读写的解耦以及地址和数据的解耦。

此时，原本串行的请求就变成了读写并发，但是在读写事务内部里，逻辑仍然是地址和数据握手之后等待响应握手，才算完成一笔事务。所以 AXI4 进一步引入 outstanding。

outstanding transaction 是指已发起、发送出去，但还没收到返回响应、没有完成握手的事务。这时候 driver 仍然可以继续发送后续请求，也就是说，一笔事务在“请求发出”之后并没有结束，而是进入了“等待响应”的状态，而 driver 不能在这里停住，它还得继续处理后面的 transaction。

实现 outstanding 时，关键不是再塞一个“响应 mailbox”，而是把已经发出但还没完成的事务按 ID 挂起来。以写为例，只需要在 `AW` 和 `W` 握手完成之后，把当前这笔 txn 记录到对应 ID 的等待 mailbox 里，写 task 就结束了，无需等待响应回来；同时响应 task 负责等待 `BVALID && BREADY`，当响应到来时，再根据 `BID` 去对应的 mailbox 里取出最早那笔写请求完成配对。读事务也是同理，只不过回收的是 `RDATA/RRESP/RLAST`。

这里还有一个关键约束：AXI4 允许不同 ID 的响应乱序返回，但同一个 ID 内必须保序返回。所以 pending 结构才要按 ID 分桶成 mailbox：同一个 ID 的请求按顺序 `put()`，响应回来时按顺序 `get()`。这样就同时支持了 outstanding 和不同 ID 的乱序返回。

最后再说 `ready`。前面的处理是当响应处理线程发现有待响应事务以后，去拉 `ready`，然后等对面 `valid`，这个想法本身功能上没有错。不过可以把 `ready` 单独拆一个线程，这么拆并不是因为协议强制，而是可以方便做 backpressure。因为 `ready` 的本质不是“命令对方现在给我发响应”，而只是表示“如果你现在有合法响应，我这边接得住”，真正响应什么时候来，取决于 slave 什么时候拉 `valid`。AXI 协议本身允许 `ready` 先高、`valid` 先高、或者两者同拍拉高，只要最后某一拍 `valid && ready` 同时为 1，就算握手成功，所以 `ready` 完全可以提前拉高，甚至一直为 1；把 `ready` 单独拆出来以后，你就可以单独控制它是一直 ready，还是随机延迟几拍再 ready，还是随机拉低几拍制造 backpressure，而响应进程只需要阻塞拿取 txn 并等待握手，少了拉起 ready 这一步。

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
    collect_r_response_data()
  join
```

//
- `target_index` 还没真正用起来
- mid-run reset 还没专门处理
- `RRESP` 现在只保留了最终值，没按 beat 单独存
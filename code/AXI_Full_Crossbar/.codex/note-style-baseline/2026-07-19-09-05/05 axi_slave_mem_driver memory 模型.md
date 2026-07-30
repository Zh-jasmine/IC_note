# 05 axi_slave_mem_driver memory 模型

文件：

```text
10_uvm_work/tb/axi_agent/axi_slave_mem_driver.svh
```

`axi_slave_mem_driver` 的作用，和前面的 `axi_master_driver` 正好相反。master driver 是把 sequence 给出的 transaction 主动翻译成总线时序；slave memory driver 不从 sequencer 取事务，它本身就是一个被动响应模型，职责是接住 crossbar 从 M 侧打过来的 `AW/W/AR`，把数据写进本地 memory，再按协议返回 `B/R`。所以它不是“生成请求”的 driver，而是“消费请求并造出响应”的 memory model。

如果先看最朴素的模型，slave 侧的逻辑其实很简单：写的时候，先拿到写地址，再拿到写数据，把数据写进 memory，最后回一个 `B`；读的时候，先拿到读地址，再从 memory 里把数据读出来，最后回一个 `R`。所以从最低层看，这个模型真正做的只有两件事：一是维护一份按 byte 编址的内存 `mem`，二是把 AXI 通道上的请求翻译成对这份 memory 的读写。

这里的 memory 定义是：

```text
bit [7:0] mem [longint unsigned];
```

也就是说，testbench 里维护的是一个 byte 级的稀疏 memory。之所以用 byte 为单位，是因为写通道本身就带 `WSTRB`，而 `WSTRB` 的含义就是“本拍哪些 byte lane 有效”。所以这个 memory model 不是整拍整拍写，而是逐 byte lane 地写：

```text
if WSTRB[lane] == 1:
  mem[addr + lane] = WDATA 对应 byte
```

这样才能正确表达窄写、部分写和按字节屏蔽写。

和 master driver 一样，这里也用了并行 task，但目的不一样。master 那边是为了把主动发请求、等待响应、outstanding 挂账这些行为解耦；slave 这边则是为了把五通道中真正独立的反应式行为拆开。整体结构是：

```text
run_phase()
  init_slave_outputs()
  wait reset release
  fork
    accept_aw()
    accept_w_and_send_b()
    accept_ar()
    send_r()
  join
```

这四个线程可以分成两条链看：一条是写链路 `AW -> W -> B`，另一条是读链路 `AR -> R`。

先看写链路。`accept_aw()` 的职责只是接收写地址。当 `AWVALID && AWREADY` 握手成功后，它不会直接写 memory，而是把这笔写事务后续还需要用到的最小上下文信息提取出来，塞进 `aw_mb`。这里提取出来的不是完整 `axi_txn`，而是一个局部结构 `addr_ctx_s`，里面只有：

| 字段 | 作用 |
| --- | --- |
| `id` | 后续回 `BID` 用 |
| `addr` | 写起始地址 |
| `len` | 一共多少个 beat |
| `size` | 每个 beat 的字节数 |
| `burst` | 地址是否递增 |

这说明 slave memory driver 的关注点和 master driver 不一样。master 侧需要保留完整 transaction，是因为它还要把请求重新回传给 sequence；而 slave 侧这里只需要记住后面接收 `W` 和回 `B` 时真正还会用到的地址上下文，所以一个小结构就够了。

接着 `accept_w_and_send_b()` 从 `aw_mb` 里取出这份地址上下文，然后开始按 beat 接收 `W`。每接到一拍 `WVALID && WREADY`，就根据 `WSTRB` 把 `WDATA` 对应的 byte 写进 memory；如果 burst 不是 `FIXED`，地址就按 `1 << size` 递增。等所有 beat 都写完之后，这个线程再驱动：

```text
BID    = ctx.id
BRESP  = OKAY
BVALID = 1
```

然后等待 master 的 `BREADY`。也就是说，`B` 响应不是独立凭空产生的，而是明确地依附于“这笔写数据已经全部收完”这件事之后。

再看读链路。`accept_ar()` 负责接收读地址，逻辑和 `accept_aw()` 对称：当 `ARVALID && ARREADY` 握手成功后，把 `id/addr/len/size/burst` 这几个后续还会用到的字段塞进 `ar_mb`。然后 `send_r()` 从 `ar_mb` 里取出这份地址上下文，按 beat 构造返回数据。每一拍都会做三件事：根据当前地址从 `mem` 里把各个 byte lane 拼成 `RDATA`，给出 `RID/RRESP/RLAST`，然后拉起 `RVALID` 等待 master 的 `RREADY`。其中 `mem.exists(addr + lane)` 这一句的含义是：如果该地址之前从来没被写过，就默认返回 `8'h00`。所以这个 memory model 也是零初始化语义。

把两条链路合起来，这个 slave driver 的内部数据流其实很直接：

```text
写:
AW 握手
  -> 保存写地址上下文到 aw_mb
  -> W 按 beat 到来
  -> 按 WSTRB 写入 mem
  -> 回 B

读:
AR 握手
  -> 保存读地址上下文到 ar_mb
  -> 从 mem 按 beat 取数
  -> 回 R
```

这里最值得注意的一点，是它虽然也用了 mailbox，但这个 mailbox 的作用不是 outstanding 配对，而是把“地址先到”和“数据/响应后到”这两段逻辑串起来。也就是说，`aw_mb` 和 `ar_mb` 在这里更像“地址上下文暂存区”，而不是 master driver 那种“按 ID 记录未完成请求”的 pending 结构。

当前这版模型已经足够支撑基础读写闭环，但它还不是一个协议特性完全展开的 AXI slave。它有几个很明确的限制。第一，写链路实际上要求先收到 `AW`，再去接对应的 `W`，因为 `accept_w_and_send_b()` 是先 `aw_mb.get(ctx)` 再开始拉 `WREADY` 的，所以它天然更偏向 `AW` 先于 `W` 的实现，而没有把 `W` 先到这种更完整的 AXI4 情况展开处理。第二，读链路和写链路内部都是串行消费 mailbox 的，也就是一笔地址上下文取出来之后，会把整笔 `W` 或整笔 `R` 跑完，再处理下一笔，因此它是一个简单 memory model，不是在做 fully-featured 的多事务交织 slave。第三，地址更新这里只处理了最基础的 `FIXED` 和“非 FIXED 就递增”逻辑，`WRAP` 没有真正按 wrap boundary 展开。第四，所有响应都固定回 `OKAY`，也没有展开 error response。  

所以这份代码更准确的定位应该是：一个用于 UVM 环境自测的、足够支撑基本 AXI read/write 行为的 slave memory model，而不是一个完整覆盖所有 AXI4 边界情况的参考实现。

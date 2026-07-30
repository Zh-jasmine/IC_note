# 05 axi_slave_mem_driver 

文件：

```text
10_uvm_work/tb/axi_agent/axi_slave_mem_driver.svh
```

`axi_slave_mem_driver` 的作用，和前面的 `axi_master_driver` 正好相反。master driver 是把 sequence 给出的 transaction 主动翻译成总线时序；slave memory driver 不从 sequencer 取事务，它本身就是一个被动响应模型，职责是接住 crossbar 从 M 侧过来的 `AW/W/AR`，把数据写进本地 memory，再按协议返回 `B/R`。

slave 侧的逻辑：写的时候，拿到写地址和写数据（不分先后）后就把数据写进 memory（维护一个mailbox fifo），最后回`B`，读的时候，先拿到读地址，再从 memory 里把数据读出来，最后回一个 `R`。

slave侧需要写数据时，地址和数据是解耦的，不分先后。不过读数据时只有知道了 ar 才能去mem读数据。 所以为了实现地址和数据的解耦（其实也就是不互相依赖），slave 这里同样，主进程在收到aw后， 就将总线信号放到txn里，并put进mailbox。 w同理。然后新建一个task，阻塞等待前两个mailbox 有数据。
```
aw_mb.get(addr_ctx);
w_mb.get(w_ctx);
```

像这样同时阻塞，只有两个mailbox都有数据了才会去写数据并返回响应。
slave侧需要读数据时，同理，rw接受完成后将总线信号存进txn然后放到mailbox里，再让读数据task阻塞取txn。

整体结构：

```text
run_phase()
  init_slave_outputs()
  wait reset release
  fork
    accept_aw();
	accept_w();
	commit_write_and_send_b();
	accept_ar();
	send_r();
  join
```



# 05 axi_slave_mem_driver memory 模型

文件：

```text
10_uvm_work/tb/axi_agent/axi_slave_mem_driver.svh
```

这个 driver 模拟外部 AXI slave memory。它连接在 crossbar 的 M 侧。

## 整体结构

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

## 写响应链路

```text
accept_aw()
  -> 接收 AW
  -> 保存 id/addr/len/size/burst 到 aw_mb

accept_w_and_send_b()
  -> 从 aw_mb 取地址上下文
  -> 接收 W beat
  -> 按 WSTRB 写 byte memory
  -> 发送 BID/BRESP/BVALID
```

写 memory 的关键逻辑：

```text
for each byte lane:
  if WSTRB[lane] == 1:
    mem[addr + lane] = WDATA 对应 byte
```

## 读响应链路

```text
accept_ar()
  -> 接收 AR
  -> 保存 id/addr/len/size/burst 到 ar_mb

send_r()
  -> 从 ar_mb 取地址上下文
  -> 从 memory 读数据
  -> 逐 beat 返回 RDATA/RRESP/RLAST/RVALID
```

## 地址递增规则

```text
如果 burst != FIXED:
  addr += 1 << size
```

## 当前限制

- 基础 `FIXED` 行为可以保持地址不变
- 基础 `INCR` 行为可以递增地址
- `WRAP` 还没有完整 wrap boundary 处理
- slave memory 是 testbench 模型，不是 DUT

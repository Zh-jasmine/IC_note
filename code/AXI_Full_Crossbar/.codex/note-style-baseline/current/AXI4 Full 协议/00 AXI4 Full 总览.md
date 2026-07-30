# 00 AXI4 Full 总览

## AXI 到底复杂在哪里？

AXI 不是“一根总线 + 一个 read/write 命令”。更准确地说，它是一套 **多通道、可流水、可突发、可并发、带响应和顺序约束的 memory-mapped （存储器映射）协议**。

如果只看最简单的访问，它像这样：

```text
Master 发地址 -> Slave 收地址 -> 数据传输 -> 返回响应
```

但 AXI4 Full 真正复杂的地方是：

- 地址和数据不是同一个通道。
- 读和写不是同一个通道。
- 每个通道都有自己的 `VALID/READY` 握手。
- 一次事务可以是多个 beat 的 burst。
- Master 可以发出多个 outstanding transaction。
- 响应要靠 ID 匹配。
- 同 ID 和不同 ID 的 ordering 规则不同。
- narrow / unaligned / WSTRB / 4KB boundary 这些细节会直接影响数据正确性。

## 学习和项目边界

当前阶段重点学习 AXI4 Full 的基础数据传输协议：

```text
VALID/READY
五通道
burst
WSTRB / byte lane
narrow / unaligned
ID / outstanding / ordering
backpressure
response
```

`AxLOCK/AxCACHE/AxPROT/AxQOS/AxREGION/AxUSER`、ACE/cache coherency、低功耗接口和 formal proof 先做概念了解。

验证项目阅读路线见 [[09 AXI Full Crossbar UVM]]。

# 06 WSTRB narrow unaligned

AXI 的写数据不是简单“整个 bus 一次全写”。它按 byte lane 工作。

## byte lane 示例

32位bus 8-bit 示例：

![[9.jpg]]

64位bus 32-bit 示例：

![[10.jpg]]

## WSTRB 

`WSTRB` 是写数据 byte lane 的有效掩码。

假设数据总线是 32-bit，也就是 4 个 byte lane：

```text
WSTRB[0] 对应 WDATA[7:0]
WSTRB[1] 对应 WDATA[15:8]
WSTRB[2] 对应 WDATA[23:16]
WSTRB[3] 对应 WDATA[31:24]
```

如果 `WSTRB = 4'b0011`，表示只写低两个 byte，高两个 byte 不改。

## narrow transfer

narrow transfer 指每个 beat 传输的字节数小于数据总线宽度。

例子：

```text
总线宽度 = 32-bit = 4 bytes
AWSIZE = 1 => 每 beat 2 bytes
```

这时每个 beat 只占用部分 byte lane，具体占哪些 lane 由地址低位和 burst 规则决定。

## unaligned access

unaligned access 指起始地址没有按传输大小对齐。

例子：

```text
AWSIZE = 2 => 每 beat 4 bytes
AWADDR = 0x1001
```

`0x1001` 不是 4-byte aligned。实现和验证时要特别小心：

- 第一个 beat 的有效 byte lane 可能不是从 lane 0 开始。
- `WSTRB` 必须和地址低位匹配。
- scoreboard 必须按 byte-addressed memory 更新，而不能按 word 粗暴覆盖。

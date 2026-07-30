# 03 写事务 AW W B

写事务不是一个单通道动作，而是三条通道协同完成：

```text
1. AW 通道完成写地址/控制握手
2. W 通道完成一个或多个写数据 beat
3. 最后一个 W beat 带 WLAST
4. Slave 通过 B 通道返回写响应
```

## 写事务协议图


![[wikimedia-axi-write-transaction.svg]]

## AW 通道

`AW` 通道不是写数据，它描述“接下来这笔写事务怎么做”。

| 信号                | 含义                                   |
| ----------------- | ------------------------------------ |
| `AWID`            | 写事务 ID，后续 `BID` 要对应它                 |
| `AWADDR`          | burst 首地址                            |
| `AWLEN`           | burst 长度编码，实际 beat 数 = `AWLEN + 1`   |
| `AWSIZE`          | 每个 beat 的字节数，bytes/beat = `2^AWSIZE` |
| `AWBURST`         | burst 类型：`FIXED / INCR / WRAP`       |
| `AWVALID/AWREADY` | 地址通道握手                               |

## W 通道

`W` 通道才是真正的数据。

| 信号 | 含义 |
|---|---|
| `WDATA` | 写数据 |
| `WSTRB` | byte lane 有效掩码 |
| `WLAST` | 当前 beat 是本次 burst 的最后一个 |
| `WVALID/WREADY` | 数据通道握手 |

AXI4 里没有 `WID`。这意味着：

- 不能用 `WID` 区分交错的写数据流。
- AXI4 不支持 AXI3 那种 write data interleaving。
- 但 `AW` 和 `W` 仍然是独立握手通道，不能把它们画成一个简单串行命令。

## B 通道

`B` 通道返回写事务结果。

| 信号 | 含义 |
|---|---|
| `BID` | 对应 `AWID` |
| `BRESP` | 写响应结果 |
| `BVALID/BREADY` | 写响应握手 |

对 AXI4 来说，Slave 拉高 `BVALID` 之前必须已经看到：

```text
AWVALID && AWREADY
WVALID && WREADY && WLAST
```

也就是说，写地址握手完成，并且最后一个写数据 beat 被接收后，写响应才有资格返回。

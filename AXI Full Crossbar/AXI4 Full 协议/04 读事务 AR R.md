# 04 读事务 AR R

读事务由两个通道完成：

```text
1. AR 通道完成读地址/控制握手
2. R 通道返回一个或多个读数据 beat
3. 最后一个 R beat 带 RLAST
```

## 读事务协议图

![[wikimedia-axi-read-transaction.svg]]

## AR 通道

| 信号                | 含义                                 |
| ----------------- | ---------------------------------- |
| `ARID`            | 读事务 ID，后续 `RID` 要对应它               |
| `ARADDR`          | burst 首地址                          |
| `ARLEN`           | burst 长度编码，实际 beat 数 = `ARLEN + 1` |
| `ARSIZE`          | 每个 beat 的字节数                       |
| `ARBURST`         | burst 类型                           |
| `ARVALID/ARREADY` | 读地址握手                              |

## R 通道

| 信号              | 含义            |
| --------------- | ------------- |
| `RID`           | 对应 `ARID`     |
| `RDATA`         | 读数据           |
| `RRESP`         | 当前 beat 的读响应  |
| `RLAST`         | 当前 beat 是最后一个 |
| `RVALID/RREADY` | 读数据握手         |
注意
**某一笔读响应的 `RVALID`，必须对应一笔已经被接受的 AR 读请求。**
也就是 slave 不能凭空在 R 通道返回数据。它必须先在 AR 通道看到一次有效握手；


读事务完成条件：

```text
RVALID && RREADY && RLAST
```




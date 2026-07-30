# 07 ID outstanding ordering

AXI 支持 outstanding transaction：Master 不必等上一笔事务完全完成，就可以发下一笔事务的地址。

这就需要 ID。

## ID 

| 信号     | 作用               |
| ------ | ---------------- |
| `AWID` | 写请求 ID           |
| `BID`  | 写响应 ID，对应 `AWID` |
| `ARID` | 读请求 ID           |
| `RID`  | 读数据 ID，对应 `ARID` |

ID 的作用是让 Master 知道：

```text
这个响应是对应哪一笔请求的？
```

## ordering 

最重要的规则：

```text
同一 ID 的事务响应必须保持顺序。
不同 ID 的事务可以没有顺序关系，具体取决于 DUT/Interconnect 是否支持乱序。
```

读通道：

- `RID` 必须对应之前发出的 `ARID`。
- 不同 ID 的读响应可以乱序返回。
- 同 ID 的读响应必须按请求顺序返回。

写通道：

- `BID` 必须对应之前发出的 `AWID`。
- 同 ID 的写响应必须按写请求顺序返回。
- AXI4 没有 `WID`，不能做 write data interleaving。

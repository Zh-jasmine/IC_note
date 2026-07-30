# 07 axi_scoreboard 当前状态与下一步

文件：

```text
10_uvm_work/tb/env/axi_scoreboard.svh
```

当前 scoreboard 还是骨架：

```text
s_fifo[AXI_S_COUNT]
  接收 S 侧 monitor item

m_fifo[AXI_M_COUNT]
  接收 M 侧 monitor item

consume_s()/consume_m()
  当前只统计和打印
```

它现在还没有真正做系统级比对。后续可以拆成四类 checker。

## 1. routing checker

检查地址路由是否正确：

```text
S 侧 AW/AR 地址 0x0000_0000 - 0x0000_0FFF -> M0
S 侧 AW/AR 地址 0x0001_0000 - 0x0001_0FFF -> M1
S 侧 AW/AR 地址 0x0002_0000 - 0x0002_0FFF -> M2
非法地址 -> DECERR
```

## 2. data checker

检查写数据和读数据：

```text
W beat 数 = AWLEN + 1
WLAST 只在最后一个 W beat 为 1
WSTRB 只更新被选中的 byte lane
写入后读回数据一致
```

## 3. response checker

检查响应返回路径：

```text
M side B -> S side B
M side R -> S side R
BRESP/RRESP 正确传回
非法地址返回 DECERR
```

重点还要关注：

```text
M_ID_WIDTH -> S_ID_WIDTH 的 ID 还原
response 是否回到原来的 source master
```

## 4. ordering checker

检查顺序约束：

```text
同 ID 的读响应必须按请求顺序返回
同 ID 的写响应必须按请求顺序返回
不同 ID 允许更灵活的返回顺序
```

当前阶段结论：

- scoreboard 已经接线了
- 但还不能称为完整 checker
- 第一版最应该先实现 routing + data

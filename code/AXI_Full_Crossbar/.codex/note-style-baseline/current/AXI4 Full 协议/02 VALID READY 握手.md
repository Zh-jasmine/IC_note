# 02 VALID READY 握手

每个 AXI 通道都用 `VALID/READY` 握手：

```text
VALID：源端说“我这里有有效 payload（有效载荷 真正有用的数据）”
READY：目的端说“我这一拍能接收 payload”
传输成立：ACLK 上升沿，VALID=1 且 READY=1
```

## 三种合法握手形态

VALID 先到：

![[assets/3.jpg]]

READY 先到：

![[assets/4.jpg]]

VALID 和 READY 同时到：

![[assets/5.jpg]]

## 最容易写错的规则

`VALID` 和 `READY` 不是“请求-应答”关系，而是两个方向的流控信号。

必须记住：

- 源端不能等 `READY` 才决定是否拉高 `VALID`，否则可能死锁。
- 目的端可以等 `VALID` 后再拉高 `READY`。
- 一旦 `VALID=1` 且还没握手，payload 必须保持稳定。
- `READY=0` 时就是 backpressure，表示目的端暂时接不住。

## 验证断言直觉

对 RTL 验证来说，这条断言非常重要：

```systemverilog
// VALID 拉高但 READY 未拉高时，payload 不能变化
VALID && !READY |=> $stable(payload);
```




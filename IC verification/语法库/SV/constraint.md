# constraint 基本写法

[[SV&UVM#^sv-constraint-basic|返回原处]]

## 原代码

```verilog
constraint c_addr {
    addr inside {[32'h1000:32'h1fff]};
    addr[1:0] == 2'b00;
}

constraint c_write {
    if (write) {
        data != 0;
    }
}
```

## constraint 的本质

constraint 不是普通顺序执行代码，而是给随机求解器的一组条件。调用 `randomize()` 时，求解器会尝试找到一组变量值，使所有开启的约束同时成立。

因此，constraint 更像“数学条件”，不是“程序流程”。

## 逐行语法

```verilog
constraint c_addr {
```

定义一个命名约束块。命名很重要，因为后面可以单独开关：

```verilog
req.c_addr.constraint_mode(0);
req.c_addr.constraint_mode(1);
```

```verilog
addr inside {[32'h1000:32'h1fff]};
```

`inside` 表示集合约束。这里要求 `addr` 必须在 `0x1000` 到 `0x1fff` 之间。

也可以写离散集合：

```verilog
addr inside {32'h1000, 32'h2000, 32'h3000};
```

```verilog
addr[1:0] == 2'b00;
```

低两位为 0，表示地址 4 字节对齐。这是协议约束里非常常见的写法。

```verilog
constraint c_write {
    if (write) {
        data != 0;
    }
}
```

条件约束。含义是：当 `write == 1` 时，`data != 0` 必须成立。

注意：这不是 procedural `if`，而是求解条件的一部分。

## inline constraint

```verilog
assert(req.randomize() with {
    write == 1;
    addr inside {[32'h1000:32'h10ff]};
});
```

inline constraint 是临时约束，只作用于这一次 `randomize()`。

它适合 sequence 临时收紧场景，例如 smoke test 固定写操作、error test 限定非法地址范围。

## dist 分布

```verilog
constraint c_dist {
    write dist {1 := 70, 0 := 30};
}
```

`dist` 控制随机分布权重。这里写操作权重 70，读操作权重 30。

`:=` 和 `:/` 的区别：

```verilog
addr dist {
    [0:3] := 10,
    [4:7] := 20
};
```

`:=` 表示范围内每个值都得到对应权重。

```verilog
addr dist {
    [0:3] :/ 10,
    [4:7] :/ 20
};
```

`:/` 表示权重在范围内平均分摊。

## solve before

```verilog
constraint c_order {
    solve write before data;
}
```

`solve before` 指定求解顺序。它不是说 `write` 的数值小于或早于 `data`，而是让求解器先决定 `write`，再决定 `data`。

常用于控制变量影响数据分布的场景。

## 约束冲突 debug

常见方法：

```verilog
if (!req.randomize()) begin
    `uvm_error("RAND", "randomize failed")
end
```

先检查返回值。

然后逐步关闭约束：

```verilog
req.c_addr.constraint_mode(0);
```

如果关闭某个约束后随机成功，说明冲突大概率和这个约束有关。

## 易错点

- `randomize()` 返回值必须检查。
- constraint 中的 `if` 不是普通顺序执行逻辑。
- 多个 constraint 是同时生效，不是按书写顺序依次执行。
- `solve before` 控制求解顺序，不是数值关系。
- 约束过紧会随机失败，约束过松会产生非法激励。

## 面试说法

可以这样答：

SV constraint 是给随机求解器的条件集合。`inside` 用于范围或集合约束，`if` 可用于条件约束，`dist` 控制分布，`solve before` 控制求解顺序。实际项目里必须检查 `randomize()` 返回值，随机失败时可以用 `constraint_mode()` 逐步关闭约束定位冲突。


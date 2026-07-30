# sequence item 发送流程

[[SV&UVM#^uvm-sequence-start-item|返回原处]]

## 原代码

```verilog
task body();
    apb_item req;

    req = apb_item::type_id::create("req");
    start_item(req);
    assert(req.randomize() with {
        write == 1;
        addr inside {[32'h1000:32'h1fff]};
    });
    finish_item(req);
endtask
```

## 这段代码处于哪里

这段代码通常写在 sequence 的 `body()` 里。sequence 的职责是产生 transaction，不直接驱动 pin-level 信号。

完整链路是：

```text
sequence -> sequencer -> driver -> interface -> DUT
```

## 逐行语法

```verilog
task body();
```

`body()` 是 sequence 的主体任务。sequence 被 `start()` 后，核心激励逻辑就在这里执行。

```verilog
apb_item req;
```

声明一个 transaction handle。这里只是 handle，还没有对象。

```verilog
req = apb_item::type_id::create("req");
```

通过 factory 创建 item。这样如果后续对 `apb_item` 做 factory override，这里可以创建出替换后的子类。

如果写成：

```verilog
req = new("req");
```

factory override 不会生效。

```verilog
start_item(req);
```

向 sequencer 申请发送这个 item。它会等待 sequencer 授权，并和 driver 侧握手机制配合。

```verilog
assert(req.randomize() with {
    write == 1;
    addr inside {[32'h1000:32'h1fff]};
});
```

对 item 做随机化。`with { ... }` 是 inline constraint，只影响这一次随机化。

这里表示：

- `write` 固定为 1。
- `addr` 限制在 `0x1000` 到 `0x1fff`。

```verilog
finish_item(req);
```

提交 item。之后 driver 可以通过 `get_next_item()` 拿到它。

## driver 侧对应写法

```verilog
seq_item_port.get_next_item(req);
drive_one_item(req);
seq_item_port.item_done();
```

`get_next_item()` 获取 item。  
`drive_one_item()` 把 transaction 转成 pin-level 时序。  
`item_done()` 告诉 sequencer 当前 item 已经处理完。

## start_item 和 finish_item 之间能做什么

常见写法：

```verilog
start_item(req);
assert(req.randomize());
finish_item(req);
```

也可以先给字段赋值：

```verilog
start_item(req);
req.addr  = 32'h1000;
req.write = 1'b1;
finish_item(req);
```

但要注意，如果字段是 rand 并且后续 randomize，手动赋值可能会被随机化覆盖，除非加 inline constraint。

## 易错点

- 忘记 `finish_item()`，driver 可能拿不到 item。
- driver 忘记 `item_done()`，sequence 可能卡住。
- 在 driver 中 randomize transaction，会破坏职责分离。
- sequence 直接操作 vif，会降低复用性。
- `assert(req.randomize())` 在仿真禁用 assertion 时可能有风险，有些项目更喜欢显式 if 检查。

更稳的写法：

```verilog
if (!req.randomize() with { write == 1; }) begin
    `uvm_fatal("RAND", "apb_item randomize failed")
end
```

## 面试说法

可以这样答：

sequence 通过 `start_item` 和 `finish_item` 产生并提交 transaction。item 通常用 `type_id::create()` 创建，以支持 factory override。随机化一般放在 sequence 中，driver 只负责通过 `get_next_item()` 获取 item 并驱动协议时序，驱动完成后调用 `item_done()`。


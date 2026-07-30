# mailbox 通信写法

[[SV&UVM#^sv-mailbox-basic|返回原处]]

## 原代码

```verilog
mailbox #(apb_item) mbx = new();

mbx.put(req);
mbx.get(req);
```

## 这段代码解决什么问题

`mailbox` 用于线程之间传递数据。它不仅是一个容器，还带有阻塞同步语义。

典型场景：

- generator 产生 transaction。
- driver 从 mailbox 取 transaction。
- generator 和 driver 运行在不同线程。

## 逐行语法

```verilog
mailbox #(apb_item) mbx = new();
```

声明并创建一个参数化 mailbox。`#(apb_item)` 表示 mailbox 中传递的数据类型是 `apb_item`。

如果不写参数类型：

```verilog
mailbox mbx = new();
```

就是非类型化 mailbox，任何类型都能放进去，但类型安全较差。

```verilog
mbx.put(req);
```

把 `req` 放进 mailbox。对于无界 mailbox，通常不会因为容量满而阻塞。对于有界 mailbox，如果满了，`put()` 会阻塞。

```verilog
mbx.get(req);
```

从 mailbox 取一个 item，并赋给 `req`。如果 mailbox 为空，`get()` 会阻塞，直到有数据可取。

## 有界 mailbox

```verilog
mailbox #(apb_item) mbx = new(4);
```

`new(4)` 表示最多缓存 4 个 item。满的时候，producer 的 `put()` 会阻塞。

这可以模拟背压，也能防止 producer 无限产生数据导致内存膨胀。

## 非阻塞访问

```verilog
if (mbx.try_get(req)) begin
    drive(req);
end else begin
    // mailbox is empty
end
```

`try_get()` 不会阻塞。取到数据返回 1，取不到返回 0。

```verilog
if (!mbx.try_put(req)) begin
    `uvm_warning("MBX", "mailbox is full")
end
```

`try_put()` 不会阻塞。放入成功返回 1，失败返回 0。

## peek 和 get

```verilog
mbx.peek(req);
```

`peek()` 只查看 mailbox 头部元素，不移除它。

```verilog
mbx.get(req);
```

`get()` 会取出并移除元素。

## mailbox 和 queue 的区别

queue 是数据结构：

```verilog
apb_item q[$];
```

它本身没有线程同步语义。你需要自己判断空、满、等待条件。

mailbox 是同步通信机制：

```verilog
mbx.get(req);
```

它可以阻塞等待数据，因此更适合线程间通信。

## 易错点

- `get()` 可能永久阻塞，必须考虑 producer 是否一定会 put。
- `try_get()` 不阻塞，但必须检查返回值。
- mailbox 传的是 object handle，不是自动深拷贝。
- producer 修改 put 进去的对象，consumer 看到的可能也是修改后的对象。
- UVM 中更常见的是 TLM port/fifo，但 mailbox 仍是 SV 基础高频点。

## 面试说法

可以这样答：

mailbox 是 SV 提供的线程间通信机制，支持阻塞 `put/get` 和非阻塞 `try_put/try_get`。它和 queue 的区别是 mailbox 自带同步语义，适合 generator 和 driver 这种 producer-consumer 模型。需要注意 mailbox 传递 class object 时传的是 handle，不是深拷贝。


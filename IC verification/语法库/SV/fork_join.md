# fork/join timeout 写法

[[SV&UVM#^sv-fork-join-timeout|返回原处]]

## 原代码

```verilog
fork
    begin
        wait(done);
    end
    begin
        #100us;
        `uvm_error("TIMEOUT", "wait done timeout")
    end
join_any
disable fork;
```

## 这段代码解决什么问题

这是一种典型 timeout 写法，用来等待某个条件发生，同时防止仿真无限卡死。

它并发启动两个线程：

- 正常线程：等待 `done` 变成真。
- 超时线程：等待固定时间，如果时间到了还没结束，就报 timeout。

谁先结束，`join_any` 就让父线程继续执行。随后 `disable fork` 杀掉另一个仍在运行的线程。

## 逐行语法

```verilog
fork
```

启动一个并发块。`fork` 和普通 `begin/end` 的区别是：`begin/end` 里的语句顺序执行，`fork/join` 里的子线程并发执行。

```verilog
begin
    wait(done);
end
```

这是第一个子线程。`wait(done)` 是阻塞语句，只要 `done` 为 0，就一直等待；当 `done` 变成 1 时，这个线程结束。

```verilog
begin
    #100us;
    `uvm_error("TIMEOUT", "wait done timeout")
end
```

这是第二个子线程。它先延迟 `100us`，然后打印 UVM error。它代表“最晚只能等这么久”。

```verilog
join_any
```

`join_any` 的含义是：只要 fork 中任意一个子线程结束，父线程就继续往下执行。

```verilog
disable fork;
```

结束当前 fork 作用域下仍然活着的子线程。这里非常关键。

如果 `done` 先发生，timeout 线程还在等 `#100us`，需要被杀掉。  
如果 timeout 先发生，`wait(done)` 线程还在等，也需要被杀掉。

## join / join_any / join_none

```verilog
fork
    task_a();
    task_b();
join
```

`join` 等所有子线程都结束，父线程才继续。

```verilog
fork
    task_a();
    task_b();
join_any
```

`join_any` 等任意一个子线程结束，父线程就继续。

```verilog
fork
    task_a();
    task_b();
join_none
```

`join_none` 不等待子线程，父线程立即继续。

## 常见变体

**变体 1：等待信号边沿 timeout**

```verilog
fork
    begin
        @(posedge done);
    end
    begin
        repeat (1000) @(posedge clk);
        `uvm_error("TIMEOUT", "done timeout")
    end
join_any
disable fork;
```

这种写法比 `#100us` 更适合时钟同步协议，因为它按 clock cycle 计时。

**变体 2：等待多个条件之一**

```verilog
fork
    wait(resp_valid);
    wait(error_seen);
    begin
        repeat (1000) @(posedge clk);
        `uvm_error("TIMEOUT", "no response")
    end
join_any
disable fork;
```

这表示 response、error、timeout 三者谁先发生，就结束等待。

## 易错点

- `join_any` 后忘记 `disable fork`，残留线程会继续跑。
- `disable fork` 会杀当前 fork 作用域下的未结束线程，作用域要确认清楚。
- 如果 fork 外层还有别的并发线程，不要误杀到不该杀的逻辑。
- timeout 用 `#delay` 还是 `repeat @(posedge clk)`，取决于协议是否时钟同步。
- `uvm_error` 不会自动停止仿真；如果 timeout 后必须终止，可以用 `uvm_fatal`。

## 面试说法

可以这样答：

`fork/join_any` 常用于 timeout 监控。一个线程等待正常条件，另一个线程计时超时。任意线程结束后，父线程继续执行，然后用 `disable fork` 清理另一个未结束线程。否则超时线程或等待线程可能残留，后续仿真会出现误报或死等。


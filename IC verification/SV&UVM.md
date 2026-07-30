# SV/UVM 



## <span style="color:#8B0000">1. SystemVerilog 基础</span>

SystemVerilog 基础不是单纯背语法，而是要理解“硬件表达”和“验证建模”之间的边界。RTL 更关心信号位宽、时序逻辑、组合逻辑和可综合性；验证环境更关心随机化、对象、动态数据结构、并发通信和可观察性。

面试中这一章常被用来判断候选人是否真的写过 testbench：如果回答只停留在 `logic` 比 `reg` 新、queue 可以 push/pop，通常不够。更好的回答要能说清楚类型选择会不会影响 `X/Z` 观察、数组维度会不会影响 bit layout、动态结构适合 testbench 还是 RTL。

### 1.1 二值与四值类型

SystemVerilog 中常见的二值类型有 `bit`、`byte`、`shortint`、`int`、`longint`，只能表示 `0/1`。四值类型有 `logic`、`reg`、`wire`，可以表示 `0/1/X/Z`。

验证里如果需要观察未知态传播，通常不能随便用 `bit`，因为 `bit` 会把 `X/Z` 压成二值，可能掩盖未初始化、总线争用、复位不完整等问题。class 内部的纯软件计数器、循环变量、配置参数可以用 `int` 或 `bit`，DUT 接口信号通常用 `logic`。

面试展开时可以强调：验证环境的一个重要任务就是发现未知态、复位问题和非法驱动。如果在 interface、monitor 采样变量、scoreboard 比对变量中盲目使用二值类型，可能会把本来应该暴露的 `X` 变成普通 0 或 1，导致 bug 被隐藏。二值类型不是不能用，而是应该用在明确不需要 `X/Z` 语义的软件建模变量上。

```verilog
bit         valid_2state;
logic       valid_4state;
int         loop_idx;
logic [7:0] bus_data;
```

### 1.2 logic、reg、wire

`reg` 是 Verilog 时代的变量类型，不一定真的对应寄存器。`logic` 是 SystemVerilog 推荐使用的变量类型，可以用于过程赋值。`wire` 是 net 类型，适合连续赋值、模块端口连接和多驱动网络。

简单理解：

- `logic`：变量，常用于 testbench、RTL 内部过程赋值。
- `wire`：网络，常用于连续赋值、多驱动连接。
- `reg`：老语法保留，SV 中多数场景可以用 `logic` 替代。

回答时不要说“`logic` 完全替代 `wire`”。更准确的说法是：`logic` 更适合单驱动变量，`wire` 更适合 net 连接和连续赋值语义。接口信号在 testbench 中通常写成 `logic`，但如果有多驱动、tri-state、连续 assign 网络，就仍然需要理解 net 类型。

```verilog
logic a;
logic b;
wire  y;

assign y = a & b;
```

### 1.3 packed 与 unpacked

`packed array` 是连续位向量，适合描述硬件位宽。`unpacked array` 是元素集合，更像软件数组。

packed 维度在变量名前，unpacked 维度在变量名后。面试中经常会问 `logic [7:0] a [4]` 和 `logic [4][7:0] a` 的区别。

判断 packed/unpacked 的关键是看它是否参与位级运算和整体赋值。packed array 可以被当成一个连续向量切片、拼接、比较；unpacked array 更像多个独立元素，适合存储多笔数据。scoreboard 队列、memory model、transaction 缓存一般用 unpacked 结构；DUT 端口、协议字段、寄存器字段一般用 packed vector。

```verilog
logic [7:0] data;      // packed: 一个 8bit 向量
logic       data_arr [8]; // unpacked: 8 个 1bit 元素
logic [7:0] mem [16];  // 16 个 8bit 元素
```

### 1.4 动态数组、队列、关联数组

动态数组适合运行时决定大小；队列适合先进先出、push/pop；关联数组适合稀疏索引或用字符串、地址做 key。

队列在 testbench 中很常见，例如 scoreboard 缓存 expected/actual transaction。关联数组常用于按 ID、地址、transaction tag 管理乱序返回。

项目里选择数据结构要和协议行为对应。顺序返回协议可以用 queue，因为 expected 和 actual 的顺序一致；带 ID 的乱序协议更适合关联数组，因为返回顺序不固定，需要通过 ID/tag 找到对应 expected。动态数组适合一次性分配一批固定数量元素，比如根据配置创建 N 个 channel 状态。

```verilog
int dyn_arr[];
int q[$];
int aa[string];

dyn_arr = new[8];
q.push_back(10);
q.push_front(5);
aa["id0"] = 100;
```

### 1.5 enum、struct、typedef

`enum` 适合描述状态、类型、操作码。`struct packed` 适合把多个字段组织成一个硬件位向量。`typedef` 可以提高代码可读性，也方便复用类型。

`enum` 的好处不只是可读性，还包括限制取值范围和帮助 debug。波形里看到 `ACCESS` 比看到 `2'b10` 更容易理解。`struct packed` 常用于把寄存器字段、协议 header 字段组织起来，但要注意 packed struct 的字段顺序和位宽会影响最终 bit layout。

```verilog
typedef enum logic [1:0] {
    IDLE,
    SETUP,
    ACCESS
} apb_state_e;

typedef struct packed {
    logic [31:0] addr;
    logic [31:0] data;
    logic        write;
} apb_pkt_s;
```

### 1.6 阻塞赋值与非阻塞赋值

阻塞赋值 `=` 会按语句顺序立即更新左值，非阻塞赋值 `<=` 会在当前时间步的 NBA 区域统一更新。面试中这不是纯语法题，而是考你是否理解仿真调度和 RTL 建模习惯。

组合逻辑里通常用阻塞赋值，因为组合逻辑表达的是输入变化后立即计算中间结果；时序逻辑里通常用非阻塞赋值，因为触发器在同一个时钟边沿同时采样并更新。混用不一定语法错误，但很容易造成仿真和预期不一致。

```verilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q <= '0;
    end else begin
        q <= d;
    end
end
```

### 1.7 initial、always、always_comb、always_ff

`initial` 只执行一次，testbench 中常用于初始化 clock/reset、调用 `run_test()`。`always` 反复执行，常用于时钟生成或 RTL 逻辑。SystemVerilog 增加了 `always_comb`、`always_ff`、`always_latch`，用来表达更明确的设计意图。

验证岗位也会被问这类 RTL 基础，因为验证工程师需要能看懂 DUT，也要能识别 latch、组合环、阻塞/非阻塞错误等问题。

```verilog
initial begin
    clk = 0;
    forever #5ns clk = ~clk;
end

always_comb begin
    y = a & b;
end
```

### 1.8 task、function、ref、const ref

`function` 不应该消耗仿真时间，适合纯计算、转换、比较、打印格式化等逻辑。`task` 可以包含 `@`、`#delay`、`wait` 等耗时语句，适合驱动、采样、等待协议事件。

参数传递上，`input/output/inout/ref` 都可能被问。`ref` 是引用传递，子程序内部修改会影响调用者变量；大数组传参时用 `const ref` 可以避免复制开销，同时防止函数修改参数。

```verilog
function bit is_aligned(input logic [31:0] addr);
    return addr[1:0] == 2'b00;
endfunction

task wait_ready(ref logic ready);
    wait(ready == 1'b1);
endtask
```

### 1.9 @event 与 wait(condition)

`@(signal)` 等待 signal 发生变化，关注的是事件；`wait(condition)` 等待条件为真，关注的是表达式值。如果条件一开始就为真，`wait(condition)` 会立即通过；而 `@(signal)` 必须等下一次变化。

这个问题在面经里很常见，因为它能区分“知道语法”和“知道仿真行为”。写 timeout、等待握手、等待 reset release 时，两者差别会影响 testbench 是否死等或提前通过。

```verilog
@(posedge valid);
wait(valid && ready);
```

### 易错点

- `bit` 看不到 `X/Z`，验证接口信号不要随便用 `bit`。
- `logic` 不是万能替代 `wire`，多驱动 net 仍要理解 `wire`。
- packed/unpacked 维度位置不同，含义不同。
- `enum` 最好显式指定位宽，避免和硬件信号对齐时出问题。
- 队列适合 testbench，不适合直接综合成 RTL 存储结构。
- 时序逻辑里乱用阻塞赋值，可能导致仿真行为和硬件意图不一致。
- function 里不能写耗时控制，等待、驱动、采样通常用 task。
- `@signal` 和 `wait(signal)` 触发语义不同，不能混着背。

### QUESTION

- `bit` 和 `logic` 的区别是什么？
- `logic` 和 `wire` 的区别是什么？
- packed array 和 unpacked array 有什么区别？
- dynamic array、queue、associative array 分别适合什么场景？
- 为什么验证环境中不能随便把接口信号定义成 `bit`？
- 阻塞赋值和非阻塞赋值有什么区别？
- task 和 function 有什么区别？
- `@signal` 和 `wait(signal)` 有什么区别？

## <span style="color:#8B0000">2. SV OOP</span>

SV OOP 是 UVM 的基础。UVM 里的 transaction、sequence、driver、monitor、agent、env、test 都是 class 体系组织起来的。如果 OOP 理解不清楚，后面 factory、config object、sequence 复用、callback、多态替换都会很难讲清。

面试里 OOP 通常不会只问“什么是继承”，而是会结合 UVM 问：为什么 factory override 要求继承关系、为什么 transaction 赋值后两个 handle 会互相影响、为什么 driver 里拿到的是父类 handle 但实际执行子类方法。

### 2.1 class 与 object handle

class 是模板，对象是运行时创建出来的实例，handle 是指向对象的句柄。handle 本身不是对象，默认值是 `null`。

两个 handle 可以指向同一个对象，所以 `p2 = p1` 只是句柄赋值，不是复制一个新对象。面试中经常追问 shallow copy 和 deep copy，本质就是字段里如果还有对象 handle，是否递归复制内部对象。

在验证环境中，transaction 经常在 monitor、scoreboard、coverage 之间传递。如果只是传 object handle，而后续又修改了这个 object，就可能导致多个组件看到的内容被意外改变。因此 monitor 广播 transaction 前，很多项目会 clone 一份，或者约定 transaction 发出后不再修改。

```verilog
class base_pkt;
    rand bit [31:0] addr;
    rand bit [31:0] data;
endclass

base_pkt p1;
base_pkt p2;

p1 = new();
p1.addr = 32'h1000;
p2 = p1;
p2.addr = 32'h2000;
```

### 2.2 继承与多态

继承用于复用父类字段和方法，多态用于通过父类 handle 调用子类重写后的行为。父类方法需要声明 `virtual`，通过父类 handle 调用时才会动态绑定到子类实现。

UVM factory override 能工作，底层依赖的就是继承、多态和统一的创建机制。

多态在 UVM 中很常见。例如 sequence 里声明的是 `base_item req`，但 factory 实际创建出 `err_item`，driver 仍然可以按 `base_item` 接口处理它。这样 test 可以在不改 driver 的情况下替换 transaction 行为。

```verilog
class base_pkt;
    virtual function void print();
        $display("base packet");
    endfunction
endclass

class apb_pkt extends base_pkt;
    virtual function void print();
        $display("apb packet");
    endfunction
endclass
```

### 2.3 static 与 automatic

`static` 成员属于类或子程序本身，不属于某个对象实例。多个对象共享同一个 static 变量。

task/function 默认生命周期和声明位置有关。验证中更常关注的是：递归、并发调用、局部变量独立性。如果一个方法可能被并发调用，要避免共享局部状态导致竞争。

项目中 static 常用于全局计数、唯一 ID 分配、共享表等，但要谨慎使用。static 变量会让多个对象实例产生隐式耦合，debug 时不如显式配置清楚。如果一个变量应该属于某个 agent 实例，就不要写成 static。

```verilog
class pkt_counter;
    static int total_count;

    function void incr();
        total_count++;
    endfunction
endclass
```

### 2.4 copy、clone、compare、print

UVM object 常实现 `do_copy`、`do_compare`、`do_print` 等方法，用于事务复制、比较和打印。项目里 transaction compare fail 时，能否打印清楚字段差异非常重要。

`copy/clone` 解决对象复用和保护问题，`compare` 解决 scoreboard 比对问题，`print/sprint` 解决 debug 可视化问题。一个 transaction 类如果只定义字段、不实现这些方法，短 demo 能跑，但项目 debug 会很痛苦。

```verilog
function void do_copy(uvm_object rhs);
    apb_item rhs_;

    if (!$cast(rhs_, rhs)) begin
        `uvm_fatal("COPY", "cast failed")
    end

    super.do_copy(rhs);
    addr  = rhs_.addr;
    data  = rhs_.data;
    write = rhs_.write;
endfunction
```

### 易错点

- class handle 使用前必须创建对象，否则是 `null`。
- `p2 = p1` 不是深拷贝。
- 父类方法没有 `virtual` 时，通过父类 handle 调用不会动态绑定。
- `static` 变量被所有实例共享。
- UVM 中直接 `new()` 会绕过 factory override。

### QUESTION

- class、object、handle 分别是什么？
- shallow copy 和 deep copy 有什么区别？
- virtual function 的作用是什么？
- static 变量和普通成员变量有什么区别？
- UVM factory 为什么依赖多态？

## <span style="color:#8B0000">3. 随机化与约束</span>

随机化的目标不是“生成很多随机值”，而是在协议合法范围内探索尽可能多的功能场景。约束负责保证合法性，coverage 负责反馈覆盖情况，sequence 负责组织场景。面试里如果只会写 `rand` 和 `constraint`，不够；更重要的是能解释约束和覆盖率如何配合。

项目中常见策略是 directed test 覆盖基本功能，constrained random 覆盖组合空间，error injection 覆盖异常路径。随机化写得好，环境能自动探索边界；随机化写得差，会产生大量无效激励或永远打不到关键场景。

### 3.1 rand、randc、randomize

`rand` 表示变量可随机。`randc` 表示循环随机，在取完所有可能值之前不会重复。`randomize()` 触发求解器求解，返回值必须检查。

`randc` 不适合巨大值域，否则状态空间太大。项目里常用 `rand` 加覆盖率反馈控制随机分布。

`randomize()` 失败不是小事，它通常说明约束互相矛盾、inline constraint 过紧，或者变量值域无法满足条件。面试时可以主动说“我会检查 randomize 返回值”，这比只写 `assert(req.randomize())` 更工程化。

```verilog
class apb_item;
    rand  bit [31:0] addr;
    rand  bit [31:0] data;
    randc bit [3:0]  id;
endclass

apb_item req = new();

if (!req.randomize()) begin
    $fatal("randomize failed");
end
```

### 3.2 基本约束

约束用于限制随机变量的合法范围。常见写法包括范围、集合、条件、唯一性、对齐约束。

协议类 transaction 的约束通常分为三类：基础合法性约束、场景约束、错误注入约束。基础合法性约束应该长期打开，例如地址对齐、burst 长度范围；场景约束可以由 sequence 临时添加；错误注入约束则可能故意打破部分合法性，用于验证 DUT 的错误响应。

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

[grammar](语法库/SV/constraint.md) ^sv-constraint-basic

### 3.3 inline constraint

内联约束用于在某个 sequence 或某次随机化中临时收紧约束，不需要修改 transaction 类本身。

inline constraint 的价值是让 transaction 类保持通用，而把具体场景留给 sequence。比如同一个 `apb_item` 可以被 smoke sequence、random sequence、error sequence 复用，只是每个 sequence 施加不同的 inline constraint。

```verilog
assert(req.randomize() with {
    write == 1;
    addr inside {[32'h1000:32'h10ff]};
});
```

### 3.4 dist 与 solve before

`dist` 用于控制分布权重。`solve before` 用于控制求解顺序，常用于先决定控制变量，再决定数据变量。

`:=` 表示范围内每个值都获得指定权重；`:/` 表示把权重分摊到范围内所有值。

`dist` 不应该被当成精确比例控制，它只是影响求解器倾向。覆盖率收敛时可以调整分布，让低概率场景更容易出现。`solve before` 常用于避免条件变量的分布被后续约束“扭曲”，尤其是一个变量决定另一个变量取值范围时。

```verilog
constraint c_dist {
    write dist {1 := 70, 0 := 30};
}

constraint c_order {
    solve write before data;
}
```

### 3.5 约束冲突 debug

随机失败通常来自约束冲突、内联约束和类约束互相矛盾、变量值域过小、约束过度收紧。debug 时先检查 `randomize()` 返回值，再逐步关闭部分约束，缩小冲突范围。

真实项目里约束冲突常出现在“基础约束 + 场景约束 + 配置约束”叠加之后。比如基础约束要求地址在合法空间，sequence 又把地址限制到错误空间，这时随机失败不是工具问题，而是场景定义互相矛盾。debug 时不要盲目删约束，而要判断哪个约束属于长期合法性，哪个属于临时场景。

```verilog
req.c_addr.constraint_mode(0);

if (!req.randomize()) begin
    `uvm_error("RAND", "randomize still failed after disabling c_addr")
end
```

### 易错点

- `randomize()` 返回值不检查，随机失败会被忽略。
- `solve before` 不是数值大小关系。
- `randc` 不是所有场景都适合。
- 约束太死会导致覆盖率难收敛。
- 约束太松会产生大量非法激励，浪费仿真。

### QUESTION

- `rand` 和 `randc` 的区别是什么？
- `randomize()` 失败有哪些原因？
- `inside`、`dist`、`solve before` 分别怎么用？
- `:=` 和 `:/` 的区别是什么？
- 约束冲突怎么 debug？

## <span style="color:#8B0000">4. 线程与同步通信</span>

验证环境天然是并发系统：driver 在驱动，monitor 在采样，scoreboard 在比对，coverage 在采样，timeout watchdog 在监控。SV 的并发和同步机制是理解 testbench 行为的基础。

面试常见考点不是让你背 API，而是看你是否知道阻塞点在哪里、线程什么时候结束、残留线程会不会影响后续 test、多个线程共享资源时如何避免死锁。

### 4.1 fork/join

`fork/join` 用于并发执行。`join` 等待所有子线程结束；`join_any` 等任意一个结束；`join_none` 不等待，父线程继续执行。

timeout 监控常用 `join_any + disable fork`。如果不 `disable fork`，另一个未结束线程还会继续运行。

在 UVM run_phase 里，timeout 逻辑非常常见。比如 sequence 等待 interrupt、driver 等待 ready、scoreboard 等待 response，都不能无限等。一个成熟的验证环境应该给关键等待点加 timeout，否则 bug 可能表现为仿真永远挂住。

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

[grammar](语法库/SV/fork_join.md) ^sv-fork-join-timeout

### 4.2 event

`event` 用于线程间通知。一个线程触发事件，另一个线程等待事件。它适合简单同步，不适合传递复杂数据。

`event` 的优势是轻量，适合“某件事发生了”的通知；缺点是它不携带数据，也不适合复杂握手。对于带数据的 producer-consumer 模型，mailbox 或 TLM FIFO 更合适。

```verilog
event reset_done_e;

initial begin
    wait(rst_n == 1'b1);
    -> reset_done_e;
end

initial begin
    @reset_done_e;
    start_test();
end
```

### 4.3 semaphore

`semaphore` 用于资源互斥，比如多个线程争用同一个资源。`get()` 获取 key，`put()` 释放 key。

semaphore 可以理解为 testbench 里的锁。它适合保护共享资源，例如共享总线、共享文件句柄、共享 memory model。使用时最重要的是保证所有路径都能释放锁，尤其是中途报错或提前 return 的路径。

```verilog
semaphore bus_lock = new(1);

task access_bus();
    bus_lock.get(1);
    drive_bus_transfer();
    bus_lock.put(1);
endtask
```

### 4.4 mailbox

`mailbox` 用于线程之间传递数据。`put()` 放数据，`get()` 阻塞取数据，`try_get()` 非阻塞取数据。早期非 UVM testbench 中常用 mailbox 连接 generator 和 driver。

在 UVM 中，mailbox 的位置经常被 TLM 取代，但理解 mailbox 仍然重要，因为它体现了 producer-consumer 模型。generator 产生事务，driver 消费事务，这个抽象和 sequence/sequencer/driver 的思想是一致的，只是 UVM 提供了更标准的通信和仲裁机制。

```verilog
mailbox #(apb_item) mbx = new();

mbx.put(req);
mbx.get(req);
```

[grammar](语法库/SV/mailbox.md) ^sv-mailbox-basic

### 易错点

- `join_any` 后不 `disable fork`，残留线程可能继续影响仿真。
- `mailbox.get()` 是阻塞调用，可能导致死等。
- `try_get()` 要检查返回值。
- `semaphore.get()` 后忘记 `put()` 会造成死锁。
- UVM 中更常用 TLM 通信，但 SV 基础通信机制仍然会被问。

### QUESTION

- `join`、`join_any`、`join_none` 有什么区别？
- 为什么 timeout 常用 `join_any + disable fork`？
- mailbox 和 queue 有什么区别？
- event、semaphore、mailbox 分别适合什么场景？
- 如何分析线程死锁？

## <span style="color:#8B0000">5. interface、modport、virtual interface</span>

interface 这一章是 SV 和 UVM 连接的关键。DUT、clock、reset、interface 都在 module 静态层次；UVM driver、monitor、agent 都是 class 动态对象。`virtual interface` 就是把这两个世界接起来的句柄。

面试时不要只说“interface 用于封装信号”。更完整的回答应该包括：interface 降低端口连接复杂度，modport 限制方向，clocking block 规范采样/驱动时机，virtual interface 让 class 能访问真实 interface 实例。

### 5.1 interface

`interface` 用于封装一组相关信号，减少端口连接复杂度。它可以包含信号、task、function、clocking block、modport。

对于 APB/AXI/AHB 这类总线协议，把信号集中放在 interface 中，driver 和 monitor 通过同一个接口访问，环境结构会更清楚。

项目中通常会给每个协议定义一个 interface，例如 `apb_if`、`axi_if`、`spi_if`。driver 只关心如何通过 interface 驱动协议，monitor 只关心如何通过 interface 采样协议。这样 DUT 换实例名、环境换层次，driver/monitor 不需要改内部层次路径。

```verilog
interface apb_if(input logic clk, input logic rst_n);
    logic        psel;
    logic        penable;
    logic [31:0] paddr;
    logic [31:0] pwdata;
    logic [31:0] prdata;
    logic        pwrite;
endinterface
```

[grammar](语法库/SV/interface.md) ^sv-interface-basic

### 5.2 modport

`modport` 用于限制访问方向，定义不同模块或 testbench 角色看到的输入输出视角。例如 DUT 视角和 driver 视角的方向通常相反。

modport 的价值在于让方向关系更明确。DUT 看到的 `input`，driver 可能是 `output`；monitor 通常几乎全是 `input`。如果项目里 interface 信号很多，modport 能减少误驱动和误连接。

```verilog
modport dut_mp (
    input  clk,
    input  rst_n,
    input  psel,
    input  penable,
    input  paddr,
    input  pwdata,
    input  pwrite,
    output prdata
);
```

### 5.3 virtual interface

`virtual interface` 是 class 侧访问真实 interface 实例的句柄。DUT 和 interface 在 module 静态层次中，UVM driver/monitor 是 class 动态对象，所以需要通过 `virtual interface` 把硬件信号世界和 class 世界连接起来。

virtual interface 通常由 top module 或 test 设置到 config_db，再由 agent/driver/monitor 在 build_phase 取出。多实例环境中，更推荐把 vif 放在 agent config object 里，而不是所有组件都自己从全局 `"*"` 取。

```verilog
class apb_driver extends uvm_driver #(apb_item);
    virtual apb_if vif;

    task drive_one_item(apb_item tr);
        @(posedge vif.clk);
        vif.psel   <= 1'b1;
        vif.pwrite <= tr.write;
        vif.paddr  <= tr.addr;
        vif.pwdata <= tr.data;
    endtask
endclass
```

### 易错点

- class 中保存 interface 句柄要写 `virtual`。
- 直接在 class 中写死 `tb_top.u_if` 会破坏复用性。
- 多 agent 环境不要无脑用 `"*"` 传 vif。
- modport 是方向约束，不是单独实例。
- driver 和 monitor 可以共用一个 interface，但职责不能混。

### QUESTION

- interface 解决什么问题？
- modport 的作用是什么？
- 为什么 UVM 中需要 virtual interface？
- vif 一般在哪里 set，在哪里 get？
- 多个 agent 时怎么避免 vif 配错？

## <span style="color:#8B0000">6. clocking block</span>

clocking block 的核心价值是减少 testbench 和 DUT 在同一个时钟边沿读写信号时的 race condition。它不是协议本身的一部分，而是 testbench 的时序访问约束。

面试中如果能从仿真调度角度解释它，会比只说“clocking block 用来同步”更有说服力：DUT 在时钟边沿采样输入、更新输出，testbench 如果也在同一边沿直接读写，可能因为调度 region 不同产生竞争；clocking block 给输入采样和输出驱动定义明确偏移。

### 6.1 作用

`clocking block` 用于规范 testbench 对同步信号的采样和驱动时机，主要解决 race condition。DUT 和 testbench 如果都在同一个时钟边沿读写信号，调度顺序可能导致不稳定行为。

```verilog
clocking drv_cb @(posedge clk);
    default input #1step output #1ns;
    output psel, penable, paddr, pwdata, pwrite;
    input  prdata;
endclocking
```

### 6.2 input/output skew

`input #1step` 表示在当前时间槽之前的稳定值采样，常用于 monitor。`output #1ns` 表示在时钟边沿之后延迟一定时间驱动，常用于 driver。具体 skew 取决于项目规范。

`#1step` 是一个特殊概念，表示采样前一个时间精度的值，常用于避免采到当前 time slot 中刚被更新的值。output skew 则让 testbench 在时钟边沿之后驱动，模拟更合理的驱动时机，也避免和 DUT always block 抢同一个调度点。

```verilog
clocking mon_cb @(posedge clk);
    default input #1step output #1ns;
    input psel, penable, paddr, pwdata, prdata, pwrite;
endclocking
```

### 6.3 driver 与 monitor 视角

driver 的 clocking block 需要声明输出信号；monitor 的 clocking block 主要声明输入信号。两者最好分开，避免读写方向混乱。

项目里常见写法是 `drv_cb` 和 `mon_cb` 分开。driver 只通过 `drv_cb` 驱动，monitor 只通过 `mon_cb` 采样，这样职责清楚，也方便 review 时发现错误方向访问。

```verilog
@(vif.drv_cb);
vif.drv_cb.psel  <= 1'b1;
vif.drv_cb.paddr <= tr.addr;
```

### 易错点

- 不要混用 clocking block 访问和原始信号访问。
- input/output skew 要和协议、仿真时间单位匹配。
- clocking block 不能替代协议理解。
- monitor 不应该通过 clocking block 驱动信号。

### QUESTION

- clocking block 解决什么问题？
- `input #1step` 是什么意思？
- race 和 clocking block 有什么关系？
- driver 和 monitor 是否应该共用同一个 clocking block？
- clocking block 和 modport 能否一起使用？

## <span style="color:#8B0000">7. UVM 基础结构</span>

UVM 的核心思想是分层和复用。test 负责配置和场景，env 负责组织验证环境，agent 负责封装单个接口，driver/monitor/scoreboard/coverage 分别承担驱动、采样、检查和覆盖率统计。

面试里讲 UVM 架构时，不要只背组件名。更重要的是讲数据流：sequence 产生 transaction，driver 驱动 DUT，monitor 采样 DUT 行为，scoreboard 比较 expected 和 actual，coverage 统计验证计划覆盖情况。

### 7.1 uvm_object 与 uvm_component

`uvm_object` 常用于 transaction、sequence item、config object。`uvm_component` 常用于 driver、monitor、agent、env、test。

component 有层次结构和 phase，创建时需要 parent。object 没有组件树层次，通常是数据对象或配置对象。

可以把 component 理解成验证环境的“骨架”，object 理解成环境里流动的“数据”。component 一般在 build_phase 创建并挂到 topology 上，object 通常在运行过程中动态创建、传递、复制和比较。

```verilog
class apb_item extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;

    `uvm_object_utils(apb_item)

    function new(string name = "apb_item");
        super.new(name);
    endfunction
endclass
```

### 7.2 transaction 与 sequence_item

transaction 是事务级抽象，用字段描述一次协议操作。`uvm_sequence_item` 是常见 transaction 基类，支持 sequencer/driver 通信、打印、比较、复制等机制。

transaction 字段设计要贴合协议语义。比如 APB item 至少应该包含 addr、data、write、strb、resp 等；AXI item 可能还要包含 id、burst、len、size、prot、resp。字段过少会导致 scoreboard 和 coverage 无法表达真实协议行为。

```verilog
class apb_item extends uvm_sequence_item;
    rand bit [31:0] addr;
    rand bit [31:0] data;
    rand bit        write;
endclass
```

### 7.3 test、env、agent

test 负责场景配置和启动 sequence。env 负责组织 agent、scoreboard、coverage、reference model。agent 封装某个接口的 driver、monitor、sequencer。

agent 分 active 和 passive。active agent 有 sequencer/driver/monitor，可以主动驱动接口；passive agent 通常只有 monitor 和 coverage，用于观察 DUT 或外部 master 行为。项目里同一个 agent 设计成 active/passive 可配置，复用性更高。

```verilog
class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass
```

### 易错点

- object 注册用 `uvm_object_utils`，component 注册用 `uvm_component_utils`。
- component 构造函数带 parent，object 通常不带 parent。
- sequence 是 object，不是 component。
- agent 可以是 active 或 passive。
- transaction 字段设计要贴合协议，不要只放 data。

### QUESTION

- `uvm_object` 和 `uvm_component` 的区别是什么？
- sequence 是 object 还是 component？
- agent、env、test 分别负责什么？
- transaction 字段应该怎么设计？
- active agent 和 passive agent 有什么区别？

## <span style="color:#8B0000">8. UVM phase 与 objection</span>

phase 机制让 UVM 环境按统一顺序执行。所有 component 都按 phase 流程创建、连接、运行和收尾，这样大环境中多个组件不会各自随意启动。

objection 是 run-time phase 结束控制机制。它解决的问题是：UVM 不知道你的激励什么时候才算结束，所以需要 test 或 sequence 在关键运行期间 raise objection，结束后 drop objection。

### 8.1 build/connect/run

`build_phase` 用于创建组件和读取配置。`connect_phase` 用于连接 TLM 端口。`run_phase` 是消耗仿真时间的阶段。

build_phase 只做结构搭建，不应该消耗仿真时间；connect_phase 只做连接，不应该创建复杂运行对象；run_phase 才是真正执行激励、采样、检查等待的地方。把事情放错 phase，是 UVM 新手常见问题。

```verilog
function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    agent = apb_agent::type_id::create("agent", this);
endfunction

function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.ap.connect(sb.imp);
endfunction
```

### 8.2 check/report/final

`check_phase` 用于检查 scoreboard 是否还有残留事务、是否有错误状态。`report_phase` 用于输出统计结果。`final_phase` 常用于仿真结束前的最终清理。

check_phase 的价值经常被忽略。scoreboard 即使没有 compare error，也可能还有 expected 没被 actual 匹配，或者 outstanding transaction 没清空。这些都应该在 check_phase 报出来。

```verilog
function void check_phase(uvm_phase phase);
    super.check_phase(phase);

    if (expected_q.size() != 0) begin
        `uvm_error("CHECK", "expected queue is not empty")
    end
endfunction
```

### 8.3 objection

objection 控制 run-time phase 结束。开始主要激励前 raise，激励结束后 drop。当所有 objection 都 drop 后，run_phase 才能结束。

objection 的难点不是 API，而是所有权。一般应由 test 或 top-level virtual sequence 控制整体 objection，底层 driver/monitor 不应该随意 raise/drop 全局 objection，否则环境结束时机很难维护。

```verilog
task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq.start(env.agent.sqr);
    phase.drop_objection(this);
endtask
```

### 8.4 run_test 与 +UVM_TESTNAME

`run_test()` 是 UVM 仿真启动入口，一般在 top module 的 initial block 中调用。它会创建 root，选择 test，启动 phase 机制。没有 `run_test()`，UVM component 树不会按标准流程跑起来。

```verilog
module tb_top;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    initial begin
        run_test();
    end
endmodule
```

`run_test("base_test")` 可以在代码里指定 test，但项目里更常用命令行 `+UVM_TESTNAME=xxx_test`，这样不改 top 代码就能切换 testcase。面试里要能讲清楚：test 不是被直接 `new` 出来的，而是通过 factory 创建，所以 test 也可以被 factory override。

```text
simv +UVM_TESTNAME=smoke_test
simv +UVM_TESTNAME=stress_test
```

如果 `run_test()` 里写死 test 名，同时命令行又传 `+UVM_TESTNAME`，不同仿真器/版本可能会报警或以代码指定为准。工程里建议 top 里保留 `run_test();`，由 regression 脚本统一传 test 名。

### 8.5 topology 与 phase debug

UVM debug 经常先看 topology。`uvm_top.print_topology()` 可以确认组件是否创建成功、名字和层次是否符合预期。config_db get 失败、analysis port 连错、override 不生效时，topology 是第一批要看的信息。

```verilog
function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
endfunction
```

phase 相关问题常见两类：仿真提前结束和仿真不结束。提前结束通常是 objection 没 raise，或者 sequence 没真正 start；不结束通常是 objection 没 drop，driver/monitor forever loop 没问题但 test 的结束条件没满足，或者后台线程没有被 `disable fork` 清理。

```text
提前结束：检查 run_phase 是否 raise_objection，sequence 是否启动
不结束：检查 objection count，后台 fork 线程，scoreboard 等待条件
结构异常：检查 topology、factory override、config_db 路径
```

### 易错点

- `build_phase` 是 function，不能消耗仿真时间。
- `run_phase` 是 task，可以消耗仿真时间。
- 忘记 raise objection，仿真可能提前结束。
- 忘记 drop objection，仿真可能不结束。
- 组件创建通常放 build，端口连接通常放 connect。
- top module 里通常只写 `run_test();`，具体 test 由 `+UVM_TESTNAME` 控制。
- topology 能帮你确认组件有没有被 factory 正确创建。

### QUESTION

- UVM phase 的常见顺序是什么？
- build_phase 和 connect_phase 分别做什么？
- 哪些 phase 可以消耗仿真时间？
- objection 解决什么问题？
- 仿真提前结束或不结束怎么 debug？
- `run_test()` 做了什么？
- `+UVM_TESTNAME` 和在代码里写死 test 名有什么区别？
- `uvm_top.print_topology()` 一般用来查什么？

## <span style="color:#8B0000">9. factory</span>

factory 是 UVM 可复用性的核心机制之一。它让 test 可以在不修改 env/agent/driver 源码的情况下替换对象或组件类型。比如把普通 transaction 替换成 error transaction，把普通 driver 替换成带错误注入的 driver。

面试回答 factory 时，一定要把三件事讲清楚：注册、创建、替换。注册靠 utils 宏，创建靠 `type_id::create()`，替换靠 type override 或 instance override。

### 9.1 factory 的作用

factory 用于统一创建对象和组件，并支持类型替换。核心价值是在不修改环境源码的情况下，用子类替换父类行为。

factory 的工程意义是降低 test 和 env 的耦合。如果 env 里写死 `new()`，test 想替换行为就必须改 env 源码；如果 env 里统一用 `create()`，test 可以通过 override 改变创建结果。

```verilog
base_item item;

item = base_item::type_id::create("item");
```

### 9.2 create 与 new

`new()` 直接创建写死的类型，factory 无法插手。`type_id::create()` 会经过 factory，因此 override 才能生效。

不是所有地方都必须拒绝 `new()`。普通内部 helper object、不需要被 override 的临时对象可以用 `new()`；但 UVM component、sequence item、sequence、config object 这类可能被替换或复用的类型，通常应该用 factory create。

```verilog
class base_item extends uvm_sequence_item;
    `uvm_object_utils(base_item)

    function new(string name = "base_item");
        super.new(name);
    endfunction
endclass
```

### 9.3 type override 与 instance override

type override 对某个类型的所有创建生效。instance override 只对指定层次路径下的实例生效。

type override 适合全局替换，影响范围大；instance override 适合精准替换某个路径，适合多 agent 环境。面试追问 override 不生效时，要先想到路径、注册、create/new、继承关系和 override 时机。

```verilog
class err_item extends base_item;
    `uvm_object_utils(err_item)

    function new(string name = "err_item");
        super.new(name);
    endfunction
endclass

base_item::type_id::set_type_override(err_item::get_type());
```

[grammar](语法库/UVM/factory.md) ^uvm-factory-override

### 易错点

- 没有注册宏，factory 不认识类型。
- 用 `new()` 创建，override 不生效。
- override 类型需要继承兼容。
- instance override 路径写错不会生效。
- debug 时可以打印 topology 和 factory override 信息。

### QUESTION

- factory 的作用是什么？
- `create()` 和 `new()` 有什么区别？
- type override 和 instance override 有什么区别？
- override 不生效怎么 debug？
- 为什么 factory override 要求类型兼容？

## <span style="color:#8B0000">10. uvm_config_db</span>

config_db 是 UVM 环境可配置性的核心机制。它让 test 在高层设置参数，让 env/agent/driver/monitor 在各自 build_phase 中读取配置，从而避免组件之间直接互相引用。

真正项目里，config_db 不只是传 vif。更常见的是传 cfg object，cfg 中包含 vif、active/passive、coverage enable、check enable、协议模式、timeout、地址 map 等。

### 10.1 作用

`uvm_config_db` 是 UVM 的层次化配置传递机制，常用于传递 `virtual interface`、agent config、env config、开关参数。

config_db 的查找依赖类型、路径和 field name。任何一个不匹配，get 都会失败。面试时如果能主动说出 debug 顺序，会显得更像实际用过。

```verilog
uvm_config_db#(virtual apb_if)::set(
    null,
    "uvm_test_top.env.apb_agent",
    "vif",
    apb_vif
);
```

[grammar](语法库/UVM/config_db.md) ^uvm-config-db-set

### 10.2 set/get 参数

`set(cntxt, inst_name, field_name, value)` 用于设置配置。`get(cntxt, inst_name, field_name, value)` 用于读取配置。查找是否成功取决于类型、路径和 field name。

`null` 常用于从 root 设置绝对路径，`this` 常用于从当前 component 设置相对路径，`""` 常表示当前实例，`"*"` 是通配。`"*"` 在小 demo 方便，但多实例项目中可能把同一个 vif 传给多个 agent，导致很隐蔽的问题。

```verilog
if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
    `uvm_fatal("NOVIF", "virtual interface not set")
end
```

### 10.3 直接传 vif 与传 cfg

小 demo 可以直接传 vif。项目里更推荐传 cfg object，把 vif、is_active、coverage_enable、check_enable、timeout、协议模式等集中管理。

cfg object 的好处是配置集中、层次清晰、易于扩展。后续 agent 新增字段时，只需要扩 cfg 类，而不是到处新增 config_db set/get。多实例环境中，每个 agent 拿自己的 cfg，也更容易定位配置错误。

```verilog
class apb_agent_cfg extends uvm_object;
    `uvm_object_utils(apb_agent_cfg)

    virtual apb_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit coverage_enable = 1;
endclass
```

### 易错点

- set/get 模板类型不一致会失败。
- 路径不匹配会失败。
- set 太晚会导致 build_phase 中 get 不到。
- 滥用 `"*"` 会污染多实例环境。
- cfg object 改字段后要注意默认值和覆盖路径。

### QUESTION

- `uvm_config_db` 解决什么问题？
- set/get 参数分别是什么？
- `this`、`null`、`""`、`"*"` 有什么区别？
- config_db 和 resource_db 有什么关系？
- get 失败怎么 debug？

## <span style="color:#8B0000">11. sequence / sequencer / driver</span>

sequence/sequencer/driver 是 UVM 激励机制的核心。它们把“产生什么事务”和“如何按协议驱动信号”分开。sequence 负责事务级意图，driver 负责 pin-level 时序，sequencer 负责中间仲裁和握手。

这套机制的价值是复用。一个 APB write sequence 可以在不同 DUT 环境复用，只要 driver 遵守同样的 APB interface 时序；一个 driver 也可以执行不同 sequence 产生的 transaction。

### 11.1 三者职责

sequence 负责产生 transaction。sequencer 负责 sequence 和 driver 之间的通信与仲裁。driver 负责把 transaction 转换成 pin-level 时序。

如果把随机化直接写在 driver 里，driver 就同时负责场景生成和协议驱动，复用性会很差。UVM 把这两个职责拆开，是为了让 test 更容易组合场景，让 driver 更专注协议时序。

```text
sequence -> sequencer -> driver -> interface -> DUT
```

### 11.2 start_item/finish_item

sequence 中通常通过 `start_item()` 请求发送 item，`start_item()`的含义是把当前的item发送到seq绑定的sqr上， 然后通过 `finish_item()` 完成随机化和提交。driver 通过 seq_item_port 获取 item。

`start_item/finish_item` 背后涉及 sequencer 仲裁。多个 sequence 同时运行时，sequencer 决定哪个 item 先给 driver。简单环境看不出 sequencer 价值，但复杂场景需要它处理 arbitration、lock、grab、priority 等控制。

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

[grammar](语法库/UVM/sequence_driver.md) 

### 11.3 get_next_item/item_done

`get_next_item()` 和 `item_done()` 是两阶段握手。driver 获取 item 后驱动协议，完成后必须调用 `item_done()`。

两阶段握手的意义是 driver 可以明确告诉 sequencer：我已经拿到 item，但还没处理完；等 pin-level 驱动结束后再 `item_done()`。如果 driver 忘记 `item_done()`，sequence 侧可能一直认为 item 没完成。

```verilog
task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(req);
        drive_one_item(req);
        seq_item_port.item_done();
    end
endtask
```

### 11.4 virtual sequence

virtual sequence 用于协调多个 agent 的 sequence，例如同时控制 AXI master、APB slave、interrupt agent。它通常运行在 virtual sequencer 上，内部启动多个子 sequence。

virtual sequence 本身不应该直接驱动 interface，它负责更高层场景编排。比如先通过 APB 配寄存器，再启动 AXI 数据传输，最后等待 interrupt。这种跨接口流程就适合 virtual sequence。

```verilog
task body();
    axi_seq.start(p_sequencer.axi_sqr);
    apb_seq.start(p_sequencer.apb_sqr);
endtask
```

### 11.5 m_sequencer 与 p_sequencer

`m_sequencer` 是 UVM sequence 内部通用 sequencer handle。`p_sequencer` 是通过宏声明出来的强类型 sequencer handle，方便访问用户自定义 sequencer 字段。

`p_sequencer` 用起来方便，但会让 sequence 绑定到某个具体 sequencer 类型，降低复用性。项目里如果 sequence 只是发送普通 item，不建议依赖 p_sequencer；如果是 virtual sequence 需要访问多个子 sequencer，则使用 p_sequencer 比较常见。

```verilog
`uvm_declare_p_sequencer(virtual_sequencer)
```

### 11.6 get_next_item、try_next_item、get

driver 侧最常见的是 `get_next_item()` 加 `item_done()`。它是阻塞式两阶段握手：没有 item 时 driver 等待；拿到 item 后，driver 完成 pin-level 驱动，再调用 `item_done()` 通知 sequencer。

`try_next_item()` 是非阻塞尝试获取 item。它适合 driver 在没有 sequence item 时仍然要维持默认总线行为的场景，例如每拍先尝试取新事务，取不到就驱动 idle。

```verilog
task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.try_next_item(req);

        if (req == null) begin
            drive_idle();
        end
        else begin
            drive_one_item(req);
            seq_item_port.item_done();
        end
    end
endtask
```

`get()` 是阻塞式单阶段握手，driver 拿到 item 时，sequencer 侧就认为这个 item 已经给出，不再需要单独 `item_done()`。它写法短，但表达不出“driver 正在处理这个 item”的阶段，所以协议 driver 更常见 `get_next_item/item_done`。

面试里如果被问到二者区别，可以这样答：`get_next_item/item_done` 更适合需要明确完成点的 driver；`get` 更像一次性取走；`try_next_item` 用于非阻塞轮询，取不到必须处理 `null`。

### 11.7 sequencer 仲裁、priority、lock、grab

sequencer 的价值在多 sequence 并发时才明显。多个 sequence 同时向同一个 sequencer 发送 item，sequencer 根据 arbitration 策略决定先服务谁。常见策略包括 FIFO、random、weighted、strict FIFO 等，具体支持取决于 UVM 实现和项目封装。

priority 用来影响仲裁结果，但它不是绝对抢占。已经交给 driver 的 item 不会因为高优先级 sequence 到来就被中断。优先级只影响下一次仲裁。

```verilog
seq_a.start(sqr, null, 100);
seq_b.start(sqr, null, 200);
```

`lock()` 和 `grab()` 都用于让某个 sequence 独占 sequencer，一般用于不可被打断的协议流程。区别可以粗略理解为：`lock` 按仲裁队列等待锁，`grab` 更像插队式强抢，通常更危险。

```verilog
task body();
    lock(m_sequencer);
    start_item(req);
    finish_item(req);
    unlock(m_sequencer);
endtask
```

项目里要谨慎使用 `grab`。它会降低场景可组合性，容易让其他 sequence 饿死。多数场景优先考虑通过 virtual sequence 组织顺序，或者用 lock 保护确实不能打断的一小段事务。

### 11.8 pre_body、body、post_body

`body()` 是 sequence 的主体逻辑。`pre_body()` 和 `post_body()` 是 sequence start 前后自动调用的 hook，常用于统一 raise/drop objection、打印开始结束日志、初始化上下文。

```verilog
task pre_body();
    if (starting_phase != null) begin
        starting_phase.raise_objection(this);
    end
endtask

task body();
    repeat (10) begin
        `uvm_do(req)
    end
endtask

task post_body();
    if (starting_phase != null) begin
        starting_phase.drop_objection(this);
    end
endtask
```

新项目里不一定推荐让每个 sequence 都自己控制 objection，因为容易造成结束时机分散。更清晰的方式是 test 或 virtual sequence 统一控制整体 objection，普通子 sequence 只做事务生成。面试时如果被问 `pre_body/post_body`，要说明它们能做什么，也要说明项目里为什么可能不用它们控制全局结束。

### 易错点

- driver 忘记 `item_done()` 会导致 sequence 卡住。
- 不建议在 driver 中 randomize transaction。
- sequence 不应该直接操作 vif。
- virtual sequence 负责协调，不负责 pin-level 驱动。
- p_sequencer 使用不当会降低 sequence 可复用性。
- `try_next_item()` 取不到 item 时必须判断 `req == null`。
- priority 影响仲裁，不会中断 driver 已经在执行的 item。
- `grab` 会强烈影响其他 sequence，项目里要慎用。
- sequence 自己 raise/drop objection 会让结束控制分散，复杂环境要谨慎。

### QUESTION

- sequence、sequencer、driver 分别负责什么？
- `start_item` 和 `finish_item` 做了什么？
- `get_next_item/item_done` 和 `get` 有什么区别？
- virtual sequence 解决什么问题？
- `m_sequencer` 和 `p_sequencer` 有什么区别？
- `try_next_item()` 适合什么 driver 场景？
- sequencer 仲裁解决什么问题？
- `lock` 和 `grab` 有什么区别？
- `pre_body`、`body`、`post_body` 分别什么时候调用？

## <span style="color:#8B0000">12. TLM 与 analysis port</span>

TLM 是 UVM component 之间传递 transaction 的标准方式。它避免组件之间直接调用内部方法，也避免把 pin-level 信号传来传去。monitor、scoreboard、coverage、reference model 之间通常都通过 TLM 连接。

面试里要能讲清楚 analysis port 的“一对多广播”语义，以及它和阻塞通信的区别。analysis port 适合观察数据流，不适合需要反馈、握手、阻塞等待的命令式交互。

### 12.1 TLM 基本概念

TLM 是 transaction-level modeling，用于 component 之间传输事务，而不是直接传 pin-level 信号。UVM 中很多组件通信都依赖 TLM 端口。

TLM 的关键是抽象层级。driver 面对 interface 是 pin-level，monitor 采样后转换成 transaction，scoreboard 和 coverage 只处理 transaction。这样 checker 不需要关心每个周期的引脚细节。

```text
monitor.ap -> scoreboard.imp
monitor.ap -> coverage.analysis_export
```

### 12.2 analysis port

analysis port 是一对多广播模型。monitor 采集到 transaction 后可以通过 analysis port 同时发给 scoreboard、coverage、logger。

analysis port 的发送方不关心有多少接收方，也不等待接收方处理完成。这种松耦合非常适合 monitor，因为 monitor 的职责是观察并发布事实，不应该被 scoreboard 或 coverage 的处理速度反向影响。

```verilog
class apb_monitor extends uvm_monitor;
    uvm_analysis_port #(apb_item) ap;

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        ap = new("ap", this);
    endfunction
endclass
```

### 12.3 analysis imp/export/fifo

`uvm_analysis_imp` 实现 `write()` 接收数据。`uvm_analysis_export` 常用于层次转接。`uvm_tlm_analysis_fifo` 可以把非阻塞 write 转成可阻塞 get，方便 scoreboard 按流程处理。

`write()` 是 function，不能消耗仿真时间。如果 scoreboard 收到 transaction 后需要等待、排序、阻塞处理，可以先写入 analysis FIFO，再在 run_phase 里用 task 方式取出处理。

```verilog
class apb_scoreboard extends uvm_scoreboard;
    uvm_analysis_imp #(apb_item, apb_scoreboard) imp;

    function void write(apb_item t);
        actual_q.push_back(t);
    endfunction
endclass
```

### 12.4 uvm_subscriber

`uvm_subscriber #(T)` 是 UVM 提供的 analysis consumer 基类，内部已经带了 `analysis_export`，用户主要实现 `write(T t)`。它常用于 coverage collector，也可以用于轻量统计。

```verilog
class apb_cov extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_cov)

    bit tr_write;

    covergroup cg;
        option.per_instance = 1;
        coverpoint tr_write;
    endgroup

    function new(string name, uvm_component parent);
        super.new(name, parent);
        cg = new();
    endfunction

    function void write(apb_item t);
        tr_write = t.write;
        cg.sample();
    endfunction
endclass
```

subscriber 和 scoreboard 的区别在职责。subscriber 通常消费一份 transaction 做覆盖率或统计，不负责判定 DUT 对错；scoreboard 负责 expected/actual 比对。不要为了省组件把 coverage、compare、日志全部塞进 monitor。

### 易错点

- analysis port 是广播，不等待接收方反馈。
- `write()` 是 function，不能消耗仿真时间。
- 多个来源接同一个 scoreboard 时要区分来源。
- 需要阻塞处理时可用 analysis FIFO。
- port/export/imp 的方向要看谁发、谁收、谁实现。
- coverage collector 更适合用 subscriber 或独立组件承接 monitor transaction。

### QUESTION

- TLM 的作用是什么？
- analysis port 和 analysis imp 分别是什么？
- analysis port 是否阻塞？
- analysis FIFO 解决什么问题？
- 多个 monitor 接一个 scoreboard 怎么区分来源？
- `uvm_subscriber` 常用在哪些地方？

## <span style="color:#8B0000">13. monitor / scoreboard / reference model</span>

这三者决定验证环境是否真的能“判断对错”。只会产生激励的环境不完整，因为它只能把 DUT 跑起来，不能证明 DUT 行为正确。monitor 把 pin-level 行为转换成 transaction，reference model 产生期望，scoreboard 做比较。

面试项目追问中，scoreboard 是高频点。面试官常问 expected 从哪里来、乱序怎么比、丢包怎么发现、compare fail 打印什么、队列残留在哪里检查。

### 13.1 monitor

monitor 负责从 interface 采样 pin-level 信号，并还原成 transaction。monitor 不应该驱动 DUT。

monitor 的难点在于采样时机和协议边界识别。比如 APB 要识别 setup/access，AXI 要分别采集 AW/W/B/AR/R 多个 channel，SPI 要按 bit 组装 byte。monitor 写得不准，scoreboard 后面再复杂也没有意义。

```verilog
task run_phase(uvm_phase phase);
    forever begin
        @(posedge vif.clk);
        if (vif.psel && vif.penable) begin
            collect_transfer();
        end
    end
endtask
```

### 13.2 scoreboard

scoreboard 负责比较 expected 和 actual。简单顺序协议可以用 FIFO 比对；乱序协议通常要用 ID/tag 做关联匹配。

scoreboard 设计要匹配协议返回特性。顺序协议可以 expected queue 和 actual queue 逐个 pop；乱序协议要用 associative array 按 ID/tag 存 expected；有延迟的协议要考虑 timeout；有丢弃或错误响应的协议要考虑哪些 transaction 不应该返回正常数据。

```verilog
if (!act.compare(exp)) begin
    `uvm_error("CMP", "actual transaction does not match expected")
end
```

### 13.3 reference model

reference model 根据输入事务生成期望输出。它不能简单照抄 RTL，否则可能把 RTL bug 复制到验证环境。

reference model 应该从规格行为出发，而不是从 RTL 实现出发。简单寄存器模块可以用 memory model，复杂算法模块可能需要 C model 或 Python model。reference model 越接近规格，越能独立发现 RTL 实现错误。

```verilog
function apb_item predict(apb_item in);
    apb_item exp;

    exp = apb_item::type_id::create("exp");
    exp.copy(in);
    exp.data = model_mem[in.addr];
    return exp;
endfunction
```

### 13.4 in-order 与 out-of-order

in-order 比对可以按队列顺序 pop。out-of-order 比对通常用关联数组，以 transaction ID、address、tag 作为 key。

乱序比对还要处理 outstanding transaction。比如 AXI 同一个 ID 内通常有顺序要求，不同 ID 可以乱序；scoreboard 不能简单按返回顺序比较，而要根据协议规则决定匹配方式。

```verilog
expected_by_id[exp.id] = exp;

if (expected_by_id.exists(act.id)) begin
    exp = expected_by_id[act.id];
    expected_by_id.delete(act.id);
end
```

### 易错点

- monitor 不能主动驱动信号。
- scoreboard 要根据协议选择顺序或乱序比对。
- compare fail 要打印 transaction 内容、时间、来源、索引。
- reference model 不要复制 RTL 实现细节。
- check_phase 要检查 scoreboard 队列是否清空。

### QUESTION

- monitor、scoreboard、reference model 分别负责什么？
- expected transaction 从哪里来？
- scoreboard 如何处理乱序返回？
- reference model 写得太像 RTL 有什么风险？
- compare fail 时应该打印哪些信息？

## <span style="color:#8B0000">14. functional coverage</span>

功能覆盖率的本质是把验证计划转成可量化的覆盖模型。它回答的问题不是“代码跑过没有”，而是“规格要求的场景有没有被打到”。因此 coverage model 应该从 feature list、协议状态、边界条件、异常路径中推导出来。

面试中比较好的回答是：我会先根据验证计划定义 coverpoint/cross，再通过 regression 看 coverage hole，判断 hole 是激励缺失、约束过紧、配置没打开、DUT 不支持，还是覆盖点本身定义不合理。

### 14.1 功能覆盖率与代码覆盖率

代码覆盖率关注 RTL 结构是否被执行，例如 line、branch、toggle、FSM。功能覆盖率关注验证计划中的功能场景是否被覆盖，例如地址范围、burst 类型、错误响应、读写组合。

代码覆盖率高不代表功能测全，功能覆盖率高也不代表没有 bug。两者是互补关系。

代码覆盖率通常由工具自动统计，功能覆盖率需要验证工程师主动建模。一个设计可能 line coverage 很高，但关键的错误响应、边界地址、乱序返回组合根本没测到；反过来，功能覆盖率定义太粗，也可能看起来 100% 但实际没覆盖细节。

### 14.2 covergroup、coverpoint、bins

`covergroup` 定义覆盖模型，`coverpoint` 定义采样对象，`bins` 定义感兴趣的取值集合。

coverpoint 不应该只是把所有变量都 cover 一遍，而要对应验证意图。比如地址 coverpoint 应该分合法区间、边界区间、非法区间；burst length 应该覆盖最小值、最大值、典型值；response 应该覆盖 OKAY、ERROR 等协议语义。

```verilog
covergroup apb_cg;
    option.per_instance = 1;

    cp_write: coverpoint tr.write {
        bins read  = {0};
        bins write = {1};
    }
endgroup
```

### 14.3 cross coverage

`cross` 用于覆盖组合场景，例如读写类型和地址区间的组合。cross 不能乱加，否则组合爆炸，覆盖率很难收敛。

cross 的价值是发现“单点都覆盖了，但组合没覆盖”的问题。例如读覆盖了，写也覆盖了，低地址覆盖了，高地址也覆盖了，但不代表“高地址写”覆盖了。cross 应该只用于真正有验证意义的组合，不要把所有 coverpoint 两两 cross。

```verilog
cp_addr: coverpoint tr.addr {
    bins low  = {[32'h1000:32'h10ff]};
    bins high = {[32'h1f00:32'h1fff]};
}

wr_x_addr: cross cp_write, cp_addr;
```

### 14.4 ignore_bins 与 illegal_bins

`ignore_bins` 表示不计入覆盖率统计的场景，通常是合法但不关心。`illegal_bins` 表示不应该出现的非法场景，命中时应该报错或至少引起注意。

`ignore_bins` 和 `illegal_bins` 的区别在面试里很常问。ignore 是“我不统计”，illegal 是“这不该发生”。如果某个组合协议上不可能发生，用 ignore；如果发生代表 DUT 或 testbench 有问题，用 illegal。

```verilog
cp_resp: coverpoint resp {
    bins ok = {2'b00};
    illegal_bins reserved = {2'b10, 2'b11};
}
```

### 易错点

- 采样时机不对，覆盖率没有意义。
- cross 过多会导致覆盖空间爆炸。
- coverage model 要来自验证计划，不是随便写。
- `illegal_bins` 命中后要结合项目策略处理。
- 覆盖率收敛要分析 coverage hole，而不是盲目加随机次数。

### QUESTION

- 功能覆盖率和代码覆盖率有什么区别？
- covergroup 一般在哪里 sample？
- ignore_bins 和 illegal_bins 有什么区别？
- cross coverage 有什么风险？
- 覆盖率收不上去怎么分析？

## <span style="color:#8B0000">15. SVA</span>

SVA 是把协议规则写成可执行检查。它比 scoreboard 更适合检查局部时序性质，比如 valid 后 ready 的时限、grant 不能无请求出现、信号在握手期间保持稳定。scoreboard 更适合端到端数据正确性，SVA 更适合周期级协议约束。

面试里要能讲清楚：SVA 不是简单替代 scoreboard，而是补充检查层。好的验证环境通常同时有 monitor、scoreboard、coverage 和 assertion。

### 15.1 sequence、property、assert

SVA 用于描述和检查时序性质。`sequence` 描述时序片段，`property` 描述完整性质，`assert property` 执行检查。

sequence 更像可复用的时序片段，property 是带采样时钟、复位关闭条件和 implication 的完整规则。简单断言可以直接写 property，复杂协议建议拆 sequence，提高可读性。

```verilog
property apb_setup_to_access;
    @(posedge clk) disable iff (!rst_n)
        psel && !penable |=> psel && penable;
endproperty

assert property (apb_setup_to_access)
    else $error("APB setup should be followed by access");
```

### 15.2 implication

`|->` 是 overlapped implication，右侧从同一个采样点开始检查。`|=>` 是 non-overlapped implication，右侧从下一个采样点开始检查。

判断用 `|->` 还是 `|=>`，关键看协议要求是“同周期响应”还是“下一周期响应”。比如 req 和 ack 同拍要求用 `|->`；APB setup 下一拍进入 access 更适合 `|=>`。

```verilog
property same_cycle_ack;
    @(posedge clk) req |-> ack;
endproperty

property next_cycle_ack;
    @(posedge clk) req |=> ack;
endproperty
```

### 15.3 delay 与 repetition

`##1` 表示延迟 1 个采样周期。`##[1:5]` 表示 1 到 5 个周期内。重复操作可以表达连续保持、范围重复等时序要求。

范围延迟常用于性能或协议时限检查。比如 request 发出后 1 到 16 拍内必须 response。如果超过上限，就是 timeout 类协议错误。SVA 可以比 testbench timeout 更局部、更精确地定位问题。

```verilog
property req_ack_p;
    @(posedge clk) disable iff (!rst_n)
        $rose(req) |-> ##[1:5] ack;
endproperty
```

### 15.4 disable iff

`disable iff (!rst_n)` 通常用于 reset 期间关闭断言，避免复位阶段产生误报。

reset 期间信号可能处于非协议稳定状态，如果不断言关闭，会产生大量无意义错误。`disable iff` 是异步关闭条件，只要条件满足，property 尝试会被终止或不启动。

```verilog
assert property (
    @(posedge clk) disable iff (!rst_n)
        valid |-> ready
);
```

### 15.5 throughout、until、intersect、first_match、ended

这些操作符是 SVA 面试里比较容易被追问的部分。它们不是为了写得“高级”，而是为了把协议里的保持、终止、并行匹配和确定性匹配表达清楚。

`throughout` 表示一个条件在某个 sequence 持续期间一直成立。典型场景是 valid 拉高后，在 ready 到来前 payload 必须保持稳定。

```verilog
property payload_stable_until_ready;
    @(posedge clk) disable iff (!rst_n)
        valid && !ready |-> $stable(data) throughout (!ready [*0:$] ##1 ready);
endproperty
```

`until` 表示左侧条件持续成立，直到右侧条件发生。它常用于“等待某个结束条件之前，状态不能改变”的规则。`until_with` 要求结束条件发生的那个周期左侧也成立，检查更严格。

```verilog
property hold_busy_until_done;
    @(posedge clk) disable iff (!rst_n)
        busy |-> busy until_with done;
endproperty
```

`intersect` 要求两个 sequence 从同一时间开始，并且在同一时间结束。它适合表达两个时序片段必须完全对齐，不只是都发生过。

```verilog
sequence req_to_ack;
    req ##[1:4] ack;
endsequence

sequence data_window;
    valid [*2:5];
endsequence

property aligned_window;
    @(posedge clk) disable iff (!rst_n)
        req_to_ack intersect data_window;
endproperty
```

`first_match` 用于在范围匹配存在多种可能时选择最早匹配，避免后续表达式因为多条匹配路径产生歧义。比如 `##[1:10] ack` 可能在多个周期都满足，`first_match` 会固定最早的 ack。

```verilog
property first_ack_then_drop_req;
    @(posedge clk) disable iff (!rst_n)
        req |-> first_match(##[1:10] ack) ##1 !req;
endproperty
```

`ended` 用于检测一个 sequence 的结束点。复杂协议里常把 setup、data、response 拆成 sequence，再用 `.ended` 对齐后续检查。

```verilog
sequence apb_access;
    psel && !penable ##1 psel && penable && pready;
endsequence

property access_done_drop_psel;
    @(posedge clk) disable iff (!rst_n)
        apb_access.ended |=> !psel;
endproperty
```

面试回答时不需要把所有语法一次背完，重点是能说出使用场景：`throughout` 管保持，`until` 管直到某事件前的持续约束，`intersect` 管两个 sequence 对齐，`first_match` 管范围匹配的确定性，`ended` 管复杂 sequence 的结束点。

### 易错点

- `|->` 和 `|=>` 很容易混淆。
- `$rose(req)` 和 `req == 1` 不等价。
- `disable iff` 条件写反会导致断言一直关闭或一直误报。
- 断言失败不一定是 RTL 错，也可能是 assertion 写错。
- SVA 采样点要和协议时钟一致。
- 范围延迟和重复可能产生多条匹配路径，需要时用 `first_match` 收敛语义。
- `throughout` 检查的是整个 sequence 持续区间，不是只检查开始和结束两个点。

### QUESTION

- sequence 和 property 有什么区别？
- `|->` 和 `|=>` 有什么区别？
- `disable iff` 的作用是什么？
- `$rose`、`$fell`、`$stable` 分别怎么用？
- 怎么检查 req 后 1 到 5 拍内 ack？
- `throughout` 和 `until` 分别适合检查什么？
- 为什么有时候要用 `first_match`？

## <span style="color:#8B0000">16. UVM RAL</span>

RAL 把寄存器从“地址 + 数据”的低层访问抽象成“寄存器名 + 字段名”的模型。它让 test 可以写 `reg_model.ctrl.enable.write()` 这种语义化操作，而不是到处手写地址常量。

面试中 RAL 常追问 frontdoor/backdoor、mirror/update/predict、adapter/predictor、寄存器字段属性、reset 后 mirror 同步。只会说“RAL 用来访问寄存器”不够。

### 16.1 RAL 的作用

RAL 是 UVM register abstraction layer，用于把寄存器访问抽象成 register model。测试用例可以用寄存器名和字段名访问寄存器，而不是手写地址和总线 transaction。

RAL 的好处包括：减少硬编码地址、统一寄存器读写 API、支持寄存器字段级访问、支持 mirror 检查、支持 frontdoor/backdoor 两种访问方式，也方便自动生成寄存器测试。

```verilog
uvm_status_e status;

reg_model.ctrl.write(status, 32'h1, UVM_FRONTDOOR);
```

### 16.2 frontdoor 与 backdoor

frontdoor 通过真实总线访问寄存器，能验证总线协议和寄存器逻辑。backdoor 通过层次路径直接访问寄存器变量，速度快，常用于初始化、检查或特殊 debug。

frontdoor 更真实，但慢；backdoor 快，但绕过总线协议。不能用 backdoor 代替 frontdoor 验证寄存器总线访问。常见策略是初始化或大规模 preload 用 backdoor，功能验证和协议验证用 frontdoor。

```verilog
reg_model.status.read(status, data, UVM_FRONTDOOR);
reg_model.status.peek(status, data);
```

### 16.3 mirror、desired、actual

RAL 中常见概念包括 desired value、mirrored value、DUT actual value。`mirror()` 会读 DUT 并更新镜像，`update()` 会把 desired 写到 DUT。

desired 是模型里“希望 DUT 变成的值”，mirrored 是模型认为 DUT 当前应该有的值，actual 是 DUT 真实硬件值。RAL 的难点之一就是保持模型镜像和 DUT 实际状态一致，尤其在 volatile、RO、W1C、硬件自清字段中。

```verilog
reg_model.ctrl.set(32'h5);
reg_model.ctrl.update(status);
reg_model.ctrl.mirror(status, UVM_CHECK);
```

### 16.4 adapter 与 predictor

adapter 负责在 register operation 和 bus transaction 之间转换。predictor 负责根据总线监测到的事务更新 register model 的 mirror。

adapter 是 RAL 和具体总线协议之间的桥。比如 RAL 发起一次 register write，adapter 要把它转换成 APB/AXI transaction。predictor 则从 monitor 看到的 bus transaction 推断寄存器模型应该如何更新。

```verilog
reg_predictor.map     = reg_model.default_map;
reg_predictor.adapter = reg_adapter;
bus_monitor.ap.connect(reg_predictor.bus_in);
```

### 易错点

- frontdoor 能验证总线路径，backdoor 不能替代总线验证。
- adapter 地址、byte enable、读写方向转换容易写错。
- predictor 没连好时，mirror value 可能不更新。
- reset 后要同步 register model 的 mirror。
- volatile、RO、W1C 等特殊字段要正确建模。

### QUESTION

- RAL 解决什么问题？
- frontdoor 和 backdoor 有什么区别？
- mirror、update、predict 分别做什么？
- adapter 和 predictor 的作用是什么？
- W1C、RO、volatile 字段怎么建模？

## <span style="color:#8B0000">17. 常见协议面试点</span>

协议题通常不要求把标准背完整，而是看你能不能抓住握手、时序、乱序、backpressure、边界条件。回答协议题要先讲通用思想，再落到具体信号。

### 17.1 APB

APB 是低复杂度外设总线，典型传输分 setup 和 access 两个阶段。setup 阶段 `PSEL=1`、`PENABLE=0`；access 阶段 `PSEL=1`、`PENABLE=1`，等待 `PREADY` 完成。

```text
setup : PSEL=1, PENABLE=0
access: PSEL=1, PENABLE=1, wait PREADY
```

验证点包括读写寄存器、wait state、非法地址、reset 默认值、back-to-back transfer、`PREADY` 拉低时地址和控制信号保持稳定。

### 17.2 AXI

AXI 面试重点是五通道和 valid/ready 握手。写地址 AW、写数据 W、写响应 B、读地址 AR、读数据 R 相互独立。通道独立带来高吞吐，也带来 outstanding、乱序、ID 匹配、backpressure 的复杂度。

valid/ready 规则是：valid 表示发送方有数据，ready 表示接收方能接收；同周期 valid && ready 才完成一次 beat。valid 拉起后，在握手完成前 payload 要保持稳定。

```text
write: AW + W -> B
read : AR -> R
beat transfer: VALID && READY
```

AXI 验证点包括 burst 长度、地址对齐、wrap/incr burst、WSTRB、outstanding depth、ID 乱序返回、backpressure、响应错误、4KB boundary。面试时不需要一次背全标准，但要能讲出为什么 AXI scoreboard 不能只用简单 FIFO：因为不同 ID 可能乱序返回，需要按 ID/tag 建模匹配。

### 17.3 AHB

AHB 典型特征是地址相位和数据相位流水。面试常问 HTRANS、HREADY、HRESP，以及地址相位和数据相位错开一拍带来的 monitor/scoreboard 处理。

验证时要注意 wait state：当 `HREADY` 拉低时，当前传输不能推进，控制信号和数据相位关系要保持正确。monitor 不能简单每拍采一笔，要按有效传输和 ready 状态识别边界。

### 17.4 SPI 与 I2C

SPI 常问 CPOL/CPHA、片选、MOSI/MISO、bit order、全双工。验证重点是不同 mode 下采样边沿是否正确，片选无效时从设备是否忽略总线，连续 byte 之间是否符合时序。

I2C 常问 start/stop、ACK/NACK、7-bit/10-bit 地址、open-drain、clock stretching、仲裁。验证重点是 SDA 只能在 SCL 低时改变，start/stop 例外；ACK 由接收方在第 9 个 clock 驱动。

### 易错点

- APB wait state 期间地址和控制信号不能随意变化。
- AXI valid 拉起后，握手前 payload 必须稳定。
- AXI 多 ID 乱序返回时，scoreboard 不能只用一个顺序 FIFO。
- AHB monitor 要处理地址相位和数据相位流水。
- SPI/I2C 的采样边沿和协议 mode 必须在 transaction 中表达清楚。

### QUESTION

- APB setup/access 阶段分别是什么？
- AXI 五个 channel 分别是什么？
- valid/ready 握手规则是什么？
- AXI 为什么会有 outstanding 和乱序问题？
- AHB 地址相位和数据相位有什么关系？
- SPI 的 CPOL/CPHA 影响什么？
- I2C 的 ACK/NACK 在第几个 clock？

## <span style="color:#8B0000">18. CDC、亚稳态与异步 FIFO</span>

CDC 是 clock domain crossing，指信号从一个时钟域传到另一个时钟域。验证面试里 CDC 经常和亚稳态、双触发器同步、握手同步、异步 FIFO、Gray code 一起问。它既是设计问题，也是验证问题。

面试回答要区分“设计如何避免 CDC 风险”和“验证如何证明 CDC 逻辑工作”。普通仿真不会真实模拟亚稳态，所以 CDC 不能只靠跑 testcase，需要结合结构检查、协议断言、异步时钟随机相位、FIFO 边界场景和必要的 CDC 静态工具。

### 18.1 亚稳态与双触发器同步

亚稳态来自异步信号在目标时钟采样边沿附近变化，触发器输出可能短时间不稳定。数字仿真通常不会真实反映这种模拟电路行为，所以面试里不能说“我用波形看到了亚稳态”。

单 bit 慢变控制信号常用两级触发器同步。第一级可能亚稳，第二级给它一个周期恢复时间，降低亚稳态传播概率。它不能保证绝对没有亚稳态，只是把概率降到工程可接受范围。

```verilog
always_ff @(posedge dst_clk or negedge dst_rst_n) begin
    if (!dst_rst_n) begin
        sync1 <= 1'b0;
        sync2 <= 1'b0;
    end
    else begin
        sync1 <= async_sig;
        sync2 <= sync1;
    end
end
```

双触发器只适合同步单 bit 控制信号，不适合直接同步多 bit 数据总线。多 bit 信号每一位到达目标域的时间可能不同，目标域可能采到混合值。

### 18.2 多 bit CDC 与握手同步

多 bit 数据跨时钟域通常需要协议保证数据稳定，再用同步后的控制信号通知目标域采样。常见方案包括 req/ack 握手、toggle 同步、异步 FIFO。

req/ack 握手适合低吞吐控制类传输。源域保持 data 不变并拉起 req，目标域同步 req 后采样 data，再返回 ack，源域收到 ack 后才能改变 data。

```text
src_clk: data stable + req
dst_clk: sync req -> sample data -> ack
src_clk: sync ack -> release data
```

验证重点不是只看 req/ack 是否跳变，而是检查 data 在握手期间是否保持稳定、req/ack 是否不会丢、源域是否等待 ack 后才发下一笔。

### 18.3 异步 FIFO

异步 FIFO 用于两个时钟域之间的数据流传输。写指针在写时钟域递增，读指针在读时钟域递增；为了判断 full/empty，需要把对方指针同步到本时钟域。

异步 FIFO 通常用 Gray code 同步指针，因为 Gray code 相邻值只有一 bit 变化，可以降低多 bit 指针同步时采到非法组合的风险。注意同步的是 Gray 指针，不是直接同步 binary 指针。

```verilog
assign wr_gray = (wr_bin >> 1) ^ wr_bin;
assign rd_gray = (rd_bin >> 1) ^ rd_bin;
```

empty 一般在读时钟域判断：同步过来的写指针等于当前读指针，说明没有可读数据。full 一般在写时钟域判断：下一写指针追上同步过来的读指针，并满足最高位翻转关系。

### 18.4 异步 FIFO 验证点

异步 FIFO 面试要能讲出具体 testcase 和 checker。只说“测 full/empty”太浅，要覆盖不同频率、相位、边界、连续读写和复位场景。

```text
基础：单写单读，数据顺序正确
边界：写满、读空、full 后继续写、empty 后继续读
并发：同时读写，读写频率随机变化
时钟：write faster、read faster、频率接近、随机相位
复位：单域复位、双域复位、复位后指针和 flag 正确
```

scoreboard 可以按写入顺序维护 expected queue，读出时比较数据顺序。assertion 可以检查 full 时不允许有效写、empty 时不允许有效读、flag 不能出现非法组合。

### 易错点

- 普通 RTL 仿真不能真实模拟亚稳态。
- 双触发器同步适合单 bit 控制，不适合多 bit 数据总线。
- 异步 FIFO 同步指针通常用 Gray code。
- full/empty 判断分别属于写时钟域和读时钟域。
- CDC 验证要结合 testcase、assertion 和静态 CDC 工具，不是只看波形。

### QUESTION

- 什么是 CDC？为什么会产生亚稳态？
- 双触发器同步解决什么问题？有什么限制？
- 多 bit 数据为什么不能简单每一位打两拍？
- 异步 FIFO 为什么用 Gray code？
- 异步 FIFO 的 full 和 empty 怎么判断？
- 你会怎么验证一个异步 FIFO？

## <span style="color:#8B0000">19. Reset 验证</span>

reset 面试常被问，是因为它能暴露候选人有没有真实 debug 过芯片环境。reset 不是“拉低再拉高”这么简单，验证要关注同步/异步复位、复位释放时序、复位期间协议行为、复位后状态恢复。

### 19.1 同步复位与异步复位

同步复位只在时钟边沿生效，时序更容易约束，但要求时钟存在。异步复位不依赖时钟即可进入复位，常用于上电或紧急复位，但释放时要注意同步，否则可能引入 CDC/Recovery/Removal 风险。

常见设计策略是“异步 assert，同步 deassert”：复位可以异步拉低，让电路快速进入复位；复位释放通过目标时钟域同步，避免不同触发器在不同周期出复位。

```verilog
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rst_sync1 <= 1'b0;
        rst_sync2 <= 1'b0;
    end
    else begin
        rst_sync1 <= 1'b1;
        rst_sync2 <= rst_sync1;
    end
end
```

### 19.2 reset testcase

reset testcase 不能只在仿真 0 时刻做一次。更有价值的是在不同业务阶段插入 reset：空闲时 reset、传输中 reset、FIFO 半满时 reset、outstanding transaction 未完成时 reset。

```text
power-on reset：上电后寄存器和输出默认值正确
mid-transaction reset：协议传输中复位，DUT 回到初始状态
back-to-back reset：短间隔连续复位，状态机不挂死
partial reset：部分模块复位，跨模块接口不产生非法行为
reset recovery：复位释放后第一笔 transaction 正常
```

monitor 和 scoreboard 要知道 reset 语义。reset 期间 monitor 可以停止采样或标记 flush；scoreboard 通常要清空 expected queue，否则 reset 前的 expected 会和 reset 后的 actual 错配。

### 19.3 reset assertion

reset assertion 适合检查复位期间输出默认值、复位释放后状态机合法、复位期间不发起非法握手。

```verilog
property reset_default_p;
    @(posedge clk)
        !rst_n |-> !valid && state == IDLE;
endproperty

assert property (reset_default_p);
```

对于异步复位释放，assertion 要注意采样时钟和关闭条件。不要把 reset 期间本来允许不稳定的信号写成强约束，否则会产生大量假失败。

### 易错点

- reset 期间 scoreboard 不清队列，复位后容易误报。
- 异步复位释放不处理同步，容易引入跨时钟风险。
- 只测仿真开头 reset，不足以覆盖真实项目风险。
- reset assertion 要区分复位中和复位后的检查。

### QUESTION

- 同步复位和异步复位有什么区别？
- 为什么常说 reset 要异步 assert、同步 deassert？
- mid-transaction reset 怎么测？
- reset 时 scoreboard 和 monitor 应该怎么处理？
- reset 后第一笔 transaction 为什么重要？

## <span style="color:#8B0000">20. VPlan 与验证完备性</span>

VPlan 是验证计划，不是文档形式主义。它把 spec 里的功能点、协议规则、异常场景、性能边界拆成可执行的 testcase、checker、coverage。面试官问 VPlan，本质是在问你怎么证明“测够了”。

### 20.1 从 spec 到 feature list

做 VPlan 的第一步是读 spec 并拆 feature。每个 feature 要能对应到至少一种验证手段：directed test、random sequence、assertion、scoreboard check、coverage point。

```text
spec feature -> test scenario -> checker -> coverage -> regression status
```

例如寄存器模块不能只写“验证寄存器读写”，要拆成 reset 默认值、RW/RO/W1C 字段、非法地址、byte enable、backdoor/frontdoor 一致性、访问权限、side effect。

### 20.2 assertion、scoreboard、coverage 的分工

assertion 适合检查局部时序规则和协议不变量，例如 valid 后 payload 稳定、req 后有限周期 ack、FIFO 不能同时 full/empty。它定位快，但不擅长端到端数据建模。

scoreboard 适合做端到端功能正确性，比如输入一笔 transaction 后，输出数据、寄存器状态、内存内容是否符合 reference model。它可以处理复杂算法和乱序匹配，但定位周期级协议错误不如 assertion 直接。

coverage 负责回答“有没有测到”，不是回答“对不对”。coverage hit 不代表 DUT 正确，必须和 checker 搭配；checker 通过也不代表测够，必须看 coverage hole。

### 20.3 coverage closure 方法

coverage closure 要按 hole 分类，不要只说“多跑随机”。常见分类包括：可达但没打到、约束过紧、sequence 缺场景、DUT 配置没打开、coverage model 写错、spec 确认不可达。

```text
hole -> 判断可达性 -> 查约束和配置 -> 补 sequence/checker -> 回归确认
```

如果是不可达点，不能偷偷删 coverage，要有 spec 或设计确认，然后用 `ignore_bins` 或 waiver 记录原因。面试时能讲清这个流程，会比只报覆盖率数字更像真实项目经验。

### 20.4 regression 与 signoff

regression 不只是跑很多 testcase。它需要有分层：smoke 快速发现环境坏掉，nightly 覆盖主要随机和定向场景，weekly/full regression 跑大种子、大配置和长时间稳定性。

signoff 通常看多个维度：功能覆盖率、代码覆盖率、assertion 结果、scoreboard error、bug 状态、waiver 合理性、关键场景是否通过。覆盖率 100% 也不自动等于可以 signoff，因为 coverage model 本身可能漏了 feature。

### 易错点

- VPlan 不能只列 testcase 名，要能追踪到 spec feature。
- coverage hit 不代表功能正确。
- checker pass 不代表场景测全。
- coverage hole 要分类处理，不能盲目加随机次数。
- waiver 必须有理由和 owner，不能变成隐藏问题的工具。

### QUESTION

- VPlan 一般包括哪些内容？
- 怎么从 spec 拆 coverage point？
- assertion、scoreboard、coverage 分别解决什么问题？
- 覆盖率收不上去怎么分析？
- 什么时候可以用 ignore_bins 或 waiver？
- 你怎么判断一个模块验证可以 signoff？

## <span style="color:#8B0000">21. 项目面试表达与 debug</span>

项目表达是把前面的知识点串成完整验证故事。面试官真正关心的是：你是否知道环境为什么这样搭、数据怎么流、错了怎么查、覆盖率怎么证明测够了。

一个好的项目回答应该有层次、有因果、有细节。不要只说“我写了 driver、monitor、scoreboard”，要说 driver 驱动什么协议时序，monitor 如何识别 transaction，scoreboard 的 expected 从哪里来，coverage hole 怎么闭合。

### 21.1 项目描述顺序

项目面试建议按链路讲：DUT/协议背景、验证环境结构、transaction 定义、sequence 激励、driver 驱动、monitor 采样、scoreboard 比对、coverage 收敛、bug debug。

推荐表达顺序是先讲全貌，再讲一个具体链路。比如“我验证的是 APB slave 寄存器模块，环境包括一个 active APB agent、scoreboard、RAL model 和 coverage。test 通过 sequence 发起寄存器读写，monitor 采样 APB transaction，predictor 更新 RAL mirror，scoreboard 检查读回值和期望值。”

```text
验证对象 -> 环境结构 -> 激励 -> 检查 -> 覆盖率 -> bug debug
```

### 21.2 验证环境结构

不要只说“我搭了 UVM 环境”，要能讲清楚 env 里有哪些 agent，agent 是 active 还是 passive，scoreboard 的 expected 从哪里来，coverage model 覆盖哪些验证计划点。

结构描述要带数据流。比如 sequence 产生 item 给 driver，driver 通过 vif 驱动 DUT，monitor 采样后通过 analysis port 发给 scoreboard 和 coverage。scoreboard 一路拿 expected，一路拿 actual，最后 compare。

```text
test
  env
    master_agent
      sequencer
      driver
      monitor
    scoreboard
    coverage
```

### 21.3 bug debug 方法

常见 debug 入口包括 UVM log、waveform、transaction dump、scoreboard mismatch、assertion fail、coverage hole。一个好的 bug 例子要包含触发条件、现象、定位过程、根因、修复或规避方式。

debug 不能只说“看波形”。更完整的过程是：先看 UVM error 定位哪个 checker 报错，再看 transaction log 判断输入输出事务是否合理，再看 waveform 对齐协议周期，最后回到 RTL 或 testbench 代码定位根因。

```text
现象：scoreboard compare mismatch
定位：查看 transaction log，确认 expected 正确，actual 延迟一拍
根因：RTL valid/ready 握手后状态机提前跳转
```

### 21.4 覆盖率收敛

覆盖率收敛不是只加随机次数。要分析没 hit 的 bin 是否可达、是否约束太紧、sequence 是否缺场景、DUT 配置是否没打开、覆盖点是否定义不合理。

覆盖率 hole 的处理要分类。可达但没打到，补 sequence 或调约束；不可达但合法上不需要，改 ignore_bins；定义错误，修 coverage model；需要特定配置才能打开的场景，要在 test 中配置 DUT。这样回答比“多跑 random”更专业。

```text
coverage hole -> 判断是否可达 -> 检查约束 -> 补 sequence -> 回归验证
```

### 易错点

- 只背组件名，没有数据流。
- 只讲激励，不讲检查。
- 只讲覆盖率数字，不讲覆盖点来源。
- bug 例子没有根因和定位过程。
- 不会解释为什么环境这样分层。

### QUESTION

- 你搭的 UVM 环境有哪些组件？
- transaction 字段怎么定义？
- expected result 从哪里来？
- coverage point 怎么从验证计划拆出来？
- 讲一个你定位过的 bug。
- 如果 scoreboard mismatch，你怎么 debug？

## <span style="color:#8B0000">22. callback 与 report</span>

callback 和 report 都属于工程化机制。callback 解决“在不改原组件的情况下插入行为”，report 解决“统一日志、错误、verbosity 控制”。它们不是环境主链路，但会显著影响复用和 debug 体验。

面试中 callback 常被问作 factory 的补充：factory 替换整个类型，callback 插入局部行为。report 则常被追问 `uvm_info` verbosity、error/fatal 区别、如何控制日志噪声。

### 22.1 callback

callback 用于在不修改原组件源码的情况下插入用户行为。例如 driver 发送前后调用 callback，test 可以注册不同 callback 做错误注入、统计或特殊检查。

callback 适合“少量 hook 点”的扩展，比如 pre_drive/post_drive、pre_check/post_check。它不适合替代清晰的继承结构。如果 callback 太多，行为来源会变得分散，debug 反而困难。

```verilog
virtual task pre_drive(apb_item tr);
endtask

virtual task post_drive(apb_item tr);
endtask
```

### 22.2 report severity

UVM report 常见级别包括 `UVM_INFO`、`UVM_WARNING`、`UVM_ERROR`、`UVM_FATAL`。`FATAL` 通常会结束仿真，`ERROR` 通常计入错误但仿真可继续。

severity 的选择要体现问题严重程度。配置缺失、vif 为空这类环境无法继续运行的问题应该 fatal；compare mismatch 通常 error；可疑但不一定错误的情况 warning；普通流程打印 info。

```verilog
`uvm_info("DRV", "drive one item", UVM_MEDIUM)
`uvm_warning("CFG", "coverage disabled")
`uvm_error("CMP", "compare mismatch")
`uvm_fatal("NOVIF", "virtual interface not set")
```

### 22.3 verbosity

`uvm_info` 受 verbosity 控制。常见 verbosity 包括 `UVM_LOW`、`UVM_MEDIUM`、`UVM_HIGH`、`UVM_FULL`、`UVM_DEBUG`。

verbosity 应该服务 debug。默认 regression 日志要简洁，只打印关键阶段和错误；debug 模式可以打开 transaction trace、driver 细节、coverage 采样等高 verbosity 信息。

```verilog
`uvm_info("TRACE", $sformatf("addr=%0h data=%0h", addr, data), UVM_HIGH)
```

### 22.4 barrier 与 heartbeat

`uvm_barrier` 用于多个线程或组件之间的同步等待。它像一个计数屏障：达到指定等待数量后，所有等待者一起继续。它适合多路初始化完成后再启动主场景。

```verilog
uvm_barrier init_barrier;

initial begin
    init_barrier = new("init_barrier", 3);
end

task wait_init_done();
    init_barrier.wait_for();
endtask
```

`uvm_heartbeat` 用于检测环境是否还有组件在活动，常用于发现仿真“看起来没结束但其实已经没人工作”的死等问题。它不是功能检查器，更像仿真活性监控。

面试中一般不会要求手写完整 heartbeat 代码，更常问用途：barrier 解决多线程同步，heartbeat 解决仿真活性检测。实际项目里是否使用，取决于团队基础库和仿真管理策略。

### 易错点

- log 太少不利于 debug，log 太多会淹没有用信息。
- `uvm_info` 受 verbosity 控制，warning/error/fatal 通常不按普通 verbosity 过滤。
- callback 会增加行为路径，使用时要保证可追踪。
- 不要用 callback 替代清晰的环境结构设计。
- barrier 是同步机制，不是数据传输机制。
- heartbeat 只能帮助发现活性问题，不能替代 scoreboard 或 assertion。

### QUESTION

- callback 解决什么问题？
- UVM report 有哪些 severity？
- verbosity 控制什么？
- `uvm_error` 和 `uvm_fatal` 有什么区别？
- 项目里怎么设计有用的 log？
- `uvm_barrier` 和 `uvm_heartbeat` 分别解决什么问题？

## <span style="color:#8B0000">23. DPI、VPI 与混合验证</span>

DPI/VPI 在验证面试里通常是扩展题。不是所有岗位都会深入问，但如果项目里提到 C model、reference model、脚本化仿真控制，就可能追问。

### 23.1 DPI

DPI 是 Direct Programming Interface，用于 SystemVerilog 和 C/C++ 之间直接调用。常见用途是调用 C reference model、复用软件算法、接入外部数据处理函数。

```verilog
import "DPI-C" function int crc32(input int seed, input int data);

function void check_crc(int seed, int data, int expected);
    int got;

    got = crc32(seed, data);
    if (got != expected) begin
        `uvm_error("CRC", "crc mismatch")
    end
endfunction
```

DPI 分 imported function 和 exported function。SV 调 C 通常用 import；C 回调 SV 可以用 export。DPI function 不应消耗仿真时间，task 才能表达可能耗时的调用语义。

### 23.2 VPI

VPI 是 Verilog Procedural Interface，更偏仿真器对象访问和回调机制。它可以遍历层次、读写信号、注册 callback，能力更底层，但使用复杂度也更高。

简单说，DPI 更适合“SV 和 C 之间传数据、调函数”；VPI 更适合“工具级访问仿真对象和事件”。面试里如果没做过 VPI，不要硬编项目经验，可以说了解用途但实际项目主要用 DPI 调 C model。

### 23.3 C reference model

很多算法模块会有 C/C++ golden model。UVM scoreboard 可以把 monitor 收到的 input transaction 转成 C model 输入，再把 C model 输出作为 expected，与 DUT actual 比较。

```text
monitor input -> scoreboard -> DPI C model -> expected
monitor output -> scoreboard -> compare
```

风险点是数据类型和时序对齐。SV 的四值逻辑传到 C 通常会变成二值语义，X/Z 处理要明确；C model 可能是事务级即时输出，而 RTL 有 pipeline latency，scoreboard 要对齐延迟或用 tag 匹配。

### 易错点

- DPI function 不应消耗仿真时间。
- SV 四值逻辑传到 C 时要注意 X/Z 语义丢失。
- C model 正确性也要确认，不能默认 golden model 永远没错。
- VPI 能力更底层，但复杂度高，普通 UVM 环境不一定需要。

### QUESTION

- DPI 常用来做什么？
- DPI function 和 task 有什么区别？
- DPI 和 VPI 的区别是什么？
- 用 C reference model 做 scoreboard 时要注意什么？
- SV 四值逻辑传到 C 可能有什么问题？

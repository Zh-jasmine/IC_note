# factory override 写法

[[SV&UVM#^uvm-factory-override|返回原处]]

## 原代码

```verilog
class err_item extends base_item;
    `uvm_object_utils(err_item)

    function new(string name = "err_item");
        super.new(name);
    endfunction
endclass

base_item::type_id::set_type_override(err_item::get_type());
```

## factory 解决什么问题

factory 的核心作用是“创建解耦”和“类型替换”。

如果环境里写死：

```verilog
item = new("item");
```

那创建出来的一定是当前类。

如果写成：

```verilog
item = base_item::type_id::create("item");
```

创建请求会经过 factory。factory 可以根据 override 规则决定最终创建 `base_item` 还是它的某个子类。

## 逐行语法

```verilog
class err_item extends base_item;
```

定义一个子类 `err_item`，继承自 `base_item`。override 要求类型兼容，所以替换类通常必须是原类的子类。

```verilog
`uvm_object_utils(err_item)
```

把 `err_item` 注册到 factory。没有注册宏，factory 不知道这个类型存在。

component 用：

```verilog
`uvm_component_utils(my_driver)
```

object 用：

```verilog
`uvm_object_utils(my_item)
```

```verilog
function new(string name = "err_item");
    super.new(name);
endfunction
```

UVM object 的构造函数通常只有 `name`。UVM component 的构造函数通常是：

```verilog
function new(string name, uvm_component parent);
    super.new(name, parent);
endfunction
```

```verilog
base_item::type_id::set_type_override(err_item::get_type());
```

设置 type override。之后所有通过 factory 创建 `base_item` 的地方，都会被替换为 `err_item`。

## type override

```verilog
base_item::type_id::set_type_override(err_item::get_type());
```

影响所有 `base_item::type_id::create()`。

适合全局替换，比如把普通 transaction 替换成 error transaction。

## instance override

```verilog
base_driver::type_id::set_inst_override(
    err_driver::get_type(),
    "uvm_test_top.env.agent.drv"
);
```

只替换指定路径的实例。

适合多 agent 环境中只替换某一个 driver 或 monitor。

## create 和 new

支持 override：

```verilog
item = base_item::type_id::create("item");
```

不支持 override：

```verilog
item = new("item");
```

这是 factory 面试最常见追问。

## override 不生效怎么 debug

检查顺序：

1. 原类和替换类是否都注册到 factory。
2. 创建时是否用了 `type_id::create()`。
3. 替换类是否继承自原类。
4. override 设置是否发生在 create 之前。
5. instance override 路径是否和实际 topology 一致。
6. 是否被后续 override 覆盖。

## 面试说法

可以这样答：

UVM factory 用于统一创建和类型替换。对象或组件必须先用 utils 宏注册，创建时使用 `type_id::create()`，factory override 才能生效。type override 是全局替换，instance override 是按层次路径替换。override 不生效时，我会检查注册宏、create/new、继承关系、override 时机和实例路径。


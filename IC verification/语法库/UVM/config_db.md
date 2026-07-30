# uvm_config_db set/get

[[SV&UVM#^uvm-config-db-set|返回原处]]

## 原代码

```verilog
uvm_config_db#(virtual apb_if)::set(
    null,
    "uvm_test_top.env.apb_agent",
    "vif",
    apb_vif
);
```

## config_db 解决什么问题

UVM 环境是 class 层次，DUT interface 在 module 层次。driver/monitor 需要访问 interface，但不能把顶层路径写死在 class 中。

`uvm_config_db` 提供一种按层次路径传递配置的方式，常用于：

- 传递 `virtual interface`
- 传递 agent config
- 传递 env config
- 传递开关参数，比如 coverage enable、check enable

## set 参数拆解

```verilog
uvm_config_db#(virtual apb_if)::set(...)
```

模板类型是 `virtual apb_if`。`set()` 和 `get()` 的模板类型必须一致。

```verilog
null
```

第一个参数是 context。`null` 表示从 UVM root 开始。

```verilog
"uvm_test_top.env.apb_agent"
```

第二个参数是 instance path，表示配置要放到哪个层次范围下。

```verilog
"vif"
```

第三个参数是 field name。它相当于配置项名字。

```verilog
apb_vif
```

第四个参数是真正传入的值，也就是 top module 中实例化出来的 interface handle。

## get 写法

```verilog
if (!uvm_config_db#(virtual apb_if)::get(this, "", "vif", vif)) begin
    `uvm_fatal("NOVIF", "virtual interface not set")
end
```

`this` 表示从当前 component 的层次开始查找。

`""` 表示当前 component 本身。

`"vif"` 必须和 set 时的 field name 匹配。

最后一个 `vif` 是接收配置值的变量。

## this、null、空字符串、星号

```verilog
set(null, "uvm_test_top.env.agent", "vif", vif)
```

从 root 开始设置到指定路径。

```verilog
get(this, "", "vif", vif)
```

从当前 component 开始查当前实例可见的 `vif`。

```verilog
set(null, "*", "vif", vif)
```

全局模糊设置。小 demo 方便，但多 agent 环境容易传错。

## 推荐项目写法

项目里更推荐传 config object：

```verilog
class apb_agent_cfg extends uvm_object;
    `uvm_object_utils(apb_agent_cfg)

    virtual apb_if vif;
    uvm_active_passive_enum is_active = UVM_ACTIVE;
    bit coverage_enable = 1;
endclass
```

然后只传一个 cfg：

```verilog
uvm_config_db#(apb_agent_cfg)::set(
    this,
    "env.apb_agent",
    "cfg",
    cfg
);
```

## get 失败 debug

检查顺序：

1. 模板类型是否一致。
2. field name 是否一致。
3. set 路径和实际 component 路径是否一致。
4. set 是否发生在 get 之前。
5. 是否被更高优先级配置覆盖。

## 面试说法

可以这样答：

`uvm_config_db` 是 UVM 的层次化配置传递机制，常用于传 vif 和 cfg object。它查找时依赖类型、路径和 field name。项目里我更倾向于传 agent config object，而不是零散传很多字段，这样多实例环境更清楚，也更容易维护。


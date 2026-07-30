# 09 AXI Full Crossbar UVM

这一章拆分到目录笔记里，按组件和功能阅读：

- [00 总览与数据流](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/00 总览与数据流.md>)
- [01 axi_crossbar 顶层参数和端口](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/01 axi_crossbar 顶层参数和端口.md>)
- [02 wrapper 地址映射与大向量拆包](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/02 wrapper 地址映射与大向量拆包.md>)
- [03 axi_if 五通道与角色初始化](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/03 axi_if 五通道与角色初始化.md>)
- [04 axi_master_driver 请求分发与响应回收](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/04 axi_master_driver 请求分发与响应回收.md>)
- [05 axi_slave_mem_driver memory 模型](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/05 axi_slave_mem_driver memory 模型.md>)
- [06 axi_monitor 通道级采样](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/06 axi_monitor 通道级采样.md>)
- [07 axi_scoreboard 当前状态与下一步](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/07 axi_scoreboard 当前状态与下一步.md>)
- [08 tb_top 与 axi_env 串接关系](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/08 tb_top 与 axi_env 串接关系.md>)
- [09 自测问题与当前验收标准](</Users/zh-jasmine/Documents/笔记/AXI4 Full 协议/09 AXI Full Crossbar UVM/09 自测问题与当前验收标准.md>)

推荐阅读顺序：

1. 先看 `00~03`，把 DUT、wrapper、interface 关系理顺。
2. 再看 `04~07`，把 master/slave/monitor/scb 的数据流理顺。
3. 最后看 `08~09`，把环境连接和自测问题串起来。

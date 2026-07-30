// axi_wstrb_test — WSTRB 字节选通验证
//   目标：验证 AXI 写入时只有被 WSTRB 选中的 byte 会更新，未选中的 byte 保持原值
//   方法：先 wstrb=4'hF 全写 base，再用部分 wstrb 写 patch，
//         backdoor 读寄存器确认字节选通正确。
//   注意：本 test 不触发 SPI 传输（无需验证 MOSI），写 slv_reg8 会被
//         scoreboard 压入期望队列，test 结束前手动清空避免 SCB_FAIL。

`ifndef AXI_WSTRB_TEST_SV
`define AXI_WSTRB_TEST_SV

class axi_wstrb_test extends test_base;
    `uvm_component_utils(axi_wstrb_test)

    localparam bit [31:0] REG_ADDR = 32'h20; // slv_reg8 / mosi_data
    localparam string     REG_PATH = "tb_top.DUT.AXI_SPI_n_regs0.slv_reg8";

    function new(string name = "axi_wstrb_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function automatic bit [31:0] apply_wstrb(bit [31:0] base_data,
                                              bit [31:0] patch_data,
                                              bit [3:0]  strb);
        bit [31:0] result;
        result = base_data;
        for (int i = 0; i < 4; i++)
            if (strb[i])
                result[(i*8) +: 8] = patch_data[(i*8) +: 8];
        return result;
    endfunction

    task automatic write_reg(bit [31:0] data, bit [3:0] strb, string tag);
        automatic axi_write_seq wr;
        wr = axi_write_seq::type_id::create(tag);
        wr.waddr = REG_ADDR;
        wr.wdata = data;
        wr.wstrb = strb;
        wr.start(env.axi_agt.axi_sqr);
    endtask

    task automatic read_reg_backdoor(output bit [31:0] value);
        uvm_hdl_data_t hdl_value;
        if (!uvm_hdl_read(REG_PATH, hdl_value))
            `uvm_fatal(get_name(), $sformatf("uvm_hdl_read failed for %s", REG_PATH))
        value = hdl_value[31:0];
    endtask

    task automatic check_case(string name,
                              bit [31:0] patch_data,
                              bit [3:0]  strb);
        bit [31:0] base_data;
        bit [31:0] expected;
        bit [31:0] got;

        base_data = 32'h11223344;
        expected  = apply_wstrb(base_data, patch_data, strb);

        `uvm_info(get_name(), $sformatf("[%s] base=0x%08h patch=0x%08h strb=%b expected=0x%08h",
                  name, base_data, patch_data, strb, expected), UVM_LOW)

        // 1. 全写 base（wstrb=F）
        write_reg(base_data, 4'hF, {name, "_base"});
        #1;
        read_reg_backdoor(got);
        if (got !== base_data)
            `uvm_error(get_name(), $sformatf("[%s] base write mismatch: got=0x%08h expected=0x%08h",
                       name, got, base_data))

        // 2. 部分 WSTRB 写 patch
        write_reg(patch_data, strb, {name, "_patch"});
        #1;
        read_reg_backdoor(got);
        if (got !== expected)
            `uvm_error(get_name(), $sformatf("[%s] WSTRB mismatch: got=0x%08h expected=0x%08h",
                       name, got, expected))
        else
            `uvm_info(get_name(), $sformatf("[%s] OK got=0x%08h", name, got), UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        // 单字节 4 个 lane
        check_case("byte0", 32'h000000AA, 4'b0001);
        check_case("byte1", 32'h0000BB00, 4'b0010);
        check_case("byte2", 32'h00DD0000, 4'b0100);
        check_case("byte3", 32'hEE000000, 4'b1000);

        // 稀疏选通：非连续 byte
        check_case("sparse", 32'h00AA00CC, 4'b0101);

        // 清空 scoreboard 队列：本 test 只验证寄存器层面的 WSTRB，
        // 不触发 SPI 传输，写 slv_reg8 导致的 push 在这里清掉
        env.scb.expected_data_q.delete();

        `uvm_info(get_name(), "WSTRB byte select test done — all 5 cases", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : axi_wstrb_test

`endif

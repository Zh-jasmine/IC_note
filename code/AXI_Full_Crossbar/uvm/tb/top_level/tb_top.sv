`timescale 1ns/1ps

module tb_top;
    import uvm_pkg::*;
    import axi_types_pkg::*;
    import axi_agent_pkg::*;
    import axi_env_pkg::*;
    import axi_harness_pkg::*;

    logic clk = 1'b0;
    logic rst = 1'b1;
    logic aresetn;

    axi_interface #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_S_ID_WIDTH, AXI_USER_WIDTH)
        s_axi_if [AXI_S_COUNT] (
            .aclk(clk),
            .aresetn(aresetn)
        );

    axi_interface #(AXI_ADDR_WIDTH, AXI_DATA_WIDTH, AXI_M_ID_WIDTH, AXI_USER_WIDTH)
        m_axi_if [AXI_M_COUNT] (
            .aclk(clk),
            .aresetn(aresetn)
        );

    assign aresetn = ~rst;

    always #5ns clk = ~clk;

    initial begin
        repeat (5) @(posedge clk);
        rst = 1'b0;
    end

    axi_crossbar_2m3s_wrapper dut_wrap (
        .clk(clk),
        .rst(rst),
        .s_axi_if(s_axi_if),
        .m_axi_if(m_axi_if)
    );

    genvar i;
    generate
        for (i = 0; i < AXI_S_COUNT; i++) begin : gen_s_sva
            axi_basic_sva #(
                .ADDR_WIDTH(AXI_ADDR_WIDTH),
                .DATA_WIDTH(AXI_DATA_WIDTH),
                .ID_WIDTH(AXI_S_ID_WIDTH),
                .USER_WIDTH(AXI_USER_WIDTH)
            ) s_sva (
                .vif(s_axi_if[i])
            );
        end

        for (i = 0; i < AXI_M_COUNT; i++) begin : gen_m_sva
            axi_basic_sva #(
                .ADDR_WIDTH(AXI_ADDR_WIDTH),
                .DATA_WIDTH(AXI_DATA_WIDTH),
                .ID_WIDTH(AXI_M_ID_WIDTH),
                .USER_WIDTH(AXI_USER_WIDTH)
            ) m_sva (
                .vif(m_axi_if[i])
            );
        end
    endgenerate

    initial begin
        uvm_config_db#(axi_s_vif_t)::set(null, "uvm_test_top.env.master_agent0.*", "vif", s_axi_if[0]);
        uvm_config_db#(axi_s_vif_t)::set(null, "uvm_test_top.env.master_agent1.*", "vif", s_axi_if[1]);

        uvm_config_db#(axi_m_vif_t)::set(null, "uvm_test_top.env.slave_agent0.*", "vif", m_axi_if[0]);
        uvm_config_db#(axi_m_vif_t)::set(null, "uvm_test_top.env.slave_agent1.*", "vif", m_axi_if[1]);
        uvm_config_db#(axi_m_vif_t)::set(null, "uvm_test_top.env.slave_agent2.*", "vif", m_axi_if[2]);

        run_test("axi_smoke_rw_test");
    end
endmodule

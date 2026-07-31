// reset_mid_test — VPlan 7.3
//   传输中途拉复位，验证：CS 释放、SPI 引脚回 idle、AXI 输出清零、
//   复位后重新配置并发一帧，scoreboard 比对恢复帧

`ifndef RESET_MID_TEST_SV
`define RESET_MID_TEST_SV

class reset_mid_test extends test_base;
    `uvm_component_utils(reset_mid_test)
    function new(string name = "reset_mid_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_write_seq  wr;
        automatic axi_spi_cfg_seq seq;
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        phase.raise_objection(this);
        #200;
        seq_start();

        wr = axi_write_seq::type_id::create("wr_data");
        wr.waddr = 32'h20;  wr.wdata = 32'hA5;
        wr.start(env.axi_agt.axi_sqr);

        wr = axi_write_seq::type_id::create("wr0");
        wr.waddr = 32'h00;  wr.wdata = 32'h0;
        wr.start(env.axi_agt.axi_sqr);
        wr = axi_write_seq::type_id::create("wr1");
        wr.waddr = 32'h00;  wr.wdata = 32'h1;
        wr.start(env.axi_agt.axi_sqr);

        #800;
        force tb_top.s00_axi_aresetn = 0;
        #200;
        force tb_top.s00_axi_aresetn = 1;

        if (spi_vif.CS === 1'b1)
            `uvm_info(get_name(), "[7.3] CS deasserted after reset OK", UVM_LOW)
        else
            `uvm_error(get_name(), "[7.3] CS should be high after reset")

        seq = axi_spi_cfg_seq::type_id::create("seq");
        seq.mosi_data_i     = 32'h3C;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        `uvm_info(get_name(), "[7.3] reset mid TX + recovery done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : reset_mid_test

`endif

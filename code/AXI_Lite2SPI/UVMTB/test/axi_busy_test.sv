// axi_busy_test — VPlan 5.1 + 5.2
//   验证 AXI 寄存器 slv_reg1(0x04) 的 busy 标志：
//   传输中读 → busy=1，传输结束后读 → busy=0
`ifndef AXI_BUSY_TEST_SV
`define AXI_BUSY_TEST_SV

class axi_busy_test extends test_base;
    `uvm_component_utils(axi_busy_test)
    function new(string name = "axi_busy_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic axi_spi_cfg_seq   cfg;
        automatic axi_write_seq wr;
        automatic axi_read_seq  rd;
        phase.raise_objection(this);
        #200;

        cfg = axi_spi_cfg_seq::type_id::create("cfg");
        cfg.word_len_i  = 2'b10;
        cfg.spi_mode_i  = 2'b00;
        cfg.sck_speed_i = 2'b11;
        cfg.cs_sck_i        = 8'h4;
        cfg.sck_cs_i        = 8'h4;
        cfg.ifg_i           = 8'h4;
        cfg.mosi_data_i     = 32'hA5;
        cfg.start_i      = 0;
        cfg.start(env.axi_agt.axi_sqr);

        wr = axi_write_seq::type_id::create("wr_data");
        wr.waddr = 32'h20;  wr.wdata = 32'hA5;
        wr.start(env.axi_agt.axi_sqr);

        wr = axi_write_seq::type_id::create("wr0");
        wr.waddr = 32'h00;  wr.wdata = 32'h0;
        wr.start(env.axi_agt.axi_sqr);
        wr = axi_write_seq::type_id::create("wr1");
        wr.waddr = 32'h00;  wr.wdata = 32'h1;
        wr.start(env.axi_agt.axi_sqr);

        // [5.1] busy=1 during TX — 等 CS↓ 表示传输已开始
        @(negedge spi_vif.CS);
        rd = axi_read_seq::type_id::create("rd_busy");
        rd.raddr = 32'h04;
        rd.start(env.axi_agt.axi_sqr);
        if (rd.rdata_o[0] === 1'b1)
            `uvm_info(get_name(), $sformatf("[5.1] busy=1 during TX  OK (rdata=0x%0h)", rd.rdata_o), UVM_LOW)
        else
            `uvm_error(get_name(), $sformatf("[5.1] busy should be 1 during TX, got 0x%0h", rd.rdata_o))

        @(posedge spi_vif.CS);
        #50;

        // [5.2] busy=0 after TX
        rd = axi_read_seq::type_id::create("rd_idle");
        rd.raddr = 32'h04;
        rd.start(env.axi_agt.axi_sqr);
        if (rd.rdata_o[0] === 1'b0)
            `uvm_info(get_name(), $sformatf("[5.2] busy=0 after TX  OK (rdata=0x%0h)", rd.rdata_o), UVM_LOW)
        else
            `uvm_error(get_name(), $sformatf("[5.2] busy should be 0 after TX, got 0x%0h", rd.rdata_o))

        phase.drop_objection(this);
    endtask
endclass : axi_busy_test

`endif

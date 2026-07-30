// reset_sva_test — VPlan 一.复位
//   驱动 tb_top 的复位 SVA（AXI_RESET_CHK / AXI_RESET_RELEASE_CHK / SPI_RESET_CHK）
//   5 场景：A 空闲复位 / B AXI 配置写途中复位 / C 传输中复位 /
//           D 背靠背连续复位 / E 复位后恢复一帧（scoreboard 比对）

`ifndef RESET_SVA_TEST_SV
`define RESET_SVA_TEST_SV

class reset_sva_test extends test_base;
    `uvm_component_utils(reset_sva_test)

    function new(string name = "reset_sva_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task automatic reset_pulse(int dur_ns);
        force tb_top.s00_axi_aresetn = 1'b0;
        #(dur_ns);
        force tb_top.s00_axi_aresetn = 1'b1;
    endtask

    task automatic cfg_one_frame(bit [31:0] data);
        automatic axi_spi_cfg_seq seq = axi_spi_cfg_seq::type_id::create("seq_frame");
        seq.mosi_data_i     = data;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_done();
    endtask

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq cfg;
        automatic axi_write_seq   wr;
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        phase.raise_objection(this);
        #200;

        // ---- A: idle reset ----
        `uvm_info(get_name(), "[A] idle reset", UVM_LOW)
        reset_pulse(200);
        #200;

        // ---- B: reset during AXI config writes ----
        `uvm_info(get_name(), "[B] reset during AXI config writes", UVM_LOW)
        cfg = axi_spi_cfg_seq::type_id::create("cfgB");
        cfg.word_len_i  = 2'b01;
        cfg.spi_mode_i  = 2'b11;
        cfg.sck_speed_i = 2'b10;
        cfg.start_i = 0;
        cfg.start(env.axi_agt.axi_sqr);
        reset_pulse(150);
        #200;

        // ---- C: reset mid transaction ----
        `uvm_info(get_name(), "[C] reset mid transaction", UVM_LOW)
        seq_start();
        wr = axi_write_seq::type_id::create("wr_data");
        wr.waddr = 32'h20;  wr.wdata = 32'hA5;  wr.start(env.axi_agt.axi_sqr);
        wr = axi_write_seq::type_id::create("wr0");
        wr.waddr = 32'h00;  wr.wdata = 32'h0;  wr.start(env.axi_agt.axi_sqr);
        wr = axi_write_seq::type_id::create("wr1");
        wr.waddr = 32'h00;  wr.wdata = 32'h1;  wr.start(env.axi_agt.axi_sqr);
        #800;
        reset_pulse(200);
        if (spi_vif.CS === 1'b1)
            `uvm_info(get_name(), "[C] CS deasserted after reset OK", UVM_LOW)
        else
            `uvm_error(get_name(), "[C] CS should be high after reset")
        #200;

        // ---- D: back-to-back resets ----
        `uvm_info(get_name(), "[D] back-to-back resets", UVM_LOW)
        reset_pulse(100);
        reset_pulse(100);
        #200;

        // ---- E: recovery frame after reset ----
        `uvm_info(get_name(), "[E] recovery frame after reset", UVM_LOW)
        cfg_one_frame(32'h3C);

        `uvm_info(get_name(), "reset SVA test done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : reset_sva_test

`endif

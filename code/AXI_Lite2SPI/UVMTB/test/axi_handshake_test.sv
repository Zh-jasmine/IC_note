// axi_handshake_test — VPlan 协议合规
//   验证 AXI 写通道三种握手时序：
//   (1) AW 与 W 同时到达 (aw_delay=0, w_delay=0)
//   (2) AW 先到，W 延迟到达 (aw_delay=0, w_delay=3)
//   (3) W 先到，AW 延迟到达 (aw_delay=3, w_delay=0)
//   每种时序发一帧 SPI 传输，scoreboard 比对 MOSI 数据正确性

`ifndef AXI_HANDSHAKE_TEST_SV
`define AXI_HANDSHAKE_TEST_SV

class axi_handshake_test extends test_base;
    `uvm_component_utils(axi_handshake_test)

    function new(string name = "axi_handshake_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task automatic send_frame(int unsigned aw_dly, int unsigned w_dly,
                              bit [31:0] data, string desc);
        automatic axi_write_seq   wr;
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;

        `uvm_info(get_name(), $sformatf("--- %s (aw_delay=%0d, w_delay=%0d, data=0x%0h) ---",
            desc, aw_dly, w_dly, data), UVM_LOW)
        seq_start();

        wr = axi_write_seq::type_id::create("wr_data");
        wr.waddr = 32'h20;
        wr.wdata = data;
        wr.start(env.axi_agt.axi_sqr);

        // start=0（带握手延迟）
        wr = axi_write_seq::type_id::create("wr0");
        wr.waddr    = 32'h00;
        wr.wdata    = 32'h0;
        wr.aw_delay = aw_dly;
        wr.w_delay  = w_dly;
        wr.start(env.axi_agt.axi_sqr);

        // start=1（带握手延迟）
        wr = axi_write_seq::type_id::create("wr1");
        wr.waddr    = 32'h00;
        wr.wdata    = 32'h1;
        wr.aw_delay = aw_dly;
        wr.w_delay  = w_dly;
        wr.start(env.axi_agt.axi_sqr);

        // 等传输完成
        @(posedge spi_vif.CS);
        #100;

        `uvm_info(get_name(), $sformatf("--- %s done ---", desc), UVM_LOW)
    endtask

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        // [1] 同时到达（默认行为，回归验证）
        send_frame(0, 0, 32'hA0, "simultaneous (AW=W)");

        // [2] AW 先到，W 延迟 3 拍
        send_frame(0, 3, 32'hA1, "AW first (W +3clk)");

        // [3] W 先到，AW 延迟 3 拍
        send_frame(3, 0, 32'hA2, "W first (AW +3clk)");

        // [4] 大延迟差：AW 先到，W 延迟 8 拍
        send_frame(0, 8, 32'hA3, "AW first (W +8clk)");

        // [5] 大延迟差：W 先到，AW 延迟 8 拍
        send_frame(8, 0, 32'hA4, "W first (AW +8clk)");

        `uvm_info(get_name(), "AXI handshake timing test done — all 5 frames", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : axi_handshake_test

`endif

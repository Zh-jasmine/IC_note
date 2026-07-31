// ============================================================
// tb_top.sv — UVM 顶层 + SVA 多例化
// ============================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// AXI agent files
`include "axi/axi_seq_item.sv"
`include "axi/axi_interface.sv"
`include "axi/axi_config.sv"
`include "axi/axi_sequencer.sv"
`include "axi/axi_driver.sv"
`include "axi/axi_monitor.sv"
`include "axi/axi_agent.sv"
`include "axi/axi_sequence_lib.sv"

// SPI agent files (passive)
`include "spi/spi_seq_item.sv"
`include "spi/spi_interface.sv"
`include "spi/spi_miso_slave_model.sv"
`include "spi/spi_config.sv"
`include "spi/spi_monitor.sv"

// SVA checkers
`include "sva/spi_sva_checker.sv"
`include "sva/axi_sva_checker.sv"

// Reference model
`include "ref_model/spi_ref_model.sv"

// Scoreboard
`include "scoreboard/tb_scoreboard.sv"

// Functional coverage
`include "coverage/tb_coverage.sv"

// Environment
`include "env/environment_config.sv"
`include "env/tb_environment.sv"

// RAL (寄存器抽象层)
`include "ral/axi_spi_reg_adapter.sv"
`include "ral/axi_spi_reg_block.sv"

// Test library
`include "test/base/test_base.sv"
// SPI tests
`include "test/spi/spi_word_len_test.sv"
`include "test/spi/spi_mode_test.sv"
`include "test/spi/spi_cs_sck_test.sv"
`include "test/spi/spi_sck_cs_test.sv"
`include "test/spi/spi_ifg_test.sv"
`include "test/spi/spi_sck_speed_test.sv"
`include "test/spi/spi_burst_test.sv"
`include "test/spi/spi_data_pattern_tests.sv"
`include "test/spi/spi_random_test.sv"
// MISO tests
`include "test/miso/spi_miso_tests.sv"
// AXI tests
`include "test/axi/axi_busy_test.sv"
`include "test/axi/axi_handshake_test.sv"
`include "test/axi/axi_wstrb_test.sv"
`include "test/axi/axi_concurrent_test.sv"
// RAL test
`include "test/ral/ral_test.sv"
// Reset tests
`include "test/reset/reset_mid_test.sv"
`include "test/reset/reset_sva_test.sv"

// DUT RTL
`include "../DUT/AXI_slave_top.v"


module tb_top;

    // ========== Clock & Reset ==========
    logic s00_axi_aclk;
    logic s00_axi_aresetn;

    initial begin
        s00_axi_aclk = 0;
        forever #5 s00_axi_aclk = ~s00_axi_aclk;
    end

    initial begin
        s00_axi_aresetn = 0;
        #100;
        s00_axi_aresetn = 1;
    end

    // ========== Interfaces ==========
    axi_interface axi_vif();
    spi_interface spi_vif();

    wire MOSI;
    wire SCK;
    wire CS;

    assign axi_vif.ACLK    = s00_axi_aclk;
    assign axi_vif.ARESETN = s00_axi_aresetn;
    assign spi_vif.GCLK    = s00_axi_aclk;
    assign spi_vif.SCLK    = SCK;
    assign spi_vif.MOSI    = MOSI;
    assign spi_vif.CS      = CS;
    // ============================================================
    // SVA checkers
    // ============================================================
    spi_sva_checker u_spi_sva_checker (
        .GCLK         (spi_vif.GCLK),
        .ARESETn      (s00_axi_aresetn),
        .SCLK         (spi_vif.SCLK),
        .CS           (spi_vif.CS),
        .MOSI         (spi_vif.MOSI)
    );

    axi_sva_checker u_axi_sva_checker (
        .ACLK   (s00_axi_aclk),
        .ARESETn(s00_axi_aresetn),
        .AWVALID(axi_vif.AWVALID),
        .AWREADY(axi_vif.AWREADY),
        .WVALID (axi_vif.WVALID),
        .WREADY (axi_vif.WREADY),
        .BRESP  (axi_vif.BRESP),
        .BVALID (axi_vif.BVALID),
        .ARVALID(axi_vif.ARVALID),
        .ARREADY(axi_vif.ARREADY),
        .RDATA  (axi_vif.RDATA),
        .RRESP  (axi_vif.RRESP),
        .RVALID (axi_vif.RVALID)
    );

    // ============================================================
    // DUT
    // ============================================================
    AXI_slave_top DUT (
        .s00_axi_aclk    (s00_axi_aclk),
        .s00_axi_aresetn (s00_axi_aresetn),
        .s00_axi_awaddr  (axi_vif.AWADDR[5:0]),
        .s00_axi_awprot  (axi_vif.AWPROT),
        .s00_axi_awvalid (axi_vif.AWVALID),
        .s00_axi_awready (axi_vif.AWREADY),
        .s00_axi_wdata   (axi_vif.WDATA),
        .s00_axi_wstrb   (axi_vif.WSTRB),
        .s00_axi_wvalid  (axi_vif.WVALID),
        .s00_axi_wready  (axi_vif.WREADY),
        .s00_axi_bresp   (axi_vif.BRESP),
        .s00_axi_bvalid  (axi_vif.BVALID),
        .s00_axi_bready  (axi_vif.BREADY),
        .s00_axi_araddr  (axi_vif.ARADDR[5:0]),
        .s00_axi_arprot  (axi_vif.ARPROT),
        .s00_axi_arvalid (axi_vif.ARVALID),
        .s00_axi_arready (axi_vif.ARREADY),
        .s00_axi_rdata   (axi_vif.RDATA),
        .s00_axi_rresp   (axi_vif.RRESP),
        .s00_axi_rvalid  (axi_vif.RVALID),
        .s00_axi_rready  (axi_vif.RREADY),
        .MISO            (spi_vif.MISO),
        .MOSI            (MOSI),
        .SCK             (SCK),
        .CS              (CS)
    );

    wire [1:0] dut_spi_mode;
    wire [1:0] dut_word_len;

    assign dut_spi_mode = DUT.AXI_SPI_n_regs0.slv_reg2[1:0];
    assign dut_word_len = DUT.AXI_SPI_n_regs0.slv_reg4[1:0];

    // ============================================================
    // Simple MISO slave model for readback tests
    // ============================================================
    spi_miso_slave_model u_miso_model (
        .GCLK    (spi_vif.GCLK),
        .SCLK    (spi_vif.SCLK),
        .CS      (spi_vif.CS),
        .tx_data (spi_vif.miso_tx_data),
        .spi_mode(dut_spi_mode),
        .word_len(dut_word_len),
        .MISO    (spi_vif.MISO)
    );
    // ========== UVM start ==========
    initial begin
        $fsdbDumpfile("tb_top.fsdb");
        $fsdbDumpvars(0, tb_top);
        uvm_config_db#(virtual axi_interface)::set(null, "uvm_test_top", "axi_vif", axi_vif);
        uvm_config_db#(virtual spi_interface)::set(null, "uvm_test_top", "spi_vif", spi_vif);
        run_test();
    end

endmodule : tb_top

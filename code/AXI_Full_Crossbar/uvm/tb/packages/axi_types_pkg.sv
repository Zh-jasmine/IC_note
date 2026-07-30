package axi_types_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    parameter int AXI_S_COUNT    = 2;
    parameter int AXI_M_COUNT    = 3;
    parameter int AXI_ADDR_WIDTH = 32;
    parameter int AXI_DATA_WIDTH = 32;
    parameter int AXI_STRB_WIDTH = AXI_DATA_WIDTH/8;
    parameter int AXI_S_ID_WIDTH = 4;
    parameter int AXI_M_ID_WIDTH = AXI_S_ID_WIDTH+$clog2(AXI_S_COUNT);
    parameter int AXI_USER_WIDTH = 1;

    typedef virtual axi_interface #(
        AXI_ADDR_WIDTH,
        AXI_DATA_WIDTH,
        AXI_S_ID_WIDTH,
        AXI_USER_WIDTH
    ) axi_s_vif_t;

    typedef virtual axi_interface #(
        AXI_ADDR_WIDTH,
        AXI_DATA_WIDTH,
        AXI_M_ID_WIDTH,
        AXI_USER_WIDTH
    ) axi_m_vif_t;

    typedef enum int {
        AXI_READ,
        AXI_WRITE
    } axi_op_e;

    typedef enum int {
        AXI_BURST_FIXED,
        AXI_BURST_INCR,
        AXI_BURST_WRAP
    } axi_burst_e;

    typedef enum int {
        AXI_MON_AW,
        AXI_MON_W,
        AXI_MON_B,
        AXI_MON_AR,
        AXI_MON_R
    } axi_mon_kind_e;

    localparam bit [1:0] AXI_RESP_OKAY   = 2'b00;
    localparam bit [1:0] AXI_RESP_EXOKAY = 2'b01;
    localparam bit [1:0] AXI_RESP_SLVERR = 2'b10;
    localparam bit [1:0] AXI_RESP_DECERR = 2'b11;

    `include "axi_item.sv"
endpackage

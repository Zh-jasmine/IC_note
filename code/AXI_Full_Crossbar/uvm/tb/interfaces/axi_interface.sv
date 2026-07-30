`timescale 1ns/1ps

interface axi_interface #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1
) (
    input logic aclk,
    input logic aresetn
);
    localparam int STRB_WIDTH = DATA_WIDTH/8;

    logic [ID_WIDTH-1:0]     awid;
    logic [ADDR_WIDTH-1:0]   awaddr;
    logic [7:0]              awlen;
    logic [2:0]              awsize;
    logic [1:0]              awburst;
    logic                    awlock;
    logic [3:0]              awcache;
    logic [2:0]              awprot;
    logic [3:0]              awqos;
    logic [USER_WIDTH-1:0]   awuser;
    logic                    awvalid;
    logic                    awready;

    logic [DATA_WIDTH-1:0]   wdata;
    logic [STRB_WIDTH-1:0]   wstrb;
    logic                    wlast;
    logic [USER_WIDTH-1:0]   wuser;
    logic                    wvalid;
    logic                    wready;

    logic [ID_WIDTH-1:0]     bid;
    logic [1:0]              bresp;
    logic [USER_WIDTH-1:0]   buser;
    logic                    bvalid;
    logic                    bready;

    logic [ID_WIDTH-1:0]     arid;
    logic [ADDR_WIDTH-1:0]   araddr;
    logic [7:0]              arlen;
    logic [2:0]              arsize;
    logic [1:0]              arburst;
    logic                    arlock;
    logic [3:0]              arcache;
    logic [2:0]              arprot;
    logic [3:0]              arqos;
    logic [USER_WIDTH-1:0]   aruser;
    logic                    arvalid;
    logic                    arready;

    logic [ID_WIDTH-1:0]     rid;
    logic [DATA_WIDTH-1:0]   rdata;
    logic [1:0]              rresp;
    logic                    rlast;
    logic [USER_WIDTH-1:0]   ruser;
    logic                    rvalid;
    logic                    rready;

    task automatic init_master_outputs();
        awid = '0; awaddr = '0; awlen = '0; awsize = 3'd2; awburst = 2'b01;
        awlock = 1'b0; awcache = 4'h0; awprot = 3'h0; awqos = 4'h0; awuser = '0; awvalid = 1'b0;
        wdata = '0; wstrb = '0; wlast = 1'b0; wuser = '0; wvalid = 1'b0;
        bready = 1'b0;
        arid = '0; araddr = '0; arlen = '0; arsize = 3'd2; arburst = 2'b01;
        arlock = 1'b0; arcache = 4'h0; arprot = 3'h0; arqos = 4'h0; aruser = '0; arvalid = 1'b0;
        rready = 1'b0;
    endtask

    task automatic init_slave_outputs();
        awready = 1'b0;
        wready = 1'b0;
        bid = '0; bresp = 2'b00; buser = '0; bvalid = 1'b0;
        arready = 1'b0;
        rid = '0; rdata = '0; rresp = 2'b00; rlast = 1'b0; ruser = '0; rvalid = 1'b0;
    endtask
endinterface

module axi_sva_checker (
    input logic        ACLK,
    input logic        ARESETn,
    input logic [31:0] AWADDR,
    input logic        AWVALID,
    input logic        AWREADY,
    input logic [31:0] WDATA,
    input logic [ 3:0] WSTRB,
    input logic        WVALID,
    input logic        WREADY,
    input logic [ 1:0] BRESP,
    input logic        BVALID,
    input logic        BREADY,
    input logic [31:0] ARADDR,
    input logic        ARVALID,
    input logic        ARREADY,
    input logic [31:0] RDATA,
    input logic [ 1:0] RRESP,
    input logic        RVALID,
    input logic        RREADY
);

    property p_axi_reset;
        @(posedge ACLK) !ARESETn |=>
            (!AWREADY && !WREADY && !BVALID &&
             !ARREADY && !RVALID &&
             (BRESP == 2'b00) && (RRESP == 2'b00) &&
             (RDATA == 32'h0));
    endproperty

    AXI_RESET_CHK: assert property(p_axi_reset)
        else $error("AXI reset: outputs not idle (AWREADY=%b WREADY=%b BVALID=%b ARREADY=%b RVALID=%b BRESP=%b RRESP=%b RDATA=%h)",
                    AWREADY, WREADY, BVALID, ARREADY, RVALID, BRESP, RRESP, RDATA);

    property p_axi_reset_release;
        @(posedge ACLK)
        ($rose(ARESETn) && !AWVALID && !WVALID && !ARVALID) |=>
            (!AWREADY && !WREADY && !BVALID &&
             !ARREADY && !RVALID);
    endproperty

    AXI_RESET_RELEASE_CHK: assert property(p_axi_reset_release)
        else $error("AXI reset release: outputs not idle (AWREADY=%b WREADY=%b BVALID=%b ARREADY=%b RVALID=%b)",
                    AWREADY, WREADY, BVALID, ARREADY, RVALID);

    property p_awaddr_stable_until_awready;
        @(posedge ACLK) disable iff (!ARESETn)
            (AWVALID && !AWREADY) |=> (AWVALID && $stable(AWADDR));
    endproperty

    AXI_AW_STABLE_CHK: assert property(p_awaddr_stable_until_awready)
        else $error("AXI AW payload changed or AWVALID dropped before AWREADY");

    property p_wdata_stable_until_wready;
        @(posedge ACLK) disable iff (!ARESETn)
            (WVALID && !WREADY) |=> (WVALID && $stable(WDATA) && $stable(WSTRB));
    endproperty

    AXI_W_STABLE_CHK: assert property(p_wdata_stable_until_wready)
        else $error("AXI W payload changed or WVALID dropped before WREADY");

    property p_araddr_stable_until_arready;
        @(posedge ACLK) disable iff (!ARESETn)
            (ARVALID && !ARREADY) |=> (ARVALID && $stable(ARADDR));
    endproperty

    AXI_AR_STABLE_CHK: assert property(p_araddr_stable_until_arready)
        else $error("AXI AR payload changed or ARVALID dropped before ARREADY");

    property p_write_accept_followed_by_bvalid;
        @(posedge ACLK) disable iff (!ARESETn)
            (AWVALID && AWREADY && WVALID && WREADY) |-> ##[1:8] BVALID;
    endproperty

    AXI_WRITE_RESP_CHK: assert property(p_write_accept_followed_by_bvalid)
        else $error("AXI write accepted but BVALID was not observed in time");

endmodule : axi_sva_checker

module axi_sva_checker (
    input logic        ACLK,
    input logic        ARESETn,
    input logic        AWVALID,
    input logic        AWREADY,
    input logic        WVALID,
    input logic        WREADY,
    input logic [ 1:0] BRESP,
    input logic        BVALID,
    input logic        ARVALID,
    input logic        ARREADY,
    input logic [31:0] RDATA,
    input logic [ 1:0] RRESP,
    input logic        RVALID
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

endmodule : axi_sva_checker
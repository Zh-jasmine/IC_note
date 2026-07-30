interface axi_interface();

    logic        ACLK;
    logic        ARESETN;

    // Write address channel
    logic [31:0] AWADDR;
    logic        AWVALID;
    logic        AWREADY;
    logic [ 2:0] AWPROT;

    // Write data channel
    logic [31:0] WDATA;
    logic [ 3:0] WSTRB;
    logic        WVALID;
    logic        WREADY;

    // Write response channel
    logic [ 1:0] BRESP;
    logic        BVALID;
    logic        BREADY;

    // Read address channel
    logic [31:0] ARADDR;
    logic        ARVALID;
    logic        ARREADY;
    logic [ 2:0] ARPROT;

    // Read data channel
    logic [31:0] RDATA;
    logic        RVALID;
    logic        RREADY;
    logic [ 1:0] RRESP;

endinterface : axi_interface

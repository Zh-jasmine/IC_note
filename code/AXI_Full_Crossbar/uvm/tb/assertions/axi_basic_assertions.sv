`timescale 1ns/1ps

module axi_basic_sva #(
    parameter int ADDR_WIDTH = 32,
    parameter int DATA_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int USER_WIDTH = 1
) (
    axi_interface vif
);
    assert property (@(posedge vif.aclk) disable iff (!vif.aresetn)
        vif.awvalid && !vif.awready |=>
        $stable({vif.awid, vif.awaddr, vif.awlen, vif.awsize, vif.awburst, vif.awlock, vif.awcache, vif.awprot, vif.awqos, vif.awuser}))
        else $error("AW payload changed while stalled");

    assert property (@(posedge vif.aclk) disable iff (!vif.aresetn)
        vif.wvalid && !vif.wready |=>
        $stable({vif.wdata, vif.wstrb, vif.wlast, vif.wuser}))
        else $error("W payload changed while stalled");

    assert property (@(posedge vif.aclk) disable iff (!vif.aresetn)
        vif.arvalid && !vif.arready |=>
        $stable({vif.arid, vif.araddr, vif.arlen, vif.arsize, vif.arburst, vif.arlock, vif.arcache, vif.arprot, vif.arqos, vif.aruser}))
        else $error("AR payload changed while stalled");

    assert property (@(posedge vif.aclk) disable iff (!vif.aresetn)
        vif.bvalid && !vif.bready |=>
        $stable({vif.bid, vif.bresp, vif.buser}))
        else $error("B payload changed while stalled");

    assert property (@(posedge vif.aclk) disable iff (!vif.aresetn)
        vif.rvalid && !vif.rready |=>
        $stable({vif.rid, vif.rdata, vif.rresp, vif.rlast, vif.ruser}))
        else $error("R payload changed while stalled");
endmodule

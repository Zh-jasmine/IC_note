class axi_smoke_rw_seq extends uvm_sequence #(axi_item);
    `uvm_object_utils(axi_smoke_rw_seq)

    localparam bit [AXI_ADDR_WIDTH-1:0] SMOKE_ADDR0 = 32'h0000_0010;
    localparam bit [AXI_ADDR_WIDTH-1:0] SMOKE_ADDR1 = 32'h0000_0014;
    localparam bit [AXI_DATA_WIDTH-1:0] SMOKE_DATA0 = 32'hA5A5_5A5A;
    localparam bit [AXI_DATA_WIDTH-1:0] SMOKE_DATA1 = 32'h1234_ABCD;

    function new(string name = "axi_smoke_rw_seq");
        super.new(name);
    endfunction

    virtual task body();
        axi_item write_req0;
        axi_item write_req1;
        axi_item write_rsp;
        axi_item read_req0;
        axi_item read_req1;
        axi_item read_rsp;
        bit saw_write_id1;
        bit saw_write_id2;
        bit saw_read_id3;
        bit saw_read_id4;

        write_req0 = axi_item::type_id::create("write_req0");
        start_item(write_req0);
        write_req0.op = AXI_WRITE;
        write_req0.id = 4'h1;
        write_req0.addr = SMOKE_ADDR0;
        write_req0.len = 0;
        write_req0.size = 3'd2;
        write_req0.burst = AXI_BURST_INCR;
        write_req0.data = new[1];
        write_req0.strb = new[1];
        write_req0.data[0] = SMOKE_DATA0;
        write_req0.strb[0] = {AXI_STRB_WIDTH{1'b1}};
        finish_item(write_req0);

        write_req1 = axi_item::type_id::create("write_req1");
        start_item(write_req1);
        write_req1.op = AXI_WRITE;
        write_req1.id = 4'h2;
        write_req1.addr = SMOKE_ADDR1;
        write_req1.len = 0;
        write_req1.size = 3'd2;
        write_req1.burst = AXI_BURST_INCR;
        write_req1.data = new[1];
        write_req1.strb = new[1];
        write_req1.data[0] = SMOKE_DATA1;
        write_req1.strb[0] = {AXI_STRB_WIDTH{1'b1}};
        finish_item(write_req1);

        repeat (2) begin
            get_response(write_rsp);
            case (write_rsp.id)
                4'h1: begin
                    if (saw_write_id1) `uvm_fatal("AXI_SMOKE_SEQ", "Duplicate write response for ID=1")
                    saw_write_id1 = 1'b1;
                    check_write_rsp(write_rsp, 4'h1);
                end
                4'h2: begin
                    if (saw_write_id2) `uvm_fatal("AXI_SMOKE_SEQ", "Duplicate write response for ID=2")
                    saw_write_id2 = 1'b1;
                    check_write_rsp(write_rsp, 4'h2);
                end
                default: `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Unexpected write response ID=%0h", write_rsp.id))
            endcase
        end

        if (!(saw_write_id1 && saw_write_id2)) begin
            `uvm_fatal("AXI_SMOKE_SEQ", "Missing one or more write responses")
        end

        read_req0 = axi_item::type_id::create("read_req0");
        start_item(read_req0);
        read_req0.op = AXI_READ;
        read_req0.id = 4'h3;
        read_req0.addr = SMOKE_ADDR0;
        read_req0.len = 0;
        read_req0.size = 3'd2;
        read_req0.burst = AXI_BURST_INCR;
        finish_item(read_req0);

        read_req1 = axi_item::type_id::create("read_req1");
        start_item(read_req1);
        read_req1.op = AXI_READ;
        read_req1.id = 4'h4;
        read_req1.addr = SMOKE_ADDR1;
        read_req1.len = 0;
        read_req1.size = 3'd2;
        read_req1.burst = AXI_BURST_INCR;
        finish_item(read_req1);

        repeat (2) begin
            get_response(read_rsp);
            case (read_rsp.id)
                4'h3: begin
                    if (saw_read_id3) `uvm_fatal("AXI_SMOKE_SEQ", "Duplicate read response for ID=3")
                    saw_read_id3 = 1'b1;
                    check_read_rsp(read_rsp, 4'h3, SMOKE_DATA0);
                end
                4'h4: begin
                    if (saw_read_id4) `uvm_fatal("AXI_SMOKE_SEQ", "Duplicate read response for ID=4")
                    saw_read_id4 = 1'b1;
                    check_read_rsp(read_rsp, 4'h4, SMOKE_DATA1);
                end
                default: `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Unexpected read response ID=%0h", read_rsp.id))
            endcase
        end

        if (!(saw_read_id3 && saw_read_id4)) begin
            `uvm_fatal("AXI_SMOKE_SEQ", "Missing one or more read responses")
        end

        `uvm_info("AXI_SMOKE_SEQ", "AXI4 smoke sequence passed: 2 writes + 2 reads", UVM_LOW)
    endtask

    function void check_write_rsp(axi_item rsp, bit [AXI_S_ID_WIDTH-1:0] exp_id);
        if (rsp.op != AXI_WRITE) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Expected write response, got op=%0d", rsp.op))
        end
        if (rsp.id != exp_id) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Write response ID mismatch. expected=%0h got=%0h", exp_id, rsp.id))
        end
        if (rsp.resp != AXI_RESP_OKAY) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Write response error: %0h", rsp.resp))
        end
    endfunction

    function void check_read_rsp(axi_item rsp, bit [AXI_S_ID_WIDTH-1:0] exp_id, bit [AXI_DATA_WIDTH-1:0] exp_data);
        if (rsp.op != AXI_READ) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Expected read response, got op=%0d", rsp.op))
        end
        if (rsp.id != exp_id) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Read response ID mismatch. expected=%0h got=%0h", exp_id, rsp.id))
        end
        if (rsp.resp != AXI_RESP_OKAY) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Read response error: %0h", rsp.resp))
        end
        if (rsp.data.size() != 1) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Expected 1 read beat, got %0d", rsp.data.size()))
        end
        if (rsp.data[0] !== exp_data) begin
            `uvm_fatal("AXI_SMOKE_SEQ", $sformatf("Readback mismatch. expected=%0h got=%0h", exp_data, rsp.data[0]))
        end
    endfunction
endclass

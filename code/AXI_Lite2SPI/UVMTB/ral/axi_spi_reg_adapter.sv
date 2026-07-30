class axi_spi_reg_adapter extends uvm_reg_adapter;

    `uvm_object_utils(axi_spi_reg_adapter)

    function new(string name = "axi_spi_reg_adapter");
        super.new(name);
        supports_byte_enable = 1;
        provides_responses = 1;
    endfunction

    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        axi_seq_item item;
        item = axi_seq_item::type_id::create("axi_reg_item");
        item.kind  = AXI_CH_REQ;
        item.write = (rw.kind == UVM_WRITE);
        item.addr  = rw.addr;
        item.wdata = rw.data;
        item.wstrb = rw.byte_en;
        if (item.wstrb == 4'h0) item.wstrb = 4'hF;
        return item;
    endfunction

    virtual function void bus2reg(uvm_sequence_item bus_item, ref uvm_reg_bus_op rw);
        axi_seq_item item;

        if (!$cast(item, bus_item)) begin
            `uvm_fatal("AXI_REG_ADAPTER", "bus_item is not axi_seq_item")
        end

        rw.kind   = item.write ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.write ? item.wdata : item.rdata;
        rw.status = ((item.write && item.bresp == 2'b00) ||
                     (!item.write && item.rresp == 2'b00)) ? UVM_IS_OK : UVM_NOT_OK;
    endfunction

endclass : axi_spi_reg_adapter

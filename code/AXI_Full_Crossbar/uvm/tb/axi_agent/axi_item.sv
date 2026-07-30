class axi_item extends uvm_sequence_item;
    rand axi_op_e op;
    rand axi_mon_kind_e kind;
    rand bit [AXI_M_ID_WIDTH-1:0] id;
    rand bit [AXI_ADDR_WIDTH-1:0] addr;
    rand bit [7:0] len;
    rand bit [2:0] size;
    rand bit [1:0] burst;
    int port_index;
    bit is_m_side;

    rand bit [AXI_DATA_WIDTH-1:0] data[];
    rand bit [AXI_STRB_WIDTH-1:0] strb[];

    bit [AXI_DATA_WIDTH-1:0] beat_data;
    bit [AXI_STRB_WIDTH-1:0] beat_strb;
    bit last;
    bit [1:0] resp;
    int source_index;
    int target_index;

    constraint c_size {
        size inside {[0:$clog2(AXI_STRB_WIDTH)]};
    }

    constraint c_burst {
        burst inside {AXI_BURST_FIXED, AXI_BURST_INCR, AXI_BURST_WRAP};
    }

    constraint c_arrays {
        if (op == AXI_WRITE) {
            data.size() == int'(len) + 1;
            strb.size() == int'(len) + 1;
        }
    }

    `uvm_object_utils_begin(axi_item)
        `uvm_field_enum(axi_op_e, op, UVM_DEFAULT)
        `uvm_field_enum(axi_mon_kind_e, kind, UVM_DEFAULT)
        `uvm_field_int(port_index, UVM_DEC)
        `uvm_field_int(is_m_side, UVM_BIN)
        `uvm_field_int(id, UVM_HEX)
        `uvm_field_int(addr, UVM_HEX)
        `uvm_field_int(len, UVM_DEC)
        `uvm_field_int(size, UVM_DEC)
        `uvm_field_int(burst, UVM_DEC)
        `uvm_field_array_int(data, UVM_HEX)
        `uvm_field_array_int(strb, UVM_HEX)
        `uvm_field_int(beat_data, UVM_HEX)
        `uvm_field_int(beat_strb, UVM_HEX)
        `uvm_field_int(last, UVM_BIN)
        `uvm_field_int(resp, UVM_HEX)
        `uvm_field_int(source_index, UVM_DEC)
        `uvm_field_int(target_index, UVM_DEC)
    `uvm_object_utils_end

    function new(string name = "axi_item");
        super.new(name);
        op = AXI_READ;
        kind = AXI_MON_AW;
        len = 0;
        size = 3'd2;
        burst = AXI_BURST_INCR;
        beat_data = '0;
        beat_strb = '0;
        last = 1'b0;
        resp = AXI_RESP_OKAY;
        source_index = -1;
        target_index = -1;
        port_index = -1;
        is_m_side = 0;
    endfunction
endclass

import "DPI-C" function void rm_reset();
import "DPI-C" function int rm_addr_to_m_port(input int unsigned addr);
import "DPI-C" function int unsigned rm_expand_id(input int s_port, input int unsigned sid, input int unsigned sid_width);
import "DPI-C" function void rm_write_beat(
    input int unsigned base_addr,
    input int unsigned len,
    input int unsigned size,
    input int unsigned burst,
    input int unsigned beat_idx,
    input int unsigned data,
    input int unsigned strb,
    input int unsigned strb_width
);
import "DPI-C" function int unsigned rm_read_beat(
    input int unsigned base_addr,
    input int unsigned len,
    input int unsigned size,
    input int unsigned burst,
    input int unsigned beat_idx,
    input int unsigned strb_width
);

class axi_ref_model extends uvm_object;
    `uvm_object_utils(axi_ref_model)

    function new(string name = "axi_ref_model");
        super.new(name);
        rm_reset();
    endfunction

    function void reset();
        rm_reset();
    endfunction

    function int addr_to_m_port(bit [AXI_ADDR_WIDTH-1:0] addr);
        return rm_addr_to_m_port(addr);
    endfunction

    function bit [AXI_M_ID_WIDTH-1:0] expand_id(int s_port, bit [AXI_S_ID_WIDTH-1:0] sid);
        return rm_expand_id(s_port, sid, AXI_S_ID_WIDTH);
    endfunction

    function void write_beat(
        bit [AXI_ADDR_WIDTH-1:0] base_addr,
        bit [7:0] len,
        bit [2:0] size,
        bit [1:0] burst,
        int unsigned beat_idx,
        bit [AXI_DATA_WIDTH-1:0] data,
        bit [AXI_STRB_WIDTH-1:0] strb
    );
        rm_write_beat(base_addr, len, size, burst, beat_idx, data, strb, AXI_STRB_WIDTH);
    endfunction

    function bit [AXI_DATA_WIDTH-1:0] read_beat(
        bit [AXI_ADDR_WIDTH-1:0] base_addr,
        bit [7:0] len,
        bit [2:0] size,
        bit [1:0] burst,
        int unsigned beat_idx
    );
        return rm_read_beat(base_addr, len, size, burst, beat_idx, AXI_STRB_WIDTH);
    endfunction
endclass

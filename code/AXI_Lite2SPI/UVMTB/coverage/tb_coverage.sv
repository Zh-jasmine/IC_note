`ifndef TB_COVERAGE_SV
`define TB_COVERAGE_SV

`uvm_analysis_imp_decl(_cov_axi)
`uvm_analysis_imp_decl(_cov_spi)

class tb_coverage extends uvm_component;

    `uvm_component_utils(tb_coverage)

    localparam bit [5:0] SPI_MODE_ADDR  = 6'h08;
    localparam bit [5:0] SCK_SPEED_ADDR = 6'h0C;
    localparam bit [5:0] WORD_LEN_ADDR  = 6'h10;

    uvm_analysis_imp_cov_axi #(axi_seq_item, tb_coverage) axi_export;
    uvm_analysis_imp_cov_spi #(spi_seq_item, tb_coverage) spi_export;

    bit [31:0] aw_addr_q[$];
    bit [31:0] w_data_q[$];
    bit [ 3:0] w_strb_q[$];

    bit [1:0] cur_spi_mode  = 2'd0;
    bit [1:0] cur_sck_speed = 2'd0;
    bit [1:0] cur_word_len  = 2'd0;

    bit [1:0]  s_mode, s_wlen, s_speed;
    bit [31:0] s_data;

    covergroup cg_spi_frame;
        option.per_instance = 1;

        cp_mode:  coverpoint s_mode  { bins mode0={0}; bins mode1={1};
                                       bins mode2={2}; bins mode3={3}; }
        cp_wlen:  coverpoint s_wlen  { bins w32={0}; bins w16={1};
                                       bins w8={2};  bins w4={3}; }
        cp_speed: coverpoint s_speed { bins d128={0}; bins d64={1};
                                       bins d32={2};  bins d16={3}; }
        cp_data:  coverpoint s_data  { bins zero={0}; bins nonzero={[1:$]}; }

        x_mode_wlen:  cross cp_mode, cp_wlen;
        x_mode_speed: cross cp_mode, cp_speed;
    endgroup

    function new(string name="tb_coverage", uvm_component parent=null);
        super.new(name, parent);
        cg_spi_frame = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_export = new("axi_export", this);
        spi_export = new("spi_export", this);
    endfunction

    function void write_cov_axi(axi_seq_item item);
        case (item.kind)
            AXI_CH_AW: aw_addr_q.push_back(item.addr);
            AXI_CH_W: begin
                w_data_q.push_back(item.wdata);
                w_strb_q.push_back(item.wstrb);
            end
            AXI_CH_B: sample_completed_write(item.bresp);
            default: begin
                if (item.write) update_from_write(item.addr, item.wdata, item.wstrb, item.bresp);
            end
        endcase
    endfunction

    function void sample_completed_write(bit [1:0] bresp);
        bit [31:0] addr;
        bit [31:0] data;
        bit [ 3:0] strb;

        if ((aw_addr_q.size() == 0) || (w_data_q.size() == 0) || (w_strb_q.size() == 0))
            return;

        addr = aw_addr_q.pop_front();
        data = w_data_q.pop_front();
        strb = w_strb_q.pop_front();
        update_from_write(addr, data, strb, bresp);
    endfunction

    function void update_from_write(bit [31:0] addr, bit [31:0] data, bit [3:0] strb, bit [1:0] bresp);
        if (bresp != 2'b00)
            return;

        if ((addr[5:2] == SPI_MODE_ADDR[5:2]) && strb[0])
            cur_spi_mode = data[1:0];

        if ((addr[5:2] == SCK_SPEED_ADDR[5:2]) && strb[0])
            cur_sck_speed = data[1:0];

        if ((addr[5:2] == WORD_LEN_ADDR[5:2]) && strb[0])
            cur_word_len = data[1:0];
    endfunction

    function void write_cov_spi(spi_seq_item item);
        s_mode  = cur_spi_mode;
        s_wlen  = cur_word_len;
        s_speed = cur_sck_speed;
        s_data  = item.spi_data;
        cg_spi_frame.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("functional coverage = %0.2f%%",
            cg_spi_frame.get_inst_coverage()), UVM_LOW)
    endfunction

endclass

`endif // TB_COVERAGE_SV

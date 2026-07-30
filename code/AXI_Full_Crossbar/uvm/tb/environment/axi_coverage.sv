class axi_coverage extends uvm_subscriber #(axi_item);
    `uvm_component_utils(axi_coverage)

    int cg_side;
    int cg_port;
    int cg_kind;
    int cg_burst;
    int cg_resp;
    int cg_size;

    covergroup axi_cg;
        option.per_instance = 1;
        cp_side:  coverpoint cg_side { bins s_side = {0}; bins m_side = {1}; }
        cp_port:  coverpoint cg_port { bins ports[] = {[0:7]}; }
        cp_kind:  coverpoint cg_kind { bins aw = {AXI_MON_AW}; bins w = {AXI_MON_W}; bins b = {AXI_MON_B}; bins ar = {AXI_MON_AR}; bins r = {AXI_MON_R}; }
        cp_burst: coverpoint cg_burst { bins fixed = {AXI_BURST_FIXED}; bins incr = {AXI_BURST_INCR}; bins wrap = {AXI_BURST_WRAP}; }
        cp_resp:  coverpoint cg_resp { bins okay = {AXI_RESP_OKAY}; bins exokay = {AXI_RESP_EXOKAY}; bins slverr = {AXI_RESP_SLVERR}; bins decerr = {AXI_RESP_DECERR}; }
        cp_size:  coverpoint cg_size { bins byte1 = {0}; bins byte2 = {1}; bins byte4 = {2}; }
        cross cp_side, cp_kind;
    endgroup

    function new(string name = "axi_coverage", uvm_component parent = null);
        super.new(name, parent);
        axi_cg = new();
    endfunction

    virtual function void write(axi_item t);
        cg_side = t.is_m_side;
        cg_port = t.port_index;
        cg_kind = t.kind;
        cg_burst = t.burst;
        cg_resp = t.resp;
        cg_size = t.size;
        axi_cg.sample();
    endfunction

    virtual function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        `uvm_info("AXI_COV", $sformatf("Functional coverage = %.2f%%", axi_cg.get_coverage()), UVM_NONE)
    endfunction
endclass


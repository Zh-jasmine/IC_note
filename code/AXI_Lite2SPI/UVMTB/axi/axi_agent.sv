class axi_agent extends uvm_agent;

    `uvm_component_utils(axi_agent)

    axi_config      axi_cfg;

    axi_sequencer   axi_sqr;
    axi_monitor     axi_mtr;
    axi_driver      axi_drv;

    uvm_analysis_port#(axi_seq_item) axi_mtr_port;

    function new(string name = "axi_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        axi_mtr_port = new("axi_mtr_port", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg))
            `uvm_fatal(get_name(), {"axi_config must be set for: ", get_full_name()})

        uvm_config_db#(axi_config)::set(this, "axi_sqr", "axi_config", axi_cfg);
        axi_sqr = axi_sequencer::type_id::create("axi_sqr", this);

        uvm_config_db#(axi_config)::set(this, "axi_drv", "axi_config", axi_cfg);
        axi_drv = axi_driver::type_id::create("axi_drv", this);

        uvm_config_db#(axi_config)::set(this, "axi_mtr", "axi_config", axi_cfg);
        axi_mtr = axi_monitor::type_id::create("axi_mtr", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        axi_drv.seq_item_port.connect(axi_sqr.seq_item_export);
        axi_mtr.axi_mtr_port.connect(this.axi_mtr_port);
    endfunction : connect_phase

endclass : axi_agent

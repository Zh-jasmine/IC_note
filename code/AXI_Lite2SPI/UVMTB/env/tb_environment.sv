class tb_environment extends uvm_env;

    `uvm_component_utils(tb_environment)

    environment_config env_cfg;

    axi_agent     axi_agt;
    spi_monitor   spi_mtr;
    spi_ref_model rm;
    tb_scoreboard scb;
    tb_coverage   cov;

    function new(string name = "tb_environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(environment_config)::get(this, "", "environment_config", env_cfg))
            `uvm_fatal(get_name(), "environment_config not found in config_db")

        uvm_config_db#(axi_config)::set(this, "axi_agt", "axi_config", env_cfg.axi_cfg);
        axi_agt = axi_agent::type_id::create("axi_agt", this);

        uvm_config_db#(spi_config)::set(this, "spi_mtr", "spi_config", env_cfg.spi_cfg);
        uvm_config_db#(axi_config)::set(this, "spi_mtr", "axi_config", env_cfg.axi_cfg);
        spi_mtr = spi_monitor::type_id::create("spi_mtr", this);

        uvm_config_db#(axi_config)::set(this, "rm", "axi_config", env_cfg.axi_cfg);
        rm = spi_ref_model::type_id::create("rm", this);

        uvm_config_db#(axi_config)::set(this, "scb", "axi_config", env_cfg.axi_cfg);
        scb = tb_scoreboard::type_id::create("scb", this);

        cov = tb_coverage::type_id::create("cov", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        axi_agt.axi_mtr_port.connect(rm.axi_fifo.analysis_export);
        rm.expected_spi_item.connect(scb.expected_spi_fifo.analysis_export);
        spi_mtr.spi_mtr_port.connect(scb.actual_spi_fifo.analysis_export);

        axi_agt.axi_mtr_port.connect(cov.axi_export);
        spi_mtr.spi_mtr_port.connect(cov.spi_export);
    endfunction : connect_phase

endclass : tb_environment

class test_base extends uvm_test;

    `uvm_component_utils(test_base)

    environment_config env_cfg;
    tb_environment     env;

    function new(string name = "test_base", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        // Create configs
        env_cfg = environment_config::type_id::create("env_cfg", this);
        env_cfg.axi_cfg = axi_config::type_id::create("axi_cfg", this);
        env_cfg.spi_cfg = spi_config::type_id::create("spi_cfg", this);

        // Get vifs from tb_top (set at path "uvm_test_top")
        if (!uvm_config_db#(virtual axi_interface)::get(this, "", "axi_vif", env_cfg.axi_cfg.vif))
            `uvm_fatal(get_name(), "axi_interface not found in config_db. Set from tb_top.")

        if (!uvm_config_db#(virtual spi_interface)::get(this, "", "spi_vif", env_cfg.spi_cfg.vif))
            `uvm_fatal(get_name(), "spi_interface not found in config_db. Set from tb_top.")

        // Pass env_cfg to environment and create it
        uvm_config_db#(environment_config)::set(this, "env", "environment_config", env_cfg);
        env = tb_environment::type_id::create("env", this);
    endfunction : build_phase

    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction : end_of_elaboration_phase

    task automatic seq_start();
        axi_spi_cfg_seq cfg = axi_spi_cfg_seq::type_id::create("seq_start");

        cfg.start_i = 1'b0;
        cfg.start(env.axi_agt.axi_sqr);
    endtask : seq_start

    task automatic wait_spi_done();
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;

        if (spi_vif.CS === 1'b1)
            @(negedge spi_vif.CS);
        @(posedge spi_vif.CS);
    endtask : wait_spi_done

endclass : test_base

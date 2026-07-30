package axi_env_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_types_pkg::*;
    import axi_agent_pkg::*;

    `include "axi_virtual_sequencer.sv"
    `include "axi_ref_model.sv"
    `include "axi_scoreboard.sv"
    `include "axi_coverage.sv"
    `include "axi_env.sv"
endpackage

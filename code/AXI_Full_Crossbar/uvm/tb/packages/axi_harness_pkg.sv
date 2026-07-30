package axi_harness_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import axi_types_pkg::*;
    import axi_agent_pkg::*;
    import axi_env_pkg::*;

    `include "axi_smoke_rw_seq.sv"
    `include "axi_base_test.sv"
    `include "axi_smoke_rw_test.sv"
    `include "axi_env_build_test.sv"
endpackage

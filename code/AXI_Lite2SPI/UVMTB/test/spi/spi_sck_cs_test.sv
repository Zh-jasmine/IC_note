// spi_sck_cs_test - VPlan 3.2
//   Sweep SCK_CS register values and check SPI data transfer still completes.
`ifndef SPI_SCK_CS_TEST_SV
`define SPI_SCK_CS_TEST_SV

class spi_sck_cs_test extends test_base;
    `uvm_component_utils(spi_sck_cs_test)

    function new(string name = "spi_sck_cs_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic int sck_cs;
        automatic axi_spi_cfg_seq seq;

        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i)
                0: sck_cs = 2;
                1: sck_cs = 4;
                2: sck_cs = 8;
            endcase

            seq = axi_spi_cfg_seq::type_id::create("seq");
            seq.sck_cs_i    = sck_cs;
            seq.mosi_data_i = 32'h5A;
            seq.start(env.axi_agt.axi_sqr);
            wait_spi_done();

            `uvm_info(get_name(), $sformatf("SCK_CS=%0d transfer done", sck_cs), UVM_LOW)
        end

        phase.drop_objection(this);
    endtask
endclass : spi_sck_cs_test

`endif
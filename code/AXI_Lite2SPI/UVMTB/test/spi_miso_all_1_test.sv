// spi_miso_all_1_test — VPlan 4.3
//   MISO 全 1（0xFF），验证 DUT 采样 + slv_reg9 读回正确

`ifndef SPI_MISO_ALL_1_TEST_SV
`define SPI_MISO_ALL_1_TEST_SV

class spi_miso_all_1_test extends spi_miso_base_test;
    `uvm_component_utils(spi_miso_all_1_test)
    function new(string name = "spi_miso_all_1_test", uvm_component parent = null);
        super.new(name, parent);
        exp_miso_byte = 8'hFF;
    endfunction
endclass : spi_miso_all_1_test

`endif

module spi_sva_checker (
    input logic GCLK,
    input logic ARESETn,
    input logic SCLK,
    input logic CS,
    input logic MOSI
);


  property p_spi_reset;
        @(posedge GCLK) !ARESETn |=>
            ((CS === 1'b1) && (SCLK === 1'b0) && (MOSI === 1'b0));
    endproperty

    SPI_RESET_CHK: assert property(p_spi_reset)
        else $error("SPI reset: 引脚未回 idle (CS=%b SCK=%b MOSI=%b)", CS, SCLK, MOSI);


endmodule : spi_sva_checker
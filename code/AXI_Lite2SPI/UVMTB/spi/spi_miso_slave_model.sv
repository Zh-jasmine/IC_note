`ifndef SPI_MISO_SLAVE_MODEL_SV
`define SPI_MISO_SLAVE_MODEL_SV

// Configurable MISO slave model for readback tests.
// SPI mode encoding follows {CPOL, CPHA}; word_len follows DUT encoding:
// 0=32-bit, 1=16-bit, 2=8-bit, 3=4-bit.
module spi_miso_slave_model (
    input  logic        GCLK,
    input  logic        SCLK,
    input  logic        CS,
    input  logic [31:0] tx_data,
    input  logic [ 1:0] spi_mode,
    input  logic [ 1:0] word_len,
    output logic        MISO
);

    int bit_idx;

    function automatic int unsigned num_bits(input logic [1:0] len);
        case (len)
            2'd0:    num_bits = 32;
            2'd1:    num_bits = 16;
            2'd2:    num_bits = 8;
            2'd3:    num_bits = 4;
            default: num_bits = 8;
        endcase
    endfunction

    function automatic bit shift_on_posedge(input logic [1:0] mode);
        logic cpol;
        logic cpha;
        begin
            cpol = mode[1];
            cpha = mode[0];
            shift_on_posedge = (cpol != cpha);
        end
    endfunction

    task automatic drive_shift_bit();
        logic cpha;
        begin
            cpha = spi_mode[0];

            if (!cpha) begin
                if (bit_idx > 0)
                    bit_idx = bit_idx - 1;
                MISO <= tx_data[bit_idx];
            end else begin
                MISO <= tx_data[bit_idx];
                if (bit_idx > 0)
                    bit_idx = bit_idx - 1;
            end
        end
    endtask

    initial begin
        bit_idx = 0;
        MISO = 1'b0;
    end

    always @(negedge CS) begin
        bit_idx = num_bits(word_len) - 1;
        if (!spi_mode[0])
            MISO <= tx_data[bit_idx];
        else
            MISO <= 1'b0;
    end

    always @(posedge CS) begin
        MISO <= 1'b0;
    end

    always @(posedge SCLK) begin
        if (!CS && shift_on_posedge(spi_mode))
            drive_shift_bit();
    end

    always @(negedge SCLK) begin
        if (!CS && !shift_on_posedge(spi_mode))
            drive_shift_bit();
    end

endmodule : spi_miso_slave_model

`endif

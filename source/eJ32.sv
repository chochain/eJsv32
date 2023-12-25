///
/// eJ32 top module (Outer Interpreter)
///
`include "../source/eJ32.vh"
`include "../source/eJ32_if.sv"

import ej32_pkg::*;

module eJ32 #(
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    ) (
       ej32_ctl ctl,            // eJ32 bus
       mb8_io   b8_if           // memory bus
    );
    // ej32 memory bus
    `IU  addr;                  ///> shared memory address
    `U8  data;                  ///> data return from SRAM (sent to core)
    `U8  data_o;                ///> data return from core
    `U1  dwe_o;                 ///> data write enable driven by core

    spram8_128k            smem(b8_if.slave, ~ctl.clk);
    ej32_core #(TIB, OBUF) core(.ctl(ctl), .data_i(data), .addr_o(addr), .*);

    assign data = b8_if.vo;     ///> data fetched from SRAM (1-cycle)
   
    always_comb begin
        if (dwe_o) b8_if.put_u8(addr, data_o);  ///> write to SRAM
        else       b8_if.get_u8(addr);          ///> read from SRAM
    end
endmodule: eJ32

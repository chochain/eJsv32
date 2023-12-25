///
/// eJ32 top module (Outer Interpreter)
///
`include "../source/eJ32.vh"
`include "../source/eJ32_if.sv"

import ej32_pkg::*;

module top #(
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    ) (
       ej32_ctl ctl,            // eJ32 bus
       mb8_io   b8_if,          // memory bus
       output `IU addr_t,       // debug output
       output `U3 phase_t,
       output `U5 rp_t
    );
    // ej32 memory bus
    `IU  addr;
    `U8  data, data_o;
    `U1  dwe_o;
    // ej32 debug output
    `U3  phase_o;
    `IU  p_o, a_o;
    `DU  s_o, r_o;
    `U5  sp_o, rp_o;

    spram8_128k       smem(b8_if.slave, ~ctl.clk);
    eJ32 #(TIB, OBUF) ej32(.ctl(ctl), .data_i(data), .addr_o(addr), .*);

    assign data    = b8_if.vo;
    always_comb begin
        if (dwe_o) b8_if.put_u8(addr, data_o);
        else       b8_if.get_u8(addr);
    end
    ///
    /// debug tasks
    ///
    assign rp_x    = rp_o;
    assign addr_x  = addr;
    assign phase_x = phase_o;
   
    task trace;
        automatic opcode_t code;
        if (!$cast(code, ctl.code)) begin
            /// JVM opcodes, some are not avialable yet
            code = op_err;
        end
        $write(
            "%6t> p:a[io]=%4x:%4x[%2x:%2x] rp=%2x<%4x> sp=%2x<%8x, %8x> %2x=%d.%-16s",
            $time/10, p_o, a_o, data, data_o, rp_o, r_o, sp_o, s_o, ctl.t, code, phase_o, code.name);
    endtask: trace
endmodule: top

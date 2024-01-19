///
/// eJ32 common interfaces
///
`ifndef EJ32_EJ32_IF
`define EJ32_EJ32_IF

`include "../source/eJ32.vh"

interface EJ32_CTL;
   import ej32_pkg::*;
   `U1  clk;
   `U1  rst;
   opcode_t code;              // opcode
   `U3  phase;                 // opcode phase i.e. nth-cycle of opcode
   `DU  t;                     // TOS, on bus
   
   function void reset();
       code  = nop;
       phase = 3'b0;
       t     = 0;
   endfunction: reset
endinterface: EJ32_CTL

interface mb32_io(input `U1 clk);
    logic [3:0]  bmsk;
    logic [14:0] ai;
    `U1  we;
    `DU  vi;
    `DU  vo;

`ifdef VERILATOR   
    modport master(output we, bmsk, ai, vi);
    modport slave(input we, bmsk, ai, vi, output vo);
`else
    clocking io_clk @(posedge clk);
        default input #1 output #1;
    endclocking // ioMaster

    modport master(clocking io_clk, output we, bmsk, ai, vi);
    modport slave(clocking io_clk, input we, bmsk, ai, vi, output vo);
`endif
endinterface: mb32_io

interface mb8_io;
    `U1  we;
    `IU  ai;
    `U8  vi;
    `U8  vo;
    
    modport master(output we, ai, vi, import put_u8, get_u8);
    modport slave(input we, ai, vi, output vo);

    function void put_u8(input `IU ax, input `U8 vx);
        we = 1'b1;
        ai = ax;
        vi = vx;
    endfunction: put_u8
    
    function void get_u8(input `IU ax);
        we = 1'b0;
        ai = ax;
        // return vo
    endfunction: get_u8
endinterface : mb8_io

interface ss_io();
    import ej32_pkg::*;
    stack_op op;
    `DU vi;
    `DU s;
    
    modport master(input s, output op, vi, import push, pop);
    modport slave(input op, vi, output s);

    function void push(input `DU v);
        op  = sPUSH;
        vi  = v;
    endfunction: push

    function `DU pop;
        op   = sPOP;
        pop  = s;
    endfunction: pop
    
endinterface: ss_io
`endif // EJ32_EJ32_IF



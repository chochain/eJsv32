//
// eJ32 - Java Forth Machine - Load/Store Unit
//
`include "../source/eJ32_if.sv"

`define PHASE0 phase_n = 0
`define R(op)  ctl.rs_op = op
`define S(op)  ctl.ss_op = op

module EJ32_LS #(
    parameter TIB      = 'h1000,          ///> input buffer address
    parameter OBUF     = 'h1400,          ///> output buffer address
    parameter DSZ      = 32,              ///> 32-bit data width
    parameter ASZ      = 17               ///> 128K address space
    ) (
    EJ32_CTL ctl,
    input  `U8 data,                      ///> data from memory bus
    input  `DU s,                         ///> NOS
    output `U1 ls_en,
    output `U1 ls_asel_o,
    output `IU ls_addr_o,                 ///> address to memory bus
    output `U8 data_o,                    ///> data to memory bus
    output `U1 dwe_o                      ///> data write enable
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    // instruction
    `U3  phase;                 ///> FSM phase (aka state)
    `IU  a;                     ///> memory address
    `IU  asel;
    // IO
    `U2  dsel;                  ///> 32-bit, 4-to-1 mux, byte select
    `IU  ibuf, obuf;            ///> input, output buffer pointers
    /// @}
    /// @defgroup Next Register
    /// @{
    // instruction
    opcode_t code_n;            ///> JVM opcode
    `U3 phase_n;                ///> FSM phase (aka state)
    `IU a_n;                    ///> data address
    `IU asel_n;                 ///> address select
    `DU t_n;                    ///> TOS
    `DU r_n;                    ///> top of return stack
    `U8 data_n;
    `U2 dsel_n;                 ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t code;              ///> shadow ctl.code
    `U1 code_x;                 ///> instruction unit control
    `U1 p_x, a_x;               ///> address controls
    `IU a_d;                    ///> 2-byte merged address
    // data stack
    `DU t;                      ///> shadow TOS
    `U1 t_x, t_z, t_neg;        ///> TOS controls
    `DU t_d;                    ///> 4-byte merged data
    // memory & IO buffers
    `U8 d8x4[4];                ///> 4-to-1 byte select
    `U1 dwe, dsel_x;            ///> data/addr bus controls
    `U1 ibuf_x, obuf_x;         ///> input/output buffer controls
    /// @}
   
    task STEP(input `U3 n); phase_n = n; `CLR(code_x); endtask;
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);        endtask;
    // data stack
    task TOS(input `DU v);  t_n = v; `SET(t_x);  endtask;
    task ALU(input `DU v);  TOS(v); `S(sPOP);    endtask;
    task PUSH(input `DU v); TOS(v); `S(sPUSH);   endtask;
    task POP();             TOS(s); `S(sPOP);    endtask;
    // memory unit
    task SETA(input `IU a); a_n = a; `SET(a_x);   endtask;      // build addr ptr
    task MEM(input `IU a); SETA(a); `SET(asel_n); endtask;   // fetch from memory, data returns next cycle
    task DW(input `U3 n); dsel_n = n; `SET(dwe); `SET(dsel_x); endtask;   // data write n-th byte
    ///
    /// wires to reduce verbosity
    ///
    assign code     = ctl.code;               ///> input from ej32 control
    assign phase    = ctl.phase;
    assign t        = ctl.t;
    assign t_z      = ctl.t_z;
    assign t_neg    = ctl.t_neg;
    assign ls_addr_o= a;                      ///> memory address
    assign ls_asel_o= asel;
    assign data_o   = data_n;                 ///> data sent to memory bus
    assign dwe_o    = dwe;                    ///> data write enable
    assign d8x4     =                         ///> 4-to-1 Big-Endian
        {t[31:24],t[23:16],t[15:8],t[7:0]};
    assign data_n   = d8x4[dsel];             ///> data byte select (Big-Endian)
    ///
    /// wires to external modules
    ///
    assign a_d    = {a[ASZ-9:0], data};       ///> merge lowest byte into addr
    assign t_d    = {t[DSZ-9:0], data};       ///> merge lowest byte into TOS
    ///
    /// combinational
    ///
    task INIT();
        code_x    = 1'b1;         /// fetch opcode by default
        phase_n   = 3'b0;         /// phase and IO controls
        a_n       = {ASZ{1'b0}};  /// default to clear address
        a_x       = 1'b0;
        asel_n    = 1'b0;         /// address default to program counter
        t_n       = {DSZ{1'b0}};  /// TOS
        t_x       = 1'b0;
        dsel_x    = 1'b0;         /// data bus
        dsel_n    = 3;
        dwe       = 1'b0;         /// data write
        ibuf_x    = 1'b0;
        obuf_x    = 1'b0;
        ctl.ss_op = sNOP;         /// data stack
    endtask: INIT
    
    always_comb begin
        INIT();
        case (code)
        iaload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data)); end
            2: begin WAIT(3); MEM(a + 1); TOS(t_d); end
            3: begin WAIT(4); MEM(a + 1); TOS(t_d); end
            4: begin WAIT(5); TOS(t_d); end
            default: `PHASE0;
            endcase
        baload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t));    end
            1: begin WAIT(2); TOS(`X8D(data)); end
            default: `PHASE0;
            endcase
        saload:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(t)); end
            1: begin WAIT(2); MEM(a + 1); TOS(`X8D(data)); end
            2: begin WAIT(3); TOS(t_d); end
            default: `PHASE0;
            endcase
        iastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); `SET(dsel_x); dsel_n = 0; end
            1: begin WAIT(2); MEM(a + 1); DW(1); end
            2: begin WAIT(3); MEM(a + 1); DW(2); end
            3: begin WAIT(4); MEM(a + 1); DW(3); end
            4: begin WAIT(5); DW(3); POP(); end         // CC: reset a?
            default: `PHASE0;
            endcase
        bastore:
            case (phase)
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); end
            1: begin WAIT(2); POP(); DW(3); end         // CC: reset a?
            default: `PHASE0;       // CC: extra cycle
            endcase
        sastore:
            case (phase)
            // CC: logic changed
            // 0: begin WAIT(1); MEM(s); `SET(spop); end
            // 1: begin WAIT(2); MEM(a + 1); DW(2); end
            // 2: begin WAIT(3); POP(); DW(3); `SET(asel_n); end
            0: begin WAIT(1); MEM(`XDA(s)); `S(sPOP); `SET(dsel_x); dsel_n = 2; end
            1: begin WAIT(2); MEM(a + 1); DW(3); end
            2: begin WAIT(3); DW(3); POP(); end
            default: `PHASE0;
            endcase
        iinc:
            case (phase)
            // 0: begin phase_n = 1; MEM(s); end
            // 1: begin phase_n = 2; `HOLD; ALU(t + data); asel_n = 1'b1; end
            // default: begin `PHASE0; `HOLD; TOS(s); DW(0); end
            // CC: change Dr. Ting's logic
            0: begin WAIT(1); MEM(`XDA(s)); end
            1: begin WAIT(2); ALU(t + `X8D(data)); `SET(asel_n); end
            default: begin `PHASE0; TOS(s); DW(0); end
            endcase // case (phase)
        get:
            case (phase)
            0: begin WAIT(1); MEM(ibuf); `S(sPUSH); end
            1: begin WAIT(2); TOS(`X8D(data)); `SET(ibuf_x); end
            default: `PHASE0;     // CC: extra memory cycle
            endcase
        put:
            case (phase)
            0: begin WAIT(1); MEM(obuf); `SET(dsel_x); end
            default: begin `PHASE0; POP(); DW(3); `SET(obuf_x); end
            endcase
        default: `PHASE0;
        endcase
    end // always_comb
    
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            asel  <= 1'b0;
            dsel  <= 3;
            ibuf  <= TIB;
            obuf  <= OBUF;
            a     <= {ASZ{1'b0}};
        end
        else if (ctl.clk) begin
            ctl.phase <= phase_n;
            asel      <= asel_n;
            // instruction
            if (code_x)  ctl.code <= code_n;
            if (t_x)     ctl.t    <= t_n;
            if (a_x)     a        <= a_n;
            if (dsel_x)  dsel     <= dsel_n;
            if (ibuf_x)  ibuf     <= ibuf + 1;
            if (obuf_x)  obuf     <= obuf + 1;
        end
    end // always_ff @ (posedge clk, posedge rst)
endmodule: EJ32_LS

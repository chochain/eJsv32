//
// eJ32 - Java Forth Machine - Arithmetic Unit
//
`include "../source/eJ32_if.sv"

`define PHASE0 phase_n = 0
`define R(op)  ctl.rs_op = op
`define S(op)  ctl.ss_op = op

module ej32_core #(
    parameter DSZ      = 32,              ///> 32-bit data width
    parameter ASZ      = 17,              ///> 128K address space
    parameter SS_DEPTH = 32               ///> 32 deep data stack
    ) (
    ej32_ctl ctl,
    input  `U8 data,                      ///> data from memory bus
    /// for div_patch
    input  `IU p,                         ///> program counter
    output `IU p_o                        
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    // instruction
    `U3  phase;                 ///> FSM phase (aka state)
    // data stack
    `DU  s;                     ///> NOS
    `DU  ss[SS_DEPTH];          ///> data stack, 3K LUTs, TODO: use EBR memory
    `U5  sp;                    ///> data stack pointers, sp1 = sp + 1
    /// @}
    /// @defgroup Next Register
    /// @{
    // instruction
    opcode_t code_n;            ///> JVM opcode
    `U3 phase_n;                ///> FSM phase (aka state)
    `DU t_n;                    ///> TOS
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t code;              ///> shadow ctl.code
    `U1 code_x;                 ///> instruction unit control
    `U1 p_x;
    `IU a_d;                    ///> 2-byte merged address
    // data stack
    `DU t;                      ///> shadow TOS
    `U1 t_x, t_z, t_neg;        ///> TOS controls
    `DU t_d;                    ///> 4-byte merged data
    `U5 sp1;                    ///> data stack pointers, sp1 = sp + 1
    // return stack
    `U5 rp1;                    ///> return stack pointers
    `U1 r_x;                    ///> return stack controls
    /// @}
    /// @defgroup ALU pre-calc wires
    /// @{
    `DU  isht_o, iushr_o;
    `U1  shr_f;
    `DU2 mul_v;
    `DU  div_q, div_r;
    `U1  div_rst, div_by_z, div_bsy;
    ///
    /// extended ALU units
    ///
    mult      mult_inst(
    .a(t),
    .b(s),
    .r(mul_v)
    );
    div_int   divide_inst(
    .clk(ctl.clk),
    .rst(div_rst),
    .x(s),
    .y(t),
    .busy(div_bsy),
    .dbz(div_by_z),
    .q(div_q),
    .r(div_r)
    );
    shifter   shifter_inst(
    .d(s),
    .dir(shr_f),
    .bits(t[4:0]),
    .r(isht_o)
    );
    ushifter  ushifter_inst(
    .d(s),
    .bits(t[4:0]),
    .r(iushr_o)
    );
    task STEP(input `U3 n); phase_n = n; `CLR(code_x); endtask;
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);        endtask;
    // data stack
    task TOS(input `DU v);  t_n = v; `SET(t_x);  endtask;
    task ALU(input `DU v);  TOS(v); `S(sPOP);    endtask;
    task PUSH(input `DU v); TOS(v); `S(sPUSH);   endtask;
    task POP();             TOS(s); `S(sPOP);    endtask;
    // external ALU modules
    task DIV(input `DU v);
        case (phase)
        0: WAIT(1);
        default: begin
            if (div_bsy) WAIT(1);
            else begin `PHASE0; ALU(v); end
        end
        endcase
    endtask: DIV
    ///
    /// wires to reduce verbosity
    ///
    assign s      = ss[sp];                 ///> data stack, TODO: EBR
    assign sp1    = sp + 1;
    ///
    /// IO signals wires
    ///
    assign code   = ctl.code;               ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;
    assign t_z    = ctl.t_z;
    assign t_neg  = ctl.t_neg;
    ///
    /// wires to external modules
    ///
    assign div_rst= (code!=idiv && code!=irem) ? '1 : phase==0;
//    assign a_d    = {a[ASZ-9:0], data};     ///> merge lowest byte into addr
    assign t_d    = {t[DSZ-9:0], data};     ///> merge lowest byte into TOS
    ///
    /// combinational
    ///
    task INIT();
        code_x    = 1'b1;         /// fetch opcode by default
        phase_n   = 3'b0;         /// phase and IO controls        t_n       = {DSZ{1'b0}};  /// TOS
        t_x       = 1'b0;
        ctl.ss_op = sNOP;         /// data stack
        ///
        /// external module control flags
        ///
        shr_f     = 1'b0;         /// shifter flag
        if (!$cast(code_n, data)) begin
            /// JVM opcodes, some are not avialable yet
            code_n = op_err;
        end
    endtask: INIT
    
    always_comb begin
        INIT();
        ///
        /// instruction dispatcher
        ///
        case (code)
        nop        : begin end    // do nothing
        aconst_null: PUSH(0);
        iconst_m1  : PUSH(-1);
        iconst_0   : PUSH(0);
        iconst_1   : PUSH(1);
        iconst_2   : PUSH(2);
        iconst_3   : PUSH(3);
        iconst_4   : PUSH(4);
        iconst_5   : PUSH(5);
        bipush:
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data)); end
            default: `PHASE0;
            endcase
        sipush:                     // CC: not tested
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data)); end
            1: begin STEP(2); TOS(t_d); end
            default: `PHASE0;
            endcase
        pop: POP();
        pop2:
            case (phase)
            0: begin WAIT(1); POP(); end
            default: begin `PHASE0; POP(); end
            endcase
        dup: `S(sPUSH);
        dup_x1:                     // CC: logic changed since a_n is 16-bit only
            case (phase)
            0: begin WAIT(1); PUSH(s); end
            1: WAIT(2);             // wait for stack update??
            default: `PHASE0;
            endcase
        dup_x2: PUSH(ss[sp - 1]);
        dup2:                       // CC: logic changed since a_n is 16-bit only 
            case (phase)
            0: begin WAIT(1); PUSH(s); end
            1: WAIT(2);             // CC: wait for stack update??
            2: begin WAIT(3); PUSH(s); end
            default: `PHASE0;
            endcase
        swap: begin TOS(s); `S(sMOVE); end
        //
        // ALU ops
        //
        iadd: ALU(s + t);
        isub: ALU(s - t);
        imul: ALU(mul_v[DSZ-1:0]);
        idiv: DIV(div_q);
        irem: DIV(div_r);
        ineg: ALU(0 - t);
        ishl: ALU(isht_o);
        ishr: begin ALU(isht_o); `SET(shr_f); end
        iushr:ALU(iushr_o);
        iand: ALU(s & t);
        ior:  ALU(s | t);
        ixor: ALU(s ^ t);
        ldi:
            case (phase)
            0: begin STEP(1); PUSH(`X8D(data)); end
            1: begin STEP(2); TOS(t_d); end
            2: begin STEP(3); TOS(t_d); end
            3: begin STEP(4); TOS(t_d); end
            default: `PHASE0;
            endcase
        default: `PHASE0;
        endcase
    end // always_comb
    ///
    /// data stacks
    ///
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            sp    <= '0;
        end
        else if (ctl.clk) begin
            // data stack
            case (ctl.ss_op)
            sMOVE: ss[sp] <= t;
            sPOP:  sp <= sp - 1;
            sPUSH: begin ss[sp1] <= t; sp <= sp + 1; end // CC: ERROR -> EBR with multiple writers
//          sPUSH: begin ss[sp] <= t; sp <= sp + 1; end  // CC: use this to fix synthesizer
            endcase
        end
    end // always_ff @ (posedge ctl.clk, posedge ctl.rst)
    
    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (!ctl.rst && ctl.clk) begin
            ctl.phase <= phase_n;
            // instruction
            if (code_x)    ctl.code <= code_n;
            if (t_x)       ctl.t    <= t_n;
            ///
            /// validate and patch
            /// CC: do not know why DIV is skipping the branch
            ///
            if (!div_rst) div_patch();
        end
    end // always_ff @ (posedge clk, posedge rst)

    task div_patch();
        automatic `U8 op = code==idiv ? "/" : "%";
        if (phase_n==1) begin
            if (!div_bsy) begin
                $write("ERR: %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
                assert(phase_n == 0) else begin
                    $write(", phase_n=%d reset =0", phase_n) ;
                    ctl.phase <= 0;
                end
                assert(code_x == 1) else begin
                    $write(", code_x=%d code_n=%s, p=%4x forced +1", code_x, code_n.name, p);
                    ctl.code <= code_n; p_o <= p + 1;
                end
                assert(ctl.ss_op == sPOP) else begin
                    $write(", sp=%d, sp1=%d forced -1", sp, sp1);
                    sp <= sp - 1;
                end
                assert(t_n == (t_n==(idiv ? div_q : div_r))) else begin
                    $write(", t_x=%d t_n=%8x =q/r", t_x, t_n);
                    ctl.t <= code==idiv ? div_q : div_r;
                end
                $display(" :ERR");
            end
        end
        else begin // done div_int
            $display("OK %8x %c %8x => %8x..%8x", s, op, t, div_q, div_r);
            assert(div_q == (s / t));
            assert(div_r == (s % t));
        end
    endtask: div_patch
endmodule: ej32_core

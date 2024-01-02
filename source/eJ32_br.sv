//
// eJ32 - Java Forth Machine - Branching Unit
//
`include "../source/eJ32_if.sv"

`define R(op) rs_op=op

module EJ32_BR #(
    parameter RS_DEPTH = 32,    ///> 32 deep return stack
    parameter DSZ      = 32,    ///> 32-bit data width
    parameter ASZ      = 17     ///> 128K address space
    ) (
    EJ32_CTL ctl,               ///> eJ32 control bus
    input    `U1 br_en,         ///> branching unit active
    input    `IU p,             ///> instruction pointer
    input    `U8 data,          ///> data from memory bus
    input    `DU s,             ///> NOS from stack unit
    output   `IU br_p_o,        ///> target instruction pointer
    output   `U1 br_psel
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    // instruction
    `IU  a;                     ///> instrunction address
    `U3  phase;                 ///> FSM phase (aka state)
    `DU  rs[RS_DEPTH];          ///> return stack, 3K LUTs, TODO: use EBR memory
    `DU  r;                     ///> top of RS
    `U5  rp;                    ///> return stack pointers
    stack_op rs_op;             ///> return stack opcode
    // IO
    /// @}
    /// @defgroup Next Register
    /// @{
    `IU a_n;                    ///> instruction pointer
    `U1 asel_n;
    `DU t_n, r_n;               ///> TOS, top of return stack
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t code;              ///> shadow ctl.code
    `U1 asel;                   ///> address select
    `U1 a_x;                    ///> address controls
    `IU a_d;                    ///> 2-byte merged address
    // data stack
    `DU t;                      ///> shadow TOS
    `U1 t_x, t_z, t_neg;        ///> TOS controls
    `DU t_d;                    ///> 4-byte merged data
    // return stack
    `U5 rp1;                    ///> return stack pointer
    `U1 r_x;                    ///> return stack control

    // data stack
    task TOS(input `DU d);  t_n = d;  `SET(t_x); endtask;
    task PUSH(input `DU d); TOS(d);              endtask;    // `S(sPUSH) in AU
    task RPUSH(input `DU d); r_n = d; `R(sPUSH); endtask;
    // branching
    // Note: address is memory offset (instead of Java class file reference)
    //
    task SETA(input `IU i); a_n = i; `SET(a_x);    endtask;  // build addr ptr
    task JMP(input `IU i);  SETA(i); `SET(asel_n); endtask;  // jmp and clear a
    task BRAN(input `U1 f);
        case (phase)
        0: SETA(`XDA(data));
        1: if (f) JMP(a_d);
        endcase
    endtask: BRAN
    ///
    /// wires to reduce verbosity
    ///
    assign r      = rs[rp];                   ///> return stack, TODO: EBR
    assign rp1    = rp + 1;
    ///
    /// IO signals wires
    ///
    assign code   = ctl.code;
    assign phase  = ctl.phase;
    assign t      = ctl.t;
    assign t_z    = ctl.t == 0;               ///> zero flag
    assign t_neg  = ctl.t[DSZ-1];             ///> negative flag
    assign t_d    = {t[DSZ-9:0], data};       ///> merge lowest byte into t
    assign a_d    = {a[ASZ-9:0], data};       ///> merge lowest byte into addr
    /// output ports
    assign br_p_o = a;
    assign br_psel= asel;
    ///
    /// combinational
    ///
    task INIT();
        asel_n  = 1'b0;
        a_x     = 1'b0;
        t_n     = {DSZ{1'b0}};  /// TOS
        t_x     = 1'b0;
        r_n     = {DSZ{1'b0}};  /// return stack
        rs_op   = sNOP;
    endtask: INIT

    always_comb begin
        INIT();
        case (code)
        // return stack => TOS
        iload:     PUSH(rs[rp - data]);    // CC: not tested
        iload_0:   PUSH(rs[rp]);           // CC: not tested
        iload_1:   PUSH(rs[rp - 1]);       // CC: not tested
        iload_2:   PUSH(rs[rp - 2]);       // CC: not tested
        iload_3:   PUSH(rs[rp - 3]);       // CC: not tested
        istore_0:  begin r_n = t; `R(sMOVE); end  // local var, CC: not tested
        //
        // conditional branching ops
        //
        ifeq:      BRAN(t_z);
        ifne:      BRAN(!t_z);
        iflt:      BRAN(t_neg);
        ifge:      BRAN(!t_neg);
        ifgt:      BRAN(!t_z && !t_neg);
        ifle:      BRAN(t_z || t_neg);
        if_icmpeq: BRAN(t_z);
        if_icmpne: BRAN(!t_z);
        if_icmplt: BRAN(t_neg);
        if_icmpgt: BRAN(!t_z && !t_neg);
        //
        // unconditional branching ops
        //
        goto:
            case (phase)
            0: SETA(`X8A(data)); // set addr higher byte
            1: JMP(a_d);         // merge addr lower byte
            endcase
        jsr:     if (phase==2) begin JMP(`XDA(t_d)); PUSH(`XAD(p) + 2); end
        ret:     JMP(`XDA(r));
        jreturn: if (phase==0) begin `R(sPOP); JMP(`XDA(r)); end
        invokevirtual:
            case (phase)
            0: begin SETA(`X8A(data)); RPUSH(`XAD(p) + 2); end
            1: begin JMP(a_d); end
            endcase
        // eForth VM specific ops
        donext:
            case (phase)
            0: SETA(`X8A(data));
            1: if (r == 0) `R(sPOP);
               else begin
                  r_n = r - 1; `R(sMOVE);
                  JMP(a_d);
               end
            endcase
        dupr:  PUSH(r);
        popr:  begin PUSH(r); `R(sPOP); end
        pushr: RPUSH(t);
        endcase
    end

    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            a    <= {ASZ{1'b0}};     /// init address
            asel <= 1'b0;            /// cold start by decoder
            rp   <= '0;
        end
        else if (ctl.clk && br_en) begin
            asel <= asel_n;
            if (t_x) ctl.t <= t_n;
            if (a_x) a     <= a_n;

            // return stack
            case (rs_op)
            sMOVE: rs[rp] <= r_n;
            sPOP:  rp     <= rp - 1;
            sPUSH: begin rs[rp1] <= r_n; rp <= rp + 1; end
            endcase
        end
    end
endmodule: EJ32_BR

///
/// eJ32 top module - Decoder Unit
///
`include "../source/eJ32_if.sv"
`define PHASE0 phase_n = 0
`define AU1 au_en = 1'b1
`define BR1 br_en = 1'b1
`define LS1 ls_en = 1'b1

import ej32_pkg::*;

module EJ32_DC #(
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    ) (
       EJ32_CTL ctl,
       input  `IU p,            // program counter
       input  `U1 div_bsy,
       output `U1 au_en,
       output `U1 br_en,
       output `U1 ls_en,
       output `IU p_o
    );
    opcode_t code_n;
    `U3  phase_n;
    `U1  code_x;
    `U1  p_x;
    ///
    /// wire
    ///
    opcode_t code;
    `U3  phase;

    task STEP(input `U3 n); phase_n = n; `CLR(code_x); endtask;
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);        endtask;
    task BRAN();
        `BR1;
        case (phase)
        0: STEP(1);
        1: STEP(2);
        2: `PHASE0;
        endcase
    endtask: BRAN
    task WAIT1();
        case (phase)
        0: WAIT(1);
        1: `PHASE0;
        endcase
    endtask: WAIT1
    task WAIT2();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        2: `PHASE0;
        endcase
    endtask: WAIT2
    task WAIT3();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        2: WAIT(3);
        3: `PHASE0;
        endcase
    endtask: WAIT3
    task WAIT5();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        2: WAIT(3);
        3: WAIT(4);
        4: WAIT(5);
        5: `PHASE0;
        endcase
    endtask: WAIT5
    task DIV();
        `AU1;
        case (phase)
        0: WAIT(1);
        1: if (div_bsy) WAIT(1);
        else `PHASE0;
        endcase
    endtask: DIV

    assign code  = ctl.code;
    assign phase = ctl.phase;

    always_comb begin           ///> decoder unit
        au_en = 1'b0;
        br_en = 1'b0;
        ls_en = 1'b0;

        case (code)
        // AU unit
        nop        : `AU1;
        aconst_null: `AU1;
        iconst_m1  : `AU1;
        iconst_0   : `AU1;
        iconst_1   : `AU1;
        iconst_2   : `AU1;
        iconst_3   : `AU1;
        iconst_4   : `AU1;
        iconst_5   : `AU1;
        bipush: begin `AU1;
           case (phase)
           0: STEP(1);
           1: `PHASE0;
           endcase
        end
        sipush: begin `AU1;
            case (phase)
            0: STEP(1);
            1: STEP(2);
            2: `PHASE0;
            endcase // case (phase)
        end
        pop:          `AU1;
        pop2:   begin `AU1; WAIT1(); end
        dup:          `AU1;
        dup_x1: begin `AU1; WAIT2(); end
        dup_x2:`AU1;
        dup2:   begin `AU1; WAIT3(); end
        swap: `AU1;
        iadd: `AU1;
        isub: `AU1;
        imul: `AU1;
        idiv: DIV();
        irem: DIV();
        ineg: `AU1;
        ishl: `AU1;
        ishr: `AU1;
        iushr:`AU1;
        iand: `AU1;
        ior:  `AU1;
        ixor: `AU1;
        // BR unit
        iinc: begin `BR1; `AU1; WAIT2(); end
        iload:     `BR1;
        iload_0:   `BR1;
        iload_1:   `BR1;
        iload_2:   `BR1;
        iload_3:   `BR1;
        istore_0:  `BR1;
        ifeq:      BRAN();
        ifne:      BRAN();
        iflt:      BRAN();
        ifge:      BRAN();
        ifgt:      BRAN();
        ifle:      BRAN();
        if_icmpeq: BRAN();
        if_icmpne: BRAN();
        if_icmplt: BRAN();
        if_icmpgt: BRAN();
        goto:      BRAN();
        jsr: begin `BR1; WAIT2(); end
        ret: `BR1;
        jreturn: begin
            `BR1;
            case (phase)
            0: STEP(1);
            1: `PHASE0;
            endcase // case (phase)
        end
        invokevirtual: BRAN();
        donext:        BRAN();
        dupr: `BR1;
        popr: `BR1;
        pushr:`BR1;
        // LS unit
        iaload:  begin `LS1; WAIT5(); end
        baload:  begin `LS1; WAIT2(); end
        saload:  begin `LS1; WAIT3(); end
        iastore: begin `LS1; WAIT5(); end
        bastore: begin `LS1; WAIT2(); end
        sastore: begin `LS1; WAIT3(); end
        ldi: begin
            `LS1;
            case (phase)
            0: STEP(1);
            1: STEP(2);
            2: STEP(3);
            3: STEP(4);
            4: `PHASE0;
            endcase // case (phase)
        end
        get: begin `LS1; WAIT2(); end
        put: begin `LS1; WAIT1(); end
        default: `PHASE0;
        endcase
    end // always_comb

    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (!ctl.rst && ctl.clk) begin
            ctl.phase <= phase_n;
            if (code_x)  ctl.code <= code_n;
        end
    end // always_ff @ (posedge clk, posedge rst)
endmodule: EJ32_DC

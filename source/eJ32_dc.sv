///
/// eJ32 top module - Decoder Unit
///
`include "../source/eJ32_if.sv"
`define AU1  au_en=1'b1
`define BR1  br_en=1'b1
`define LS1  ls_en=1'b1
`define AB1  begin `AU1; `BR1; end
`define AL1  begin `AU1; `LS1; end
`define BL1  begin `BR1; `LS1; end
`define ABL1 begin `AU1; `BR1; `LS1; end

import ej32_pkg::*;

module EJ32_DC #(
       parameter COLD = 'h0     // cold start address
    ) (
       EJ32_CTL ctl,
       input  `U8 data,         // byte return from memory bus
       input  `U1 div_bsy,
       output `U1 au_en,
       output `U1 br_en,
       output `U1 ls_en,
       output `U1 p_inc
    );
    ///
    /// register next
    ///
    opcode_t code_n;
    `U3  phase_n;
    ///
    /// wire
    ///
    `U3  phase;
    `U1  code_x, code_x2;  // opcode pipeline delays
    `U1  p_x;
    ///
    /// generic multi-cycle macros
    ///
    task STEP(input `U3 n); phase_n = n; `CLR(code_x); endtask
    task WAIT(input `U3 n); STEP(n); `CLR(p_x);        endtask
    task WAIT1(); if (phase==0) WAIT(1); endtask
    task WAIT2();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        endcase
    endtask: WAIT2
    task WAIT3();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        2: WAIT(3);
        endcase
    endtask: WAIT3
    task WAIT5();
        case (phase)
        0: WAIT(1);
        1: WAIT(2);
        2: WAIT(3);
        3: WAIT(4);
        4: WAIT(5);
        endcase
    endtask: WAIT5
    task STEP2();
        case (phase)
        0: STEP(1);
        1: STEP(2);
        endcase
    endtask: STEP2
    task STEP4();
        case (phase)
        0: STEP(1);
        1: STEP(2);
        2: STEP(3);
        3: STEP(4);
        endcase
    endtask: STEP4
    ///
    /// module specific tasks
    ///
    task BRAN(); `AB1; STEP2(); endtask  // branching ops
    task DIV();                          // divider ops
        `AU1;
        case (phase)
        0: WAIT(1);
        1: if (div_bsy) WAIT(1);
        endcase
    endtask: DIV
    ///
    /// decoder unit
    ///
    task INIT();
        au_en   = 1'b0;
        br_en   = 1'b0;
        ls_en   = 1'b0;
        code_x  = 1'b1;         ///> update opcode by default
        phase_n = 3'b0;
        p_x     = 1'b1;         ///> advance program counter by default
    endtask: INIT
    ///
    /// decoder state machine (table lookup)
    ///
    always_comb begin
        INIT();
        case (ctl.code)
        // AU unit => TOS
        aconst_null:  `AU1;
        iconst_m1:    `AU1;
        iconst_0:     `AU1;
        iconst_1:     `AU1;
        iconst_2:     `AU1;
        iconst_3:     `AU1;
        iconst_4:     `AU1;
        iconst_5:     `AU1;
        bipush: begin `AU1; if (phase==1) STEP(1); end
        sipush: begin `AU1; STEP2(); end
        // return stack => data stack
        iload:        `AB1
        iload_0:      `AB1
        iload_1:      `AB1
        iload_2:      `AB1
        iload_3:      `AB1
        istore_0:     `AB1
        // LS unit (multi-cycle, waiting for TOS)
        iaload:  begin `LS1; WAIT5(); end
        baload:  begin `LS1; WAIT2(); end
        saload:  begin `LS1; WAIT3(); end
        iastore: begin `AL1; WAIT5(); end
        bastore: begin `AL1; WAIT2(); end
        sastore: begin `AL1; WAIT3(); end
        // AU stack ops
        pop:     `AU1;
        pop2:    begin `AU1; WAIT1(); end
        dup:     `AU1;
        dup_x1:  begin `AU1; WAIT2(); end
        dup_x2:  `AU1;
        dup2:    begin `AU1; WAIT3(); end
        swap:    `AU1;
        // AU arithmetics
        iadd:    `AU1;
        isub:    `AU1;
        imul:    `AU1;
        idiv:    DIV();
        irem:    DIV();
        ineg:    `AU1;
        ishl:    `AU1;
        ishr:    `AU1;
        iushr:   `AU1;
        iand:    `AU1;
        ior:     `AU1;
        ixor:    `AU1;
        iinc:    begin `ABL1; WAIT2(); end
        // BR conditional branching
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
        // BR unconditional branching
        goto:      BRAN();
        jsr:       begin `ABL1; WAIT2(); end
        ret:       `BR1;
        jreturn:   begin `BR1; if (phase==0) STEP(1); end
        invokevirtual: BRAN();
        // eForth VM specific
        donext:        BRAN();
        dupr:    `AB1
        popr:    `AB1
        pushr:   `AB1
        ldi: begin `AL1; STEP4(); end
        get: begin `AL1; WAIT2(); end
        put: begin `AL1; WAIT1(); end
        endcase
    end
    ///
    /// instruction unit
    ///
    always_comb begin
        // fetch instruction
        if (!$cast(code_n, data)) begin
            /// JVM opcodes, some are not avialable yet
            code_n = op_err;
        end
    end

    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        ctl.phase <= phase;
        if (code_x2) ctl.code <= code_n;
        if (ctl.rst) begin
            phase    <= 3'b0;
            code_x2  <= 1'b1;
            p_inc    <= 1'b0;
        end
        else if (ctl.clk) begin
            phase    <= phase_n;
            code_x2  <= code_x;
            p_inc    <= p_x;
        end
    end
endmodule: EJ32_DC

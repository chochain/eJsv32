///
/// eJ32 top module - Decoder Unit
///
`include "../source/eJ32_if.sv"
`define AU1  au_en=1'b1
`define BR1  br_en=1'b1
`define LS1  ls_en=1'b1
`define DP1  dp_en=1'b1
`define AD1  {au_en,dp_en}=2'b11
`define AB1  {au_en,br_en}=2'b11
`define AL1  {au_en,ls_en}=2'b11
`define BL1  {br_en,ls_en}=2'b11
`define ABL1 {au_en,br_en,ls_en}=3'b111

import ej32_pkg::*;

module EJ32_DC (
       EJ32_CTL ctl,
       input  `U1 dc_en,        // decoder unit enable
       input  `U8 ram_d,        // byte return from memory bus
       input  `U1 div_bsy,      // AU divider busy
       output `U1 au_en,        // enable AU
       output `U1 br_en,        // enable BR
       output `U1 ls_en,        // enable LS
       output `U1 dp_en,        // enable DIV
       output `U1 p_inc         // advance program counter
    );
    ///
    /// register next
    ///
    opcode_t code_n;
    `U3  phase_n;
    ///
    /// wire
    ///
    opcode_t code;              // wired to ctl.code
    `U3  phase;                 // wired to ctl.phase
    `U1  code_x;                // code <= code_n
    `U1  p_x;                   // wired to p_inc
    ///
    /// code/phase updaet control
    ///
    task NXPH(input `U3 n); phase_n = n; `CLR(code_x); endtask
    task HOLD(input `U3 n); NXPH(n); `CLR(p_x);        endtask
    ///
    /// generic multi-cycle macros
    ///
    task STEP1(); if (phase==0) NXPH(1); endtask
    task STEP2();
        case (phase)
        0: NXPH(1);
        1: NXPH(2);
        endcase
    endtask: STEP2
    task STEP4();
        case (phase)
        0: NXPH(1);
        1: NXPH(2);
        2: NXPH(3);
        3: NXPH(4);
        endcase
    endtask: STEP4
    task WAIT1(); if (phase==0) HOLD(1); endtask
    task WAIT2();
        case (phase)
        0: HOLD(1);
        1: HOLD(2);
        endcase
    endtask: WAIT2
    task WAIT3();
        case (phase)
        0: HOLD(1);
        1: HOLD(2);
        2: HOLD(3);
        endcase
    endtask: WAIT3
    task WAIT5();
        case (phase)
        0: HOLD(1);
        1: HOLD(2);
        2: HOLD(3);
        3: HOLD(4);
        4: HOLD(5);
        endcase
    endtask: WAIT5
    ///
    /// module specific tasks
    ///
    task BRAN(); `AB1; STEP2(); endtask  // branching ops
    task DIV();
        `AD1;
        case (phase)
        0: if (div_bsy) HOLD(1);
           else begin              // CC: this branch works OK
               assert(phase_n==0 && div_bsy==1'b0 && code_x==1'b1 && p_x==1'b1) else begin
                   $display("DIV.0.ERR phase_n=%d->0, div_bsy=%x->0, code_x=%x->1, p_x=%x->1",
                            phase_n, div_bsy, code_x, p_x);
               end
           end
        1: if (div_bsy) HOLD(1);
           else begin              // CC: but don't know why this branch skipped? see patch below
               $display("DIV.1 div_bsy=%x", div_bsy);
               HOLD(2);
           end
        default: assert(phase==2); // CC: double check here
        endcase
    endtask: DIV
    ///
    /// decoder unit
    ///
    task INIT();
        {au_en, br_en, ls_en, dp_en} = 4'b0000;
        code_x  = 1'b1;         ///> update opcode by default
        phase_n = 3'b0;
        p_x     = 1'b1;         ///> advance program counter by default
    endtask: INIT
    ///
    /// decoder state machine (table lookup)
    ///
    always_comb begin
        INIT();
        case (code)
        // AU unit => TOS
        aconst_null:  `AU1;
        iconst_m1:    `AU1;
        iconst_0:     `AU1;
        iconst_1:     `AU1;
        iconst_2:     `AU1;
        iconst_3:     `AU1;
        iconst_4:     `AU1;
        iconst_5:     `AU1;
        bipush:  begin `AU1; if (phase==0) NXPH(1); end // CC: why STEP1() does not work here?
        sipush:  begin `AU1; STEP2(); end
        // return stack => data stack
        iload:        `AB1;
        iload_0:      `AB1;
        iload_1:      `AB1;
        iload_2:      `AB1;
        iload_3:      `AB1;
        istore_0:     `AB1;
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
        imul:    `AD1;
        idiv:    DIV();
        irem:    DIV();
        ineg:    `AU1;
        ishl:    `AD1;
        ishr:    `AD1;
        iushr:   `AD1;
        iand:    `AU1;
        ior:     `AU1;
        ixor:    `AU1;
        iinc:    begin `AL1; WAIT2(); end
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
        jreturn:   begin `BR1;  STEP1(); end
        invokevirtual: BRAN();
        // eForth VM specific
        donext:        BRAN();
        dupr:    `AB1;
        popr:    `AB1;
        pushr:   `AB1;
        ldi:     begin `AL1; STEP4(); end
        get:     begin `AL1; WAIT2(); end
        put:     begin `AL1; WAIT1(); end
        endcase
    end
    ///
    /// wire to control bus and output port
    ///
    assign ctl.phase = phase;
    assign ctl.code  = code;
    assign p_inc     = p_x;
    ///
    /// instruction unit
    ///
    always_comb begin
        // fetch instruction
        if (!$cast(code_n, ram_d)) begin
            /// JVM opcodes, some are not avialable yet
            code_n = op_err;
        end
    end

    always_ff @(posedge ctl.clk) begin
        if (ctl.rst) begin
            phase <= 3'b0;
        end
        else begin
            if ((code==idiv||code==irem) && !div_bsy) div_patch();  // CC: why?
            else begin
                if (code_x) code <= code_n;
                phase <= phase_n;
            end
        end
    end
    ///
    /// CC: do not know why DIV is skipping the branch
    ///
    task div_patch();
       if (phase==1 && phase_n!=2) begin
          $display("DIV_FIX.1 phase_n=%d->2, div_bsy=%x->0, code_x=%x->0, p_x=%x->0",
                   phase_n, div_bsy, code_x, p_x);
          phase <= 2;
       end
       else begin
          /// no patch
          if (code_x) code <= code_n;
          phase <= phase_n;
       end
    endtask: div_patch
endmodule: EJ32_DC

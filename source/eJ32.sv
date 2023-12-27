///
/// eJ32 top module (Outer Interpreter)
///
`include "../source/eJ32_if.sv"

import ej32_pkg::*;

module EJ32 #(
    parameter TIB  = 'h1000,    // input buffer ptr
    parameter OBUF = 'h1400     // output buffer ptr
    );
    // ej32 memory bus
    `IU  addr;
    `IU  ls_addr_o;             ///> shared memory address
    `U1  ls_asel_o;
    `IU  br_addr_o;
    `U8  data;                  ///> data return from SRAM (sent to core)
    `IU  p, p_o;
    `DU  s;
    `U8  data_o;                ///> data return from core
    `U1  dwe_o;                 ///> data write enable driven by core
    `U1  au_en, br_en, ls_en;

    mb8_io      b8_if();        ///> memory bus
    EJ32_CTL    ctl();          ///> ej32 control bus
   
    spram8_128k smem(b8_if.slave, ~ctl.clk);
    EJ32_AU                au(.ctl(ctl), .*);
    EJ32_LS   #(TIB, OBUF) ls(.ctl(ctl), .*); 
    EJ32_BR                br(.ctl(ctl), .*);

    assign data = b8_if.vo;     ///> data fetched from SRAM (1-cycle)

    always_comb begin           ///> decoder unit
        au_en = 1'b0;
        br_en = 1'b0;
        ls_en = 1'b0;
        
        case (ctl.code)
        // AU unit
        nop        : `SET(au_en);
        aconst_null: `SET(au_en);
        iconst_m1  : `SET(au_en);
        iconst_0   : `SET(au_en);
        iconst_1   : `SET(au_en);
        iconst_2   : `SET(au_en);
        iconst_3   : `SET(au_en);
        iconst_4   : `SET(au_en);
        iconst_5   : `SET(au_en);
        bipush:      `SET(au_en);
        sipush:      `SET(au_en);
        pop:         `SET(au_en);
        pop2:        `SET(au_en);
        dup:         `SET(au_en);
        dup_x1:      `SET(au_en);
        dup_x2:      `SET(au_en);
        dup2:        `SET(au_en);
        swap:        `SET(au_en);
        iadd:        `SET(au_en);
        isub:        `SET(au_en);
        imul:        `SET(au_en);
        idiv:        `SET(au_en);
        irem:        `SET(au_en);
        ineg:        `SET(au_en);
        ishl:        `SET(au_en);
        ishr:        `SET(au_en);
        iushr:       `SET(au_en);
        iand:        `SET(au_en);
        ior:         `SET(au_en);
        ixor:        `SET(au_en);
        // BR unit
        iinc:        begin `SET(br_en); `SET(au_en); end
        iload:       `SET(br_en);
        iload_0:     `SET(br_en);
        iload_1:     `SET(br_en);
        iload_2:     `SET(br_en);
        iload_3:     `SET(br_en);
        istore_0:    `SET(br_en);
        ifeq:        `SET(br_en);
        ifne:        `SET(br_en);
        iflt:        `SET(br_en);
        ifge:        `SET(br_en);
        ifgt:        `SET(br_en);
        ifle:        `SET(br_en);
        if_icmpeq:   `SET(br_en);
        if_icmpne:   `SET(br_en);
        if_icmplt:   `SET(br_en);
        if_icmpgt:   `SET(br_en);
        goto:        `SET(br_en);
        jsr:         `SET(br_en);
        ret:         `SET(br_en);
        jreturn:     `SET(br_en);
        invokevirtual: `SET(br_en);
        donext:      `SET(br_en);
        dupr:        `SET(br_en);
        popr:        `SET(br_en);
        pushr:       `SET(br_en);
        // LS unit
        iaload:      `SET(ls_en);
        baload:      `SET(ls_en);
        saload:      `SET(ls_en);
        iastore:     `SET(ls_en);
        bastore:     `SET(ls_en);
        sastore:     `SET(ls_en); 
        ldi:         `SET(ls_en);
        get:         `SET(ls_en); 
        put:         `SET(ls_en);
        endcase 
    end // always_comb
   
    always_comb begin
        if (dwe_o) b8_if.put_u8(addr, data_o);  ///> write to SRAM
        else       b8_if.get_u8(addr);          ///> read from SRAM
    end
    ///
    /// debugging
    ///
    localparam DOT = 'h2e;      ///> '.'
    task fetch(input `IU ax, input `U2 opt);
        repeat(1) @(posedge ctl.clk) begin
            case (opt)
            'h1: $write("%02x", b8_if.vo);
            'h2: $write("%c", b8_if.vo < 'h20 ? DOT : b8_if.vo);
            endcase
            b8_if.get_u8(ax);
        end
    endtask: fetch
endmodule: EJ32

`ifndef EJ32_EJ32_VH
`define EJ32_EJ32_VH

typedef enum logic [7:0] {
        nop     = 'h0,
        aconst_null, iconst_m1,
        iconst_0, iconst_1, iconst_2, iconst_3, iconst_4, iconst_5,
        
        bipush  = 'h10, sipush,
        iload   = 'h15,
        iload_0 = 'h1a,
        iload_1, iload_2, iload_3,
        //
        // stack opcodes
        //
        iaload  = 'h2e,
        baload  = 'h33,
        saload  = 'h35,
        istore_0= 'h36,
        iastore = 'h4f,
        bastore = 'h54,
        sastore = 'h56,
        pop     = 'h57,
        pop2, dup, dup_x1, dup_x2, dup2, dup2_x1, dup2_x2, swap,
        //
        // alu opcodes
        //
        iadd    = 'h60,
        isub    = 'h64,
        imul    = 'h68,
        idivv   = 'h6c,
        irem    = 'h70,
        ineg    = 'h74,
        ishl    = 'h78,
        ishr    = 'h7a,
        iushr   = 'h7c,
        iand    = 'h7e,
        ior     = 'h80,
        ixor    = 'h82,
        iinc    = 'h84,
        //
        // comparision opcodes
        //
        ifeq    = 'h99,
        ifne, iflt, ifge, ifgt, ifle,
        if_icmpeq, if_icmpne, if_icmplt, if_icmpgt,
        //
        // jump opcodes
        //
        goto    = 'ha7,
        jsr, ret,
        //
        // FVM extension opcodes
        //
        jreturn       = 'hb1,
        invokevirtual = 'hb6,
        donext        = 'hca,
        ldi, popr, pushr, dupr, get, put
} jvm_opcode;
`endif // EJ32_EJ32_VH

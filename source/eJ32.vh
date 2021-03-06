`ifndef EJ32_EJ32_VH
`define EJ32_EJ32_VH

typedef enum logic [7:0] {
        //
        // constants
        //
        nop     = 'h0,
        aconst_null, iconst_m1,
        iconst_0, iconst_1, iconst_2, iconst_3, iconst_4, iconst_5,
        lconst_0, lconst_1,
        fconst_0, fconst_1, fconst_2,
        dconst_0, dconst_1,
        bipush  = 'h10,    sipush,
        ldc, ldc_w, ldc2_w,
        //
        // load
        //
        iload   = 'h15,    lload, fload, dload, aload,
        iload_0 = 'h1a, iload_1, iload_2, iload_3,
        lload_0, lload_1, lload_2, lload_3,
        fload_0, fload_1, fload_2, fload_3,
        dload_0, dload_1, dload_2, dload_3,
        aload_0, aload_1, aload_2, aload_3,
        //
        // auto load
        //
        iaload  = 'h2e,    laload, faload, daload, aaload,
        baload  = 'h33,    caload, saload,
        //
        // store
        //
        istore  = 'h36,    lstore, fstore, dstore, astore,
        istore_0, istore_1, istore_2, istore_3,
        lstore_0, lstore_1, lstore_2, lstore_3,
        fstore_0, fstore_1, fstore_2, fstore_3,
        dstore_0, dstore_1, dstore_2, dstore_3,
        astore_0, astore_1, astore_2, astore_3,
        iastore = 'h4f,    lastore, fastore, dastore, aastore,
        bastore = 'h54,    castore, sastore,
        //
        // stack
        //
        pop     = 'h57, pop2,
        dup, dup_x1, dup_x2, dup2, dup2_x1, dup2_x2,
        swap,
        //
        // alu math
        //
        iadd    = 'h60,    ladd, fadd, dadd,
        isub    = 'h64,    lsub, fsub, dsub,
        imul    = 'h68,    lmul, fmul, dmul,
        idiv    = 'h6c,    ldiv, fdiv, ddiv,
        irem    = 'h70, lrem, frem, drem,
        ineg    = 'h74, lneg, fneg, dneg,
        ishl    = 'h78, lshl,
        ishr    = 'h7a, lshr,
        iushr   = 'h7c, lushr,
        iand    = 'h7e, land,
        ior     = 'h80, lor,
        ixor    = 'h82, lxor,
        iinc    = 'h84,
        //
        // conversion
        //
        i2l     = 'h85, i2f, i2d,
        l2i, l2f, l2d,
        f2i, f2l, f2d,
        d2i, d2l, d2f,
        i2b, i2c, i2s,
        //
        // comparision
        //
        lcmp    = 'h94,    fcmpl, fcmpg, dcmpl, dcmpg,
        ifeq    = 'h99, ifne, iflt, ifge, ifgt, ifle,
        if_icmpeq, if_icmpne, if_icmplt, if_icmpge, if_icmpgt,
        if_acmpeq, if_acmpne,
        //
        // control
        //
        goto    = 'ha7, jsr, ret,
        tableswitch, lookupswitch,
        ireturn, lreturn, freturn, dreturn, areturn,
        jreturn = 'hb1,       // CC: 'return' is a reserved word
        //
        // references
        //
        getstatic     = 'hb2, putstatic, getfield, putfield,
        invokevirtual = 'hb6, invokespecial, invokestatic, invokeinterface, invokedynamic,
        jnew          = 'hbb, // CC: 'new' is a reserved word
        newarray, anewarray, arraylength, athrow,
        checkcast     = 'hc0, instanceof, monitorenter, monitorexit,
        //
        // extended
        //
        wide    = 'hc4,
        multianewarray, ifnull, ifnotnull, goto_w, jsr_w,
        //
        // reserved (overlapped with FVM extended)
        // breakpoint = 'hca,
        // impdep1    = 'hfe,
        // impdep2    = 'hff,
        //
        // FVM extended
        //
        donext        = 'hca,  // CC: reserved for breakpoint
        ldi, popr, pushr, dupr, ext, get, put,
        //
        // Error handler
        //
        op_err = 'hff
} jvm_opcode;
`endif // EJ32_EJ32_VH

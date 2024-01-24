`ifndef EJ32_EJ32_VH
`define EJ32_EJ32_VH
package ej32_pkg;
//
// Note: https://www.infoworld.com/article/2077625/control-flow.html
//
// Universal data type
//
`define DSZ 32                     /* data width          */
`define ASZ 17                     /* address width       */
`define SSZ 6                      /* stack depth         */
   
`define U1 logic                   /* 1-bit flag          */
`define U2 logic[1:0]              /* stack opcode        */
`define U3 logic[2:0]              /* phase               */
`define U8 logic[7:0]              /* 8-bit data (memory) */
`define IU logic[`ASZ-1:0]         /* instruction address */
`define SU logic[`SSZ-1:0]         /* stack pointers      */
`define DU logic[`DSZ-1:0]         /* data unit           */
`define DU2 logic[(`DSZ*2)-1:0]    /* double data (mul)   */
//
// data conversion macros
//
`define SET(v) v=1'b1
`define CLR(v) v=1'b0
`define X8A(b) { {`ASZ-'h8{1'b0}},  b }
`define X8D(b) { {`DSZ-'h8{1'b0}},  b }
`define XAD(a) { {`DSZ-`ASZ{1'b0}}, a }
`define XDA(d) d[`ASZ-1:0]

typedef enum `U8 {  ///> JVM opcodes
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
        // comparison
        //                      
        lcmp    = 'h94,    fcmpl, fcmpg, dcmpl, dcmpg,
        //
        // conditional branching
        //
        ifeq    = 'h99, ifne, iflt, ifge, ifgt, ifle,
        if_icmpeq, if_icmpne, if_icmplt, if_icmpge, if_icmpgt,
        if_acmpeq, if_acmpne,
        //
        // unconditional branching
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
        multianewarray,
        // conditional branching (with null)
        //
        ifnull, ifnotnull, goto_w, jsr_w,
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
} opcode_t /*verilator public*/;

typedef enum `U2 { tEQ  = 2'b0, tGT   = 2'b01, tGE  = 2'b10, tLT  = 2'b11 } tos_sign /*verilator public*/;
typedef enum `U2 { sNOP = 2'b0, sPUSH = 2'b01, sMOVE= 2'b10, sPOP = 2'b11 } stack_op /*verilator public*/;

/* opcode cycles per Dr. Ting's 520K-cycle test cases
  count opcode        c  en
  ----- ------------- -  --
  68623 ifeq          4  AB
  64944 saload        4  L
  48800 dup2          4  A
  43092 iaload        6  L
  36954 iastore       6  AL
  36330 goto          4  AB
  30978 invokevirtual 4  AB 
  30218 bipush        2  A
  26875 ldi           5  AL
  24557 dup           1  A
  20716 jreturn       2  B
  12300 pop           1  A
  11450 iand          1  A
   9306 swap          1  A
   7000 irem          35 A
   7000 idiv          35 A
   5685 isub          1  A
   5660 ixor          1  A
   5632 iconst_2      1  A
   4260 baload        3  L
   3945 donext        4  AB
   2877 iadd          1  A
   2758 put           2  AL
   1539 bastore       3  AL
   1320 iconst_1      1  A
   1158 pushr         1  AB
    936 if_icmpgt     4  AB
    840 iflt          4  AB
    819 get           3  AL
    778 popr          1  AB
    684 if_icmplt     4  AB
    661 iconst_m1     1  A
    490 iconst_0      1  A
    286 pop2          2  A
    258 dupr          1  AB
    132 sastore       4  AL
     64 iconst_3      1  A
     48 if_icmpeq     4  AB
     22 imul          1  A
      2 iconst_4      1  A
      1 nop           1
      1 ishr          1  A
      1 ior           1  A
*/   

endpackage: ej32_pkg
`endif // EJ32_EJ32_VH

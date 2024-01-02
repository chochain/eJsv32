//
// eJ32 - Java Forth Machine - Load/Store Unit
//
`include "../source/eJ32_if.sv"

module EJ32_LS #(
    parameter TIB  = 'h1000,    ///> input buffer address
    parameter OBUF = 'h1400,    ///> output buffer address
    parameter DSZ  = 32,        ///> 32-bit data width
    parameter ASZ  = 17         ///> 128K address space
    ) (
    EJ32_CTL ctl,               ///> ej32 control bus
    mb8_io   b8_if,             ///> 8-bit memory bus
    input    `U1 ls_en,
    input    `IU p,
    input    `DU s              ///> NOS
    );
    import ej32_pkg::*;
    /// @defgroup Registers
    /// @{
    // instruction
    `IU  a;                     ///> memory address
    `U1  asel;                  ///> memory address select
    `U2  dsel;                  ///> 32-bit, 4-to-1 mux, byte select
    `IU  ibuf, obuf;            ///> input, output buffer pointers
    /// @}
    /// @defgroup Next Register
    /// @{
    `DU t_n;                    ///> TOS
    `IU a_n;                    ///> data address
    `U1 asel_n;                 ///> address select
    `U2 dsel_n;                 ///> 32-bit, 4-to-1 mux, byte select
    /// @}
    /// @defgroup Wires
    /// @{
    // instruction
    opcode_t code;              ///> shadow ctl.code
    `U3 phase;                  ///> FSM phase (aka state)
    `U1 a_x;                    ///> address controls
    `IU a_d;                    ///> 2-byte merged address
    // data stack
    `DU t;                      ///> shadow TOS
    `U1 t_x;
    `DU t_d;                    ///> 4-byte merged data
    // memory & IO buffers
    `IU addr;                   ///> b8_if.ai driver
    `U8 data;                   ///> b8_if.vo shadow
    `U1 dwe, dsel_x;            ///> data/addr bus controls
    `U1 ibuf_x, obuf_x;         ///> input/output buffer controls
    /// @}

    task TOS(input `DU d);  t_n = d; `SET(t_x);   endtask;   ///> update TOS
    task SETA(input `IU i); a_n = i; `SET(a_x);   endtask;   ///> build addr ptr
    task MEM(input `IU i); SETA(i); `SET(asel_n); endtask;   ///> fetch from memory, data returns next cycle
    task DW(input `U3 n); dsel_n = n; `SET(dwe); `SET(dsel_x); endtask;   ///> data write n-th byte
    ///
    /// wires to reduce verbosity
    ///
    assign code   = ctl.code;                 ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;
    assign addr   = asel ? a : p;             ///> b8_if memory access address
    assign data   = b8_if.vo;                 ///> shadow data on memory bus
    ///
    /// address, data shifter
    ///
    assign a_d    = {a[ASZ-9:0], data};       ///> merge lowest byte into addr
    assign t_d    = {t[DSZ-9:0], data};       ///> merge lowest byte into TOS
    ///
    /// memory bus interface
    ///
    always_comb begin
        if (dwe) begin
            automatic `U8 d8x4[4] =              ///> 4-to-1 Big-Endian
                {t[31:24],t[23:16],t[15:8],t[7:0]};
            automatic `U8 v = d8x4[dsel];        ///> data byte select (Big-Endian)
            b8_if.put_u8(addr, v);               ///> write to SRAM
        end
        else b8_if.get_u8(addr);                 ///> read from SRAM
    end
    ///
    /// combinational
    ///
    task INIT();
        t_n       = {DSZ{1'b0}};  /// TOS
        t_x       = 1'b0;
        a_n       = {ASZ{1'b0}};  /// default to clear address
        a_x       = 1'b0;
        asel_n    = 1'b0;         /// address default to program counter
        dsel_x    = 1'b0;         /// data bus
        dsel_n    = 3;
        dwe       = 1'b0;         /// data write
        ibuf_x    = 1'b0;
        obuf_x    = 1'b0;
    endtask: INIT

    always_comb begin
        INIT();
        case (code)
        iaload:
            case (phase)
            0: MEM(`XDA(t));
            1: begin MEM(a + 1); TOS(`X8D(data)); end
            2: begin MEM(a + 1); TOS(t_d); end
            3: begin MEM(a + 1); TOS(t_d); end
            4: TOS(t_d);
            endcase
        baload:
            case (phase)
            0: MEM(`XDA(t));
            1: TOS(`X8D(data));
            endcase
        saload:
            case (phase)
            0: MEM(`XDA(t));
            1: begin MEM(a + 1); TOS(`X8D(data)); end
            2: TOS(t_d);
            endcase
        iastore:
            case (phase)
            0: begin MEM(`XDA(s)); `SET(dsel_x); dsel_n = 0; end
            1: begin MEM(a + 1); DW(1); end
            2: begin MEM(a + 1); DW(2); end
            3: begin MEM(a + 1); DW(3); end
            4: DW(3);                          // CC: reset a?
            endcase
        bastore:
            case (phase)
            0: MEM(`XDA(s));
            1: DW(3);                          // CC: reset a?
            endcase
        sastore:
            case (phase)                       // CC: logic changed from Dr. Ting's
            0: begin MEM(`XDA(s)); `SET(dsel_x); dsel_n = 2; end
            1: begin MEM(a + 1); DW(3); end
            2: DW(3);
            endcase
        iinc:
            case (phase)                       // CC: logic changed from Dr. Ting's
            0: MEM(`XDA(s));
            1: `SET(asel_n);
            2: begin TOS(s); DW(0); end
            endcase
        jsr:
            case (phase)
            0: MEM(`XDA(t));
            1: begin MEM(a + 1); TOS(`X8D(data)); end
            endcase
        ldi: 
            case (phase)
            1: TOS(t_d);
            2: TOS(t_d);
            3: TOS(t_d);
            endcase
        get:
            case (phase)
            0: MEM(ibuf);
            1: begin TOS(`X8D(data)); `SET(ibuf_x); end
            endcase
        put:
            case (phase)
            0: begin MEM(obuf); `SET(dsel_x); end
            1: begin DW(3);     `SET(obuf_x); end
            endcase
        endcase
    end // always_comb

    always_ff @(posedge ctl.clk, posedge ctl.rst) begin
        if (ctl.rst) begin
            a     <= {ASZ{1'b0}}; ///> clear address
            asel  <= 1'b0;        ///> note: cold start by decoder
            dsel  <= 3;
            ibuf  <= TIB;
            obuf  <= OBUF;
        end
        else if (ctl.clk && ls_en) begin
            asel <= asel_n;
            if (t_x)     ctl.t    <= t_n;
            if (a_x)     a        <= a_n;
            if (dsel_x)  dsel     <= dsel_n;
            if (ibuf_x)  ibuf     <= ibuf + 1;
            if (obuf_x)  obuf     <= obuf + 1;
        end
    end
endmodule: EJ32_LS

//
// eJ32 - Java Forth Machine - Load/Store Unit
//
`include "../source/eJ32_if.sv"

module EJ32_LS #(
    parameter TIB  = 'h1000,    ///> input buffer address
    parameter OBUF = 'h1400     ///> output buffer address
    ) (
    EJ32_CTL ctl,               ///> ej32 control bus
    mb8_io   b8_if,             ///> 8-bit memory bus
    input    `U1 ls_en,
    input    `U1 rom_en,        ///> ROM copying stage
    input    `IU p,
    input    `DU s,             ///> NOS
    output   `DU ls_t_o,        ///> TOS uplink for arbitration
    output   `U1 ls_t_x
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
    `DU t;
    `U1 t_x;                    ///> TOS update flag
    `DU t_d;                    ///> 4-byte merged data
    // memory & IO buffers
    `IU addr;                   ///> b8_if.ai driver
    `U8 data;                   ///> b8_if.vo shadow
    `U1 dwe, dsel_x;            ///> data/addr bus controls
    `U1 ibuf_x, obuf_x;         ///> input/output buffer controls
    // conversion holder
    `IU t2a, s2a;               ///> TOS/NOS to address holder
    `DU d2t;                    ///> 8-bit to 32-bit holder
    `U8 d8x4[4];                ///> 4-to-1 mux (Big-Endian)
    /// @}

    task TOS(input `DU d);  t_n = d; `SET(t_x);   endtask   ///> update TOS
    task SETA(input `IU i); a_n = i; `SET(a_x);   endtask   ///> build addr ptr
    task MEM(input `IU i); SETA(i); `SET(asel_n); endtask   ///> fetch from memory, data returns next cycle
    task DW(input `U3 n); dsel_n = n; `SET(dwe); `SET(dsel_x); endtask   ///> data write n-th byte
    ///
    /// wires to reduce verbosity
    ///
    assign code   = ctl.code;                 ///> input from ej32 control
    assign phase  = ctl.phase;
    assign t      = ctl.t;
    assign t2a    = `XDA(t);                  ///> convert TOS to address
    assign s2a    = `XDA(s);                  ///> convert NOS to address
    assign d2t    = `X8D(data);               ///> convert 8-bit data to 32-bit
    assign addr   = asel ? a : p;             ///> b8_if memory access address
    assign data   = b8_if.vo;                 ///> shadow data on memory bus
    assign d8x4   = {t[31:24],t[23:16],t[15:8],t[7:0]};  ///> 4-to-1 mux (Big-Endian)
    ///
    /// address, data shifter
    ///
    assign a_d    = {a[`ASZ-9:0], data};       ///> merge lowest byte into addr
    assign t_d    = {t[`DSZ-9:0], data};       ///> merge lowest byte into TOS
    ///
    /// wired to outputs
    ///
    assign ls_t_o = t_n;
    assign ls_t_x = t_x;
    ///
    /// memory bus interface
    ///
    always_comb begin
        if (dwe||rom_en) b8_if.put_u8(addr, d8x4[dsel]);    ///> write to SRAM
        else             b8_if.get_u8(addr);                ///> read from SRAM
    end
    ///
    /// combinational
    ///
    task INIT();
        t_n       = 'hccfeedcc;   /// TOS
        t_x       = 1'b0;
        a_n       = {`ASZ{1'b0}}; /// default to clear address
        a_x       = 1'b0;
        asel_n    = 1'b0;         /// address default to program counter
        dsel_x    = 1'b0;         /// data bus
        dsel_n    = 3;
        dwe       = 1'b0;         /// default data write flag
        ibuf_x    = 1'b0;
        obuf_x    = 1'b0;
    endtask: INIT

    always_comb begin
        INIT();
        case (code)
        iaload:
            case (phase)
            0: MEM(t2a);
            1: begin MEM(a + 1); TOS(d2t); end
            2: begin MEM(a + 1); TOS(t_d); end
            3: begin MEM(a + 1); TOS(t_d); end
            4: TOS(t_d);
            endcase
        baload:
            case (phase)
            0: MEM(t2a);
            1: TOS(d2t);
            endcase
        saload:
            case (phase)
            0: MEM(t2a);
            1: begin MEM(a + 1); TOS(d2t); end
            2: TOS(t_d);
            endcase
        iastore:
            case (phase)
            0: begin MEM(s2a); `SET(dsel_x); dsel_n = 0; end
            1: begin MEM(a + 1); DW(1); end
            2: begin MEM(a + 1); DW(2); end
            3: begin MEM(a + 1); DW(3); end
            4: DW(3);                          // CC: reset a?
            endcase
        bastore:
            case (phase)
            0: MEM(s2a);
            1: DW(3);                          // CC: reset a?
            endcase
        sastore:
            case (phase)                       // CC: logic changed from Dr. Ting's
            0: begin MEM(s2a); `SET(dsel_x); dsel_n = 2; end
            1: begin MEM(a + 1); DW(3); end
            2: DW(3);
            endcase
        iinc:
            case (phase)                       // CC: logic changed from Dr. Ting's
            0: MEM(s2a);
            1: `SET(asel_n);
            2: begin TOS(s); DW(0); end
            endcase
        jsr:
            case (phase)
            0: MEM(t2a);
            1: begin MEM(a + 1); TOS(d2t); end
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
            1: begin TOS(d2t); `SET(ibuf_x); end
            endcase
        put:
            case (phase)
            0: begin MEM(obuf); `SET(dsel_x); end
            1: begin DW(3);     `SET(obuf_x); end
            endcase
        endcase
    end

    always_ff @(posedge ctl.clk) begin
        if (ctl.rst) begin
            a     <= {`ASZ{1'b0}};  ///> clear address
            asel  <= 1'b0;          ///> note: cold start by decoder
            dsel  <= 3;
            ibuf  <= TIB;
            obuf  <= OBUF;
        end
        else if (ls_en) begin
            asel <= asel_n;
            if (a_x)     a    <= a_n;
            if (dsel_x)  dsel <= dsel_n;
            if (ibuf_x)  ibuf <= ibuf + 1'b1;
            if (obuf_x)  obuf <= obuf + 1'b1;
        end
    end
endmodule: EJ32_LS

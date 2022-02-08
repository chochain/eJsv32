// Java Forth Machine eJsv32k.v in Quartus II SystemVerilog-2005
// Chen-hanson Ting, 1/10/2022
module eJsv32k (
    input logic clk,clr,
    output logic[31:0] addr_o_o,t_o,p_o,a_o,
    output logic[7:0] data_o_o,data_i_o,code_o,
    output logic[2:0] phase_o,
    output logic[4:0] sp_o,rp_o,
    output logic write_o); 
    
    parameter width = 31;
    parameter[7:0] nop        = 8'b00000000;
    parameter[7:0] aconst_null= 8'b00000001;
    parameter[7:0] iconst_m1  = 8'b00000010;
    parameter[7:0] iconst_0   = 8'b00000011;
    parameter[7:0] iconst_1 = 8'b00000100;
    parameter[7:0] iconst_2 = 8'b00000101;
    parameter[7:0] iconst_3 = 8'b00000110;
    parameter[7:0] iconst_4 = 8'b00000111;
    parameter[7:0] iconst_5 = 8'b00001000;
    parameter[7:0] bipush   = 8'b00010000;
    parameter[7:0] sipush   = 8'b00010001;
    parameter[7:0] iload    = 8'b00010101;
    parameter[7:0] iload_0  = 8'b00011010;
    parameter[7:0] iload_1  = 8'b00011011;
    parameter[7:0] iload_2  = 8'b00011100;
    parameter[7:0] iload_3  = 8'b00011101;
    parameter[7:0] iaload   = 8'b00101110;
    parameter[7:0] baload   = 8'b00110011;
    parameter[7:0] saload   = 8'b00110101;
    parameter[7:0] istore_0 = 8'b00111011;
    parameter[7:0] iastore  = 8'b01001111;
    parameter[7:0] bastore  = 8'b01010100;
    parameter[7:0] sastore  = 8'b01010110;
    parameter[7:0] pop      = 8'b01010111;
    parameter[7:0] pop2     = 8'b01011000;
    parameter[7:0] dup      = 8'b01011001;
    parameter[7:0] dup_x1   = 8'b01011010;
    parameter[7:0] dup_x2   = 8'b01011011;
    parameter[7:0] dup2     = 8'b01011100;
    parameter[7:0] swap     = 8'b01011111;
    parameter[7:0] iadd     = 8'b01100000;
    parameter[7:0] isub     = 8'b01100100;
    parameter[7:0] imul  = 8'b01101000;
    parameter[7:0] idivv  = 8'b01101100;
    parameter[7:0] irem  = 8'b01110000;
    parameter[7:0] ineg  = 8'b01110100;
    parameter[7:0] ishl  = 8'b01111000;
    parameter[7:0] ishr  = 8'b01111010;
    parameter[7:0] iushr = 8'b01111100;
    parameter[7:0] iand  = 8'b01111110;
    parameter[7:0] ior   = 8'b10000000;
    parameter[7:0] ixor  = 8'b10000010;
    parameter[7:0] iinc  = 8'b10000100;
    parameter[7:0] ifeq  = 8'b10011001;
    parameter[7:0] ifne  = 8'b10011010;
    parameter[7:0] iflt  = 8'b10011011;
    parameter[7:0] ifge  = 8'b10011100;
    parameter[7:0] ifgt  = 8'b10011101;
    parameter[7:0] ifle  = 8'b10011110;
    parameter[7:0] if_icmpeq = 8'b10011111;
    parameter[7:0] if_icmpne = 8'b10100000;
    parameter[7:0] if_icmplt = 8'b10100001;
    parameter[7:0] if_icmpgt = 8'b10100011;
    parameter[7:0] goto      = 8'b10100111;
    parameter[7:0] jsr       = 8'b10101000;
    parameter[7:0] ret       = 8'b10101001;
    parameter[7:0] jreturn    = 8'b10110001;
    parameter[7:0] invokevirtual = 8'b10110110;
    parameter[7:0] donext     = 8'b11001010;
    parameter[7:0] ldi        = 8'b11001011;
    parameter[7:0] popr       = 8'b11001100;
    parameter[7:0] pushr      = 8'b11001101;
    parameter[7:0] dupr       = 8'b11001110;
    parameter[7:0] get        = 8'b11010000;
    parameter[7:0] put        = 8'b11010001;
    parameter[23:0] zeros     = {24{1'b0}};
// registers
    logic[width:0] s_stack[31:0];
    logic[width:0] r_stack[31:0];
    logic[4:0] sp,sp1; 
    logic[4:0] rp,rp1; 
    logic[width:0] p,t,a;
    logic[7:0] code;
    logic[2:0] phase;
    logic[1:0] data_sel;
    logic addr_sel;
// wires    
    logic[width:0] s,r,addr_o;
    logic[width:0] p_in,t_in,r_in,a_in;
    logic r_z,t_z;
    logic tload,sload,spush,spopp,rload,rloada,rpush,rpopp,aload;
    logic[7:0] code_in;
    logic[7:0] data_i,data_o;
    logic[2:0] phase_in;
    logic[1:0] data_in;
    logic write,addrload,addr_in,phaseload,dataload,pload,codeload;
    logic[width:0] quotient,remain;
    logic[63:0] product;
    logic[width:0] isht_o,iushr_o;
    logic right_shift;
    logic[width:0] inptr,outptr;
    logic inload,outload;

  ram_memory    ram_memory_inst (
    .address ( addr_o[12:0] ),
    .clock ( ~clk ),
    .data ( data_o ),
    .wren ( write ),
    .q ( data_i )
    );
  mult  mult_inst (
    .dataa ( t ),
    .datab ( s ),
    .result ( product )
    );
  divide    divide_inst (
    .denom ( t ),
    .numer ( s ),
    .quotient ( quotient ),
    .remain ( remain )
    );
  shifter   shifter_inst (
    .data ( s ),
    .direction ( right_shift ),
    .distance ( t[4:0] ),
    .result ( isht_o )
    );
  ushifter  ushifter_inst (
    .data ( s ),
    .distance ( t[4:0] ),
    .result ( iushr_o )
    );
// direct signals
    assign data_i_o = data_i ;
    assign data_o_o = data_o ;
    assign addr_o_o = addr_o ;
    assign write_o  = write ;
    assign code_o   = code ;
    assign t_o      = t ;
    assign p_o      = p ;
    assign a_o      = a ;
    assign phase_o  = phase ;
    assign sp_o     = sp ;
    assign rp_o     = rp ;
    assign data_o = (data_sel==3)?t[7:0]:(data_sel==2)?t[15:8]:(data_sel==1)?t[23:16]:t[31:24];
    assign addr_o = (addr_sel )? a: p;
    assign s      = s_stack[sp];
    assign r      = r_stack[rp];
    assign t_z    = (t == 0) ? 1'b1: 1'b0 ;
    assign r_z    = (r == 0) ? 1'b1: 1'b0 ;
// combinational
  always_comb 
    begin
        aload     <= 1'b0;
        tload     <= 1'b0; 
        sload     <= 1'b0; 
        spush     <= 1'b0; 
        spopp     <= 1'b0;
        rload     <= 1'b0; 
        rpush     <= 1'b0; 
        rpopp     <= 1'b0; 
        pload     <= 1'b1;
        p_in      <= p + 1 ;
        addrload  <= 1'b1;
        addr_in   <= 1'b0;
        dataload  <= 1'b0; 
        data_in   <= 3 ; 
        phaseload <= 1'b0; 
        phase_in  <= 0 ; 
        codeload  <= 1'b1; 
        code_in   <= data_i ; 
        write     <= 1'b0; 
        t_in      <= {width+1{1'b0}};
        a_in      <= {width+1{1'b0}};
        r_in      <= {width+1{1'b0}};
        right_shift   <= 1'b0; 
        inload    <= 1'b0; 
        outload   <= 1'b0; 
// instructions
    case (code)
        nop         :begin phaseload <= 1'b1 ; phase_in <= 0 ;end 
        aconst_null :begin t_in <= 0 ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_m1   :begin t_in <= -1 ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_0    :begin t_in <= 0 ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_1    :begin t_in <= 1  ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_2    :begin t_in <= 2  ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_3    :begin t_in <= 3  ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_4    :begin t_in <= 4  ; tload <= 1'b1 ; spush <= 1'b1 ;end
        iconst_5    :begin t_in <= 5  ; tload <= 1'b1 ; spush <= 1'b1 ;end
        bipush :begin
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= {zeros,data_i} ; tload <= 1'b1 ; spush <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        sipush :begin
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= {zeros,data_i} ; tload <= 1'b1 ; spush <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    t_in <= {t[23:0],data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        iload :begin
            t_in <= r_stack[rp - data_i] ; tload <= 1'b1 ;
            p_in <= p + 1 ;  spush <= 1'b1 ;end
        iload_0 :begin
            t_in <= r_stack[rp] ; tload <= 1'b1 ;
            spush <= 1'b1 ;end
        iload_1 :begin
            t_in <= r_stack[rp - 1] ; tload <= 1'b1 ;
            spush <= 1'b1 ;end
        iload_2 :begin
            t_in <= r_stack[rp - 2] ; tload <= 1'b1 ;
            spush <= 1'b1 ;end
        iload_3 :begin
            t_in <= r_stack[rp - 3] ; tload <= 1'b1 ;
            spush <= 1'b1 ;end
        iaload :begin
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= t ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    a_in <= a + 1 ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                2 :begin phaseload <= 1'b1 ; phase_in <= 3 ; 
                    a_in <= a + 1 ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                3 :begin phaseload <= 1'b1 ; phase_in <= 4 ; 
                    a_in <= a + 1 ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                4 :begin phaseload <= 1'b1 ; phase_in <= 5 ; 
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end 
            endcase end
        baload :begin
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= t ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    codeload <= 1'b0 ; p_in <= p - 1 ; pload <= 1'b1 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ; 
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; 
                    code_in <= nop ; codeload <= 1'b1 ; pload <= 1'b1 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end 
            endcase end
        saload :begin
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= t ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    a_in <= a + 1 ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                2 :begin phaseload <= 1'b1 ; phase_in <= 3 ; 
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end 
            endcase end
        istore_0 :begin
            r_in <= t ; rload <= 1'b1 ;
            t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        iastore :begin
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ; addr_in <= 1'b1 ; spopp <= 1'b1 ;
                    dataload <= 1'b1 ; data_in <= 0 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    a_in <= a + 1   ; aload <= 1'b1 ; addr_in <= 1'b1 ; 
                    dataload <= 1'b1 ; data_in <= 1 ; write <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                2 :begin phaseload <= 1'b1 ; phase_in <= 3 ;
                    a_in <= a + 1   ; aload <= 1'b1 ; addr_in <= 1'b1 ; 
                    dataload <= 1'b1 ; data_in <= 2 ; write <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                3 :begin phaseload <= 1'b1 ; phase_in <= 4 ;
                    a_in <= a + 1   ; aload <= 1'b1 ; addr_in <= 1'b1 ; 
                    dataload <= 1'b1 ; data_in <= 3 ; write <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                4 :begin phaseload <= 1'b1 ; phase_in <= 5 ;
                    dataload <= 1'b1 ; data_in <= 3 ; write <= 1'b1 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;
                    p_in <= p ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        bastore :begin
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ; addr_in <= 1'b1 ; spopp <= 1'b1 ;
                    codeload <= 1'b0 ; p_in <= p - 1 ; pload <= 1'b1 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    code_in <= nop ; codeload <= 1'b1 ; pload <= 1'b1 ;
                    dataload <= 1'b1 ; write <= 1'b1 ; addr_in <= 1'b0 ;end  
            endcase end
        sastore :begin
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ; addr_in <= 1'b1 ; spopp <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    a_in <= a + 1 ; aload <= 1'b1 ; addr_in <= 1'b1 ; 
                    dataload <= 1'b1 ; data_in <= 2 ; write <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    dataload <= 1'b1 ; write <= 1'b1 ; addr_in <= 1'b1 ; 
                    code_in <= nop ; codeload <= 1'b1 ; pload <= 1'b0 ;end
            endcase end
        pop :begin 
            t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        pop2 :begin 
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1 ;end
            endcase end
        dup :begin  
            spush <= 1'b1;end
        dup_x1 :begin 
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= a ; spush <= 1'b1 ; tload <= 1'b1 ;end
            endcase end
        dup_x2 :begin 
            t_in <= s_stack[sp - 1] ; spush <= 1'b1 ; tload <= 1'b1 ;end 
        dup2 :begin  
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ; 
                    t_in <= a ; spush <= 1'b1 ; tload <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                2 :begin phaseload <= 1'b1 ; phase_in <= 3 ;
                    a_in <= s ; aload <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= a ; spush <= 1'b1 ; tload <= 1'b1 ;end
            endcase end
        swap :begin 
            t_in <= s ; tload <= 1'b1 ; sload <= 1'b1 ;end 
        iadd :begin 
            t_in <= s + t ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        isub :begin 
            t_in <= s - t ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        imul :begin 
            t_in <= product[width :0] ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        idivv :begin 
            t_in <= quotient ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        irem :begin 
            t_in <= remain ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        ineg :begin 
            t_in <= 0 - t ; tload <= 1'b1 ; spopp <= 1'b1 ;end
        ishl :begin
            t_in <= isht_o ; tload <= 1'b1; spopp <= 1'b1 ;end
        ishr :begin right_shift <= 1'b1 ; 
            t_in <= isht_o ; tload <= 1'b1; spopp <= 1'b1 ;end
        iushr :begin 
            t_in <= iushr_o ; tload <= 1'b1; spopp <= 1'b1 ;end
        iand :begin 
            t_in <= s & t ; tload <= 1'b1; spopp <= 1'b1 ;end
        ior :begin 
            t_in <= s | t ; tload <= 1'b1; spopp <= 1'b1 ;end
        ixor :begin 
            t_in <= s ^ t ; tload <= 1'b1; spopp <= 1'b1 ;end
        iinc :begin 
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= s ; aload <= 1'b1 ; addrload <= 1'b1 ; addr_in <= 1'b1 ;end
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    t_in <= t + data_i ; sload <= 1'b1 ; addrload <= 1'b1 ; addr_in <= 1'b1 ;
                    spopp <= 1'b1 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;
                    t_in <= s ; tload <= 1'b1 ;
                    dataload <= 1'b1 ; data_in <= 0 ; write <= 1'b1 ; 
                    addrload <= 1'b1 ; pload <= 1'b0 ;end
            endcase end
        ifeq :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t_z ) begin
                        p_in <= {a[23 : 0 ] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        ifne :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t_z == 1'b0) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        iflt :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t[31] ) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        ifge :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t[31] == 1'b0) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        ifgt :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if ((t[31]==1'b0) && (t_z==1'b0)) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        ifle :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if ((t[31]==1'b1) || (t_z==1'b1)) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        if_icmpeq :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= s - t ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t_z ) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        if_icmpne :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= s - t ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t_z == 1'b0) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        if_icmplt :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= s - t ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if (t[31] ) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        if_icmpgt :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    t_in <= s - t ; tload <= 1'b1 ; spopp <= 1'b1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    codeload <= 1'b0 ; 
                    if ((t[31]==1'b0) && (t_z==1'b0)) begin
                        p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    end end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    t_in <= s ; tload <= 1'b1 ; spopp <= 1'b1;end 
            endcase end
        goto :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    p_in <= {a[23 : 0] , data_i} ; 
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        jsr :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= t ; aload <= 1'b1 ; addrload <= 1'b1 ; addr_in <= 1'b1 ;end
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    a_in <= a + 1 ; aload <= 1'b1 ; addrload <= 1'b1 ; addr_in <= 1'b1 ;
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; pload <= 1'b0 ;end
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ; 
                    p_in <= {t[23 : 0] , data_i} ; 
                    t_in <= p + 2 ; tload <= 1'b1 ; spush <= 1'b1 ;end
            endcase end
        ret :begin
            p_in <= r ;end
        jreturn :begin
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    p_in <= r ; rpopp <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        invokevirtual :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    r_in <= p + 2 ; rpush <= 1'b1 ; 
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    p_in <= {a[23 : 0] , data_i} ; aload <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        donext :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= {zeros , data_i} ; aload <= 1'b1 ; 
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ;
                    if (r_z ) begin
                        rpopp <= 1'b1 ;end
                    else begin
                        r_in <= r - 1 ; rload <= 1'b1 ;
                        p_in <= {a[23 : 0] , data_i} ;
                    end 
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end
            endcase end
        ldi :begin
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <=1 ; 
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; spush <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                1 :begin phaseload <= 1'b1 ; phase_in <= 2 ; 
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                2 :begin phaseload <= 1'b1 ; phase_in <= 3 ; 
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                3 :begin phaseload <= 1'b1 ; phase_in <= 4 ; 
                    t_in <= {t[23 : 0] , data_i} ; tload <= 1'b1 ;
                    codeload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;end 
            endcase end
        popr :begin 
            t_in <= r ; tload <= 1'b1 ; spush <= 1'b1 ; rpopp <= 1'b1 ;end
        pushr :begin 
            t_in <= s ; tload <= 1'b1; spopp <= 1'b1;
            r_in <= t ;  rpush <= 1'b1;end
        dupr :begin 
            t_in <= r ; tload <= 1'b1; spush <= 1'b1;end
        get :begin 
            case (phase)
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= inptr ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    codeload <= 1'b0 ; pload <= 1'b0 ; spush <= 1'b1 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;
                    t_in <= {zeros , data_i} ; tload <= 1'b1 ; 
                    code_in <= nop ; codeload <= 1'b1 ; pload <= 1'b0 ; 
                    inload <= 1'b1 ;end
            endcase end
        put :begin 
            case (phase) 
                0 :begin phaseload <= 1'b1 ; phase_in <= 1 ;
                    a_in <= outptr ; aload <= 1'b1 ; addr_in <= 1'b1 ;
                    data_in <= 3 ; dataload <= 1'b1 ; 
                    codeload <= 1'b0 ; pload <= 1'b0 ;end 
                default :begin phaseload <= 1'b1 ; phase_in <= 0 ;
                    t_in <= s ; tload <= 1'b1; spopp <= 1'b1 ;
                    data_in <= 3 ; dataload <= 1'b1 ; write <= 1'b1 ; 
                    code_in <= nop ; codeload <= 1'b1 ; pload <= 1'b0 ; 
                    outload <= 1'b1 ;end
            endcase end
        default :begin phase_in <= 0 ;end 
    endcase
    end
// registers
    always_ff @(posedge clk, posedge clr)
    begin
        if (clr) begin
            phase <= 1'b0 ;
            addr_sel <= 1'b0 ;
            data_sel <= 3 ; 
            sp  <= 0;
            sp1 <= 1;
            rp  <= 0;
            rp1 <= 1;
            inptr  <= 32'b00000000000000000001000000000000 ;
            outptr <= 32'b00000000000000000001010000000000 ;
            t   <= {width+1{1'b0}};
            a   <= {width+1{1'b0}};
            p   <= {width+1{1'b0}};
            end
        else if (clk) begin
            if (pload     ) begin p <= p_in ;end 
            if (aload     ) begin a <= a_in;end 
            if (codeload  ) begin code <= code_in ;end 
            if (phaseload ) begin phase <= phase_in ;end 
            if (addrload  ) begin addr_sel <= addr_in ;end 
            if (dataload  ) begin data_sel <= data_in ;end 
            if (tload ) begin t <= t_in;end 
            if (sload ) begin s_stack[sp] <= t;end 
            if (spush ) begin
//              s_stack[sp1] <= t;
                s_stack[sp] <= t;
                sp <= sp + 1; sp1 <= sp1 + 1;end 
            if (spopp ) begin
                sp <= sp - 1; sp1 <= sp1 - 1;end 
            if (rload ) begin r_stack[rp] <= r_in;end 
            if (rpush ) begin
                r_stack[rp1] <= r_in;
                rp <= rp + 1; rp1 <= rp1 + 1;end 
            if (rpopp ) begin 
                rp <= rp - 1; rp1 <= rp1 - 1;end 
            if (inload ) begin inptr <= inptr + 1 ;end 
            if (outload ) begin outptr <= outptr + 1 ;end 
        end 
    end
    endmodule


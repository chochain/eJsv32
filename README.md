## eJ32 - a Forth CPU on FPGA that runs Java opcodes

A reincarnation of eP32, a 32-bit CPU by Dr. Ting. However, deviating from the long linage of eForth, it uses Java Bytecode as the internal instruction set and hence the name **J**. After developing CPUs for decades, Dr. Ting, in a write up for [eJsv32 manual](https://chochain.github.io/eJsv32/docs/JVM_manual.pdf), he concluded the following

>
> *Which instruction set will be the best and to survive to the next century? Looking around, I can see only one universal computer instruction set, and it is now gradually prevailing. It is Java.*
>

Responding to the invitation from Don Golding of CORE-I FPGA project [AI & Robotics Group](https://www.facebook.com/groups/1304548976637542), Dr. Ting dedicated the last few months of his life on developing eJ32. Based on his VHDL eP32, the transcoded SystemVerilog set was completed but never has the chance been fully verified or validated in time before his passing.

> ![eJ32 architecture](https://chochain.github.io/eJsv32/docs/eJ32_arch.png)

I appreciate that Dr. Ting took me in his last projects and considered me one of his student. Though a trained software engineer, who have never worked on any FPGA before, I felt overwhelmingly obligated to at least carry his last work to a point that future developers can benefit from the gems of his life's effort.

My goal is to make the learning journey of building eJ32 as an example of designing and implementing an FPGA CPU regardless whether Java will be the prevailing ISA or not.

### Status
Currently, though eJ32 has been successfully simulated with Dr. Ting's test cases but yet synthesized on the targeted ICE40. It will take sometime to realize for lack of hardware design knowledge on my part. If interested in a fully functional Forth CPU, *J1a* is a great one. Check [here](https://www.excamera.com/sphinx/article-j1a-swapforth.html). Anyway, for a kick, here're what I've done for eJ32 so far.

### Adaptations of eJsv32k
* keep Dr. Ting's original code in ~/orig/eJsv32k
* keep Dr. Ting's documentation in ~/docs
* create ~/source/eJ32.sv as the main core
* update mult/divide/shifter/ushifter modules using simple *, /, <<
* externalize ram_memory.v module, use spram.sv and eJ32_if.sv for Lattice iCE40UP FPGA
* create a dictionary ROM from eJsv32.hex, 8K bytes, sourcing from original ej32i.mif (see source/README for details)
* add ~/test/dict_setup.sv, use $fload to install memory map (i.e. eJsv32.hex)
* add top module ~/test/outer_tb.sv to drive memory block, dict_setup, and inner interpreter eJ32
* add eJ32.vh, use enum for opcodes replacing list of parameters
* refactor eJ32.sv
  + use common tasks and macros to reduce verbosity
  + removed phaseload, aselload which are always 1'b1
  + add many $display for tracing (and my own understanding)
* fix divider, add one extra cycle for TOS update before next instruction
* modulization into a 2-bus design
* use iCE40 EBR (embedded block memory) for 64-deep data and return stacks (was 32-deep)
* use EBR as ROM which is populated from hex image file (contains 3.4K eForth + 1K test cases)
  
### Modulization, to v2
  ![eJ32 architecture](https://chochain.github.io/eJsv32/docs/eJ32_v2_blocks.png)

  |module|desc|components|LUTs|note|err|
  |--|--|--|--|--|--|
  |CTL|control bus|TOS, code, phase||not synthsized||
  |ROM|eForth image (3.4K bytes)|8K bytes onboard ROM|65|8-bit, single-port|16 EBR blocks|
  |RAM|memory|128K bytes onboard RAM|48|8-bit, single port||
  |DC|decoder unit|state machines|233||divider patch|
  |AU|arithmetic unit|ALU and data stack|1792|2 EBR blocks||
  |BR|branching unit|program counter and return stack|518|2 EBR blocks||
  |LS|load/store unit|memory and buffer IO|369|||

### Bus Design
  ![eJ32 bus design](https://chochain.github.io/eJsv32/docs/eJ32_v2_bus.png)
  
  TODO:
  * combine IU (instruction unit, in eJ32.sv) and BR
  * add s (NOS) register
  * break IF (instruction fetch) off LS
  * break RR (t Register Read), WB (t, s Write Back) off AU
  * study pipelining hazards 
    + structure - RR-WB, BR-IU
    + data - p_inc, divz, s
    + control - p (and exception)

### Installation
* Install Lattice Radiant 3.0+ (with Free license from Lattice, comes with ModelSim 32-bit)
* clone this [repository](git@github.com:chochain/eJsv32.git) to your local drive
* Open eJsv32.rdf project from within Radiant
* Compile, Synthesis if you really want to, and simulate (with ModelSim)

### Memory Map (128K bytes)

  |section|starting address|note|
  |--|--|--|
  |eForth image|0x0000|loaded from ROM|
  |Input buffer|0x1000|no RX unit yet, loaded from ROM|
  |Output buffer|0x1400|no TX unit yet|

### Limitations
* targeting only Lattice iCE40UP FPGA for now
* No serial interface (i.e. UART, SPI, ..)
  * fixed validation cases hardcoded in TIB (at 'h1000)
  * output writes into output buffer byte-by-byte (starting at 'h1400)
* 33-cycle soft divider (iCE40 has no hardware divider)
* No Map or Route provided
* Data and return stacks
  * 64-deep
  * use iCE40 EBR, embedded block memory, pseudo dual-port, Lattice generated netlist, with negative edged clock
* eForth image (3.4K)
  * use iCE40 EBR as ROM
  * loaded from ROM into RAM during at start-up (8K cycles)

### Results - Staging for future development
* The design works OK on ModelSim
  + ~2.9K LUTs which should fit in iCE40 (3K or 5K), still ironing out some synthesis error
* ModelSim COLD start - completed
  + v1 - 10K cycles, ~/docs/eJ32_trace.txt
  + v2 - 10K cycles, ~/docs/eJ32v2_trace_20240108.txt
* ModelSim Dr. Ting's 6 embeded test cases - completed
  + v1 - 600K+ cycles OK, ~/docs/eJ32_trace_full_20220414.txt.gz (Dr. Ting's modified)
  + v1 - 520K+ cycles OK, ~/docs/eJ32_trace_full_20231223.txt.gz (before modulization)
  + v2 - 520K+ cycles OK, ~/docs/eJ32v2_trace_full_20240117.txt.gz (after modulization)

### Statistics
For the 6 test cases Dr. Ting gave, they take ~520K cycles.

  |units|instructions (in K)|total cycles(in K)|note|
  |--|--|--|--|
  |AU ony|108|173|idiv,irem takes 14K cycles|
  |BR only|10|20|jreturn|
  |LS only|24|112|b/i/saload|
  |AU + BR|50|145||
  |AU + LS|14|69||

So, within the total cycles. [details here](https://chochain.github.io/eJsv32/docs/opcode_freq_v2.ods)
* Arithmetic takes about 1/3, mostly 1-cycle except bipush(2), pop2(2), dup2(4)
* Branching  takes about 1/3, all 3-cycle except jreturn 2-cycle.
* Load/Store takes about 1/3, all multi-cycles (avg. 5/instructions) 

### TODO
* learn to Map
* learn to Place & Route
* Consider i-cache + branch prediction to reduce branching delay
* Consider 32-bit and/or d-cache to reduce load/store delay
* Consider Pipelined design (see bus design above)
  + Note: Pure combinatory module (no clock) returns in 1 cycle but lengthen the path which slows down the max frequency. Pipeline does the opposite.
  + build hardwired control table
  + learn how to resolve Hazards
  + learn [CSR + Hyper Pipelining](http://www.euroforth.org/ef15/papers/strauch.pdf)

### Reference
* IceStorm, open source synthesis, https://clifford.at/icestorm
* Project-F, https://github.com/projf/projf-explore
  + Verilator + SDL2, https://projectf.io/posts/verilog-sim-verilator-sdl/
* Verilator
  + part-1~4 https://itsembedded.com/dhd/verilator_1/ ...
* SpinalHDL
* RISC-V Pipeline design https://passlab.github.io/CSE564/notes/lecture09_RISCV_Impl_pipeline.pdf

### Revision History
* 20220110 - Chen-hanson Ting: eJsv32k.v in Quartus II SystemVerilog-2005
* 20220209 - Chochain: rename to eJ32 for Lattice and future versions
* 20230216 - Chochain: consolidate ALU modules, tiddy macro tasks
* 20231216 - Chochain: modulization => v2.0
* 20240108 - Chochain: use EBR for data/return stacks and eForth image

## eJ32 JavaForthMachine

A reincarnation of eP32, a 32-bit CPU by Dr. Ting. However, deviating from the long linage of eForth, it uses Java Bytecode as the internal instruction set and hence the name **J**. After developing CPU for decades, Dr. Ting, in a write up for [eJsv32 manual](https://chochain.github.io/eJsv32/docs/JVM_manual.pdf), he concluded the following

>
> *Which instruction set will be the best and to survive to the next century? Looking around, I can see only one universal computer instruction set, and it is now gradually prevailing. It is Java.*
>

Responding to the invitation from Don Golding of CORE-I FPGA project [AI & Robotics Group](https://www.facebook.com/groups/1304548976637542), Dr. Ting dedicated the last few months of his life on developing eJ32. Based on his VHDL eP32, the transcoded SystemVerilog set was completed but never has the chance been fully verified or validated in time before his passing.

> ![eJ32 architecture](https://chochain.github.io/eJsv32/docs/eJ32_arch.png)

I appreciate that Dr. Ting took me in his last projects and considered me one of his student. Though a trained software engineer, who have never worked on any FPGA before, I felt overwhelmingly obligated to at least carry his last work to a point that future developers can benefit from the work of his life's effort.

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
* use iCE40 EBR (embedded block memory) for 64-deep data and return stacks (was 32-deep)
  
### Modulization (and bump version to v2)
  ![eJ32 architecture](https://chochain.github.io/eJsv32/docs/eJ32_v2_blocks.png)

  |module|desc|components|LUTs|note|err|
  |--|--|--|--|--|--|
  |CTL|control bus|TOS, code, phase||not synthsized||
  |ROM|memory|3.4K bytes eForth image|in progress|8-bit, single-port|7 EBR blocks|
  |RAM|memory|128K bytes onboard RAM|53|8-bit, single port||
  |DC|decoder unit|state machines|233||divider patch|
  |AU|arithmetic unit|ALU and data stack|1556|2 EBR blocks||
  |BR|branching unit|program counter and return stack|447|2 EBR blocks||
  |LS|load/store unit|memory and buffer IO|363|||

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
  * fixed validation cases hardcoded in TIB
  * output sent to output buffer
* 33-cycle soft divider (iCE40 has no hardware divider)
* No Map or Route provided
* Data and return stacks
  * 64-deep
  * use iCE40 EBR, embedded block memory, pseudo dual-port, Lattice generated netlist, with negative edged clock
* eForth image
  * not stored in ROM (iCE40 EBR)
  * loaded from file into RAM during simulation

### Results - Staging for future development
* The design works OK on ModelSim
  + ~2.6K LUTs should fit in iCE40 (3K or 5K), but some synthesis error still
* ModelSsim COLD start - completed
  + v1 - 10K cycles, ~/docs/eJ32_trace.txt
  + v2 - 10K cycles, ~/docs/eJ32v2_trace_20240108.txt
* ModelSim Dr. Ting's 6 embeded test cases - completed
  + v1 - 600K+ cycles OK, ~/docs/eJ32_trace_full_20220414.txt
  + v1 - 520K+ cycles OK, ~/docs/eJ32_trace_full_20231223.txt
  + v2 - 520K+ cycles OK, ~/docs/eJ32v2_trace_full_20240108.txt

### TODO
* learn to Map
* learn to Place & Route
* Consider Pipelined design
  + Pure combinatory module (no clock) returns in 1 cycle but lengthen the path which slows down the max frequency. Pipeline does the opposite.

### Reference
* IceStorm, open source synthesis, https://clifford.at/icestorm
* Project-F, https://github.com/projf/projf-explore
  + Verilator + SDL2, https://projectf.io/posts/verilog-sim-verilator-sdl/
* Verilator
  + part-1~4 https://itsembedded.com/dhd/verilator_1/ ...
* SpinalHDL

### Revision History
* 20220110 - Chen-hanson Ting: eJsv32k.v in Quartus II SystemVerilog-2005
* 20220209 - Chochain: rename to eJ32 for Lattice and future versions
* 20230216 - Chochain: consolidate ALU modules, tiddy macro tasks
* 20231216 - Chochain: fishbone modulization => v2.0
* 20240108 - Chochain: use EBR for data/return stacks and eForth image

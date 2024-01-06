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
Currently, though eJ32 has been successfully simulated with Dr. Ting's test cases but yet synthesized on the targeted ICE40. It will take sometime to realize for lack of hardware design knowledge on my part. For example, how to place & route or even how to use EBR.... If interested in a fully functional Forth CPU, *J1a*, is a great one. Check [here](https://https://www.excamera.com/sphinx/article-j1a-swapforth.html). Anyway, for a kick, here're what I've done for eJ32 so far.

### Adaptations of eJsv32k
* keep Dr. Ting's original code in ~/orig/eJsv32k
* keep Dr. Ting's documentation in ~/docs
* create ~/source/eJ32.sv as the main core
* update mult/divide/shifter/ushifter modules using simple *, /, <<
* externalize ram_memory.v module, use spram.sv and eJ32_if.sv for Lattice iCE40 FPGA
* create a dictionary ROM from eJsv32.hex, 8K bytes, sourcing from original ej32i.mif (see source/README for details)
* add ~/test/dict_setup.sv, use $fload to install memory map (i.e. eJsv32.hex)
* add top module ~/test/outer_tb.sv to drive memory block, dict_setup, and inner interpreter eJ32
* add eJ32.vh, use enum for opcodes replacing list of parameters
* refactored eJ32.sv
  + use common tasks and macros to reduce verbosity
  + removed phaseload, aselload which are always 1'b1
  + add many $display for tracing (and my own understanding)
  
### Modulization (and bump version to v2)
  > ![eJ32 architecture](https://chochain.github.io/eJsv32/docs/eJ32_v2_blocks.png)
  
  |module|desc|components|LUTs|note|err|
  |--|--|--|--|--|--|
  |CTL|control bus|TOS, code, phase||not synthsized||
  |RAM|memory|128K RAM|53|8-bit, single port||
  |DC|decoder unit|state machines|215||divider patch|
  |AU|arithmetic unit|ALU and data stack|3895|1285 with ss[1]|EBR multi-write|
  |BR|branching unit|program counter and return stack|4652|478 with rs[1]||
  |LS|load/store unit|memory and buffer IO|363|||

### Installation
* Install Lattice Radiant 3.0+ (with Free license from Lattice, comes with ModelSim 32-bit)
* clone this [repository](git@github.com:chochain/eJsv32.git) to your local drive
* Open eJsv32.rdf project from within Radiant
* Compile, Synthesis if you must, and simulate (with ModelSim)

### Memory Map
<code>
* Dictionary         0x0000
* Input (TIB)        0x1000
* Output buffer      0x1400
* Total              128K bytes
</code>

### Limitations
* targeting only Lattice iCE40 FPGA for now
* Data and return stacks
  * 32-deep only
  * using LUTs instead of EBR memory (i.e. expensive ~7K)
* Estimated total 10K LUTs (with data and return stacks)
* No Map or Route provided
* No serial interface (i.e. UART, SPI, ..)
  * fixed validation cases hardcoded in TIB
  * output sent to output buffer

### Results - Staging for future development
* The 10K LUTs image does not fit in iCE40 (5K), but ModelSim works OK.
  + can be reduced to 3K LUTs with EBR memory,
  + can be further reduced to 2K LUTs with hardware divider.
* ModelSsim COLD start - completed
  + v1 - 10K cycles, ~/docs/eJ32_trace.txt
  + v2 - 10K cycles, ~/docs/eJ32_trace_20231223.txt
* ModelSim Dr. Ting's 6 embeded test cases - completed
  + v1 - 600K+ cycles OK, ~/docs/eJ32_trace_full_20220414.txt
  + v1 - 520K+ cycles OK, ~/docs/eJ32_trace_full_20231223.txt
  + v2 - 520K+ cycles ??, ~/docs/eJ32_trace_full_20240104.txt

### TODO
* Use EBR for data and return stacks
* A dedicate divider unit
* Check Timing
* Consider Pipeline design
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
* 20220209 - Chochain Lee: rename to eJ32 for Lattice and future versions
* 20230216 - Chochain Lee: consolidate ALU modules, tiddy macro tasks
* 20231216 - Chochain Lee: fishbone modulization => v2.0

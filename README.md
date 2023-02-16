## eJ32 JavaForthMachine

A reincarnation of eP32, a 32-bit CPU by Dr. Ting. Diviating from the long linage of eForth, instead, it uses Java Bytecode as the internal instruction set and hence the name **J**. After developing CPU for decades, Dr. Ting, in a write up of [eJsv32 manual](https://chochain.github.io/eJsv32/docs/JVM_Manual.doc), he concluded the following

> *Which instruction set will be the best and to survive to the next century? Looking around, I can see only one universal computer instruction set, and it is now gradually prevailing. It is Java.*

Responding to the invitation from Don Golding of CORE-I FPGA project [AI & Robotics Group](https://www.facebook.com/groups/1304548976637542), Dr. Ting dedicated the last few months of his life on developing eJ32 based on his VHDL eP32. The SystemVerilog codes was completed but never has the chance been fully tested in time before his passing.

I appreciate that Dr. Ting took me in his last projects and considered me one of his student. Though a trained software engineer who has never worked on any FPGA before, I felt obligated to at least carry his last work to a point that future developer can benifit from the work of his life effort.

My goal is to make eJ32 a learning tool regardless whether Java will be the prevaling ISA or not. Here what I've done.

### Adaptations of eJsv32k
* keep Dr. Ting's original code in ~/orig/eJsv32k
* keep Dr. Ting's documentation in ~/docs
* create ~/source/eJ32.sv as the main core
* update mult/divide/shifter/ushifter modules using simple *, /, <<
* externalize ram_memory.v module, use spram.sv and eJ32_if.sv for Lattice iCE40 FPGA
* create a dictionary ROM from eJsv32.hex sourcing from original ej32i.mif (see source/README for details)
* add ~/test/dict_setup.sv, use $fload to install memory map (i.e. eJsv32.hex)
* add top module ~/test/outer_tb.sv to drive memory block, dict_setup, and inner interpreter eJ32
* add eJ32.vh, use enum for opcodes replacing list of parameters
* refactored eJ32.sv
  + use common tasks and macros to reduce verbosity
  + removed phaseload, aselload which are always 1'b1
  + add many $display for tracing (and my own understanding)

### Installation
* Install Lattice Radiant 3.0+ (with Free license from Lattice)
* clone this [repository](git@github.com:chochain/eJsv32.git) to your local drive
* Open eJsv32.rdf project from within Radiant
* Synthesis and simulate (with vsim)

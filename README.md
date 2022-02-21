## eJ32 JavaForthMachine - from Dr. Ting
### Adaptations of eJsv32k
* create ~/orig/eJsv32k to keep Dr. Ting's original code
* create ~/docs to keep Dr. Ting's documentation
* create ~/source/eJ32.sv to keep modified code
* update mult/divide/shifter/ushifter modules using simple *, /, <<
* externalize ram_memory.v module, use spram.sv and forthsuper_if.sv for iCE40
* create memory map eJsv32.hex from ej32i.mif (see source/README for details)
* add ~/test/dict_setup.sv, use $fload to install memory map (i.e. eJsv32.hex)
* add test bench ~/test/outer_tb.sv to drive memory block, dict_setup, and inner interpreter eJ32
* add eJ32.vh, use enum for opcodes replacing list of parameters
* refactored eJ32.sv
  + use common tasks and macros to reduce verbosity
  + removed phaseload, aselload which are always 1'b1
  + add $display for tracing

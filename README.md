## ForthJavaMachine
### Adaptation of Dr. Ting's eJsv32k with the following
> create ~/orig/eJsv32k to keep Dr. Ting's original code

> create ~/docs to keep Dr. Ting's documentation

> create ~/source/eJ32.sv to start modified code

>> replace mult/divide/shifter/ushifter modules use simple *,/,<<

>> externalize ram_memory.v module with spram.sv and forthsuper_if.sv

>> create eJsv32.hex from ej32i.mif (see source/README for details)

>> add ~/test/dict_setup.sv to load memory map eJsv32.hex

>> add test bench ~/test/outer_tb.sv to drive memory block, dict_setup, and inner interpreter eJ32

>> add eJ32.vh, replace parameters with opcode enum

>> refactored eJ32.sv
>>  + use common tasks and macros to reduce verbosity
>>  + removed phaseload, aselload
>>  + add $display for tracing

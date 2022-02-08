## convert hex file from Quartus to Lattice
> cd source
> echo 'Memory Size 8192x8' > eJsv32.hex
> egrep ' : ' ../orig/rom/ej32i.mif | cut -d' ' -f4 | cut -d';' -f1 >> eJsv32.hex

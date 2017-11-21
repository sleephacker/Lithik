echo off
cls
asm_constants.py Kernel\Kernel.asm Kernel\Macro\AutoConstant.asm
nasm Kernel\Floppy\Bootsector.asm -o Build\Bootsector.bin
nasm Kernel\RealMode\RealMode.asm -o Build\RealMode.bin
nasm Kernel\Kernel.asm -dDEBUGBOOT -o Build\Kernel.bin
nasm FloppyImage.asm -o Image\floppy.bin
nasm FloppyImage.asm -dVBOX -o Image\vbox_floppy.bin
move Image\vbox_floppy.bin Image\vbox_floppy.img
"C:\Program Files (x86)\Bochs-2.6.6\bochs" -f bochs.bxrc
org 7c00h
bits 16

jmp short boot
nop

BIOSParameterBlock:
	.OEM db "Lithik  "				;8 bytes padded with spaces
	.bytesPerSector dw 512			;
	.sectorsPerCluster db 1			;
	.reservedSectors dw 1			;bootsector
	.FATs db 2						;?
	.rootEntries dw 224				;this is for some reason the way2go.
	.sectors dw 2880				;1474560 / 512 = 2880 sectors
	.mediaDiscriptor db 0xf0		;1.44mb 3.5inch floppy
	.sectorsPerFAT dw 9				;
	.sectorsPerTrack dw 18			;
	.sides dw 2						;2-sided floppy
	.hiddenSectors dd 0				;
	.largeSectors dd 0				;

ExtendedBootRecord:
	.drive db 0						;
	.reserved db 0					;
	.signature db 29h				;?
	.volumeID dd 0					;
	.volumeLabel db "Lithik     "	;11 bytes padded with spaces
	.fileSystem db "FAT12   "		;8 bytes padded with spaces

boot:
	xor eax, eax
	mov ds, ax
	mov ss, ax
	mov sp, 7bffh
	mov bp, 0500h
	mov si, message
	call print
	mov ax, 0
	int 16h
	int 19h
	mov si, fail
	call print
	jmp $

print:
	mov ah, 0eh
	xor bh, bh
	.loop:
		lodsb
		cmp al, 0
		je .return
		int 10h
		jmp .loop
	.return:
		ret

message db "This floppy disk is not bootable, please remove it!", 0ah, 0dh, "Press any key to reboot...", 0ah, 0dh, 0
fail db "Reboot failed!", 0

times 510 -( $ - $$ ) db 0
dw 0xaa55
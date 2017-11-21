;incbin "Image/bootloader.bin"
bits 16
org 7c00h
%define k_bytes (k_end - k_start)
%define k_sectors (k_bytes + 512 - k_bytes % 512) / 512
%define b_sectors 2
%define r_sectors b_sectors + k_sectors
jmp short boot
nop

BIOSParameterBlock:
	.OEM db "Lithik  "				;8 bytes padded with spaces
	.bytesPerSector dw 512			;
	.sectorsPerCluster db 1			;
	.reservedSectors dw r_sectors	;bootsector + kernel
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
	mov ss, ax	;ss = 0
	mov sp, 7bffh
	mov bp, 0500h
	mov [ExtendedBootRecord.drive], dl
	dec word [BIOSParameterBlock.reservedSectors]	;skip bootsector
	mov cx, k_sectors / 18 + 8			;fail per cylinder/track, plus 8 max. extra fails
	jmp .loadReservedSectors
	.reset_error:
		xor edx, edx
		mov dx, ax
		mov bl, 08h
		call print_dword
		call newline
		ror ecx, 10h
		loop .loadReservedSectors
		jmp $						;hang
	.loadReservedSectors:
		ror ecx, 10h
		mov dl, [ExtendedBootRecord.drive]
		xor ah, ah										;reset
		stc
		int 13h
		jc .reset_error
		
		xor ah, ah
		mov al, [.loadedSectors]
		add ax, b_sectors
		call logicalToPhysical
		mov al, [BIOSParameterBlock.reservedSectors];
		sub al, [.loadedSectors];
		;mov al, 1
		mov bx, 1000h
		mov es, bx
		xor bh, bh
		mov bl, [.loadedSectors]
		shl bx, 9d					;sectors * 512 = bytes
		mov dl, [ExtendedBootRecord.drive]
		mov ah, 02h
		pusha
		mov dx, es
		ror edx, 10h
		mov dx, bx
		call print_dword
		call newline
		popa
		stc
		int 13h
		%ifndef VBOX
		jnc .boot
		%else
		;helps with virtualbox's handicap
		jc .error
		cmp al, 18
		jb .boot
		mov al, 17
		%endif
		.error:				;trust the number of loaded sectors
			xor edx, edx
			mov dx, ax
			mov bl, 08h
			add [.loadedSectors], al
			ror edx, 10h
			mov dl, [.loadedSectors]
			call print_dword
			call newline
			mov al, [BIOSParameterBlock.reservedSectors]
			cmp al, [.loadedSectors]
			je .boot;.error_boot
			ror ecx, 10h
			loop .loadReservedSectors
			jmp $						;hang
		.loadedSectors db 0
	;.error_boot:
	;	call print_dword
	;	mov ah, 0
	;	int 16h
	.boot:
		;xor edx, edx
		;mov dx, k_sectors;ax
		;mov bl, 08h
		;add [.loadedSectors], al
		;ror edx, 10h
		;mov dl, [.loadedSectors]
		;call print_dword
		;call newline
		call confirm
		jmp setup_boot
		;jmp $

confirm:
	mov cx, 32d
	.loop:
		mov bx, 32d
		sub bx, cx
		shl bx, 10d		;1024
		mov ax, 1000h
		mov ds, ax
		mov edx, [ds:bx]
		xor ax, ax
		mov ds, ax
		mov ax, cx
		mov bl, 4
		div bl
		cmp ah, 1
		pushf
		ror ecx, 10h
		call print_dword
		popf
		jne .skip_newline
		call newline
		.skip_newline:
		ror ecx, 10h
		loop .loop
	xor ah, ah
	int 16h
	ret

logicalToPhysical:		;ax = logical sector, this function can only handle up to 256 tracks
	xor dx, dx
	div word [BIOSParameterBlock.sectorsPerTrack]	;remainder in dx, but will never exceed dl
	xor cx, cx
	and dl, 00111111b
	mov cl, dl
	inc cl						;sectors start at 1
	xor dx, dx
	div word [BIOSParameterBlock.sides]
	mov ch, al
	mov dh, dl
	ret

newline:
	mov ah, 0eh
	xor bh, bh
	mov al, 0ah
	int 10h
	mov al, 0dh
	int 10h
	ret

print_dword:
	rol edx, 12d	; = ror 16+4
	mov ah, 0eh
	mov cx, 8
	.loop:
		push bx
		mov al, dh
		rol edx, 4
		and al, 0fh
		mov bx, strings.hex
		add bl, al
		adc bh, 0
		mov al, [bx]
		pop bx
		int 10h
		loop .loop
		ret

strings:
	.hex db "0123456789abcdef"

setup_boot:
	mov cx, 4
	.load:
		push cx
		mov ax, 1
		call logicalToPhysical
		xor bx, bx
		mov es, bx
		mov bx, 7e00h
		mov dl, [ExtendedBootRecord.drive]
		mov al, 1
		mov ah, 02h
		int 13h
		jnc .loaded
		pop cx
		loop .load
		jmp $
	.loaded:
		jmp kernel_boot

times 510 -( $ - $$ ) db 0
dw 0xaa55

FLAT_GDT_DISCRIPTOR:
	.bytes dw FLAT_GDT_END - FLAT_GDT_START - 1		;3 entries = 3 * 8 = 24 - 1 = 17h
	.address dd FLAT_GDT_START

FLAT_GDT_START:
FLAT_GDT_ZERO:
	.zero dq 0

FLAT_GDT_CODE:
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10011010b
	.limit1_flags db 11001111b
	.base2 db 0x00

FLAT_GDT_DATA:
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10010010b
	.limit1_flags db 11001111b
	.base2 db 0x00

FLAT_GDT_END:
FLAT_GDT_INFO:
	.KCS dw FLAT_GDT_CODE - FLAT_GDT_START
	.KDS dw FLAT_GDT_DATA - FLAT_GDT_START

kernel_boot:
	;load ds
	mov ax, 0;1000h
	mov ds, ax
	;set display mode while still possible
	mov ax, 0003h
	int 10h
	;enable A20
	mov ax, 2401h
	int 15h
	;switch to Protected Mode
	cli
	lgdt [FLAT_GDT_DISCRIPTOR]
	;make the switch
	mov eax, cr0	;for 386s and later
	or eax, 1
	mov cr0, eax
	;jump to kernel
	;jmp 08h:dword 10000h
	jmp 08h:dword PModeRelocate

bits 32
%define kernel_p_address 0x00100000
%define kernel_v_address 0x80000000
%define page_tables 0x00800000
%define page_directory 0x007ff000
PModeRelocate:
	mov ax, 10h
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov ecx, k_bytes
	shr ecx, 2
	mov esi, 10000h
	mov edi, kernel_p_address
	rep movsd
	;create page tables
	mov ecx, 400000h
	mov edi, page_tables
	xor eax, eax
	rep stosd
	;identity map the first 12 megabytes
	mov ecx, 0xc00
	.loop0:
		mov ebx, ecx
		dec ebx
		mov eax, ebx
		shl ebx, 2
		shl eax, 12
		or eax, 7;TODO: 3	;supervisor, r/w, present
		mov [page_tables + ebx], eax
		loop .loop0
	;map 12 megabytes for the kernel
	mov ecx, 0xc00
	.loop1:
		mov ebx, ecx
		dec ebx
		mov eax, ebx
		shl ebx, 2
		shl eax, 12
		add eax, kernel_p_address
		or eax, 7;TODO: 3	;supervisor, r/w, present
		mov [page_tables + 200000h + ebx], eax
		loop .loop1
	;create a directory
	mov edi, page_directory
	mov ecx, 1024d
	xor eax, eax
	rep stosd
	mov dword [page_directory], page_tables | 7;TODO: 3
	mov dword [page_directory+4], page_tables + 1000h | 7;TODO: 3
	mov dword [page_directory+8], page_tables + 2000h | 7;TODO: 3
	mov dword [page_directory+2048], page_tables + 200000h | 7;TODO: 3
	mov dword [page_directory+2052], page_tables + 201000h | 7;TODO: 3
	mov dword [page_directory+2056], page_tables + 202000h | 7;TODO: 3
	;now enable paging
	mov eax, page_directory
	mov cr3, eax
	mov eax, cr0
	or eax, 80000000h
	mov cr0, eax
	mov eax, [kernel_v_address]
	jmp kernel_v_address

times 1024 -( $ - $$ ) db 0

k_start:
incbin "Build/Kernel.bin"
k_end:

times 512 - k_bytes % 512 db 0xff

;sector numbering, useful to see which sector was loaded and where
;%rep 400h
;times 80h dd $-$$
;%endrep

; ---- 1.44 FAT12 FLOPPY ---- ;
times 1474560 -( $ - $$ ) db 0
; ---- 1.44 FAT12 FLOPPY ---- ;
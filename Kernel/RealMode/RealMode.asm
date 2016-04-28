%define kernel_realsegment 0x0e00
%define KERNEL_CS 08h
%define KERNEL_DS 10h
%define BIT16_CS 28h
%define BIT16_DS 30h
org kernel_realsegment * 10h
bits 32

black_magic:							;for some reason this bit gets modified... TODO: idk, do something about it...
	jmp BIT16_CS:.bits16
	.bits16:
	bits 16
	mov ax, BIT16_DS
	mov ds, ax
	mov ss, ax
	
	mov eax, cr0
	and eax, 0x7ffffffe				;clear protected mode bit and disable paging
	mov cr0, eax
	
	jmp 0:program.realmode			;important: CS = 0 !!!
	times 32 -( $ - $$ ) db 0

realmode:
	.int db 0
	.eax dd 0
	.ebx dd 0
	.ecx dd 0
	.edx dd 0
	.es dw 0
	.si dw 0
	.di dw 0
	.flags dw 0							;read only
	.bp dw 0							;read only
	.return dd 0						;return address
	.gdtr dw 0, 0 ,0					;gdtr to load

REAL_IDT:
	dw 3ffh
	dd 0

program:

	.realmode:
		xor ax, ax
		mov ds, ax
		mov es, ax
		mov fs, ax
		mov gs, ax
		xor ax, ax
		mov ss, ax
		mov sp, STACK + 1000h
		mov bp, STACK
		lidt [REAL_IDT]
	.call_BIOS:
		mov ax, [realmode.es]
		mov es, ax
		mov si, [realmode.si]
		mov di, [realmode.di]
		mov al, [realmode.int]
		mov [.INT_instruction+1], al	;set interrupt number
		mov eax, [realmode.eax]
		mov ebx, [realmode.ebx]
		mov ecx, [realmode.ecx]
		mov edx, [realmode.edx]
		sti
	.INT_instruction:
		int 0							;1 byte opcode followed by the 1 byte interrupt number
	.save_result:
		cli
		mov [realmode.bp], bp
		mov bp, STACK
		a16 pushf
		mov [realmode.eax], eax
		mov [realmode.ebx], ebx
		mov [realmode.ecx], ecx
		mov [realmode.edx], edx
		mov ax, es
		mov [realmode.es], ax
		mov [realmode.si], si
		mov [realmode.di], di
		pop ax
		mov [realmode.flags], ax
	.return_to_PM:
		lgdt [realmode.gdtr]
		mov eax, cr0
		or eax, 80000001h				;enable protected mode and paging
		mov cr0, eax
		jmp KERNEL_CS:dword .return

bits 32

	.return:
		mov ax, KERNEL_DS
		mov ds, ax
		jmp dword [realmode.return]

dd 0

STACK:
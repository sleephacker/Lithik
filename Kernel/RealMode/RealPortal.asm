%define real_all_offset 32
%define real_int_offset 0d + real_all_offset
%define real_eax_offset 1d + real_all_offset
%define real_ebx_offset 5d + real_all_offset
%define real_ecx_offset 9d + real_all_offset
%define real_edx_offset 13d + real_all_offset
%define real_es_offset 17d + real_all_offset
%define real_si_offset 19d + real_all_offset
%define real_di_offset 21d + real_all_offset
%define real_flags_offset 23d + real_all_offset
%define real_bp_offset 25d + real_all_offset
%define real_return_offset 27d + real_all_offset
%define real_gdtr_offset 31d + real_all_offset

bits 32

;32 bits code

real_gdtr0:
	.length dw 0
	.base dd 0

real_gdtr1:
	.length dw 0
	.base dd 10000h

;installs realmode code
real_boot:
	;mov eax, REALMODE
	;call boot_print_dword_default
	;mov eax, [REALMODE]
	;call boot_print_dword_default
	mov esi, REALMODE
	mov edi, kernel_realsegment * 10h
	mov ecx, REALMODE_END - REALMODE
	rep movsb
	mov esi, .msg
	call boot_print_default
	;mov eax, [kernel_realsegment * 10h]
	;call boot_print_dword_default
	;jmp $
	ret
	.msg db "Real Mode code installed.", 0

real_BIOS_INT:
	cli
	;backup GDT
	sgdt [real_gdtr0]
	xor ecx, ecx
	mov cx, [real_gdtr0]
	mov [real_gdtr1.length], cx
	inc ecx
	shr ecx, 2			;8 bytes per entry is multiple of 4
	mov esi, [real_gdtr0.base]
	mov edi, 10000h				;make backup here
	rep movsd
	lgdt [real_gdtr1]
	
	push dword [kernel_realsegment * 10h]		;protection against black_magic
	push dword [kernel_realsegment * 10h + 4]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 8]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 12]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 16]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 20]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 24]	;protection against black_magic
	push dword [kernel_realsegment * 10h + 28]	;protection against black_magic
	
	mov [.esp], esp
	mov [.ebp], ebp
	
	mov al, [.int]
	mov [kernel_realsegment * 10h + real_int_offset], al
	mov eax, [.eax]
	mov [kernel_realsegment * 10h + real_eax_offset], eax
	mov eax, [.ebx]
	mov [kernel_realsegment * 10h + real_ebx_offset], eax
	mov eax, [.ecx]
	mov [kernel_realsegment * 10h + real_ecx_offset], eax
	mov eax, [.edx]
	mov [kernel_realsegment * 10h + real_edx_offset], eax
	mov ax, [.es]
	mov [kernel_realsegment * 10h + real_es_offset], ax
	mov ax, [.si]
	mov [kernel_realsegment * 10h + real_si_offset], ax
	mov ax, [.di]
	mov [kernel_realsegment * 10h + real_di_offset], ax
	
	mov eax, .return
	mov [kernel_realsegment * 10h + real_return_offset], eax
	;copy the gdtr
	sgdt [kernel_realsegment * 10h + real_gdtr_offset]
	
	mov ax, BIT16_DS
	mov ds, ax
	;jmp BIT16_CS:kernel_realsegment * 10h	;realmode code has 16bits pmode entry
	jmp kernel_realsegment * 10h			;realmode code has 32bits pmode entry
	
	.return:
		lgdt [GDT_DESCRIPTOR]	;just to be sure
		mov ax, KERNEL_DS
		mov ds, ax
		mov ss, ax
		mov es, ax
		mov fs, ax
		mov gs, ax
		mov eax, [.esp]
		mov esp, eax
		mov eax, [.ebp]
		mov ebp, eax
		lidt [IDTR]
		sti
		
		pop dword [kernel_realsegment * 10h + 28]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 24]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 20]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 16]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 12]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 8]	;protection against black_magic
		pop dword [kernel_realsegment * 10h + 4]	;protection against black_magic
		pop dword [kernel_realsegment * 10h]		;protection against black_magic
		
		mov eax, [kernel_realsegment * 10h + real_eax_offset]
		mov [.eax], eax
		mov eax, [kernel_realsegment * 10h + real_ebx_offset]
		mov [.ebx], eax
		mov eax, [kernel_realsegment * 10h + real_ecx_offset]
		mov [.ecx], eax
		mov eax, [kernel_realsegment * 10h + real_edx_offset]
		mov [.edx], eax
		mov ax, [kernel_realsegment * 10h + real_es_offset]
		mov [.es], ax
		mov ax, [kernel_realsegment * 10h + real_si_offset]
		mov [.si], ax
		mov ax, [kernel_realsegment * 10h + real_di_offset]
		mov [.di], ax
		mov ax, [kernel_realsegment * 10h + real_flags_offset]
		mov [.flags], ax
		mov ax, [kernel_realsegment * 10h + real_bp_offset]
		mov [.bp], ax
		ret
	;interrupt number and realmode registers are loaded from here
	.int db 0
	.eax dd 0
	.ebx dd 0
	.ecx dd 0
	.edx dd 0
	.es dw 0
	.si dw 0
	.di dw 0
	.flags dw 0	;read only
	.bp dw 0	;read only
	;save stack stuff here, not to be used by caller
	.esp dd 0
	.ebp dd 0

real_test:
	mov byte [real_BIOS_INT.int], 12h
	call real_BIOS_INT
	ret

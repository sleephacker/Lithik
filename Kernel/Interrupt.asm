%define IRQ_base 32

PIC_mask_all:
	mov al, 0xff
	out 0x21, al
	out 0xa1, al
	ret

PIC_mask_none:
	mov al, 0
	out 0x21, al
	out 0xa1, al
	ret

;sets the handler for an IRQ
;IN: eax = IRQ, ebx = handler
;NOTE: sti
IRQ_set_handler:
	push eax
	call PIC_mask_all
	cli
	pop eax
	mov [IDT+(IRQ_base*8) + (eax * 8)], bx
	shr ebx, 16
	mov [IDT+(IRQ_base*8) + (eax * 8) + 6], bx
	sti
	call PIC_mask_none
	ret

IHP:
INT_HANDLER_placeholder:
	iret

;IN: error?, exception
%macro handle_exception 2
	xchg bx, bx
	mov byte [boot_exception.error], %1
	mov dword [boot_exception.exception], %2
	mov dword [boot_exception.return], .return
	jmp boot_exception
	.return:			;TODO: handle exceptions in VBE modes
		mov eax, %2		;not useful on real hardware, but at least somewhat helpful on bochs...
		jmp $
%endmacro

ERR_0:
	handle_exception 0, 0

ERR_1:
	handle_exception 0, 1

ERR_2:
	handle_exception 0, 2

ERR_3:
	handle_exception 0, 3

ERR_4:
	handle_exception 0, 4

ERR_5:
	handle_exception 0, 5

ERR_6:
	handle_exception 0, 6

ERR_7:
	handle_exception 0, 7

ERR_8:
	handle_exception 1, 8

ERR_9:
	handle_exception 0, 9

ERR_10:
	handle_exception 1, 10

ERR_11:
	handle_exception 1, 11

ERR_12:
	handle_exception 1, 12

ERR_13:
	handle_exception 1, 13

ERR_14:
	handle_exception 1, 14

ERR_15:
	handle_exception 0, 15

ERR_16:
	handle_exception 0, 16

ERR_17:
	handle_exception 1, 17

ERR_18:
	handle_exception 0, 18

ERR_19:
	handle_exception 0, 19

ERR_20:
	handle_exception 0, 20

ERR_30:
	handle_exception 1, 30

IRQ_0:
	push edi
	push esi
	push eax
	push ebx
	push ecx
	push edx
	pushfd
	
	mov eax, [.counter]
	inc eax
	mov [.counter], eax
	mov ebx, [.millis]
	mov ecx, ebx
	mov eax, 0
	mov al, [.inc]
	add ebx, eax
	mov [.millis], ebx
	
	xor edx, edx
	mov eax, ecx
	mov ebx, 7000d
	div ebx
	cmp edx, 6999d
	je .i0
	xor edx, edx
	mov eax, ecx
	mov ebx, 103000d
	div ebx
	cmp edx, 102999d
	je .i0
	xor edx, edx
	mov eax, ecx
	mov ebx, 3461000d
	div ebx
	cmp edx, 3460999d
	je .i2
	mov byte [.inc], 1
	mov ecx, [.millis]
	mov edx, ecx
	shr edx, 10h
	mov ax, cx
	mov bx, 1000d
	div bx
	cmp dx, 0d
	je .print
	jmp .return
	.i0:
		mov byte [.inc], 0
		jmp .print
	.i2:
		mov byte [.inc], 2
		;jmp .print
	
	.print:
		cmp byte [VBE_On], 1
		je .return
		mov eax, [.millis]
		mov edi, VGA_strings.dword
		call format_hex_dword
		mov ax, 304d					;160-8*2+160
		mov bl, 0x0e
		mov bh, 07h
		mov esi, VGA_strings.dword
		call boot_print
		mov eax, [.counter]
		mov edi, VGA_strings.dword
		call format_hex_dword
		mov ax, 464d					;160-8*2+320
		mov bl, 0x0d
		mov bh, 07h
		mov esi, VGA_strings.dword
		call boot_print
	.return:
		mov al, 20h
		out 00a0h, al
		out 0020h, al
		popfd
		pop edx
		pop ecx
		pop ebx
		pop eax
		pop esi
		pop edi
		iret
	.counter dd 0
	.millis dd 0
	.inc db 1

IRQ_1:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_2:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_3:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_4:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_5:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

%define IRQ_6 Floppy_IRQ_6

IRQ_7:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_8:			;TODO: fails after reboot, solved (sort off)
	push eax
	mov eax, [esp+4]	;eip
	mov [.eip], eax
	pop eax
	pushad
	
	mov al, 0ch
	out 70h, al
	in al, 71h
	;and al, 11000000b	;check if periodic interrupt flag is set
	;cmp al, 0
	;je .return
	
	mov eax, [.counter]
	inc eax
	mov [.counter], eax
	cmp byte [VBE_On], 1
	je .skip
	mov edi, VGA_strings.dword
	call format_hex_dword
	mov ax, 144d					;160-8*2
	mov bl, 0bh
	mov bh, 07h
	mov esi, VGA_strings.dword
	call boot_print
	mov eax, [.eip]
	mov edi, VGA_strings.dword
	call format_hex_dword
	mov ax, 624d					;4*160-8*2
	mov bl, 0fh
	mov bh, 07h
	mov esi, VGA_strings.dword
	call boot_print
	.skip:
		call Scheduler_Heartbeat
		
		mov al, 20h	
		out 00a0h, al
		out 0020h, al
	
	.return:
		popad
		iret
	.counter dd 0		;NOTE: boot_reboot.wait depends on this counter
	.eip dd 0

IRQ_9:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_10:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_11:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_12:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_13:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_14:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

IRQ_15:
	push ax			;PLACEHOLDER
	mov al, 20h		;PLACEHOLDER
	out 00a0h, al	;PLACEHOLDER
	out 0020h, al	;PLACEHOLDER
	pop ax			;PLACEHOLDER
	iret

%define idto2(a) (a - $$ + kernel_v_address) >> 16	;cool trick that makes NASM stop whining about scalar values!
%macro idt_err 1
	dw ERR_%1						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(ERR_%1)				;offset 2
%endmacro

%macro idt_ihp 0
	dw IHP							;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IHP)					;offset 2
%endmacro

IDTR:
	.limit dw 0x017f		;8*(32+16)-1
	.base dd IDT

IDT:
%assign idt_i 0
%rep 21
	idt_err idt_i
	%assign idt_i idt_i + 1
%endrep
;exceptions 21-29
%rep 9
	idt_ihp
%endrep

	idt_err 30
	idt_ihp

	dw IRQ_0						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_0)					;offset 2

	dw IRQ_1						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_1)					;offset 2

	dw IRQ_2						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_2)					;offset 2

	dw IRQ_3						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_3)					;offset 2

	dw IRQ_4						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_4)					;offset 2

	dw IRQ_5						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_5)					;offset 2

	dw IRQ_6						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_6)					;offset 2

	dw IRQ_7						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_7)					;offset 2

	dw IRQ_8						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_8)					;offset 2

	dw IRQ_9						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_9)					;offset 2

	dw IRQ_10						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_10)				;offset 2

	dw IRQ_11						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_11)				;offset 2

	dw IRQ_12						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_12)				;offset 2

	dw IRQ_13						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_13)				;offset 2

	dw IRQ_14						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_14)				;offset 2

	dw IRQ_15						;offset 1
	dw 08h							;selector
	db 0							;unused
	db 10001110b					;type
	dw idto2(IRQ_15)				;offset 2

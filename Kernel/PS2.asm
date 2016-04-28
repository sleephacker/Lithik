;NOTE:
;according to: http://wiki.osdev.org/%228042%22_PS/2_Controller
;"Before you touch the PS/2 controller at all, you should determine if it actually exists.
;	On some systems (e.g. 80x86 Apple machines) it doesn't exist and any attempt to touch it can result in a system crash."

PS2_boot:
	;TODO: set up PS/2 controller first
	.reset:
	call PS2_device_flush_response
	
	mov byte [PS2.command], 0xff		;reset + self-test
	call PS2_device_send_command_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip0
	call boot_log_byte_default
	.skip0:
	%endif
	
	cmp byte [PS2.response], 0xfa		;ack
	jne .reset
	
	call PS2_device_get_response_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip1
	call boot_log_byte_default
	.skip1:
	%endif
	
	cmp byte [PS2.response], 0xaa		;self-test completed and succesful
	jne .reset
	
	mov byte [PS2.command], 0xf0		;scancode
	mov byte al, [PS2.set]
	mov byte [PS2.command_data], al		;scancode set 1
	call PS2_device_send_command_data_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip2
	call boot_log_byte_default			;response for command
	.skip2:
	%endif
	call PS2_device_get_response_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip3
	call boot_log_byte_default			;response for data
	.skip3:
	%endif
	
	mov byte [PS2.command], 0xf4		;enable scanning
	call PS2_device_send_command_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip4
	call boot_log_byte_default
	.skip4:
	%endif
	
	mov byte [PS2.command], 0x20
	call PS2_controller_send_command_wait
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip5
	push ax
	mov bl, 0x04
	mov bh, 0xc4
	call boot_log_byte
	pop ax
	.skip5:
	%endif
	and al, 10111111b					;stop your stupid translation
	or al, 1							;send interrupts from first PS/2 port
	mov byte [PS2.command], 0x60
	mov byte [PS2.command_data], al
	call PS2_controller_send_command_data
	
	call PS2_device_flush_response
	
	%ifdef DEBUGBOOT
	or byte [boot_debug.ps2], 0
	jz .skip6
	mov byte [PS2.command], 0xee		;echo
	call PS2_device_send_command_wait
	call boot_log_byte_default
	call boot_newline
	.skip6:
	%endif
	
	mov esi, PS2_strings.init_complete
	call boot_print_default
	ret

PS2_dfr:
PS2_device_flush_response:
	mov ah, 0
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .return
	mov dx, 0x60
	in al, dx
	jmp PS2_dfr
	.return:
		ret

PS2_dgr:
PS2_device_get_response:
	mov ah, 0
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .return_false
	mov dx, 0x60
	in al, dx
	mov byte [PS2.response], al
	ret
	.return_false:
		mov ax, 0xffff
		ret

PS2_dgrw:
PS2_device_get_response_wait:
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz PS2_dgrw
	mov dx, 0x60
	in al, dx
	mov byte [PS2.response], al
	ret

PS2_dscw:
PS2_device_send_command_wait:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz PS2_dscw
	
	mov dx, 0x60
	mov al, [PS2.command]
	out dx, al
	
	.wait:
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .wait
	
	mov dx, 0x60
	in al, dx
	cmp al, 0xfe
	je PS2_dscw
	mov [PS2.response], al
	ret

PS2_dscdw:
PS2_device_send_command_data_wait:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz PS2_dscdw
	
	mov dx, 0x60
	mov al, [PS2.command]
	out dx, al
	
	.wait0:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz .wait0
	
	mov dx, 0x60
	mov al, [PS2.command_data]
	out dx, al
	
	.wait1:
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .wait1
	
	mov dx, 0x60
	in al, dx
	cmp al, 0xfe
	je PS2_dscdw
	mov [PS2.response], al
	ret

PS2_cscw:
PS2_controller_send_command_wait:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz PS2_cscw
	
	mov dx, 0x64
	mov al, [PS2.command]
	out dx, al
	
	.wait:
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .wait
	
	mov dx, 0x60
	in al, dx
	mov [PS2.response], al
	ret

PS2_cscd:
PS2_controller_send_command_data:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz PS2_cscdw
	
	mov dx, 0x64
	mov al, [PS2.command]
	out dx, al
	
	.wait:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz .wait
	
	mov dx, 0x60
	mov al, [PS2.command_data]
	out dx, al
	ret

PS2_cscdw:
PS2_controller_send_command_data_wait:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz PS2_cscdw
	
	mov dx, 0x64
	mov al, [PS2.command]
	out dx, al
	
	.wait0:
	mov dx, 0x64
	in al, dx
	test al, 00000010b
	jnz .wait0
	
	mov dx, 0x60
	mov al, [PS2.command_data]
	out dx, al
	
	.wait1:
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz .wait1
	
	mov dx, 0x60
	in al, dx
	mov [PS2.response], al
	ret

PS2_get_key:
	hlt				;PS/2 keyboard sends interrupts, waiting for them saves power
	mov dx, 0x64
	in al, dx
	test al, 00000001b
	jz PS2_get_key
	mov dx, 0x60
	in al, dx
	mov byte [PS2.scancode], al
	
	cmp al, 0xe0
	je .special
	mov ah, al
	and al, 80h
	jnz .null
	mov al, ah
	
	mov ebx, 0
	mov bl, al
	add ebx, scancode_set_1_char
	mov byte al, [ebx]
	mov [PS2.character], al
	ret
	.null:
		mov byte [PS2.character], 0
		ret
	.special:
		mov dx, 0x64
		in al, dx
		test al, 00000001b
		jz .special
		mov dx, 0x60
		in al, dx
		mov byte [PS2.special_scancode], al
		mov byte [PS2.character], 0
		ret

PS2_set_led:
	mov byte [PS2.command], 0xed
	mov byte al, [PS2.led]
	mov byte [PS2.command_data], al
	call PS2_device_send_command_data_wait
	ret

boot_PS2_cmd:	;TODO: multiple response bytes
	mov al, [boot_console.line_length]
	cmp al, 9		;ps2... + space + byte = 9
	jb .inv
	ja .word
	mov esi, boot_console.line+7
	call parse_hex_byte
	mov bl, 0
	mov bh, 0		;no error
	ret
	.word:
		mov esi, boot_console.line+7
		call parse_hex_word
		mov bl, 1
		mov bh, 0	;no error
		ret
	.con:
		call boot_PS2_cmd
		cmp bh, 0
		jne .inv_ret
		cmp ecx, 0
		jne .inv
		cmp bl, 0
		jne .cd
		mov [PS2.command], al
		call PS2_cscw
		jmp .ret
		.cd:
			mov [PS2.command], ah
			mov [PS2.command_data], al
			call PS2_cscdw
			jmp .ret
	.dev:
		call boot_PS2_cmd
		cmp bh, 0
		jne .inv_ret
		cmp ecx, 0
		jne .inv
		cmp bl, 0
		jne .dd
		mov [PS2.command], al
		call PS2_dscw
		jmp .ret
		.dd:
			mov [PS2.command], ah
			mov [PS2.command_data], al
			call PS2_dscdw
			jmp .ret
	.ret:
		mov al, [PS2.response]
		call boot_log_byte_default
		call boot_newline
		ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		mov bh, 1	;error
	.inv_ret:
		ret
	
PS2:
	.command db 0
	.command_data db 0
	.response db 0
	.scancode db 0
	.special_scancode db 0
	.character db 0
	.set db 1
	.led db 0

PS2_strings:
	.init_complete db "PS/2 keyboard initialization complete.", 0

scancode_set_1_char:
	.k00 db 0
	.k01 db 0
	.k02 db "1"
	.k03 db "2"
	.k04 db "3"
	.k05 db "4"
	.k06 db "5"
	.k07 db "6"
	.k08 db "7"
	.k09 db "8"
	.k0a db "9"
	.k0b db "0"
	.k0c db "-"
	.k0d db "="
	.k0e db 0		;BACKSPACE
	.k0f db 09h		;TAB
	.k10 db "q"
	.k11 db "w"
	.k12 db "e"
	.k13 db "r"
	.k14 db "t"
	.k15 db "y"
	.k16 db "u"
	.k17 db "i"
	.k18 db "o"
	.k19 db "p"
	.k1a db "["
	.k1b db "]"
	.k1c db 0ah		;ENTER
	.k1d db 0
	.k1e db "a"
	.k1f db "s"
	.k20 db "d"
	.k21 db "f"
	.k22 db "g"
	.k23 db "h"
	.k24 db "j"
	.k25 db "k"
	.k26 db "l"
	.k27 db ":"
	.k28 db "'"
	.k29 db "`"
	.k2a db 0		;2a = 42!
	.k2b db "\"
	.k2c db "z"
	.k2d db "x"
	.k2e db "c"
	.k2f db "v"
	.k30 db "b"
	.k31 db "n"
	.k32 db "m"
	.k33 db ","
	.k34 db "."
	.k35 db "/"
	.k36 db 0
	.k37 db "*"		;keypad
	.k38 db 0
	.k39 db " "
	.k3a db 0		;capslock
	.k3b db 0		;F1...
	.k3c db 0
	.k3d db 0
	.k3e db 0
	.k3f db 0
	.k40 db 0
	.k41 db 0
	.k42 db 0		;42!
	.k43 db 0
	.k44 db 0		;...F10
	.k45 db 0		;numlock
	.k46 db 0		;scrolllock
	.k47 db "7"		;keypad...
	.k48 db "8"
	.k49 db "9"
	.k4a db "-"
	.k4b db "4"
	.k4c db "5"
	.k4d db "6"
	.k4e db "+"
	.k4f db "1"
	.k50 db "2"
	.k51 db "3"
	.k52 db "0"
	.k53 db "."		;...keypad
	.k54 db 0		;nonexistent
	.k55 db 0		;nonexistent
	.k56 db 0		;nonexistent
	.k57 db 0		;F11
	.k58 db 0		;F12
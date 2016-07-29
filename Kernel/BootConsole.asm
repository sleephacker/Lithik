boot_console:
	mov byte [PS2.led], 1
	call PS2_set_led
	call PS2_dgrw
	.key:
		call PS2_get_key
		call PS2_set_led
		call PS2_dgrw
		
		mov al, [PS2.scancode]
		cmp al, 3bh				;F1
		je .help
		cmp al, 3ch				;F2
		je .clear
		cmp al, 0eh				;backspace
		je .backspace
		mov al, [PS2.character]
		cmp al, 0ah
		je .enter
		cmp byte [.line_length], 159
		je .done
		cmp al, 0
		je .done
		
		mov esi, PS2.character
		call boot_log_char_default
		
		mov al, [PS2.character]
		cmp al, 09h
		je .tab
		
		mov ebx, 0
		mov bl, [.line_length]
		add ebx, .line
		mov [ebx], al
		mov al, [.line_length]
		inc al
		mov [.line_length], al
		jmp .done
		
		.tab:
			mov ebx, 0
			mov bl, [.line_length]
			add ebx, .line
			mov byte [ebx], " "
			inc byte [.line_length]
			jmp .done
		.backspace:
			mov ebx, 0
			mov bl, [.line_length]
			cmp bl, 0
			je .done
			add ebx, .line
			mov byte [ebx], 0
			dec byte [.line_length]
			sub word [VGA.boot_safe_print], 2
			mov esi, VGA_spec_chars.space
			call boot_log_char_default
			sub word [VGA.boot_safe_print], 2
			mov esi, VGA_spec_chars.null
			call boot_log_char_default
			jmp .done
		.enter:
			mov ebx, 0
			mov bl, [.line_length]
			add ebx, .line
			mov byte [ebx], " "		;add space for completion
			;inc byte [.line_length]
			
			mov esi, PS2.character
			call boot_log_char_default
			call .execute_command
			jmp .done
		.help:
			cmp byte [.line_length], 0
			je .h
			call boot_newline
			mov byte [.line_length], 0
			.h:
			call boot_console_help
			jmp .done
		.clear:
			call boot_console_clear
			mov byte [.line_length], 0
			jmp .done
		.done:
			mov byte al, [PS2.led]
			shl al, 1
			cmp al, 8
			je .a
			mov byte [PS2.led], al
			jmp .key
		.a:
			mov byte [PS2.led], 1
			jmp .key
	
	.execute_command:
		mov ebx, boot_commands+1
		mov ecx, 0
		mov cl, [boot_commands]
		.loop:
			mov edx, ecx
			mov eax, [ebx]
			mov [.command], eax
			mov esi, .line
			mov edi, [ebx+4]
			mov ecx, 0
			mov cl, [edi]
			inc ecx
			inc edi
			repe cmpsb
			jcxz .call
			add ebx, 8
			mov ecx, edx
			loop .loop
		mov esi, boot_console.notfound
		call boot_print_default
	.execute_command_return:
		mov byte [.line_length], 0
		ret
	.call:
		call [.command]
		jmp .execute_command_return
	
	.command dd 0
	.line_length db 0
	.line times 160 db 0
	.notfound db "That command doesn't exist.", 0

boot_console_help:
	mov ebx, boot_commands+5
	mov ecx, 0
	mov cl, [boot_commands]
	cmp byte [boot_console.line_length], 5
	jbe .cmdlist
	.loop0:
		mov edx, ecx
		mov esi, boot_console.line+5
		mov edi, [ebx]
		mov ecx, 0
		mov cl, [edi]
		inc ecx
		inc edi
		repe cmpsb
		jcxz .found
		add ebx, 8
		mov ecx, edx
		loop .loop0
	mov esi, boot_console.notfound
	call boot_print_default
	ret
	.found:
		mov esi, edi
		dec esi
		call boot_print_default
		ret
	.cmdlist:
		.loop1:
			mov esi, [ebx]
			push ecx
			push ebx
			
			call boot_log_string_default
			mov eax, 0
			mov bx, [VGA.boot_safe_print]
			add bx, 40d
			mov ax, bx
			mov dx, 0
			mov cx, 40d
			div cx
			sub bx, dx
			mov [VGA.boot_safe_print], bx
			
			pop ebx
			pop ecx
			add ebx, 8
			loop .loop1
		mov eax, 0
		mov bx, [VGA.boot_safe_print]
		mov ax, bx
		mov dx, 0
		mov cx, 40d
		div cx
		add dx, 1
		sub bx, dx
		mov [VGA.boot_safe_print], bx
		mov esi, VGA_spec_chars.newline
		call boot_log_char_default
		ret

boot_console_echo:
	mov ebx, 0
	mov bl, [boot_console.line_length]
	cmp bl, 4							;no argument
	je .return
	add ebx, boot_console.line
	mov byte [ebx], 0
	mov esi, boot_console.line+5		;skip actual command
	call boot_print_default
	.return:
		ret

boot_console_clear:
	call boot_clear_screen
	mov word [VGA.boot_safe_print], 0
	mov ah, [VGA.print_defaults+1]
	mov al, 0
	shr ah, 4
	and ah, 0fh
	mov word [0xb8000], ax
	mov dx, [boot_data.video_base]
	mov al, 0fh						;select cursor low
	out dx, al
	mov al, 0
	inc dx
	out dx, al
	dec dx
	mov al, 0eh						;slect cursor high
	out dx, al
	mov al, 0
	inc dx
	out dx, al
	ret

boot_reboot:		;TODO: add BIOS int 19h method, or maybe not...
	mov al, [boot_console.line_length]
	cmp al, 9		;reboot + space + byte = 9
	jb .none
	mov esi, boot_console.line+7
	call parse_hex_byte
	cmp ecx, 0
	jne .none
	cmp al, 0
	je .ps2
	cmp al, 1
	je .pci
	cmp al, 2
	je .tripple_fault
	.none:
		mov esi, .no_option
		call boot_print_default
		ret
	.ps2:
		mov esi, .ps2msg
		call boot_print_default
		mov byte [PS2.command], 0xfe		;pulse reset line
		call PS2_cscw
		jmp .fail
	.pci:									;TODO: according to linux source code I should check for the right PCI type to know if this is safe.
		mov esi, .pcimsg
		call boot_print_default
		mov dx, 0cf9h
		mov al, 02h
		out dx, al
		call .wait
		mov al, 04h
		out dx, al
		jmp .fail
	.tripple_fault:
		mov esi, .triflt
		call boot_print_default
		lidt [.BAD_IDTR]
		int 3	;debug interrupt
		jmp .fail
		.BAD_IDTR dw 0, 0, 0
	.fail:
		mov esi, .failmsg
		call boot_print_default
		ret
	.wait:	;wait 4 clock ticks
		mov eax, [IRQ_8.counter]
		.w:
			mov ebx, [IRQ_8.counter]
			sub ebx, eax
			cmp ebx, 4
			jb .w
		ret
	.ps2msg db "Reboot: PS/2", 0
	.pcimsg db "Reboot: PCI / port 0cf9", 0
	.triflt db "Reboot: Tripple-fault", 0
	.no_option db "Please specify a valid method.", 0
	.failmsg db "Failed to reboot.", 0

boot_waits:
	mov al, [boot_console.line_length]
	cmp al, 14		;waits + space + dword = 14
	jb .ret
	mov esi, boot_console.line+6
	call parse_hex_dword
	call k_wait_short
	mov esi, strings.done
	call boot_print_default
	.ret:
		ret

boot_waitl:
	mov al, [boot_console.line_length]
	cmp al, 14		;waits + space + dword = 14
	jb .ret
	mov esi, boot_console.line+6
	call parse_hex_dword
	call k_wait_long
	mov esi, strings.done
	call boot_print_default
	.ret:
		ret

boot_gdtdump:
	sgdt [boot_XDTdump.xdtr]
	mov byte [boot_XDTdump.shl], 0
	jmp boot_XDTdump
boot_idtdump:
	sidt [boot_XDTdump.xdtr]
	mov byte [boot_XDTdump.shl], 3	;int * 8 = offset
boot_XDTdump:
	mov al, [boot_console.line_length]
	cmp al, 12		;xdtdump + space + word = 12
	jb .get_xdtr
	mov esi, boot_console.line+8
	call parse_hex_word
	cmp ecx, 0
	jne .get_xdtr
	mov cl, [.shl]
	shl ax, cl
	cmp ax, [.xdtr_limit]
	ja .get_xdtr
	xor ebx, ebx
	mov bx, ax
	add ebx, [.xdtr_base]
	mov ecx, 4
	.loop:
		push ecx
		push ebx
		mov eax, [ebx]
		call boot_print_word_default
		pop ebx
		add ebx, 2
		pop ecx
		loop .loop
	ret
	.get_xdtr:
		mov ax, [.xdtr_limit]
		call boot_print_word_default
		mov eax, [.xdtr_base]
		call boot_print_dword_default
		ret
	.xdtr:
		.xdtr_limit dw 0
		.xdtr_base dd 0
	.shl db 0

boot_kpread:
	mov al, [boot_console.line_length]
	cmp al, 11		;psread + space + word = 11
	jb .inv
	mov esi, boot_console.line+7
	call parse_hex_word
	cmp ecx, 0
	jne .inv
	cmp ax, [KP_INFO.max_index]
	ja .max
	xor ebx, ebx
	mov bx, ax
	add ebx, KERNEL_POINTER
	mov eax, [ebx]
	call boot_print_dword_default
	ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		ret
	.max:
		mov esi, .maxindex
		call boot_print_log_default
		mov ax, [KP_INFO.max_index]
		call boot_print_word_default
		ret
	.maxindex db "The maximum Kernel Pointer index is: ", 0

boot_kpinfo:
	mov esi, .limit
	call boot_print_log_default
	mov eax, [KP_INFO.limit]
	call boot_print_dword_default
	mov esi, .maxindex
	call boot_print_log_default
	mov ax, [KP_INFO.max_index]
	call boot_print_word_default
	ret
	.limit db "Limit:", 09h, 09h, 09h, 0
	.maxindex db "Maximum index:", 09h, 0

boot_boot:
	add esp, 4		;not going to return
	jmp boot.boot

boot_unboot:
	cmp byte [boot_console.line_length], 8	;unboot + space + option = at least 8
	jb .inv
	.find_floppy:
		mov al, 7							;unboot + space
		mov esi, .op_floppy
		call boot_console_parse_option_byte
		jecxz .floppy
		jmp .inv
	.floppy:
		shl eax, 28d	;lowest nibble becomes highest nibble, the rest is 0 (bootsector)
		mov ebx, floppy_bootsector
		mov edx, 1000d
		call floppy_write_sector
		call boot_print_word_default
		ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		ret
	.op_floppy db 7, "floppy="

boot_fdcinit:
	mov byte [Floppy_State.init], 0xff	;force it to initialize
	mov byte [floppy_init.output], 1
	call floppy_init
	mov byte [floppy_init.output], 0
	ret

boot_fdcdump:
	mov al, [boot_console.line_length]
	cmp al, 9			;fdcdump + space + option = at least 9
	jb .inv
	.find_state:
		mov al, 8			;fdcdump + space
		mov esi, .state
		call boot_console_find_option
		cmp al, 0
		je .dump_state
	.find_irq:
		mov al, 8
		mov esi, .irq
		call boot_console_find_option
		cmp al, 0
		je .dump_irq
	.find_transfer:
		mov al, 8
		mov esi, .transfer
		call boot_console_find_option
		cmp al, 0
		je .dump_transfer
	.find_disk:
		mov al, 8
		mov esi, .disk
		call boot_console_find_option
		cmp al, 0
		je .dump_disk
		ret
	.dump_state:
		mov esi, .state_title
		call boot_print_default
		mov esi, .state_init
		call boot_print_log_default
		mov al, [Floppy_State.init]
		call boot_print_byte_default
		mov esi, .state_dead
		call boot_print_log_default
		mov ax, [Floppy_State.dead]
		call boot_print_word_default
		mov esi, .state_last_op
		call boot_print_log_default
		mov ax, [Floppy_State.last_op]
		call boot_print_word_default
		mov esi, .state_last_ret
		call boot_print_log_default
		mov al, [Floppy_State.last_ret]
		call boot_print_byte_default
		mov esi, .state_config
		call boot_print_log_default
		mov al, [Floppy_State.config]
		call boot_print_byte_default
		mov esi, .state_DOR
		call boot_print_log_default
		mov al, [Floppy_State.DOR]
		call boot_print_byte_default
		mov esi, .state_drv0
		call boot_print_log_default
		mov al, [Floppy_State.drv0]
		call boot_print_byte_default
		mov esi, .state_drv1
		call boot_print_log_default
		mov al, [Floppy_State.drv1]
		call boot_print_byte_default
		mov esi, .state_drv2
		call boot_print_log_default
		mov al, [Floppy_State.drv2]
		call boot_print_byte_default
		mov esi, .state_drv3
		call boot_print_log_default
		mov al, [Floppy_State.drv3]
		call boot_print_byte_default
		mov esi, .state_drive
		call boot_print_log_default
		mov al, [Floppy_State.drive]
		call boot_print_byte_default
		mov esi, .state_motor
		call boot_print_log_default
		mov al, [Floppy_State.motor]
		call boot_print_byte_default
		jmp .find_irq
	.dump_irq:
		mov esi, .irq_title
		call boot_print_default
		mov esi, .irq_unhandled
		call boot_print_log_default
		mov eax, [Floppy_IRQ_6.unhandled]
		call boot_print_dword_default
		mov esi, .irq_expecting
		call boot_print_log_default
		mov eax, [Floppy_IRQ_6.expecting]
		call boot_print_dword_default
		mov esi, .irq_unexpected
		call boot_print_log_default
		mov eax, [Floppy_IRQ_6.unexpected]
		call boot_print_dword_default
		jmp .find_transfer
	.dump_transfer:
		mov esi, .transfer_title
		call boot_print_default
		mov esi, .transfer_op
		call boot_print_log_default
		mov ax, [Floppy_Transfer.op]
		call boot_print_word_default
		mov esi, .transfer_drive
		call boot_print_log_default
		mov al, [Floppy_Transfer.drive]
		call boot_print_byte_default
		mov esi, .transfer_cyl
		call boot_print_log_default
		mov al, [Floppy_Transfer.cyl]
		call boot_print_byte_default
		mov esi, .transfer_head
		call boot_print_log_default
		mov al, [Floppy_Transfer.head]
		call boot_print_byte_default
		mov esi, .transfer_sector
		call boot_print_log_default
		mov al, [Floppy_Transfer.sector]
		call boot_print_byte_default
		mov esi, .transfer_sectors
		call boot_print_log_default
		mov al, [Floppy_Transfer.sectors]
		call boot_print_byte_default
		mov esi, .transfer_gap
		call boot_print_log_default
		mov al, [Floppy_Transfer.gap]
		call boot_print_byte_default
		jmp .find_disk
	.dump_disk:
		mov esi, .disk_title
		call boot_print_default
		mov esi, .disk_drive
		call boot_print_log_default
		mov al, [Floppy_Disk.drive]
		call boot_print_byte_default
		mov esi, .disk_cylinders
		call boot_print_log_default
		mov ax, [Floppy_Disk.cylinders]
		call boot_print_word_default
		mov esi, .disk_sectPerCyl
		call boot_print_log_default
		mov ax, [Floppy_Disk.sectPerCyl]
		call boot_print_word_default
		mov esi, .disk_heads
		call boot_print_log_default
		mov ax, [Floppy_Disk.heads]
		call boot_print_word_default
		mov esi, .disk_maxLBA
		call boot_print_log_default
		mov ax, [Floppy_Disk.maxLBA]
		call boot_print_word_default
		ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		ret
	.state db 5, "state"
	.irq db 3, "irq"
	.transfer db 8, "transfer"
	.disk db 4, "disk"
	.state_title db "Floppy State:", 0
	.state_init db		"init:     ", 0
	.state_dead db		"dead:     ", 0
	.state_last_op db	"last_op:  ", 0
	.state_last_ret db	"last_ret: ", 0
	.state_config db	"config:   ", 0
	.state_DOR db		"DOR:      ", 0
	.state_drv0 db		"drv0:     ", 0
	.state_drv1 db		"drv1:     ", 0
	.state_drv2 db		"drv2:     ", 0
	.state_drv3 db		"drv3:     ", 0
	.state_drive db		"drive:    ", 0
	.state_motor db		"motor:    ", 0
	.irq_title db "Floppy IRQ 6:", 0
	.irq_unhandled db	"unhandled:  ", 0
	.irq_expecting db	"expecting:  ", 0
	.irq_unexpected db	"unexpected: ", 0
	.transfer_title db "Floppy Transfer:", 0
	.transfer_op db 	"op:      ", 0
	.transfer_drive db 	"drive:   ", 0
	.transfer_cyl db 	"cyl:     ", 0
	.transfer_head db 	"head:    ", 0
	.transfer_sector db "sector:  ", 0
	.transfer_sectors db"sectors: ", 0
	.transfer_gap db	"gap:     ", 0
	.disk_title db "Floppy Disk:", 0
	.disk_drive db			"drive:      ", 0
	.disk_cylinders db		"cylinders:  ", 0
	.disk_sectPerCyl db		"sectPerCyl: ", 0
	.disk_heads db			"heads:      ", 0
	.disk_maxLBA db			"maxLBA:     ", 0

boot_realtest:
	mov esi, .last_words
	call boot_print_default
	call real_test
	mov esi, .survived
	call boot_print_default
	ret
	.last_words db "Testing Real Mode...", 0
	.survived db "Test complete.", 0

boot_callbios:
	mov al, [boot_console.line_length]
	cmp al, 11d		;callbios + space + byte = 12
	jb .inv
	mov esi, boot_console.line+9
	call parse_hex_byte
	cmp ecx, 0
	jne .inv
	mov [real_BIOS_INT.int], al
	jmp .parse_eax
	.def_eax:
		mov [real_BIOS_INT.eax], eax
		jmp .parse_ebx		;continue
	.parse_eax:
		mov al, 9
		mov esi, .eax
		call boot_console_parse_option_dword
		jecxz .def_eax		;if no errors occured, define ax, otherwise set ax to 0 and continue
		mov dword [real_BIOS_INT.eax], 0
		jmp .parse_ebx		;continue
	.def_ebx:
		mov [real_BIOS_INT.ebx], eax
		jmp .parse_ecx
	.parse_ebx:
		mov al, 9
		mov esi, .ebx
		call boot_console_parse_option_dword
		jecxz .def_ebx
		mov dword [real_BIOS_INT.ebx], 0
		jmp .parse_ecx
	.def_ecx:
		mov [real_BIOS_INT.ecx], eax
		jmp .parse_edx
	.parse_ecx:
		mov al, 9
		mov esi, .ecx
		call boot_console_parse_option_dword
		jecxz .def_ecx
		mov dword [real_BIOS_INT.ecx], 0
		jmp .parse_edx
	.def_edx:
		mov [real_BIOS_INT.edx], eax
		jmp .parse_es
	.parse_edx:
		mov al, 9
		mov esi, .edx
		call boot_console_parse_option_dword
		jecxz .def_edx
		mov dword [real_BIOS_INT.edx], 0
		jmp .parse_es
	.def_es:
		mov [real_BIOS_INT.es], ax
		jmp .parse_si
	.parse_es:
		mov al, 9
		mov esi, .es
		call boot_console_parse_option_word
		jecxz .def_es
		mov word [real_BIOS_INT.es], 0
		jmp .parse_si
	.def_si:
		mov [real_BIOS_INT.si], ax
		jmp .parse_di
	.parse_si:
		mov al, 9
		mov esi, .si
		call boot_console_parse_option_word
		jecxz .def_si
		mov word [real_BIOS_INT.si], 0
		jmp .parse_di
	.def_di:
		mov [real_BIOS_INT.di], ax
		jmp .confirm
	.parse_di:
		mov al, 9
		mov esi, .di
		call boot_console_parse_option_word
		jecxz .def_di
		mov word [real_BIOS_INT.di], 0
		jmp .confirm
	.confirm:
		call .print_real_registers
		call boot_console_confirm
		cmp al, 0
		je .go4it
		ret
	.go4it:
		call real_BIOS_INT
		call .print_real_registers
		mov esi, .flags
		call boot_log_string_default
		mov ax, [real_BIOS_INT.flags]
		call boot_print_word_default
		mov esi, .bp
		call boot_log_string_default
		mov ax, [real_BIOS_INT.bp]
		call boot_print_word_default
		ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		ret
	.print_real_registers:
		mov esi, .eax
		call boot_log_string_default
		mov eax, [real_BIOS_INT.eax]
		call boot_print_dword_default
		mov esi, .ebx
		call boot_log_string_default
		mov eax, [real_BIOS_INT.ebx]
		call boot_print_dword_default
		mov esi, .ecx
		call boot_log_string_default
		mov eax, [real_BIOS_INT.ecx]
		call boot_print_dword_default
		mov esi, .edx
		call boot_log_string_default
		mov eax, [real_BIOS_INT.edx]
		call boot_print_dword_default
		mov esi, .es
		call boot_log_string_default
		mov ax, [real_BIOS_INT.es]
		call boot_print_word_default
		mov esi, .si
		call boot_log_string_default
		mov ax, [real_BIOS_INT.si]
		call boot_print_word_default
		mov esi, .di
		call boot_log_string_default
		mov ax, [real_BIOS_INT.di]
		call boot_print_word_default
		ret
	.eax db 4, "eax="
	.ebx db 4, "ebx="
	.ecx db 4, "ecx="
	.edx db 4, "edx="
	.es db 3, "es="
	.si db 3, "si="
	.di db 3, "di="
	.flags db 6, "flags="
	.bp db 3, "bp="

boot_mmap:
	mov ebx, [memory_e820_map.address]
	xor eax, eax
	.loop:
		push eax
		call .print_ebx_qword
		add ebx, 8
		call .print_ebx_qword
		add ebx, 8
		call .print_ebx_qword
		add ebx, e820_entry-16d		;must be positive, e820_entry must be at least 24
		push ebx
		call boot_newline
		pop ebx
		pop eax
		add eax, e820_entry
		cmp eax, [memory_e820_map.size]
		jbe .loop
		ret
	.print_ebx_qword:
		mov eax, [ebx+4]
		push ebx
		call boot_log_dword_default
		pop ebx
		mov eax, [ebx]
		push ebx
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		pop ebx
		ret

;TODO: add sanity checks
boot_mlist:
	mov esi, [mm.base]
	.loop:
		push esi
		push dword [esi+MM_HEADER.next]
		push dword [esi+MM_HEADER.prev]
		push dword [esi+MM_HEADER.info]
		push dword [esi+MM_HEADER.size]
		mov eax, esi
		call .print
		pop eax
		call .print
		pop eax
		call .print
		pop eax
		call .print
		pop eax
		call .print
		call boot_newline
		pop esi
		test dword [esi+MM_HEADER.info], MM_END
		jnz .ret
		mov esi, [esi+MM_HEADER.next]
		jmp .loop
	.ret:
		ret
	.print:
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		ret

boot_tpool:
	call Tasking_Pause
	mov esi, [Scheduler.currentThreadPool]
	mov ecx, [esi + ThreadPool.Qnum]
	add esi, ThreadPool.Qs
	.loop:
		push ecx
		push esi
		push dword [esi + ThreadQ.active]
		mov eax, [esi + ThreadQ.count]
		call .print
		pop eax
		call .print
		call boot_newline
		mov esi, [esp]
		mov eax, [esi + ThreadQ.first]
		cmp eax, Tasking_NULLADDR
		je .skipQ
		.Qloop:
			push eax
			push dword [eax + Thread.next]
			push eax
			push dword [eax + Thread.prev]
			push dword [eax + Thread.flags]
			push dword [eax + Thread.id]
			mov eax, [eax + Thread.priority]
			call .print
			pop eax
			call .print
			pop eax
			call .print
			pop eax
			call .print
			pop eax
			call .print
			pop eax
			call .print
			call boot_newline
			pop eax
			mov eax, [eax + Thread.next]
			cmp eax, Tasking_NULLADDR
			jne .Qloop
		.skipQ:
		pop esi
		pop ecx
		add esi, ThreadQ.struc_size
		loop .loop
		call Tasking_Resume
		ret
	.print:
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		ret

boot_twait:
	mov esi, [Scheduler.threadTimers]
	.loop:
		cmp esi, Tasking_NULLADDR
		je .ret
		push esi
		push dword [esi + SchedulerTimer.next]
		push dword [esi + SchedulerTimer.prev]
		push dword [esi + SchedulerTimer.delta]
		mov eax, [esi + SchedulerTimer.pointer]
		mov eax, [eax + Thread.id]
		call .print
		pop eax
		call .print
		pop eax
		call .print
		pop eax
		call .print
		call boot_newline
		pop esi
		mov esi, [esi + SchedulerTimer.next]
		jmp .loop
	.ret:ret
	.print:
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		ret

boot_vbemode:
	cmp byte [boot_console.line_length], 22		;vbemode + space + word + space + word + space + word = 22
	jb .inv
	mov esi, boot_console.line+8
	call parse_hex_word
	cmp ecx, 0
	jne .inv
	mov [.x], ax
	mov esi, boot_console.line+13
	call parse_hex_word
	cmp ecx, 0
	jne .inv
	mov [.y], ax
	mov esi, boot_console.line+18
	call parse_hex_word
	cmp ecx, 0
	jne .inv
	mov [VBE_desired_mode.bpp], ah
	mov [VBE_desired_mode.minBpp], al
	mov ax, [.x]
	mov [VBE_desired_mode.Xres], ax
	mov ax, [.y]
	mov [VBE_desired_mode.Yres], ax
	ret
	.inv:
		mov esi, strings.invalid_input
		call boot_print_default
		ret
	.x dw 0
	.y dw 0

boot_e9hack:
	cmp byte [boot_console.line_length], 7		;e9hack + space + text = more than 7
	jna .test
	mov esi, boot_console.line + 7
	mov cl, [boot_console.line_length]
	sub cl, 7
	.loop:
		lodsb
		out 0xe9, al
		loop .loop
		mov al, 0ah
		out 0xe9, al
		ret
	.test:
		in al, 0xe9
		call boot_print_byte_default
		ret

boot_slist:
	mov ebx, [Storage.devices]
	call list_first
	cmp eax, LIST_NULL
	je .ret
	.devloop:
		push ebx
		push eax
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		mov eax, [esp]
		mov ax, [eax + StorageDevice.devType]
		call boot_print_word_default
		pop eax
		pop ebx
		call list_next
		cmp eax, LIST_NULL
		jne .devloop
	mov ebx, [Storage.volumes]
	call list_first
	cmp eax, LIST_NULL
	je .ret
	.volloop:
		push ebx
		push eax
		mov eax, [eax + StorageVolume.device]
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		mov eax, [esp]
		mov ax, [eax + StorageVolume.fsType]
		call boot_log_word_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		mov eax, [esp]
		mov eax, [eax + StorageVolume.size + 4]
		call boot_log_dword_default
		mov eax, [esp]
		mov eax, [eax + StorageVolume.size]
		call boot_log_dword_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		mov esi, [esp]
		add esi, StorageVolume.letter
		call boot_log_char_default
		mov esi, VGA_spec_chars.tab
		call boot_log_char_default
		mov eax, [esp]
		mov esi, [eax + StorageVolume.name]
		cmp esi, Storage_NULL
		je .nameless
		call boot_print_default
		jmp .next
		.nameless:
		call boot_newline
		.next:
		pop eax
		pop ebx
		call list_next
		cmp eax, LIST_NULL
		jne .volloop
	.ret:ret

boot_console_confirm:			;al = 0 = confirmed
	mov esi, strings.confirm
	call boot_print_default
	.decision:
		call PS2_get_key
		mov al, [PS2.scancode]
		cmp al, 0eh				;backspace
		je .cancel
		cmp al, 1ch				;enter
		je .confirm
		jmp .decision
	.cancel:
		mov al, 1
		ret
	.confirm:
		mov al, 0
		ret

boot_console_find_option:		;al = characters to skip, esi = option (byte length + string option), result al: 0 = success / 1 = fail, ah = index
	xor ebx, ebx
	mov bl, al
	add ebx, boot_console.line
	mov edi, ebx
	mov ah, [boot_console.line_length]
	sub ah, al
	mov al, [esi]
	inc esi
	call find_string_256
	ret

boot_console_parse_option_byte:		;al = characters to skip, esi = option (byte length + string option), if ecx isn't zero its an error
	xor ebx, ebx
	mov bl, al
	add ebx, boot_console.line
	mov edi, ebx
	mov ah, [boot_console.line_length]
	sub ah, al
	mov al, [esi]
	inc esi
	push edi
	push esi
	call find_string_256
	pop esi
	dec esi
	pop edi
	cmp al, 0
	jne .fail
	xor ebx, ebx
	mov bl, [esi]	;length
	add bl, ah		;offset
	add ebx, edi	;base
	mov esi, ebx
	call parse_hex_byte
	ret
	.fail:
		mov ecx, 1
		ret

boot_console_parse_option_word:		;al = characters to skip, esi = option (byte length + string option), if ecx isn't zero its an error
	xor ebx, ebx
	mov bl, al
	add ebx, boot_console.line
	mov edi, ebx
	mov ah, [boot_console.line_length]
	sub ah, al
	mov al, [esi]
	inc esi
	push edi
	push esi
	call find_string_256
	pop esi
	dec esi
	pop edi
	cmp al, 0
	jne .fail
	xor ebx, ebx
	mov bl, [esi]	;length
	add bl, ah		;offset
	add ebx, edi	;base
	mov esi, ebx
	call parse_hex_word
	ret
	.fail:
		mov ecx, 1
		ret

boot_console_parse_option_dword:	;al = characters to skip, esi = option (byte length + string option), if ecx isn't zero its an error
	xor ebx, ebx
	mov bl, al
	add ebx, boot_console.line
	mov edi, ebx
	mov ah, [boot_console.line_length]
	sub ah, al
	mov al, [esi]
	inc esi
	push edi
	push esi
	call find_string_256
	pop esi
	dec esi
	pop edi
	cmp al, 0
	jne .fail
	xor ebx, ebx
	mov bl, [esi]	;length
	add bl, ah		;offset
	add ebx, edi	;base
	mov esi, ebx
	call parse_hex_dword
	ret
	.fail:
		mov ecx, 1
		ret

bc:
boot_commands:
	.length db (.end-.start)/8		;two 32 bit pointers per command
	.start:
	
	.help dd boot_console_help
	.help_string dd boot_command_strings.help
	
	.echo dd boot_console_echo
	.echo_string dd boot_command_strings.echo
	
	.clear dd boot_console_clear
	.clear_string dd boot_command_strings.clear
	
	.reboot dd boot_reboot
	.reboot_string dd boot_command_strings.reboot
	
	.viddef dd boot_viddef
	.viddef_string dd boot_command_strings.viddef
	
	.vgapal dd boot_vgapal
	.vgapal_string dd boot_command_strings.vgapal
	
	.pcilist dd boot_PCI_device_list
	.pcilist_string dd boot_command_strings.pcilist
	
	.pcifind dd boot_PCI_find
	.pcifind_string dd boot_command_strings.pcifind
	
	.ps2con dd boot_PS2_cmd.con
	.ps2con_string dd boot_command_strings.ps2con
	
	.ps2dev dd boot_PS2_cmd.dev
	.ps2dev_string dd boot_command_strings.ps2dev
	
	.waits dd boot_waits
	.waits_string dd boot_command_strings.waits
	
	.waitl dd boot_waitl
	.waitl_string dd boot_command_strings.waitl
	
	.gdtdump dd boot_gdtdump
	.gdtdump_string dd boot_command_strings.gdtdump
	
	.idtdump dd boot_idtdump
	.idtdump_string dd boot_command_strings.idtdump
	
	.kpread dd boot_kpread
	.kpread_string dd boot_command_strings.kpread
	
	.kpinfo dd boot_kpinfo
	.kpinfo_string dd boot_command_strings.kpinfo
	
	.boot dd boot_boot
	.boot_string dd boot_command_strings.boot
	
	.unboot dd boot_unboot
	.unboot_string dd boot_command_strings.unboot
	
	.fdcinit dd boot_fdcinit
	.fdcinit_string dd boot_command_strings.fdcinit
	
	.fdcdump dd boot_fdcdump
	.fdcdump_string dd boot_command_strings.fdcdump
	
	.realtest dd boot_realtest
	.realtest_string dd boot_command_strings.realtest
	
	.callbios dd boot_callbios
	.callbios_string dd boot_command_strings.callbios
	
	.mmap dd boot_mmap
	.mmap_string dd boot_command_strings.mmap
	
	.mlist dd boot_mlist
	.mlist_string dd boot_command_strings.mlist
	
	.tpool dd boot_tpool
	.tpool_string dd boot_command_strings.tpool
	
	.twait dd boot_twait
	.twait_string dd boot_command_strings.twait
	
	.vbemode dd boot_vbemode
	.vbemode_string dd boot_command_strings.vbemode
	
	.e9hack dd boot_e9hack
	.e9hack_string dd boot_command_strings.e9hack
	
	.netinit dd network_init
	.netinit_string dd boot_command_strings.netinit
	
	.slist dd boot_slist
	.slist_string dd boot_command_strings.slist
	.end:

bcs:
boot_command_strings:
	.help db 5, "help ", "Displays a list of commands or gives info on a specific command.", 0ah, "F1 also displays a list of commands.", 0
	.echo db 5, "echo ", "Prints a string.", 0
	.clear db 6, "clear ", "Clears the screen.", 0ah, "F2 also clears the screen.", 0
	.reboot db 7, "reboot ", "Reboots using the specified method.", 0ah, "Methods: ",
															db 0ah, 09h, "00 PS/2 keyboard controller",
															db 0ah, 09h, "01 PCI / port 0cf9"
															db 0ah, 09h, "02 Tripple-fault", 0
	.viddef db 7, "viddef ", "Gets/sets video defaults.", 0ah, "Format: dword lCursor_lOps_lBgclr_lFclr_pCursor_pOps_pBgclr_pFclr", 0
	.vgapal db 7, "vgapal ", "Gets/sets VGA palette registers.", 0ah, "Format: word palette_color", 0
	.pcilist db 8, "pcilist ", "Displays a list of PCI devices.", 0
	.pcifind db 8, "pcifind ", "Finds the first PCI device that matches the specified Vendor ID & Device ID.", 0ah, "Format: dword deviceID_vendorID", 0
	.ps2con db 7, "ps2con ", "Sends up to two bytes to the PS/2 Controller.", 0ah, "Format: 1 or 2 bytes 1stByte_2ndByte", 0
	.ps2dev db 7, "ps2dev ", "Sends up to two bytes to the PS/2 Device.", 0ah, "Format: 1 or 2 bytes 1stByte_2ndByte", 0
	.waits db 6, "waits ", "Waits a specified amount of milliseconds (using IRQ 0 counter).", 0ah, "Format: dword millis", 0ah, "Warning: don't use the keyboard until the command is done.", 0
	.waitl db 6, "waitl ", "Waits a specified amount of milliseconds (using actual milliseconds).", 0ah, "Format: dword millis", 0ah, "Warning: don't use the keyboard until the command is done.", 0
	.gdtdump db 8, "gdtdump ", "Dumps a GDT entry as 4 words, or the GDTR if no valid selector is specified.", 0ah, "Format: word selector", 0
	.idtdump db 8, "idtdump ", "Dumps an IDT entry as 4 words, or the IDTR if no valid interrupt is specified.", 0ah, "Format: word interrupt", 0
	.kpread db 7, "kpread ", "Reads an address from the Kernel Pointers at the specified index.", 0ah, "Format: word index", 0
	.kpinfo db 7, "kpinfo ", "Displays information about the Kernel Pointers.", 0
	.boot db 5, "boot ", "Boots the Operating System.", 0
	.unboot db 7, "unboot ", "Installs a placeholder bootsector on a drive.", 0ah, "Options:", 0ah, 09h, "byte floppy=", 0
	.fdcinit db 8, "fdcinit ", "Initializes the Floppy Drive Controller.", 0
	.fdcdump db 8, "fdcdump ", "Dumps FDC information.", 0ah, "Options: state, irq, transfer, disk", 0
	.realtest db 9, "realtest ", "Tests Real Mode.", 0
	.callbios db 9, "callbios ", "Calls a BIOS Interrupt in Real Mode.", 0ah, "Format: byte interrupt", 0ah, "Options: ",
																								db 0ah, 09h, "eax=",
																								db 0ah, 09h, "ebx=",
																								db 0ah, 09h, "ecx=",
																								db 0ah, 09h, "edx=",
																								db 0ah, 09h, "es=",
																								db 0ah, 09h, "si=",
																								db 0ah, 09h, "di=", 0
	.mmap db 5, "mmap ", "Displays the BIOS Int 15, e820 memory map.", 0
	.mlist db 6, "mlist ", "Displays a list of all memory blocks.", 0
	.tpool db 6, "tpool ", "Displays all threads in the current thread pool.", 0
	.twait db 6, "twait ", "Displays a list of all waiting threads.", 0
	.vbemode db 8, "vbemode ", "Sets the desired resolution and depth.", 0ah, "Format: word Xres word Yres word bpp_minBpp", 0
	.e9hack db 7, "e9hack ", "Reads/writes port 0xE9.", 0
	.netinit db 8, "netinit ", "?", 0
	.slist db 6, "slist ", "Displays a list of storage devices and volumes"

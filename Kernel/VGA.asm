VGA_boot:
	mov dx, [0463h]
	mov [boot_data.video_base], dx
	;set cursor start and end to occupy a full space.
	mov al, 0ah		;select cursor start
	out dx, al
	mov al, 0
	inc dx
	out dx, al
	mov al, 0bh		;select cursor end
	dec dx
	out dx, al
	mov al, 0fh
	inc dx
	out dx, al
	ret

VGA_set_palette:	;ah = palette, al = color
	mov bx, ax
	mov dx, [boot_data.video_base]
	add dx, 06h		;3?4h + 06h = 3?ah
	in al, dx
	mov al, bh		;disables signal
	mov dx, 03c0h
	out dx, al		;index
	mov al, bl
	out dx, al		;value
	mov al, 20h		;enable signal
	out dx, al		;index
	ret

VGA_get_palette:	;ah = palette -> ah = color
	mov dx, [boot_data.video_base]
	add dx, 06h		;3?4h + 06h = 3?ah
	in al, dx
	mov al, ah		;disable signal
	mov dx, 03c0h
	out dx, al
	inc dx
	in al, dx
	mov ah, al
	dec dx
	out dx, al		;same color
	mov al, 20h		;enable signal
	out dx, al
	ret

boot_clear_screen:
	mov ecx, 8000d	;25 lines * 80 characters * 2 bytes * 8 pages / 4(32 bits)
	.loop:
	shl ecx, 2
	add ecx, 0xb7ffd
	mov dword [ecx], 0
	sub ecx, 0xb7ffd
	shr ecx, 2
	loop .loop
	ret
	

boot_print:		;eax = position, bl = color, bh (low nibble) = options (0 = default), bh (high nibble) = cursor color (if required)
	mov edi, 0xb8000
	and eax, 0xffff
	add edi, eax
	.loop:
		lodsb
		cmp al, [VGA_spec_chars.tab]
		je .tab
		cmp al, [VGA_spec_chars.newline]
		je .newlineloop
		cmp al, 0
		je .return
		mov [edi], al
		mov [edi+1], bl
		add edi, 2
		jmp .loop
	.tab:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d
		div cx
		mov ax, dx
		mov dx, 0
		mov cl, [VGA.tab_spaces]
		mov ch, 0
		shl cx, 1					;2 bytes per character
		and ecx, 0xffff
		add edi, ecx
		div cx
		and edx, 0xffff
		sub edi, edx
		jmp .loop
	.newlineloop:
		call .newline
		jmp .loop
	.newline:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d	;one line
		div cx
		add edi, 160d
		and edx, 0xffff
		sub edi, edx
		ret
	.return:
		mov bl, bh
		and bl, 00000010b
		jnz .skipUpdate
		call .update
		.skipUpdate:
		mov bl, bh
		and bl, 00000001b
		jnz .skipCursor
		call .setCursor		;must be last
		.skipCursor:
		ret
	.setCursor:		;see: http://wiki.osdev.org/Text_Mode_Cursor
		shr bh, 4
		mov [edi+1], bh
		mov ebx, edi
		sub ebx, 0xb8000
		shr ebx, 1
		mov dx, [boot_data.video_base]
		mov al, 0fh						;select cursor low
		out dx, al
		mov al, bl
		inc dx
		out dx, al
		dec dx
		mov al, 0eh						;select cursor high
		out dx, al
		inc dx
		mov al, bh
		out dx, al
		ret
	.update:							;TODO: scroll
		mov bl, bh
		and bl, 00000100b
		jnz .skipNewline
		call .newline
		.skipNewline:
		mov eax, edi
		sub eax, 0xb8000
		mov [VGA.boot_safe_print], ax
		;sub ax, 4000d	;25 * 80 * 2 bytes
		;jnc .scroll
		ret
	.scroll:
		add ax, 160d
		mov dx, ax
		shl eax, 10h
		mov ax, dx
		mov dx, 0
		mov cx, 160d
		div cx
		shr eax, 10h	;high 16 bits are 0
		sub ax, dx
		xor ecx, ecx
		mov cx, ax
		;mov word [VGA.boot_safe_print], 3840d	;4000-160
		add eax, 0xb8000
		mov esi, eax
		mov edi, 0xb8000
		rep movsb		;copy
		mov edi, 3840d+0xb8000
		ret

boot_print_default:
	mov ax, [VGA.boot_safe_print]
	mov bx, [VGA.print_defaults]
	call boot_print
	ret

boot_print_log_default:
	mov ax, [VGA.boot_safe_print]
	mov bx, [VGA.log_defaults]		;use log defaults
	call boot_print
	ret

boot_log_char:		;eax = position, bl = color, bh (low nibble) = options (0 = default), bh (high nibble) = cursor color (if required)
	mov edi, 0xb8000
	and eax, 0xffff
	add edi, eax
	
	lodsb
	cmp al, [VGA_spec_chars.tab]
	je .tab
	cmp al, [VGA_spec_chars.newline]
	je .newlineReturn
	cmp al, 0
	je .return
	mov [edi], al
	mov [edi+1], bl
	add edi, 2
	jmp .return
	.tab:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d
		div cx
		mov ax, dx
		mov dx, 0
		mov cl, [VGA.tab_spaces]
		mov ch, 0
		shl cx, 1					;2 bytes per character
		and ecx, 0xffff
		add edi, ecx
		div cx
		and edx, 0xffff
		sub edi, edx
		jmp .return
	.newlineReturn:
		call .newline
		jmp .return
	.newline:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d	;one line
		div cx
		add edi, 160d
		and edx, 0xffff
		sub edi, edx
		ret
	.return:
		mov bl, bh
		and bl, 00000010b
		jnz .skipUpdate
		call .update
		.skipUpdate:
		mov bl, bh
		and bl, 00000001b
		jnz .skipCursor
		call .setCursor		;must be last
		.skipCursor:
		ret
	.setCursor:		;see: http://wiki.osdev.org/Text_Mode_Cursor
		shr bh, 4
		mov [edi+1], bh
		mov ebx, edi
		sub ebx, 0xb8000
		shr ebx, 1
		mov dx, [boot_data.video_base]
		mov al, 0fh						;select cursor low
		out dx, al
		mov al, bl
		inc dx
		out dx, al
		dec dx
		mov al, 0eh						;slect cursor high
		out dx, al
		inc dx
		mov al, bh
		out dx, al
		ret
	.update:							;TODO: scroll
		mov bl, bh
		and bl, 00000100b
		jnz .skipNewline
		call .newline
		.skipNewline:
		mov eax, edi
		sub eax, 0xb8000
		mov [VGA.boot_safe_print], ax
		;sub ax, 4000d	;25 * 80 * 2 bytes
		;jnc .scroll
		ret
	.scroll:
		add ax, 160d
		mov dx, ax
		shl eax, 10h
		mov ax, dx
		mov dx, 0
		mov cx, 160d
		div cx
		shr eax, 10h	;high 16 bits are 0
		sub ax, dx
		xor ecx, ecx
		mov cx, ax
		;mov word [VGA.boot_safe_print], 3840d	;4000-160
		add eax, 0xb8000
		mov esi, eax
		mov edi, 0xb8000
		rep movsb		;copy
		mov edi, 3840d+0xb8000
		ret

boot_log_char_default:
	mov ax, [VGA.boot_safe_print]
	mov bx, [VGA.log_defaults]
	call boot_log_char
	ret

boot_log_string:		;eax = position, bl = color, bh (low nibble) = options (0 = default), bh (high nibble) = cursor color (if required)
	mov edi, 0xb8000
	and eax, 0xffff
	add edi, eax
	mov ecx, 0
	mov cl, [esi]
	inc esi
	.loop:
		push ecx
		lodsb
		cmp al, [VGA_spec_chars.tab]
		je .tab
		cmp al, [VGA_spec_chars.newline]
		je .newlineloop
		mov [edi], al
		mov [edi+1], bl
		add edi, 2
		pop ecx
		loop .loop
	jmp .return
	.tab:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d
		div cx
		mov ax, dx
		mov dx, 0
		mov cl, [VGA.tab_spaces]
		mov ch, 0
		shl cx, 1					;2 bytes per character
		and ecx, 0xffff
		add edi, ecx
		div cx
		and edx, 0xffff
		sub edi, edx
		jmp .loop
	.newlineloop:
		call .newline
		jmp .loop
	.newline:
		mov eax, edi
		sub eax, 0xb8000
		mov dx, 0
		mov cx, 160d	;one line
		div cx
		add edi, 160d
		and edx, 0xffff
		sub edi, edx
		ret
	.return:
		mov bl, bh
		and bl, 00000010b
		jnz .skipUpdate
		call .update
		.skipUpdate:
		mov bl, bh
		and bl, 00000001b
		jnz .skipCursor
		call .setCursor		;must be last
		.skipCursor:
		ret
	.setCursor:		;see: http://wiki.osdev.org/Text_Mode_Cursor
		shr bh, 4
		mov [edi+1], bh
		mov ebx, edi
		sub ebx, 0xb8000
		shr ebx, 1
		mov dx, [boot_data.video_base]
		mov al, 0fh						;select cursor low
		out dx, al
		mov al, bl
		inc dx
		out dx, al
		dec dx
		mov al, 0eh						;slect cursor high
		out dx, al
		inc dx
		mov al, bh
		out dx, al
		ret
	.update:							;TODO: scroll
		mov bl, bh
		and bl, 00000100b
		jnz .skipNewline
		call .newline
		.skipNewline:
		mov eax, edi
		sub eax, 0xb8000
		mov [VGA.boot_safe_print], ax
		;sub ax, 4000d	;25 * 80 * 2 bytes
		;jnc .scroll
		ret
	.scroll:
		add ax, 160d
		mov dx, ax
		shl eax, 10h
		mov ax, dx
		mov dx, 0
		mov cx, 160d
		div cx
		shr eax, 10h	;high 16 bits are 0
		sub ax, dx
		xor ecx, ecx
		mov cx, ax
		;mov word [VGA.boot_safe_print], 3840d	;4000-160
		add eax, 0xb8000
		mov esi, eax
		mov edi, 0xb8000
		rep movsb		;copy
		mov edi, 3840d+0xb8000
		ret

boot_log_string_default:
	mov ax, [VGA.boot_safe_print]
	mov bx, [VGA.log_defaults]
	call boot_log_string
	ret

boot_newline:							;TODO: scroll, maybe not update cursor because it kind of looks cool right now
	mov ax, [VGA.boot_safe_print]
	mov dx, 0
	mov cx, 160d	;one line
	div cx
	mov ax, [VGA.boot_safe_print]
	add ax, 160d
	sub ax, dx
	mov [VGA.boot_safe_print], ax
	ret

boot_log_byte:
	mov edi, VGA_strings.byte
	push bx
	call format_hex_byte
	pop bx
	mov ax, [VGA.boot_safe_print]
	mov esi, VGA_strings.byte
	call boot_print
	ret

boot_log_byte_default:
	mov bx, [VGA.log_defaults]
	call boot_log_byte
	ret

boot_print_byte_default:
	mov bx, [VGA.print_defaults]
	call boot_log_byte
	ret

boot_log_word:
	mov edi, VGA_strings.word
	push bx
	call format_hex_word
	pop bx
	mov ax, [VGA.boot_safe_print]
	mov esi, VGA_strings.word
	call boot_print
	ret

boot_log_word_default:
	mov bx, [VGA.log_defaults]
	call boot_log_word
	ret

boot_print_word_default:
	mov bx, [VGA.print_defaults]
	call boot_log_word
	ret

boot_log_dword:
	mov edi, VGA_strings.dword
	push bx
	call format_hex_dword
	pop bx
	mov ax, [VGA.boot_safe_print]
	mov esi, VGA_strings.dword
	call boot_print
	ret

boot_log_dword_default:
	mov bx, [VGA.log_defaults]
	call boot_log_dword
	ret

boot_print_dword_default:
	mov bx, [VGA.print_defaults]
	call boot_log_dword
	ret

boot_viddef:
	mov al, [boot_console.line_length]
	cmp al, 15		;viddef + space + dword = 15
	jb .get
	mov esi, boot_console.line+7
	call parse_hex_dword
	cmp ecx, 0
	jne .get
	.set:
		mov [VGA.video_defaults], eax
		ret
	.get:
		mov eax, [VGA.video_defaults]
		call boot_log_dword_default
		call boot_newline	;TODO: update cursor
		ret
	ret

boot_vgapal:
	mov al, [boot_console.line_length]
	cmp al, 11		;vgapal + space + word = 11
	jb .get
	mov esi, boot_console.line+7
	call parse_hex_word
	cmp ecx, 0
	jne .get
	.set:
		call VGA_set_palette
	.get:
		mov ecx, 16d
		.loop:
			mov ah, 16d
			sub ah, cl
			call VGA_get_palette
			mov al, ah
			push ecx
			call boot_log_byte_default
			pop ecx
			loop .loop
		call boot_newline	;TODO: update cursor
		ret

VGA:
	.boot_safe_print dw 0
	.tab_spaces db 4
	.video_defaults:
	.print_defaults dw 0xa002
	.log_defaults dw 0xa402

VGA_spec_chars:
	.null db 0
	.tab db 09h
	.newline db 0ah
	.space db " "

VGA_strings:
	.byte db "--", 0
	.word db "----", 0
	.dword db "--------", 0

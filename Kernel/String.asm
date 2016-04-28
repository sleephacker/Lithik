find_string_256_:	;esi = string to find, al = length; edi = string to search, ah = length; result al: 0 = success / 1 = fail, ah = index
	cmp al, ah
	ja .not_found
	sub ah, al
	inc ah			;indexes to search at = difference in length + 1
	xor ecx, ecx
	mov cl, ah
	.index_loop:
		mov ebx, edi
		add bl, ah
		sub bl, cl
		mov edx, edi
		mov edi, ebx
		mov ebx, esi
		xchg al, cl
		shl eax, 8
		mov al, cl
		repe cmpsb
		jcxz .found
		mov ch, 0
		mov cl, al
		shr eax, 8
		mov esi, ebx
		mov edi, edx
		loop .index_loop
	.not_found:
		mov al, 1	;fail
		ret
	.found:
		mov cl, al
		shr eax, 8
		sub ah, cl
		mov al, 0	;succes
		ret

;TODO: make a proper function.
find_string_256:	;esi = string to find, al = length; edi = string to search, ah = length; result al: 0 = success / 1 = fail, ah = index
	cmp al, ah
	ja .not_found
	mov byte [.index0], 0
	mov [.lengthS], al
	mov [.lengthD], ah
	mov [.stringS], esi
	mov [.stringD], edi
	.loop0:
		mov byte [.index1], 0
		.loop1:
			xor ebx, ebx
			xor ecx, ecx
			mov bl, [.index0]
			mov cl, [.index1]
			add bx, cx
			add ebx, [.stringD]
			add ecx, [.stringS]
			mov al, [ebx]
			cmp al, [ecx]
			jne .break1
			inc byte [.index1]
			mov al, [.lengthS]
			cmp al, [.index1]
			ja .loop1
		.found:
			mov al, 0
			mov ah, [.index0]
			ret
		.break1:
		inc byte [.index0]
		mov al, [.lengthD]
		sub al, [.lengthS]
		cmp al, [.index0]
		jae .loop0
	.not_found:
		mov al, 1	;fail
		ret
	.index0 db 0
	.index1 db 0
	.lengthS db 0
	.lengthD db 0
	.stringS dd 0
	.stringD dd 0

format_hex_byte:
	mov bl, al
	and ebx, 0000000fh
	add ebx, strings.hex
	mov cl, [ebx]
	mov [edi+1], cl
	mov bl, al
	shr ebx, 4
	and ebx, 0000000fh
	add ebx, strings.hex
	mov cl, [ebx]
	mov [edi], cl
	ret

format_hex_word:
	add edi, 3
	mov ecx, 4
	.loop:
		mov bx, ax
		and ebx, 0000000fh
		mov edx, strings.hex
		add edx, ebx
		mov bl, [edx]
		mov [edi], bl
		dec edi
		ror ax, 4
		loop .loop
	ror ax, 4
	ret

format_hex_dword:
	add edi, 7
	mov ecx, 8
	.loop:
		mov ebx, eax
		and ebx, 0000000fh
		mov edx, strings.hex
		add edx, ebx
		mov bl, [edx]
		mov [edi], bl
		dec edi
		ror eax, 4
		loop .loop
	ror eax, 4
	ret

;format_dec concept: loop over powers of ten starting with 10, get remainder, push that, exit loop at some point, use ecx to determine number of digits, pop them

parse_hex_dword:		;If esi isn't the same and/or ecx isn't zero, it's an error.
	add esi, 7
	mov ecx, 8
	mov eax, 0
	.loop:
		mov bl, [esi]
		cmp bl, "a"
		jae .af
		cmp bl, "0"
		jb .invalid
		cmp bl, "9"
		ja .invalid
		sub bl, "0"
		jmp .done
		.af:
		cmp bl, "f"
		ja .invalid
		sub bl, "a"-0ah
		.done:
		or al, bl
		ror eax, 4
		dec esi
		loop .loop
	ret
	.invalid:
		mov eax, 0
		ret

parse_hex_word:		;If esi isn't the same and/or ecx isn't zero, it's an error.
	add esi, 3
	mov ecx, 4
	mov ax, 0
	.loop:
		mov bl, [esi]
		cmp bl, "a"
		jae .af
		cmp bl, "0"
		jb .invalid
		cmp bl, "9"
		ja .invalid
		sub bl, "0"
		jmp .done
		.af:
		cmp bl, "f"
		ja .invalid
		sub bl, "a"-0ah
		.done:
		or al, bl
		ror ax, 4
		dec esi
		loop .loop
	ret
	.invalid:
		mov ax, 0
		ret

parse_hex_byte:		;If esi isn't the same and/or ecx isn't zero, it's an error.
	add esi, 1
	mov ecx, 2
	mov al, 0
	.loop:
		mov bl, [esi]
		cmp bl, "a"
		jae .af
		cmp bl, "0"
		jb .invalid
		cmp bl, "9"
		ja .invalid
		sub bl, "0"
		jmp .done
		.af:
		cmp bl, "f"
		ja .invalid
		sub bl, "a"-0ah
		.done:
		or al, bl
		ror al, 4
		dec esi
		loop .loop
	ret
	.invalid:
		mov al, 0
		ret

strings:
	.hex db "0123456789abcdef"
	;messages
	.confirm db "Press ENTER to confirm or BACKSPACE to cancel:", 0
	.done db "Done.", 0
	.invalid_input db "Invalid input.", 0
	.anykey db "Press any key to continue...", 0
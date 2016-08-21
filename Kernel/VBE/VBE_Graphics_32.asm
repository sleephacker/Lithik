;All functions in this file are optimized for 32bpp modes.
;TODO: update

;not needed
vbe_make_color_32:
	ret

;calculates the physical address of a pixel
;IN: ebx = Y << 16 | X
;OUT: eax = address
vbe_calc_pixel_32:
	ror ebx, 16
	xor eax, eax
	mov ax, bx
	mov cx, [VBE_Screen.pitch]
	mul cx
	shl edx, 16
	or eax, edx
	shr ebx, 14			;ebx = X << 2 | leftovers
	and ebx, 0003fffch	;ebx = X * 4
	add eax, ebx
	add eax, [VBE_Screen.base]
	ret

;IN: eax = formatted color, ebx = Y << 16 | X
vbe_set_pixel_32:
	push eax
	call vbe_calc_pixel_32
	pop dword [eax]
	ret

;fills a rectangle
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
;NOTE: W > 1, H > 1
vbe_fill_rect_32:
	push ecx
	push eax
	call vbe_calc_pixel_32
	mov edi, eax
	mov ebx, eax
	pop eax
	;W = [esp+0]
	;H = [esp+2]
	xor ecx, ecx
	xor edx, edx
	pop cx
	mov dx, cx
	rep stosd
	pop cx
	dec cx
	.Yloop:
		mov esi, ebx
		add ebx, [VBE_Screen.pitch]
		mov edi, ebx
		mov eax, ecx
		mov ecx, edx
		rep movsd
		mov ecx, eax
		loop .Yloop
	ret

;draws the border of a rectangle
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
;NOTE: W > 1, H > 1
vbe_draw_rect_32:
	sub ecx, 00010001h
	push ecx
	push eax
	call vbe_calc_pixel_32
	mov edi, eax
	pop eax
	pop bx
	pop dx
	;bx = W
	;dx = H
	;edi = top left pixel
	xor ecx, ecx
	mov cx, bx
	rep stosd
	;edi = top right pixel
	mov cx, dx
	.Y0loop:
		mov [edi], eax
		add edi, [VBE_Screen.pitch]
		loop .Y0loop
	;edi = bottom right pixel
	mov cx, bx
	std
	rep stosd
	cld
	;edi = bottom left pixel
	mov cx, dx
	.Y1loop:
		mov [edi], eax
		sub edi, [VBE_Screen.pitch]
		loop .Y1loop
	ret

;draws a character using the 8x12 bitmap font included in the kernel.
;IN: eax = formatted color, ebx = Y << 16 | X, cl = character
vbe_draw_char_8x12_32:
	push eax
	xor ch, ch
	push cx
	call vbe_calc_pixel
	mov edi, eax
	xor ecx, ecx
	pop cx
	mov ebx, FONT_8x12
	shl ecx, 2			;char * 4
	add ebx, ecx
	shl ecx, 1			;char * 4 * 2
	add ebx, ecx		;font base + char * 12
	mov ecx, 12
	mov esi, [VBE_Screen.pitch]
	sub esi, 4 * 8		;4 bytes * 8 pixels
	pop eax
	.Yloop:
		push ecx
		mov ecx, 8
		mov dl, 10000000b
		.Xloop:
			test [ebx], dl
			jz .skip
			stosd		;mov [edi], eax; add edi, 4
			shr dl, 1
			loop .Xloop
			jmp .Xdone
			.skip:
			add edi, 4
			shr dl, 1
			loop .Xloop
		.Xdone:
		pop ecx
		inc ebx
		add edi, esi
		loop .Yloop
	ret

;draws a 0 terminated string
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = string
vbe_draw_string_8x12_32:
	push eax
	push ebx
	push ecx
	.loop:
		mov cl, [ecx]
		and cl, cl
		jz .done
		call vbe_draw_char_8x12_32
		inc dword [esp]
		add word [esp + 4], 8
		mov ecx, [esp]
		mov ebx, [esp + 4]
		mov eax, [esp + 8]
		jmp .loop
	.done:
		add esp, 12
		ret

;draws a string given its length
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = length, edx = string
vbe_draw_string_len_8x12_32:
	push eax
	push ebx
	push edx
	.loop:
		push ecx
		mov cl, [edx]
		call vbe_draw_char_8x12_32
		pop ecx
		inc dword [esp]
		add word [esp + 4], 8
		mov edx, [esp]
		mov ebx, [esp + 4]
		mov eax, [esp + 8]
		loop .loop
	.done:
		add esp, 12
		ret

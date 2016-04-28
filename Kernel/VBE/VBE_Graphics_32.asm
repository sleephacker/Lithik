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

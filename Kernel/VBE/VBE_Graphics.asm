;TODO: create a Z-buffer outside VRAM to render to.

;call this before starting to render a new image
vbe_begin_render:
	cmp byte [VBE_Screen.pages], 0
	je .ret										;no double or tripple buffering
	xor ah, ah
	mov al, [VBE_Screen.page]
	inc al
	mov bl, [VBE_Screen.pages]
	inc bl
	div bl
	mov [VBE_Screen.page], ah
	xor ecx, ecx
	mov cl, ah
	mov ebx, [VBE_Screen.lfb_base]
	mov eax, [VBE_Screen.size]
	mul ecx
	add eax, ebx
	mov [VBE_Screen.base], eax
	.ret:
		ret

;call this when the new image has been rendered and is ready to be displayed
vbe_end_render:
	cmp byte [VBE_Screen.pages], 0
	je .ret
	test word [VBE_Mode.attributes], 1 << 10	;hardware tripple buffering supported
	jz .skipwait								;if tripple buffeing is not supported, function 4f07h, 04h cannot be used.
	.wait:
		mov dword [real_BIOS_INT.eax], 4f07h
		mov dword [real_BIOS_INT.ebx], 04h		;get scheduled display status
		call real_BIOS_INT
		cmp word [real_BIOS_INT.ecx], 0			;cx =! 0 if flip has occured
		je .wait
	.skipwait:
	mov eax, [VBE_Screen.base]
	sub eax, [VBE_Mode.physBase]
	mov dword [real_BIOS_INT.eax], 4f07h
	mov dword [real_BIOS_INT.ebx], 02h			;schedule display start during vertical retrace
	mov dword [real_BIOS_INT.ecx], eax			;offset in vram
	call real_BIOS_INT
	.ret:
		ret

;copies the page that is currently being diplayed to the page that is currently being rendered to.
vbe_render_display:
	cmp byte [VBE_Screen.pages], 0
	je .ret
	xor ah, ah
	mov al, [VBE_Screen.page]
	cmp al, 0
	je .wrap
	dec al
	mov bl, [VBE_Screen.pages]
	inc bl
	div bl
	jmp .copy
	.wrap:
		mov ah, [VBE_Screen.pages]
	.copy:
		xor ecx, ecx
		mov cl, ah
		mov ebx, [VBE_Screen.lfb_base]
		mov eax, [VBE_Screen.size]
		mul ecx
		add eax, ebx
		mov esi, eax
		mov edi, [VBE_Screen.base]
		mov ecx, [VBE_Screen.size]
		rep movsb
	.ret:
		ret

;transforms a color in 0RGB format to the format used by the current video mode
;IN: eax = 0RGB color: (0 << 24 | R << 16 | G << 8 | B)
;OUT: eax = formatted color
vbe_make_color:
	mov ebx, eax
	and eax, 00ff0000h
	shr eax, 16
	mov cl, [VBE_Screen.redMaskSize]
	shl eax, cl
	shr eax, 8
	mov cl, [VBE_Screen.redFieldPos]
	shl eax, cl
	push eax
	mov eax, ebx
	and eax, 0000ff00h
	shr eax, 8
	mov cl, [VBE_Screen.greenMaskSize]
	shl eax, cl
	shr eax, 8
	mov cl, [VBE_Screen.greenFieldPos]
	shl eax, cl
	mov edx, eax	;no need to push
	mov eax, ebx
	and eax, 000000ffh
	mov cl, [VBE_Screen.blueMaskSize]
	shl eax, cl
	shr eax, 8
	mov cl, [VBE_Screen.blueFieldPos]
	shl eax, cl
	or eax, edx		;or 000B with 00G0
	pop ebx
	or eax, ebx		;or 00GB with 0R00
	ret	

;sets a pixel
;IN: eax = formatted color, ebx = Y << 16 | X
vbe_set_pixel:
	push eax
	call vbe_calc_pixel
	mov ebx, [VBE_Screen.pmask]
	and [eax], ebx
	pop ebx
	or [eax], ebx
	ret

;calculates the physical address of a pixel
;IN: ebx = Y << 16 | X
;OUT: eax = address
vbe_calc_pixel:
	xor eax, eax
	mov ax, bx
	mov cx, [VBE_Screen.yaw]
	mul cx
	shl edx, 16
	or eax, edx
	push eax
	shr ebx, 16
	xor eax, eax
	mov ax, bx
	mov cx, [VBE_Screen.pitch]
	mul cx
	shl edx, 16
	or eax, edx
	pop ebx
	add eax, ebx
	add eax, [VBE_Screen.base]
	ret

;fills the entire screen with a color
;IN: eax = formatted color
vbe_fill_screen:
	mov ebx, [VBE_Screen.base]
	xor ecx, ecx
	mov cx, [VBE_Mode.Xres]
	mov edx, [VBE_Screen.pmask]
	.Xloop:
		and [ebx], edx
		or [ebx], eax
		add ebx, [VBE_Screen.yaw]
		loop .Xloop
	mov cx, [VBE_Mode.Yres]
	dec cx
	mov ebx, [VBE_Screen.base]
	add ebx, [VBE_Screen.pitch]
	.Yloop:
		mov eax, ecx
		mov esi, [VBE_Screen.base]
		mov edi, ebx
		mov ecx, [VBE_Screen.pitch]
		rep movsb
		add ebx, [VBE_Screen.pitch]
		mov ecx, eax
		loop .Yloop
	ret

;fills a rectangle
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
;NOTE: W > 1, H > 1
vbe_fill_rect:
	push ecx
	push eax
	call vbe_calc_pixel
	pop edx
	push eax
	;base = [esp+0]
	;W = [esp+4]
	;H = [esp+6]
	xor ecx, ecx
	mov cx, [esp+4]
	.Xloop:
		mov ebx, [VBE_Screen.pmask]
		and [eax], ebx
		or [eax], edx
		add eax, [VBE_Screen.yaw]
		loop .Xloop
	mov ecx, eax
	sub ecx, [esp]	;ecx = bytes altered
	pop eax
	mov edx, ecx
	;W = [esp+0]
	;H = [esp+2]
	mov cx, [esp+2]
	dec cx
	.Yloop:
		mov esi, eax
		add eax, [VBE_Screen.pitch]
		mov edi, eax
		mov ebx, ecx
		mov ecx, edx
		rep movsb
		mov ecx, ebx
		loop .Yloop
	add esp, 4
	ret

;draws the outline of a rectangle
;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
;NOTE: W > 1, H > 1
vbe_draw_rect:
	sub ecx, 00010001h
	push ecx
	push eax
	call vbe_calc_pixel
	pop edx
	;W = [esp]
	;H = [esp+2]
	;eax = top left pixel
	xor ecx, ecx
	mov cx, [esp]
	.X0loop:
		mov ebx, [VBE_Screen.pmask]
		and [eax], ebx
		or [eax], edx
		add eax, [VBE_Screen.yaw]
		loop .X0loop
	;eax = top right pixel
	mov cx, [esp+2]
	.Y0loop:
		mov ebx, [VBE_Screen.pmask]
		and [eax], ebx
		or [eax], edx
		add eax, [VBE_Screen.pitch]
		loop .Y0loop
	;eax = bottom right pixel
	pop cx
	.X1loop:
		mov ebx, [VBE_Screen.pmask]
		and [eax], ebx
		or [eax], edx
		sub eax, [VBE_Screen.yaw]
		loop .X1loop
	;eax = bottom left pixel
	pop cx
	.Y1loop:
		mov ebx, [VBE_Screen.pmask]
		and [eax], ebx
		or [eax], edx
		sub eax, [VBE_Screen.pitch]
		loop .Y1loop
	ret

;draws a line using Bresenham's algorithm, TODO: check out Wu's algorithm for antialiasing.
;IN: eax = formatted color, ebx = Y0 << 16 | X0, ecx = Y1 << 16 | X1
vbe_draw_line:
	push eax
	push ebx
	mov esi, eax
	mov ax, bx
	shr ebx, 16
	mov edx, ecx
	shr edx, 16
	;ax = X0
	;bx = Y0
	;cx = X1
	;dx = Y1
	cmp ax, cx
	ja .left
	cmp bx, dx
	ja .right_up
	;right_down
	push dx
	push cx
	sub [esp], ax	;delta X
	sub dx, bx		;delta Y
	cmp dx, [esp]
	ja .octant_6
	jmp .octant_7
	.right_up:
	push bx
	push cx
	sub [esp], ax	;delta X
	sub bx, dx		;delta Y
	cmp bx, [esp]
	ja .octant_1
	jmp .octant_0
	.left:
	cmp bx, dx
	ja .left_up
	;left_down
	push dx
	push ax
	sub [esp], cx	;delta X
	sub dx, bx		;delta Y
	cmp dx, [esp]
	ja .octant_5
	jmp .octant_4
	.left_up:
	push bx
	push ax
	sub [esp], cx	;delta X
	sub bx, dx		;delta Y
	cmp bx, [esp]
	ja .octant_2
	jmp .octant_3
	.octant_0:
		mov [esp + 2], bx
		push dword [VBE_Screen.pitch]
		neg dword [esp]
		push dword [VBE_Screen.yaw]
		jmp .line
	.octant_1:
		xchg [esp], bx
		mov [esp + 2], bx
		push dword [VBE_Screen.yaw]
		push dword [VBE_Screen.pitch]
		neg dword [esp]
		jmp .line
	.octant_2:
		xchg [esp], bx
		mov [esp + 2], bx
		push dword [VBE_Screen.yaw]
		neg dword [esp]
		push dword [VBE_Screen.pitch]
		neg dword [esp]
		jmp .line
	.octant_3:
		mov [esp + 2], bx
		push dword [VBE_Screen.pitch]
		neg dword [esp]
		push dword [VBE_Screen.yaw]
		neg dword [esp]
		jmp .line
	.octant_4:
		mov [esp + 2], dx
		push dword [VBE_Screen.pitch]
		push dword [VBE_Screen.yaw]
		neg dword [esp]
		jmp .line
	.octant_5:
		xchg [esp], dx
		mov [esp + 2], dx
		push dword [VBE_Screen.yaw]
		neg dword [esp]
		push dword [VBE_Screen.pitch]
		jmp .line
	.octant_6:
		xchg [esp], dx
		mov [esp + 2], dx
		push dword [VBE_Screen.yaw]
		push dword [VBE_Screen.pitch]
		jmp .line
	.octant_7:
		mov [esp + 2], dx
		push dword [VBE_Screen.pitch]
		push dword [VBE_Screen.yaw]
		jmp .line
	.line:
	;[esp + 16] = color
	;[esp + 12] = Y0 < 16 | X0
	;[esp + 10] = delta Y
	;[esp + 8 ] = delta X
	;[esp + 4 ] = pitch
	;[esp + 0 ] = yaw
	mov ebx, [esp + 12]
	call vbe_calc_pixel
	mov esi, [VBE_Screen.pmask]
	mov edi, [esp + 16]
	xor ecx, ecx
	mov cx, [esp + 8]
	mov dx, [esp + 10]
	sub dx, cx
	inc cx
	.loop:
		and [eax], esi
		or [eax], edi
		cmp dx, 0
		jl .skip
		add eax, [esp + 4]
		sub dx, [esp + 8]
		.skip:
		add eax, [esp]
		add dx, [esp + 10]
		loop .loop
	add esp, 20
	ret

;draws a character using the 8x12 bitmap font included in the kernel.
;IN: eax = formatted color, ebx = Y << 16 | X, cl = character
vbe_draw_char_8x12:
	xchg bx, bx
	push eax
	xor ch, ch
	push cx
	call vbe_calc_pixel
	xor ecx, ecx
	pop cx
	mov ebx, FONT_8x12
	shl ecx, 2			;char * 4
	add ebx, ecx
	shl ecx, 1			;char * 4 * 2
	add ebx, ecx		;font base + char * 12
	mov ecx, 12
	mov edi, [VBE_Screen.pmask]
	mov esi, [VBE_Screen.yaw]
	shl esi, 3			;yaw * 8
	mov edx, [VBE_Screen.pitch]
	sub edx, esi
	pop esi
	push edx			;pitch - yaw * 8
	.Yloop:
		push ecx
		mov ecx, 8
		mov dl, 80h
		.Xloop:
			test [ebx], dl
			jz .skip
			and [eax], edi
			or [eax], esi
			.skip:
			shr dl, 1
			add eax, [VBE_Screen.yaw]
			loop .Xloop
		pop ecx
		inc ebx
		add eax, [esp]
		loop .Yloop
	add esp, 4
	ret

%include "Kernel\VBE\VBE_Macros.asm"
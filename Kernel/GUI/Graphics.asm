G:
	;transforms a color in 0RGB format to the format used by the current video mode
	;IN: eax = 0RGB color: (0 << 24 | R << 16 | G << 8 | B)
	;OUT: eax = formatted color
	.make_color dd 0
	;IN: eax = formatted color, ebx = Y << 16 | X
	.set_pixel dd 0
	;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
	;NOTE: W > 1, H > 1
	.fill_rect dd 0
	;draws the outline of a rectangle
	;IN: eax = formatted color, ebx = Y << 16 | X, ecx = H << 16 | W
	;NOTE: W > 1, H > 1
	.draw_rect dd 0
	;IN: eax = formatted color, ebx = Y0 << 16 | X0, ecx = Y1 << 16 | X1
	.draw_line dd 0
	;draws a character using the 8x12 bitmap font included in the kernel
	;IN: eax = formatted color, ebx = Y << 16 | X, cl = character
	.draw_char_8x12 dd 0
	;draws a 0 terminated string
	;IN: eax = formatted color, ebx = Y << 16 | X, ecx = string
	.draw_string_8x12 dd 0
	;draws a string given its length
	;IN: eax = formatted color, ebx = Y << 16 | X, ecx = length, edx = string
	.draw_string_len_8x12 dd 0
	;TODO: add draw_char_8x12_bg and string counterparts, to allow drawing strings and chars without drawing the background color first

Graphics_init:
	cmp [VBE_Mode.bpp], byte 32
	je .b32
	mov [G.make_color], dword vbe_make_color
	mov [G.set_pixel], dword vbe_set_pixel
	mov [G.fill_rect], dword vbe_fill_rect
	mov [G.draw_rect], dword vbe_draw_rect
	mov [G.draw_line], dword vbe_draw_line
	mov [G.draw_char_8x12], dword vbe_draw_char_8x12
	mov [G.draw_string_8x12], dword vbe_draw_string_8x12
	mov [G.draw_string_len_8x12], dword vbe_draw_string_len_8x12
	ret
	.b32:
		mov [G.make_color], dword vbe_make_color_32
		mov [G.set_pixel], dword vbe_set_pixel_32
		mov [G.fill_rect], dword vbe_fill_rect_32
		mov [G.draw_rect], dword vbe_draw_rect_32
		mov [G.draw_line], dword vbe_draw_line
		mov [G.draw_char_8x12], dword vbe_draw_char_8x12_32
		mov [G.draw_string_8x12], dword vbe_draw_string_8x12_32
		mov [G.draw_string_len_8x12], dword vbe_draw_string_len_8x12_32
		ret

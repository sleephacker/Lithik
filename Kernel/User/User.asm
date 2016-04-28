%include "Kernel\Define\Color.asm"

;default user driver
user_default:
	;moving rectangle
	mov eax, color_black
	call vbe_make_color
	make_rect 250, [.y], 300, 200
	call vbe_draw_rect_32
	inc dword [.y]
	and dword [.y], 0xff
	mov eax, color_green
	or eax, [.y]
	call vbe_make_color
	make_rect 250, [.y], 300, 200
	call vbe_draw_rect_32
	mov eax, 16
	call k_wait_short
	jmp user_default
	;debug drawing
	mov eax, color_white
	call vbe_make_color
	make_rect 200, 150, 200, 150
	call vbe_draw_rect;_32
	mov eax, color_grey
	call vbe_make_color
	make_rect 0, 0, 800, 600
	call vbe_draw_rect_32
	mov eax, color_light_grey
	call vbe_make_color
	make_rect 300, 200, 200, 200
	call vbe_draw_rect;_32
	mov eax, color_dark_grey
	call vbe_make_color
	make_rect 400, 300, 101, 101
	call vbe_fill_rect
	mov eax, color_black
	call vbe_make_color
	make_rect 400, 300, 99, 99
	call vbe_fill_rect
	jmp $
	;window prototype
	mov eax, 10000d
	call k_wait_short
	mov eax, 00565656h
	call vbe_make_color
	make_rect 100, 50, 656, 420
	call vbe_fill_rect
	mov eax, color_black
	call vbe_make_color
	make_rect 100+1, 50+19, 640, 400
	call vbe_fill_rect
	mov eax, color_black
	call vbe_make_color
	make_rect 100+642, 50+19, 12, 400
	call vbe_fill_rect
	jmp $
	.y dd 0

%define VBE_mode_list_ptr_offset 14d

VBE_On db 0			;set to 1 if a VBE mode is being used
VBE_ModeList dd 0	;place to store the mode list pointer (in linear 32bits format)
db "VBE"
VBE_Mode:			;current video mode
	;All versions
	.attributes dw 0
	.winA db 0
	.winB db 0
	.winGran dw 0
	.winSize dw 0
	.winASeg dw 0
	.winBSeg dw 0
	.winFunc dd 0
	.bytesPerLine dw 0
	;VBE 1.2
	.Xres dw 0
	.Yres dw 0
	.Xchar db 0
	.Ychar db 0
	.planes db 0
	.bpp db 0
	.banks db 0
	.memoryModel db 0
	.bankSize db 0
	.pages db 0
	.res0 db 0
	;Direct color fields for direct/6 and YUV/7 memory models
	.redMaskSize db 0
	.redFieldPos db 0
	.greenMaskSize db 0
	.greenFieldPos db 0
	.blueMaskSize db 0
	.blueFieldPos db 0
	.rsvdMaskSize db 0
	.rsvdFieldPos db 0
	.directModeInfo db 0
	;VBE 2.0
	.physBase dd 0
	.res1 dd 0
	.res2 dw 0
	;VBE 3.0
	.linBytesPerLine dw 0
	.bankPages db 0
	.linPages db 0
	.linRedMaskSize db 0
	.linRedFieldPos db 0
	.linGreenMaskSize db 0
	.linGreenFieldPos db 0
	.linBlueMaskSize db 0
	.linBlueFieldPos db 0
	.linRsvdMaskSize db 0
	.linRsvdFieldPos db 0
	.maxPixelClock dd 0
	;.res3 times 189 db 0
	.end:

VBE_Screen:
	.lfb_base dd 0	;base address of LFB
	.base dd 0		;base address of current image
	.size dd 0		;size of image in bytes
	.pages db 0		;number of images 
	.page db 0		;current page
	.yaw dd 0		;BYTES per pixel, not bits!
	.pitch dd 0		;bytes per scanline
	.pmask dd 0		;AND this with the base of a pixel to make it black
	.cmask dd 0		;AND this with a color to make it fit in the current format
	.redMaskSize db 0
	.redFieldPos db 0
	.greenMaskSize db 0
	.greenFieldPos db 0
	.blueMaskSize db 0
	.blueFieldPos db 0
	.rsvdMaskSize db 0
	.rsvdFieldPos db 0

VBE_desired_mode:
	.number dw 0	;mode number to be set if the desired mode was found
	.Xres dw 800d
	.Yres dw 600d
	.bpp db 32
	.minBpp db 24

VBE_boot_0:		;not setting video mode just yet
	mov eax, 512
	call memory_allocate_temp
	push eax	;needs to be freed at some point
	
	mov [eax], dword "VBE2"
	mov [real_BIOS_INT.di], ax
	and eax, 0xffff0000
	shr eax, 4
	mov [real_BIOS_INT.es], ax
	mov [real_BIOS_INT.eax], dword 4f00h
	mov [real_BIOS_INT.int], byte 10h
	call real_BIOS_INT
	mov eax, [real_BIOS_INT.eax]
	cmp ax, 4fh
	jne .vbe_die
	mov ebx, [esp]		;base address of allocated area
	mov eax, [ebx + VBE_mode_list_ptr_offset]
	xor ebx, ebx
	mov bx, ax
	and eax, 0xffff0000
	shr eax, 12d
	add eax, ebx
	mov [VBE_ModeList], eax		;NOTE: this is likely to be in the allocated area
	call VBE_find_mode
	mov ax, [VBE_desired_mode.number]
	call boot_print_word_default
	
	mov eax, [esp]
	mov [eax], dword "VBE2"
	mov [real_BIOS_INT.di], ax
	and eax, 0xffff0000
	shr eax, 4
	mov [real_BIOS_INT.es], ax
	mov [real_BIOS_INT.eax], dword 4f00h
	mov [real_BIOS_INT.int], byte 10h
	call real_BIOS_INT
	
	pop ebx
	mov eax, 512
	call memory_free_temp
	mov esi, .msg
	call boot_print_default
	ret
	.vbe_die:
		mov esi, .vbe_fatal
		jmp boot_die
	.vbe_fatal db "Couldn't initialize VBE!", 0
	.msg db "VBE initialization complete.", 0

VBE_boot_1:					;set the selected video mode
	xor eax, eax
	mov ax, [VBE_desired_mode.number]
	cmp ax, 0
	je .vbe_find_die
	or ax, 4000h
	mov [real_BIOS_INT.eax], dword 4f02h
	mov [real_BIOS_INT.ebx], eax
	mov [real_BIOS_INT.ecx], dword 0
	mov [real_BIOS_INT.int], byte 10h
	mov esi, .msg
	call boot_print_default
	call real_BIOS_INT		;NOTE/TODO: BIOS may enter protected mode and alter the GDT, but real_BIOS_INT.return reloads the GDT, so don't remove this feature.
	mov eax, [real_BIOS_INT.eax]
	cmp ax, 4fh
	jne .vbe_set_die
	mov byte [VBE_On], 1
	
	;set VBE_Screen values
	mov al, [VBE_Mode.linPages]
	mov [VBE_Screen.pages], al
	xor ax, ax
	mov al, [VBE_Mode.bpp]		;must be multiple of 8
	shr ax, 3
	mov [VBE_Screen.yaw], ax
	xor eax, eax
	mov ax, [VBE_Mode.linBytesPerLine]
	mov [VBE_Screen.pitch], ax
	mov bx, [VBE_Mode.Yres]
	mul bx
	shl edx, 16
	or eax, edx
	mov [VBE_Screen.size], eax
	;map LFB to static memory
	mov ecx, eax
	mov esi, [VBE_Mode.physBase]
	call memory_map_static
	mov [VBE_Screen.lfb_base], edi
	mov [VBE_Screen.base], edi
	
	cmp byte [VBE_Mode.memoryModel], 6
	je .direct
	;packed, TODO
	ret
	.direct:
		mov al, [VBE_Mode.linRedMaskSize]
		mov [VBE_Screen.redMaskSize], al
		mov al, [VBE_Mode.linRedFieldPos]
		mov [VBE_Screen.redFieldPos], al
		mov al, [VBE_Mode.linGreenMaskSize]
		mov [VBE_Screen.greenMaskSize], al
		mov al, [VBE_Mode.linGreenFieldPos]
		mov [VBE_Screen.greenFieldPos], al
		mov al, [VBE_Mode.linBlueMaskSize]
		mov [VBE_Screen.blueMaskSize], al
		mov al, [VBE_Mode.linBlueFieldPos]
		mov [VBE_Screen.rsvdFieldPos], al
		mov al, [VBE_Mode.linRsvdMaskSize]
		mov [VBE_Screen.rsvdMaskSize], al
		mov al, [VBE_Mode.linRsvdFieldPos]
		mov [VBE_Screen.rsvdFieldPos], al
		mov cl, 32
		sub cl, [VBE_Mode.bpp]
		mov eax, 0xffffffff
		shr eax, cl
		xor eax, 0xffffffff
		mov [VBE_Screen.pmask], eax
		ret
	.vbe_find_die:
		mov esi, .vbe_find_fatal
		jmp boot_die
	.vbe_set_die:
		mov esi, .vbe_set_fatal
		jmp boot_die
	.vbe_find_fatal db "Couldn't find VBE video mode!", 0
	.vbe_set_fatal db "Couldn't set VBE video mode!", 0
	.msg db "Setting VBE video mode...", 0

VBE_find_mode:		;finds a direct color graphics mode that supports LFB and matches the VBE_desired_mode, or has the same resolution and the lowest bpp that is higher than or equal to minBpp.
	mov dword [.offset], 0
	mov word [.best], 0
	mov byte [.bestbpp], 0xff
	mov eax, 256d
	call memory_allocate_temp
	push eax
	.mode_loop:
		mov ebx, [VBE_ModeList]
		add ebx, [.offset]
		cmp word [ebx], 0xffff
		je .end
		xor eax, eax
		mov ax, [ebx]
		mov [real_BIOS_INT.eax], dword 4f01h
		mov [real_BIOS_INT.ecx], eax
		mov eax, [esp]
		mov [real_BIOS_INT.di], ax
		and eax, 0xffff0000
		shr eax, 4
		mov [real_BIOS_INT.es], ax
		mov [real_BIOS_INT.int], byte 10h
		call real_BIOS_INT
		mov eax, [real_BIOS_INT.eax]
		cmp ax, 4fh
		jne .skip
		mov ebx, [esp]
		mov al, [ebx + VBE_Mode.memoryModel - VBE_Mode]
		cmp al, 6d		;direct color
		;je .goodcolor	;idk what packed pixel means...
		;cmp al, 4d		;packed pixel
		je .goodcolor
		jmp .skip
		.goodcolor:
		mov al, [ebx + VBE_Mode.attributes - VBE_Mode]
		test al, 0000000010001000b	;graphics mode with LFB
		jz .skip
		mov ax, [ebx + VBE_Mode.Xres - VBE_Mode]
		cmp ax, [VBE_desired_mode.Xres]
		jne .skip
		mov ax, [ebx + VBE_Mode.Yres - VBE_Mode]
		cmp ax, [VBE_desired_mode.Yres]
		jne .skip
		mov al, [ebx + VBE_Mode.bpp - VBE_Mode]
		cmp al, [VBE_desired_mode.bpp]
		je .found
		cmp al, [VBE_desired_mode.minBpp]
		jb .skip
		cmp al, [.bestbpp]
		ja .skip					;get the lowest bpp that is higher than the minimal bpp
		mov [.bestbpp], al
		mov ebx, [VBE_ModeList]
		add ebx, [.offset]
		mov ax, [ebx]
		mov [.best], ax
		.skip:
		add dword [.offset], 2
		jmp .mode_loop
	.end:
		cmp word [.best], 0
		je .notfound
		
		xor eax, eax
		mov ax, [.best]
		mov [VBE_desired_mode.number], ax
		mov [real_BIOS_INT.eax], dword 4f01h
		mov [real_BIOS_INT.ecx], eax
		mov eax, [esp]
		mov [real_BIOS_INT.di], ax
		and eax, 0xffff0000
		shr eax, 4
		mov [real_BIOS_INT.es], ax
		mov [real_BIOS_INT.int], byte 10h
		call real_BIOS_INT
		
		pop ebx
		mov esi, ebx
		mov edi, VBE_Mode
		mov ecx, VBE_Mode.end - VBE_Mode
		rep movsb
		mov eax, 256d
		call memory_free_temp
		ret
	.notfound:
		mov [VBE_desired_mode.number], word 0
	.return:
		pop ebx
		mov eax, 256d
		call memory_free_temp
		ret
	.found:
		mov ebx, [VBE_ModeList]
		add ebx, [.offset]
		mov ax, [ebx]
		mov [VBE_desired_mode.number], ax
		pop ebx
		mov esi, ebx
		mov edi, VBE_Mode
		mov ecx, VBE_Mode.end - VBE_Mode
		rep movsb
		mov eax, 256d
		call memory_free_temp
		ret
	.offset dd 0
	.best dw 0
	.bestbpp db 0xff	;finds something that's lower than this, so initialize to maximum

%include "Kernel\VBE\VBE_Graphics.asm"
%include "Kernel\VBE\VBE_Graphics_32.asm"
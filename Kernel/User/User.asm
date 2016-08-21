%include "Kernel\Define\Color.asm"

user:
	mov eax, 00ffffffh
	call [G.make_color]
	push eax
	mov eax, 00404040h
	call [G.make_color]
	mov edx, eax
	pop ecx
	mov eax, 0
	mov ebx, 600 << 16 | 800
	call GUI_Console_new
	push eax
	mov ebx, eax
	add ebx, GUI_Console.text
	mov edi, .hello
	call GUI_Text_addLine
	mov edi, .hello
	call GUI_Text_addLine
	mov edi, .hello
	call GUI_Text_addLine
	pop ebx
	mov eax, GE_Draw
	mov ecx, 0
	call [ebx + GUI_Component.event]
	jmp $
	.hello db "1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890Hello world!", 0

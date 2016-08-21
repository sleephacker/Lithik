;adds a string of up to 65535 characters (null/newline inclusive) to the text, starting on a new line.
;IN: ebx = GUI_Text, edi = string
;OUT: ebx = GUI_Text
GUI_Text_addLine:
	push ebx
	push edi
	mov ecx, 10000h
	xor al, al
	repne scasb
	jcxz .tooLong
	mov ebx, 10000h
	sub ebx, ecx
	push ebx
	jmp .loop
	.tooLong:
		add esp, 4
		pop ebx
		ret
	.loop:
		;[esp + 8] = GUI_Text
		;[esp + 4] = string
		;[esp + 0] = length
		mov edi, [esp + 4]
		mov ecx, [esp]
		mov al, GUI_NEWLINE
		repne scasb
		mov eax, [esp]
		sub eax, ecx
		mov [esp], ecx
		xchg [esp + 4], edi
		push edi
		dec eax		;length - termination character
		push eax
		add eax, GUI_Line.struc_size
		call mm_allocate
		pop ecx
		mov [eax + GUI_Line.length], ecx
		pop esi
		mov edi, eax
		add edi, GUI_Line.line
		rep movsb
		mov ebx, [esp + 8]
		.try:
		lock bts dword [ebx + GUI_Text.lines], 31
		jc .retry
		mov ecx, [ebx + GUI_Text.last]
		mov [eax + GUI_Line.prev], ecx
		mov [eax + GUI_Line.next], dword GUI_NULL
		cmp ecx, GUI_NULL
		jne .skip0
		mov [ebx + GUI_Text.first], eax
		jmp .skip1
		.skip0:
		mov [ecx + GUI_Line.next], eax
		.skip1:
		mov [ebx + GUI_Text.last], eax
		inc dword [ebx + GUI_Text.lines]
		lock btr dword [ebx + GUI_Text.lines], 31
		cmp dword [esp], 0
		jne .loop
		add esp, 12
		ret
	.retry:
		pause
		test [ebx + GUI_Text.lines], dword 1 << 31
		jz .try
		jmp .retry

;IN: eax = Y << 16 | X, ebx = H << 16 | W, ecx = foreground, edx = background
;OUT: eax = GUI_Console
GUI_Console_new:
	push eax
	push ebx
	push ecx
	push edx
	mov eax, GUI_Console.struc_size
	call mm_allocate
	pop dword [eax + GUI_Console.background]
	pop dword [eax + GUI_Console.foreground]
	pop dword [eax + GUI_Component.size]
	pop dword [eax + GUI_Component.position]
	mov dword [eax + GUI_Component.parent], GUI_NULL
	mov dword [eax + GUI_Component.event], GUI_Console_event
	mov dword [eax + GUI_Console.text + GUI_Text.lines], 0
	mov dword [eax + GUI_Console.text + GUI_Text.first], GUI_NULL
	mov dword [eax + GUI_Console.text + GUI_Text.last], GUI_NULL
	mov bx, [eax + GUI_Component.W]
	shr bx, 3	;Width / 8
	mov [eax + GUI_Console.charsFit], bx
	mov bx, [eax + GUI_Component.H]
	xchg eax, ebx
	xor dx, dx
	mov cx, 12
	div cx		;Height / 12
	xchg eax, ebx
	mov [eax + GUI_Console.linesFit], bx
	ret

;IN: eax = event, ebx = GUI_Console
GUI_Console_event:
	and eax, eax
	jz .draw
	ret
	.draw:
		call GUI_Console_draw
		ret

;IN: ebx = GUI_Console, ecx = Yoffset << 16 | Xoffset
GUI_Console_draw:
	add ecx, [ebx + GUI_Component.position]
	push ecx
	push ebx
	mov eax, [ebx + GUI_Console.foreground]
	call [G.make_color]
	push eax
	mov ebx, [esp + 4]
	mov eax, [ebx + GUI_Console.background]
	call [G.make_color]
	mov edx, [esp + 4]
	mov ecx, [edx + GUI_Component.size]
	mov ebx, [esp + 8]
	call [G.fill_rect]
	;[esp + 8] = offset
	;[esp + 4] = GUI_Console
	;[esp + 0] = foreground
	mov ebx, [esp + 4]
	mov esi, [ebx + GUI_Console.text + GUI_Text.last]
	cmp esi, GUI_NULL
	je .no_text
	xor ecx, ecx
	mov cx, [ebx + GUI_Console.charsFit]
	mov dx, [ebx + GUI_Console.linesFit]
	xor ebx, ebx
	mov ebx, edx
	.loopFind:
		xor edx, edx
		mov eax, [esi + GUI_Line.length]
		div ecx
		and edx, edx
		jz .skip
		inc eax
		.skip:
		cmp eax, ebx
		jae .found
		sub ebx, eax
		cmp [esi + GUI_Line.prev], dword GUI_NULL
		je .first
		mov esi, [esi + GUI_Line.prev]
		jmp .loopFind
	.no_text:
		add esp, 12
		ret
	.first:
		xor eax, eax
		jmp .print
	.found:
		sub eax, ebx
		mul ecx			;extra lines * charsPerLine = chars to skip
	.print:
		push esi
		;[esp + 12] = offset
		;[esp +  8] = GUI_Console
		;[esp +  4] = foreground
		;[esp +  0] = GUI_Line
		mov edx, esi
		add edx, GUI_Line.line
		add edx, eax
		push edx
		push dword [esi + GUI_Line.length]
		cmp ecx, [esp]
		ja .lastBit
	.loop:
		;[esp + 20] = offset
		;[esp + 16] = GUI_Console
		;[esp + 12] = foreground
		;[esp +  8] = GUI_Line
		;[esp +  4] = string
		;[esp +  0] = length
		mov eax, [esp + 12]
		mov ebx, [esp + 20]
		add [esp + 20], dword 12 << 16
		push ecx
		call [G.draw_string_len_8x12]
		pop ecx
		sub [esp], ecx
		add [esp + 4], ecx
		mov edx, [esp + 4]
		cmp ecx, [esp]
		ja .lastBit
		jmp .loop
	.lastBit:
		push ecx
		mov ecx, [esp + 4]
		mov edx, [esp + 8]
		mov eax, [esp + 16]
		mov ebx, [esp + 24]
		add [esp + 24], dword 12 << 16
		call [G.draw_string_len_8x12]
		pop ecx
		add esp, 8
		pop esi
		cmp [esi + GUI_Line.next], dword GUI_NULL
		je .last
		mov esi, [esi + GUI_Line.next]
		xor eax, eax
		jmp .print
	.last:
		add esp, 12
		ret

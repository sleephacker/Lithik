;assumes edi is at least dword-aligned, uses xmm0
%macro rep_movsd_sse2 0
.unaligned:
	test edi, 1100b
	jz .aligned
	movsd
	loop .unaligned
	jmp .done
.aligned:
	sub ecx, 4
	jc .last_bits
	movdqu xmm0, [esi]
	movdqa [edi], xmm0
	jz .done
	add esi, 16
	add edi, 16
	jmp .aligned
.last_bits:
	add ecx, 4
	rep movsd
.done:
%endmacro

;assumes edi is at least dword-aligned, uses xmm0
%macro rep_stosd_sse2 0
.unaligned:
	test edi, 1100b
	jz .aligned
	stosd
	loop .unaligned
	jmp .done
.aligned:
	sub ecx, 4
	jc .last_bits
	movdqu xmm0, [esi]
	movdqa [edi], xmm0
	jz .done
	add esi, 16
	add edi, 16
	jmp .aligned
.last_bits:
	add ecx, 4
	rep stosd
.done:
%endmacro

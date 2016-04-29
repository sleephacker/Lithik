;TODO: nice file description
;TODO: free unused pages

;IN: panic code
%macro MM_PANIC 1
	mov eax, %1
	call [mm_callback.panic]
	jmp $
%endmacro

;panic codes
%define MM_PANIC_UNDEFINED	0				;undefined callback
%define MM_PANIC_EOM		1				;end of memory

;constants
%define MM_MIN_SPLIT_SIZE	256				;minimal size of the free block after splitting a block

;info flags, use with OR
%define MM_FREE 			1				;used to indicate a free block
%define MM_START 			2				;used to indicate the start of memory
%define MM_END 				4				;used to indicate the end of memory
;info flags, use with AND
%define MM_USED				~MM_FREE		;used to indicate a used block

struc MM_HEADER
	.next		resd 1		;pointer to next header
	.prev		resd 1		;pointer to previous header
	.size		resd 1		;size off this memory block
	.info		resd 1		;contains info flags
	.header_size:			;size of this header
	.block:					;memory block after the header
endstruc

mm:
	.base dd 0
	.end dd 0		;end of memory STRUCTURE
	.eom dd 0		;ACTUAL end of memory

mm_callback:
	;end of memory has been reached
	;IN: eax = extra memory needed in bytes
	;OUT: all registers preserved on success, eax = 0 on error
	;NOTE: may not return on error
	;NOTE: any reference to the previous end of memory header becomes invalid after this call
	.endOfMemory dd mm_undefined
	
	;panic procedure, shouldn't return but crash in a controlled way.
	.panic dd mm_panic

;placeholders
mm_panic: jmp $
mm_undefined:
	mov eax, MM_PANIC_UNDEFINED
	call [mm_callback.panic]

;sets up memory for management
;IN: eax = size of memory, ebx = base of memory
mm_init:
	mov [mm.base], ebx
	sub eax, MM_HEADER.header_size
	mov [ebx + MM_HEADER.next], ebx
	add [ebx + MM_HEADER.next], eax
	mov [ebx + MM_HEADER.prev], dword 0
	mov [ebx + MM_HEADER.size], eax
	sub [ebx + MM_HEADER.size], dword MM_HEADER.header_size
	mov [ebx + MM_HEADER.info], dword MM_FREE | MM_START
	mov ecx, ebx
	add ecx, eax
	mov [mm.end], ecx
	mov [mm.eom], ecx
	add [mm.eom], dword MM_HEADER.header_size
	mov [ecx + MM_HEADER.prev], ebx
	mov [ecx + MM_HEADER.next], dword 0
	mov [ecx + MM_HEADER.info], dword MM_END
	ret

;increases the memory pool size
;IN: eax = added size in bytes
mm_add:
	mov esi, [mm.end]
	add [mm.end], eax
	add [mm.eom], eax
	mov ebx, [esi+MM_HEADER.prev]
	test dword [ebx+MM_HEADER.info], MM_FREE
	jz .used
	jmp .free
	.used:
		mov [esi+MM_HEADER.info], dword MM_FREE
		mov [esi+MM_HEADER.next], esi
		add [esi+MM_HEADER.next], eax
		mov [esi+MM_HEADER.size], eax
		sub [esi+MM_HEADER.size], dword MM_HEADER.header_size
		add esi, eax
		mov [esi+MM_HEADER.prev], esi
		mov [esi+MM_HEADER.next], dword 0
		mov [esi+MM_HEADER.size], dword 0
		mov [esi+MM_HEADER.info], dword MM_END
		ret
	.free:
		add esi, eax
		mov [ebx+MM_HEADER.next], esi
		add [ebx+MM_HEADER.size], eax
		mov [esi+MM_HEADER.prev], ebx
		mov [esi+MM_HEADER.next], dword 0
		mov [esi+MM_HEADER.size], dword 0
		mov [esi+MM_HEADER.info], dword MM_END
		ret

;allocates memory
;IN: eax = size in bytes
;OUT: eax = address
mm_allocate:
	mov esi, [mm.base]
	.loop:
		test dword [esi+MM_HEADER.info], MM_FREE
		jnz .free
		test dword [esi+MM_HEADER.info], MM_END
		jnz .end
	.next:
		mov esi, [esi+MM_HEADER.next]
		jmp .loop
	.free:
		cmp eax, [esi+MM_HEADER.size]
		ja .next
		and dword [esi+MM_HEADER.info], MM_USED
		mov ecx, [esi+MM_HEADER.size]
		sub ecx, eax
		cmp ecx, MM_MIN_SPLIT_SIZE + MM_HEADER.header_size
		jae .split
		lea eax, [esi+MM_HEADER.block]
		ret
	.split:
		mov edi, [esi+MM_HEADER.next]
		mov edx, esi
		mov [esi+MM_HEADER.size], eax
		sub [esi+MM_HEADER.next], ecx
		lea eax, [esi+MM_HEADER.block]
		mov esi, [esi+MM_HEADER.next]
		sub ecx, MM_HEADER.header_size
		mov [esi+MM_HEADER.size], ecx
		mov [esi+MM_HEADER.next], edi
		mov [esi+MM_HEADER.prev], edx
		mov [edi+MM_HEADER.prev], esi
		mov [esi+MM_HEADER.info], dword MM_FREE
		ret
	.end:
		mov esi, [esi+MM_HEADER.prev]	;go to previous block since there may not be a header at this address anymore after the endOfMemory call
		call [mm_callback.endOfMemory]
		and eax, eax
		jnz .loop
		;unresolved, panic
		MM_PANIC MM_PANIC_EOM

;frees a block
;IN: eax = address of block (not the header)
mm_free:
	sub eax, MM_HEADER.header_size
	mov esi, eax
	or dword [eax+MM_HEADER.info], MM_FREE
	.loop0:
		test dword [esi+MM_HEADER.info], MM_START
		jnz .loop1
		mov esi, [esi+MM_HEADER.prev]
		test dword [esi+MM_HEADER.info], MM_FREE
		jnz .loop0
		mov esi, [esi+MM_HEADER.next]
	.loop1:
		mov eax, [eax+MM_HEADER.next]
		test dword [eax+MM_HEADER.info], MM_FREE
		jz .merge
		test dword [eax+MM_HEADER.info], MM_END
		jz .loop1
	.merge:
		mov [eax+MM_HEADER.prev], esi
		mov [esi+MM_HEADER.next], eax
		mov [esi+MM_HEADER.size], eax
		sub [esi+MM_HEADER.size], esi
		sub [esi+MM_HEADER.size], dword MM_HEADER.header_size
		ret

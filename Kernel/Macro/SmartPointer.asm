struc cp_24					;24-bit counting pointer
	.invalid	resb 1		;0 = valid, 1 = invalid
	.count		resb 3
	.struc_size:
endstruc

;jump if reference, does it fast
;IN: cp_24 address, register (e.g. eax), register low (e.g. al), jump address
%macro cp_24_jref 4
	mov %2, 1 << 8
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %4
	lock sub dword [ %1 ], 1 << 8
%endmacro

;jump if no reference, does it properly
;IN: cp_24 address, register (e.g. eax), register low (e.g. al), jump address
%macro cp_24_jnref 4
	cmp byte [ %1 + cp_24.invalid ], 0
	jne %4
	mov %2, 1 << 8
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %%good
	lock sub dword [ %1 ], 1 << 8
	jmp %4
	%%good:
%endmacro

;IN: cp_24 address, register (e.g. eax), register low (e.g. al)
%macro cp_24_ref 3
	%%wait:
	pause
	cmp byte [ %1 + cp_24.invalid ], 0
	jne %%wait
	mov %2, 1 << 8
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %%good
	lock sub dword [ %1 ], 1 << 8
	jmp %%wait
	%%good:
%endmacro

;IN: cp_24 address
%macro cp_24_clear 1
	lock sub dword [ %1 ], 1 << 8
%endmacro

;IN: cp_24 address
;NOTE: uses ax
%macro cp_24_lock 1
	mov ah, 1
	%%wait0:
	pause
	cmp byte [ %1 + cp_24.invalid ], 0
	jne %%wait0
	xor al, al
	lock cmpxchg [ %1 + cp_24.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
	jne %%wait0									;wait if [...] != 0
	%%wait1:
	pause
	cmp dword [ %1 ], 1							;.count == 0 && .invalid == 1
	jne %%wait1
%endmacro

;IN: cp_24 address, test_macro
;NOTE: uses ax
;NOTE: test_macro is responsible for letting code outside this macro know if the attempt was aborted
;test_macro IN: address to jump to to continue (don't jump to abort)
%macro cp_24_lock_or_abort 2
	mov ah, 1
	%%wait0:
		pause
		cmp byte [ %1 + cp_24.invalid ], 0
		jne %%test
		xor al, al
		lock cmpxchg [ %1 + cp_24.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
		jne %%test									;wait if [...] != 0
	%%wait1:
		pause
		cmp dword [ %1 ], 1							;.count == 0 && .invalid == 1
		je %%done
	%%test1:
		%2 %%wait1
		mov [ %1 + cp_24.invalid ], 0
		jmp %%done
	%%test0:
		%2 %%wait0
	%%done:
%endmacro

;IN: cp_24 address, test_macro, address to jump to if aborted
;NOTE: uses ax
;NOTE: test_macro is responsible for letting code outside this macro know if the attempt was aborted
;test_macro IN: address to jump to to continue (don't jump to abort)
%macro cp_24_lock_or_abort_jmp 3
	mov ah, 1
	%%wait0:
		pause
		cmp byte [ %1 + cp_24.invalid ], 0
		jne %%test
		xor al, al
		lock cmpxchg [ %1 + cp_24.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
		jne %%test									;wait if [...] != 0
	%%wait1:
		pause
		cmp dword [ %1 ], 1							;.count == 0 && .invalid == 1
		je %%done
	%%test1:
		%2 %%wait1
		mov [ %1 + cp_24.invalid ], 0
		jmp %3
	%%test0:
		%2 %%wait0
		jmp %3
	%%done:
%endmacro

;IN: cp_24 address
%macro cp_24_unlock 1
	mov byte [ %1 + cp_24.invalid ], 0
%endmacro

struc cp_16					;16-bit counting pointer
	.invalid	resb 1		;0 = valid, 1 = invalid
	.pad		resb 1
	.count		resw 1
	.struc_size:
endstruc

;jump if reference, does it fast
;IN: cp_16 address, register (e.g. eax), register low (e.g. al), jump address
%macro cp_16_jref 4
	mov %2, 1 << 16
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %4
	lock dec word [ %1 + cp_16.count ]
%endmacro

;jump if no reference, does it properly
;IN: cp_24 address, register (e.g. eax), register low (e.g. al), jump address
%macro cp_16_jnref 4
	cmp byte [ %1 + cp_16.invalid ], 0
	jne %4
	mov %2, 1 << 16
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %%good
	lock dec word [ %1 + cp_16.count ]
	jmp %4
	%%good:
%endmacro

;IN: cp_16 address, register (e.g. eax), register low (e.g. al)
%macro cp_16_ref 3
	%%wait:
	pause
	cmp byte [ %1 + cp_16.invalid ], 0
	jne %%wait
	mov %2, 1 << 16
	lock xadd dword [ %1 ], %2
	and %3, %3
	jz %%good
	lock dec word [ %1 + cp_16.count ]
	jmp %%wait
	%%good:
%endmacro

;IN: cp_16 address
%macro cp_16_clear 1
	lock dec word [ %1 + cp_16.count ]
%endmacro

;IN: cp_16 address
;NOTE: uses ax
%macro cp_16_lock 1
	mov ah, 1
	%%wait0:
	pause
	cmp byte [ %1 + cp_16.invalid ], 0
	jne %%wait0
	xor al, al
	lock cmpxchg [ %1 + cp_16.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
	jne %%wait0									;wait if [...] != 0
	%%wait1:
	pause
	cmp word [ %1 + cp_16.count ], 0
	jne %%wait1
%endmacro

;IN: cp_16 address, test_macro
;NOTE: uses ax
;NOTE: test_macro is responsible for letting code outside this macro know if the attempt was aborted
;test_macro IN: address to jump to to continue (don't jump to abort)
%macro cp_16_lock_or_abort 2
	mov ah, 1
	%%wait0:
		pause
		cmp byte [ %1 + cp_16.invalid ], 0
		jne %%test0
		xor al, al
		lock cmpxchg [ %1 + cp_16.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
		jne %%test0									;wait if [...] != 0
	%%wait1:
		pause
		cmp word [ %1 + cp_16.count ], 0
		je %%done
	%%test1:
		%2 %%wait1
		mov word [ %1 + cp_16.invalid ], 0
		jmp %%done
	%%test0:
		%2 %%wait0
	%%done:
%endmacro

;IN: cp_16 address, test_macro, address to jump to if aborted
;NOTE: uses ax
;NOTE: test_macro is responsible for letting code outside this macro know if the attempt was aborted
;test_macro IN: address to jump to to continue (don't jump to abort)
%macro cp_16_lock_or_abort_jmp 3
	mov ah, 1
	%%wait0:
		pause
		cmp byte [ %1 + cp_16.invalid ], 0
		jne %%test0
		xor al, al
		lock cmpxchg [ %1 + cp_16.invalid ], ah		;if [...] == al == 0 then [...] = ah = 1 else al = [...] = 1
		jne %%test0									;wait if [...] != 0
	%%wait1:
		pause
		cmp word [ %1 + cp_16.count ], 0
		je %%done
	%%test1:
		%2 %%wait1
		mov word [ %1 + cp_16.invalid ], 0
		jmp %3
	%%test0:
		%2 %%wait0
		jmp %3
	%%done:
%endmacro

;IN: cp_16 address
%macro cp_16_unlock 1
	mov byte [ %1 + cp_16.invalid ], 0
%endmacro

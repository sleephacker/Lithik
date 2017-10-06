;TODO: code using ticketlocks should be uninterruptible, this should be enforced inside the macros
;all ticketlocks should be initialised to 0s

struc tlock_2x16								;must be 16-bit aligned to make use of guaranteed atomic read (see intel manual vol. 3A, 8.1.1)
	.owner		resw 1							;current lock owner ticket number
	.next		resw 1							;next ticket number
endstruc										;NOTE: code will break if this structure changes

;MACRO IN: [lock address]
;NOTE: uses eax and ebx, lock address must not use eax or ebx
%macro tlock_2x16_acquire_ab 1
	mov eax, 1 << 16
	lock xadd %1, eax							;increments .next without modifying .owner
	mov ebx, eax
	shr ebx, 16
	xor ax, bx
	jz %%done
	%%wait:
		pause
		cmp %1, bx								;reads from 16-bit aligned words are guaranteed to be atomic
		jne %%wait
	%%done:
%endmacro

;MACRO IN: [lock address]
;NOTE: uses ecx and edx, lock address must not use ecx or edx
%macro tlock_2x16_acquire_cd 1
	mov ecx, 1 << 16
	lock xadd %1, ecx							;increments .next without modifying .owner
	mov edx, ecx
	shr edx, 16
	xor cx, dx
	jz %%done
	%%wait:
		pause
		cmp %1, dx								;reads from 16-bit aligned words are guaranteed to be atomic
		jne %%wait
	%%done:
%endmacro

;MACRO IN: [lock address]
%macro tlock_2x16_release 1
	lock inc word %1							;pass to next owner
%endmacro

struc tlock_2x8									;doesn't have to be aligned to make use of guaranteed atomic read (see intel manual vol. 3A, 8.1.1)
	.owner		resw 1							;current lock owner ticket number
	.next		resw 1							;next ticket number
endstruc										;NOTE: code will break if this structure changes

;MACRO IN: lock address, register to use (ax, bx, cx, dx)
;NOTE: lock address must not use the specified register
%macro tlock_2x8_acquire 2
	mov %2, 1 << 8
	lock xadd %1, %2							;increments .next without modifying .owner
	%if %2 == ax
	xor al, ah
	%elif %2 == bx
	xor bl, bh
	%elif %2 == cx
	xor cl, ch
	%elif %2 ==dx
	xor dl, ch
	%else
	%error "Non-existent register!"
	%endif
	jz %%done
	%%wait:										;byte reads are guantanteed to be atomic
		pause
		%if %2 == ax
		cmp %1, ah
		%elif %2 == bx
		cmp %1, bh
		%elif %2 == cx
		cmp %1, ch
		%elif %2 == dx
		cmp %1, dh
		%else
		%error "Non-existent register!"
		%endif
		jne %%wait
	%%done
%endmacro

;MACRO IN: [lock address]
%macro tlock_2x8_release 1
	lock inc byte %1							;pass to next owner
%endmacro

;PCI header type 0
struc PCI_H0
	.vendor_id			resw 1
	.device_id			resw 1
	.command			resw 1
	.status				resw 1
	.class				resb 1
	.subclass			resb 1
	.prog_if			resb 1
	.rev_id				resb 1
	.BIST				resb 1
	.header_type		resb 1
	.lat_timer			resb 1
	.cache_line			resb 1
	.BAR0				resd 1
	.BAR1				resd 1
	.BAR2				resd 1
	.BAR3				resd 1
	.BAR4				resd 1
	.BAR5				resd 1
	.CIS				resd 1
	.sub_vendor_id		resw 1
	.sub_id				resw 1
	.XROM				resd 1
	.cap				resb 1
						resb 7
	.INT_line			resb 1
	.INT_pin			resb 1
	.min_grant			resb 1
	.max_lat			resb 1
endstruc

boot_PCI_device_list:
	mov eax, 0
	mov ebx, 0
	mov bx, [VGA.boot_safe_print]
	.loop:
		push eax
		push ebx
		
		call PCI_read_32
		
		cmp ax, 0xffff
		je .skip
		
		mov edi, found_device_string_compact.vendor_id
		call format_hex_word
		
		ror eax, 10h
		
		mov edi, found_device_string_compact.device_id
		call format_hex_word
		
		pop ebx
		mov eax, ebx
		push ebx
		
		;mov bl, 02h
		;mov bh, 0xa0
		mov bx, [VGA.print_defaults]
		mov esi, found_device_string_compact
		call boot_print
		
		pop ebx
		pop eax
		
		add eax, 800h	;next device
		cmp eax, 1000000h
		ja .finished
		
		add ebx, 40d	;length of compact string + 4
		
		jmp .loop
		
	.skip:
		pop ebx
		pop eax
		
		add eax, 800h	;next device
		cmp eax, 1000000h
		ja .finished
		
		jmp .loop
	.finished:
		ret

boot_PCI_find:		;TODO
	mov esi, boot_console.line+8
	;add esi, 8
	call parse_hex_dword
	push eax
	cmp ecx, 0
	jne .invalid
	call boot_clear_screen
	pop ebx
	mov eax, 0
	.loop:
		push eax
		
		call PCI_read_32
		
		cmp eax, ebx
		je .found
		
		pop eax
		
		add eax, 800h	;next device
		cmp eax, 1000000h
		ja .finished
		
		jmp .loop
	.found:
		pop eax
		mov ecx, 64
		.read:
			push eax
			push ecx
			
			dec ecx
			shr eax, 2
			add eax, ecx
			shl eax, 2
			call PCI_read_32
			
			mov edi, device_dump
			add edi, ecx
			shl ecx, 3
			add edi, ecx
			;inc edi
			call format_hex_dword
			
			pop ecx
			pop eax
			loop .read
		;mov bl, 02h
		;mov bh, 0xa4
		mov bx, [VGA.log_defaults]
		mov eax, 0
		mov esi, device_dump
		call boot_print
		ret
	.finished:
		ret
	.invalid:
		add esp, 4	;pop (32 bits of nothing)
		mov esi, strings.invalid_input
		call boot_print_default
		jmp .finished
	.number dd 0

;eax = 0 means error
PCI_find_ethernet:
	mov eax, 8
	.loop:
		push eax
		
		call PCI_read_32
		
		and eax, 0xffff0000
		cmp eax, 0x02000000
		je .found
		
		pop eax
		
		add eax, 800h	;next device
		cmp eax, 1000000h
		ja .notfound
		
		jmp .loop
	.found:
		pop eax
		sub eax, 8
		ret
	.notfound:
		mov eax, 0
		ret

;reads a 32 bit aligned dword from the PCI space
;IN: eax = PCI address
;OUT: eax = value
;NOTE: only uses eax and edx
PCI_read_32:
	or eax, 80000000h
	mov dx, 0xcf8
	out dx, eax
	mov dx, 0xcfc
	in eax, dx
	ret

;reads a byte from the PCI space
;IN: eax = PCI address
;OUT: al = value
;NOTE: doesn't use edi or esi
PCI_read_8:
;reads a 16 bit aligned word from the PCI space
;IN: eax = PCI address
;OUT: ax = value
;NOTE: doesn't use edi or esi
PCI_read_16:
	mov cl, al
	and eax, 0xfffffffc	;mask lowest 2 bits to mak it 32 bit aligned
	call PCI_read_32
	and cl, 11b
	shl cl, 3
	shr eax, cl
	ret

pci_strings:
found_device_string:
	db "Found device:"
	db 0ah
	db "Vendor ID: "
	.vendor_id times 4 db 0
	db 0ah
	db "Device ID: "
	.device_id times 4 db 0
	db 0
found_device_string_compact:	;length = 16 bytes = 32 bytes in VGA RAM
	db "VID:"
	.vendor_id times 4 db 0
	db "DID:"
	.device_id times 4 db 0
	db 0
device_dump:					;256 hex bytes * 2 + 1 zero byte
	times 16 db "-------- -------- -------- --------", 0ah
	db 0
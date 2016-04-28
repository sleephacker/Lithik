struc i8255
	.pci		resd 1	;PCI address
	.devId		resw 1	;PCI device id
	.csr		resd 1	;CSR
	.struc_size:
endstruc

;IN: eax = PCI address
;OUT: eax = address of netDevice structure
i8255_init:
	push eax
	mov eax, netDevice.struc_size + i8255.struc_size
	call mm_allocate		;allocate both in one go
	mov ebx, eax
	add ebx, netDevice.struc_size
	push eax
	push ebx
	;[esp + 8] = PCI address
	;[esp + 4] = netDevice address
	;[esp + 0] = i8255 address
	jmp $
	ret

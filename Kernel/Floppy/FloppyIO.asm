;generic operations
%define floppy_IO_READ 1000h			;read operation
%define floppy_IO_WRITE 2000h			;write operation
;operations
%define floppy_IO_READ_1 1001h			;read one sector
%define floppy_IO_WRITE_1 2001h			;write one sector
;return codes
%define floppy_IO_SUCCES 0d				;operation succesful
%define floppy_IO_TIMEOUT 1d			;operation timed out
%define floppy_IO_INVALID 2d			;invalid operation, (non existing drive, sector out of range)
%define floppy_IO_NO_DRIVE 3d			;requested drive not present
%define floppy_IO_BAD_DRIVE 4d			;bad / unsupported drive
%define floppy_IO_SEL_ERROR 5d			;error while selecting disk, most likely because there is no disk
%define floppy_IO_READ_ERROR 6d			;error while reading from disk
%define floppy_IO_WRITE_ERROR 7d		;error while writing to disk
%define floppy_IO_BUSY 8d				;driver busy
%define floppy_IO_WRITE_PROTECT 9d		;disk is write protected
%define floppy_IO_FDC_NOT_INIT 10d		;FDC needs to be initialized first
;constants
%define floppy_IO_MAX_DRIVE 3			;maximum valid drive number

Floppy_IO:
	.busy db 0		;1 = Floppy_IO is busy, to be used with multitasking
	.op dw 0		;current / last operation
	.ret dw 0		;return code

;waits until [Floppy_IO.busy] == 0
;must be called by every operation before starting the actual operation
;IN: edx = timeout
;OUT: return code in dx
floppy_busy_wait:
	add edx, [IRQ_0.counter]
	.loop:
		cmp byte [Floppy_IO.busy], 0
		je .return
		hlt
		cmp edx, [IRQ_0.counter]
		ja .loop
	.timeout:
		mov dx, floppy_IO_TIMEOUT
		ret
	.return:
		mov dx, floppy_IO_SUCCES
		ret

;READ OPERATIONS

;TODO: this is a placeholder
;reads multiple sectors
;IN: eax = LBA sector | drive << 28, ebx = buffer address, ecx = sector count, edx = busy_wait timeout
;OUT: return code in ax, [Floppy_IO.ret] (except when busy)
floppy_read_sectors:
	.loop:
		push eax
		push ebx
		push ecx
		push edx
		call floppy_read_sector
		cmp ax, floppy_IO_SUCCES
		jne .ret
		pop edx
		pop ecx
		pop ebx
		pop eax
		inc eax			;next sector
		add ebx, 512d	;next sector
		loop .loop
		mov ax, floppy_IO_SUCCES
		ret
	.ret:
		add esp, 16		;pop eax, ebx, ecx, edx
		ret

;reads a single sector
;IN: eax = LBA sector | drive << 28, ebx = buffer address, edx = busy_wait timeout
;OUT: return code in ax, [Floppy_IO.ret] (except when busy)
%define floppy_read_sector_tries 4
floppy_read_sector:
	call floppy_busy_wait
	cmp dx, floppy_IO_SUCCES
	jne .busy
	mov byte [Floppy_IO.busy], 1
	mov word [Floppy_IO.op], floppy_IO_READ_1
	cmp byte [Floppy_State.init], 0
	jne .fdcinit
	mov byte [.tries], floppy_read_sector_tries
	.try:
		push ebx
		push eax
		mov word [Floppy_Transfer.op], floppy_DMAR
		mov byte [Floppy_Transfer.sectors], 1
		shr eax, 28d
		cmp al, floppy_IO_MAX_DRIVE
		ja .invalid
		mov [Floppy_Transfer.drive], al
		mov [Floppy_State.drive], al
		call floppy_select_disk
		cmp al, floppy_SUCCES
		je .selected
	.retry:
		dec byte [.tries]
		cmp byte [.tries], 0
		je .select_error
		pop eax
		pop ebx
		jmp .try
	.selected:
		pop eax
		cmp ax, [Floppy_Disk.maxLBA]
		ja .outOfRange
	.setup_transfer:
		mov dx, 0
		div word [Floppy_Disk.sectPerCyl]
		inc dl		;sectors are 1 based
		mov [Floppy_Transfer.sector], dl
		xor dx, dx
		div word [Floppy_Disk.heads]
		mov [Floppy_Transfer.cyl], al
		mov [Floppy_Transfer.head], dl
		;TODO/NOTE: leaving [Floppy_Transfer.gap] as is
	.transfer:
		call floppy_transfer
		cmp al, floppy_SUCCES
		jne .retry_transfer
		call floppy_motors_off
	.relocate:
		pop ebx
		mov edi, ebx
		mov esi, [DMA.floppy_base]
		mov ecx, 512d	;one sector
		rep movsb
		mov word [Floppy_IO.ret], floppy_IO_SUCCES
		mov ax, floppy_IO_SUCCES
		mov byte [Floppy_IO.busy], 0
		ret
	.retry_transfer:
		dec byte [.tries]
		cmp byte [.tries], 0
		je .transfer_error
		jmp .transfer
	.busy:
		mov ax, floppy_IO_BUSY	;don't change anything in Floppy_IO when busy, always check ax for the return code
		ret
	.fdcinit:
		mov word [Floppy_IO.ret], floppy_IO_FDC_NOT_INIT
		mov ax, floppy_IO_FDC_NOT_INIT
		mov byte [Floppy_IO.busy], 0
		ret
	.outOfRange:
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_INVALID
		mov ax, floppy_IO_INVALID
		add esp, 4	;pop ebx
		mov byte [Floppy_IO.busy], 0
		ret
	.invalid:
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_INVALID
		mov ax, floppy_IO_INVALID
		add esp, 8	;pop eax and ebx
		mov byte [Floppy_IO.busy], 0
		ret
	.select_error:
		cmp al, floppy_NO_DRIVE
		je .nodrive
		cmp al, floppy_BAD_DRIVE
		je .baddrive
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_SEL_ERROR
		mov ax, floppy_IO_SEL_ERROR
		add esp, 8	;pop eax and ebx
		mov byte [Floppy_IO.busy], 0
		ret
		.nodrive:
			call floppy_motors_off
			mov word [Floppy_IO.ret], floppy_IO_NO_DRIVE
			mov ax, floppy_IO_NO_DRIVE
			add esp, 8	;pop eax and ebx
			mov byte [Floppy_IO.busy], 0
			ret
		.baddrive:
			call floppy_motors_off
			mov word [Floppy_IO.ret], floppy_IO_BAD_DRIVE
			mov ax, floppy_IO_BAD_DRIVE
			add esp, 8	;pop eax and ebx
			mov byte [Floppy_IO.busy], 0
			ret
	.transfer_error:
		;call boot_print_byte_default
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_READ_ERROR
		mov ax, floppy_IO_READ_ERROR
		add esp, 4	;pop ebx
		mov byte [Floppy_IO.busy], 0
		ret
	.tries db floppy_read_sector_tries

;WRITE OPERATIONS

;TODO: this is a placeholder
;writes multiple sectors
;IN: eax = LBA sector | drive << 28, ebx = buffer address, ecx = sector count, edx = busy_wait timeout
;OUT: return code in ax, [Floppy_IO.ret] (except when busy)
floppy_write_sectors:
	.loop:
		push eax
		push ebx
		push ecx
		push edx
		call floppy_write_sector
		cmp ax, floppy_IO_SUCCES
		jne .ret
		pop edx
		pop ecx
		pop ebx
		pop eax
		inc eax			;next sector
		add ebx, 512d	;next sector
		loop .loop
		mov ax, floppy_IO_SUCCES
		ret
	.ret:
		add esp, 16		;pop eax, ebx, ecx, edx
		ret

;writes a single sector
;IN: eax = LBA sector | drive << 28, ebx = buffer address, edx = busy_wait timeout
;OUT: return code in ax, [Floppy_IO.ret]
%define floppy_write_sector_tries 4
floppy_write_sector:
	call floppy_busy_wait
	cmp dx, floppy_IO_SUCCES
	jne .busy
	mov byte [Floppy_IO.busy], 1
	mov word [Floppy_IO.op], floppy_IO_WRITE_1
	cmp byte [Floppy_State.init], 0
	jne .fdcinit
	mov byte [.tries], floppy_write_sector_tries
	.try:
		push ebx
		push eax
		mov word [Floppy_Transfer.op], floppy_DMAW
		mov byte [Floppy_Transfer.sectors], 1
		shr eax, 28d
		cmp al, floppy_IO_MAX_DRIVE
		ja .invalid
		mov [Floppy_Transfer.drive], al
		mov [Floppy_State.drive], al
		call floppy_select_disk
		cmp al, floppy_SUCCES
		je .selected
	.retry:
		dec byte [.tries]
		cmp byte [.tries], 0
		je .select_error
		pop eax
		pop ebx
		jmp .try
	.selected:
		pop eax
		cmp ax, [Floppy_Disk.maxLBA]
		ja .outOfRange
	.relocate:
		pop ebx
		mov esi, ebx
		mov edi, [DMA.floppy_base]
		mov ecx, 512d	;one sector
		rep movsb
	.setup_transfer:
		mov dx, 0
		div word [Floppy_Disk.sectPerCyl]
		inc dl		;sectors are 1 based
		mov [Floppy_Transfer.sector], dl
		xor dx, dx
		div word [Floppy_Disk.heads]
		mov [Floppy_Transfer.cyl], al
		mov [Floppy_Transfer.head], dl
		;TODO/NOTE: leaving [Floppy_Transfer.gap] as is
	.transfer:
		call floppy_transfer
		cmp al, floppy_SUCCES
		jne .retry_transfer
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_SUCCES
		mov ax, floppy_IO_SUCCES
		mov byte [Floppy_IO.busy], 0
		ret
	.retry_transfer:
		dec byte [.tries]
		cmp byte [.tries], 0
		je .transfer_error
		jmp .transfer
	.busy:
		mov ax, floppy_IO_BUSY	;don't change anything in Floppy_IO when busy, always check ax for the return code
		ret
	.fdcinit:
		mov word [Floppy_IO.ret], floppy_IO_FDC_NOT_INIT
		mov ax, floppy_IO_FDC_NOT_INIT
		mov byte [Floppy_IO.busy], 0
		ret
	.outOfRange:
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_INVALID
		mov ax, floppy_IO_INVALID
		add esp, 4	;pop ebx
		mov byte [Floppy_IO.busy], 0
		ret
	.invalid:
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_INVALID
		mov ax, floppy_IO_INVALID
		add esp, 8	;pop eax and ebx
		mov byte [Floppy_IO.busy], 0
		ret
	.select_error:
		cmp al, floppy_NO_DRIVE
		je .nodrive
		cmp al, floppy_BAD_DRIVE
		je .baddrive
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_SEL_ERROR
		mov ax, floppy_IO_SEL_ERROR
		add esp, 8	;pop eax and ebx
		mov byte [Floppy_IO.busy], 0
		ret
		.nodrive:
			call floppy_motors_off
			mov word [Floppy_IO.ret], floppy_IO_NO_DRIVE
			mov ax, floppy_IO_NO_DRIVE
			add esp, 8	;pop eax and ebx
			mov byte [Floppy_IO.busy], 0
			ret
		.baddrive:
			call floppy_motors_off
			mov word [Floppy_IO.ret], floppy_IO_BAD_DRIVE
			mov ax, floppy_IO_BAD_DRIVE
			add esp, 8	;pop eax and ebx
			mov byte [Floppy_IO.busy], 0
			ret
	.transfer_error:
		;call boot_print_byte_default
		cmp al, floppy_READONLY
		je .write_protect
		call floppy_motors_off
		mov word [Floppy_IO.ret], floppy_IO_WRITE_ERROR
		mov ax, floppy_IO_WRITE_ERROR
		mov byte [Floppy_IO.busy], 0
		ret
		.write_protect:
			call floppy_motors_off
			mov word [Floppy_IO.ret], floppy_IO_WRITE_PROTECT
			mov ax, floppy_IO_WRITE_PROTECT
			mov byte [Floppy_IO.busy], 0
			ret
	.tries db floppy_write_sector_tries

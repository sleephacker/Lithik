;ports
%define floppy_SRA 03f0h	;RO		Status Register A
%define floppy_SRB 03f1h	;RO		Status Register B
%define floppy_DOR 03f2h	;RW		Digital Output Register
%define floppy_TDR 03f3h	;RW		Tape Drive Register
%define floppy_MSR 03f4h	;R-		Main Status Register
%define floppy_DSR 03f4h	;-W		Datarate Select Register
%define floppy_FIFO 03f5h	;RW		FIFO Port
%define floppy_DIR 03f7h	;R-		Digital Input Register
%define floppy_CCR 03f7h	;-W		Configuration Control Register
;bits
%define floppy_MT 0x80
%define floppy_MF 0x40
%define floppy_SK 0x20
;drives
%define floppy_NULLDRV 0xff	;no drive selected
;commands
%define floppy_SPECIFY 3d
%define floppy_READ 6d | floppy_MT | floppy_MF
%define floppy_WRITE 5d | floppy_MT | floppy_MF
%define floppy_RECALIBRATE 7d
%define floppy_SENSE_INT 8d
%define floppy_VERSION 16d
%define floppy_CONFIG 19d
%define floppy_UNLOCK 20d
%define floppy_LOCK 20d | floppy_MT
;operations
%define floppy_RESET 100h	;resetting floppy
%define floppy_WAIT 101h	;waiting for IRQ 6
%define floppy_SELDRV 102h	;selecting drive
%define floppy_RECDRV 103h	;recalibrating drive
%define floppy_CMDRDY 104h	;waiting until MSR & 0xc0 == 0x80
%define floppy_DMAR 105h	;reading
%define floppy_DMAW 106h	;writing
%define floppy_DMAU 107h	;unknown DMA operation
%define floppy_SELDSK 108h	;selecting disk
%define floppy_REC_ALL 109h	;recalibrating all drives
;return status
%define floppy_SUCCES 0
%define floppy_TIMEOUT 1
%define floppy_ERROR 2
%define floppy_NO_DRIVE 3
%define floppy_READONLY 4	;write protected
%define floppy_CYL_END 5	;reached end of cylinder
%define floppy_BAD_DRIVE 6	;unsupported disk

Floppy_IRQ_6:
	push edi
	push esi
	push eax
	push ebx
	push ecx
	push edx
	push ds
	pushfd
	mov ax, 10h
	mov ds, ax	;set data segment, just in case
	
	;mov al, 66h
	;mov bx, 0xc404	;red
	;call boot_log_byte
	inc dword [.unhandled]
	cmp dword [.expecting], 0
	je .unexpected_IRQ
	dec dword [.expecting]
	jmp .return
	.unexpected_IRQ:
		;TODO: error message
		;call floppy_sense_int
		;mov ah, [floppy_sense_int.st0]
		;mov al, [floppy_sense_int.cyl]
		;mov bx, 0xc404	;red
		;call boot_log_word
		inc dword [.unexpected]
		jmp .return
	
	.return:
		mov al, 20h
		;out 00a0h, al
		out 0020h, al
		
		popfd
		pop ds
		pop edx
		pop ecx
		pop ebx
		pop eax
		pop esi
		pop edi
		iret
	.wait_ready:		;eax = timeout in millis, returns 0 in al if succesful or 1 if timed out
		inc dword [.expecting]
		mov ebx, [.unhandled]
		;push ebx		;must be saved for .wait by caller
		ret
	.wait:				;call .wait_ready first
		;pop ebx		;must be saved by caller
		mov word [Floppy_State.last_op], floppy_WAIT
		add eax, [IRQ_0.counter]
		.l:
			cmp ebx, [.unhandled]
			jb .done
			cmp eax, [IRQ_0.counter]
			jae .l
			hlt
			jmp .timeout
		.done:
			dec dword [.unhandled]
			mov al, floppy_SUCCES
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			ret
		.timeout:
			sub dword [.expecting], 1
			jnc .to
			mov dword [.expecting], 0
			jmp .done	;interrupt happened anyway
			.to:
				mov al, floppy_TIMEOUT
				mov byte [Floppy_State.last_ret], floppy_TIMEOUT
				ret
	.unhandled dd 0
	.expecting dd 0
	.unexpected dd 0

Floppy_State:
	.init db 0xff	;ff = not started, 0 = complete, between = step where init failed
	.dead dw 0		;0x0000 = alive, 0xdead = dead
	.last_op dw 0	;used to track errors
	.last_ret db 0	;used to track errors
	.config db 0	;used by floppy_configure
	.DOR db 0		;used by floppy_reset
	.types:			;drive type for each of the four (?) drives: 0 = no drive, 1 = 360KB, 2 = 1200KB, 3 = 720KB, 4 = 1440KB, 5 = 2880KB
		.drv0 db 0	;TODO/NOTE: CMOS only supports up to 2 drives, but the FDC up to 4...?
		.drv1 db 0	;
		.drv2 db 0	;
		.drv3 db 0	;
	.drive db 0		;
	.motor db 0		;0 = off, 1 = on, applies to selected drive

Floppy_Transfer:
	.op dw 0		;operation
	.drive db 0		;drive to select
	.cyl db 0		;start cylinder
	.head db 0		;start head
	.sector db 0	;start sector
	.sectors db 0	;number of sectors to transfer
	.gap db 0x1b	;default gap length		

Floppy_Disk:
	.drive db 0xff	;no drive selected
	.cylinders dw 0
	.sectPerCyl dw 0
	.heads dw 0
	.maxLBA dw 0	;maximum LBA sector

%define floppy_version_tries 2
%define floppy_configure_tries 2
%define floppy_lock_tries 2
floppy_init:
	cmp byte [Floppy_State.init], 0
	je .return
	
	mov byte [Floppy_State.init], 1
	mov byte [Floppy_State.dead], 0
	mov byte [Floppy_State.DOR], 0x0c	;in case a reset is needed
	mov byte [Floppy_State.drive], 0	;select the first drive, TODO: select first drive that actually has media in it.
	mov byte [Floppy_State.motor], 1	;turn motor on
	
	mov byte [.version_tries], floppy_version_tries
	mov byte [.configure_tries], floppy_configure_tries
	mov byte [.lock_tries], floppy_lock_tries
	.version:
		call floppy_version
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		jne .version_retry
		cmp ah, 0x90
		je .version_ok
		jmp .die
		.version_retry:
			dec byte [.version_tries]
			cmp byte [.version_tries], 0
			je .die
			call floppy_reset
			jmp .version
	.version_ok:
		mov esi, .msg_version_ok
		call .print
		mov byte [Floppy_State.init], 2
	.configure:
		mov byte [Floppy_State.config], 01010111b	;implied seek on, FIFO on, drive polling off, threshhold = 8
		call floppy_configure
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .configure_ok
		.configure_retry:
			dec byte [.configure_tries]
			cmp byte [.configure_tries], 0
			je .die
			call floppy_reset
			jmp .configure
	.configure_ok:
		mov esi, .msg_configure_ok
		call .print
		mov byte [Floppy_State.init], 3
	.lock:
		mov al, 1									;lock enabled
		call floppy_lock
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .lock_ok
		.lock_retry:
			dec byte [.lock_tries]
			cmp byte [.lock_tries], 0
			je .die
			call floppy_reset
			jmp .lock
	.lock_ok:
		mov esi, .msg_lock_ok
		call .print
		mov byte [Floppy_State.init], 4
	.reset:
		call floppy_reset
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .reset_ok
		jmp .die
	.reset_ok:
		mov byte [Floppy_State.init], 5
	.recalibrate:
		call floppy_recalibrate_all
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .recalibrate_ok
		jmp .die
	.recalibrate_ok:
		mov esi, .msg_recdrv_ok
		call .print
		mov byte [Floppy_State.init], 6
	.return:
		call floppy_motors_off
		mov byte [Floppy_State.init], 0
		call floppy_register
		cmp byte [.output], 1
		je .return_print_boot
		cmp byte [.output], 2
		je .return_print_boot
		ret
		.return_print_boot:
			mov esi, .msg_succes
			call boot_print_default
			ret
	.die:
		mov word [Floppy_State.dead], 0xdead
	.dead:
		cmp byte [.output], 1
		je .dead_print_boot
		cmp byte [.output], 2
		je .dead_print_boot
		ret
		.dead_print_boot:
			mov ax, [Floppy_State.last_op]
			call boot_log_word_default
			mov al, [Floppy_State.last_ret]
			call boot_log_byte_default
			mov al, [Floppy_State.init]
			call boot_log_byte_default
			mov esi, .msg_dead
			call boot_print_default
			ret
	.print:
		cmp byte [.output], 1
		je .print_boot
		ret
		.print_boot:
			call boot_print_default
			ret
	.output db 0	;0 = no output, 1 = boot console output, 2 = output completion message to boot console
	.version_tries db floppy_version_tries
	.configure_tries db floppy_configure_tries
	.lock_tries db floppy_lock_tries
	.msg_dead db ": FDC driver gave up.", 0
	.msg_succes db "Floppy Drive Controller initialization complete.", 0
	.msg_version_ok db "FDC version OK...", 0
	.msg_configure_ok db "FDC configure OK...", 0
	.msg_lock_ok db "FDC lock OK...", 0
	.msg_recdrv_ok db "FDC recalibrate OK...", 0

%define floppy_select_tries 2
%define floppy_recdrv_tries 2
floppy_recalibrate_all:
	call floppy_update_drives
	mov byte [Floppy_State.drive], 0
	mov byte [Floppy_State.motor], 1
	.loop:
		mov eax, Floppy_State.types
		xor ebx, ebx
		mov bl, [Floppy_State.drive]
		add eax, ebx
		xor ebx, ebx
		mov bl, [eax]
		cmp bl, 0		;no drive, skip it
		je .recdrv_ok
		mov byte [.select_tries], floppy_select_tries
		mov byte [.recdrv_tries], floppy_recdrv_tries
		.select:
			mov byte [floppy_select_drive.ignore_drive_error], 1
			call floppy_select_drive
			mov byte [floppy_select_drive.ignore_drive_error], 0
			cmp word [Floppy_State.dead], 0xdead
			je .dead
			cmp al, floppy_SUCCES
			je .recdrv
			.select_retry:
				dec byte [.select_tries]
				cmp byte [.select_tries], 0
				je .die
				call floppy_reset
				jmp .select
		.recdrv:
			call floppy_recalibrate_drive
			cmp word [Floppy_State.dead], 0xdead
			je .dead
			cmp al, floppy_SUCCES
			je .recdrv_ok
			.recdrv_retry:
				dec byte [.recdrv_tries]
				cmp byte [.recdrv_tries], 0
				je .die
				call floppy_reset
				jmp .recdrv
		.recdrv_ok:
			inc byte [Floppy_State.drive]
			cmp byte [Floppy_State.drive], 3
			ja .return
			jmp .loop
	.return:
		mov byte [Floppy_State.drive], 0
		mov byte [Floppy_Disk.drive], 0xff	;needs to be selected
		mov word [Floppy_State.last_op], floppy_REC_ALL
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret
	.die:
		mov word [Floppy_State.dead], 0xdead
	.dead:
		mov byte [Floppy_Disk.drive], 0xff
		ret
	.select_tries db floppy_select_tries
	.recdrv_tries db floppy_recdrv_tries

%define floppy_select_drive_delay 50d
floppy_select_drive:		;https://en.wikipedia.org/wiki/Floppy-disk_controller gives info on data rates
	call floppy_update_drives
	mov word [Floppy_State.last_op], floppy_SELDRV
	mov eax, Floppy_State.types
	xor ebx, ebx
	mov bl, [Floppy_State.drive]
	add eax, ebx
	xor ebx, ebx
	mov bl, [eax]
	cmp bl, 0
	je .nodrive
	cmp bl, 1
	je .type1
	cmp bl, 2
	je .type2
	cmp bl, 3
	je .type3
	cmp bl, 4
	je .type4
	cmp bl, 5
	je .type5
	jmp .unsupported
	.nodrive:
		cmp byte [.ignore_drive_error], 1
		je .select
		mov byte [Floppy_State.last_ret], floppy_NO_DRIVE
		mov al, floppy_NO_DRIVE
		mov byte [Floppy_Disk.drive], floppy_NULLDRV
		ret
	.type1:			;360KB 5.25" 40 Tracks, 18 Sectors per Track, Single Sided
		mov al, 1	;300
		jmp .select
	.type2:			;1200KB 5.25"
		mov al, 0	;500
		jmp .select
	.type3:			;720KB 3.5"
		mov al, 2	;250
		jmp .select
	.type4:			;1440KB 3.5" 80 Tracks, 18 Sectors per Track, double sided
		mov word [Floppy_Disk.cylinders], 80d
		mov word [Floppy_Disk.sectPerCyl], 18d
		mov word [Floppy_Disk.heads], 2d
		mov word [Floppy_Disk.maxLBA], 2880-1		;2 * 18 * 80 = 2880, 2880 * 512B = 1440KB, LBA is 0-based, so subtract 1
		mov al, 0	;500
		jmp .select
	.type5:			;2880KB 3.5"
		mov al, 3	;1000
		jmp .select
	.unsupported:
		cmp byte [.ignore_drive_error], 1
		je .select
		mov byte [Floppy_State.last_ret], floppy_BAD_DRIVE
		mov al, floppy_BAD_DRIVE
		mov byte [Floppy_Disk.drive], floppy_NULLDRV
		ret
	.select:
		call .set_rate
		call floppy_specify
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .specify_ok
		ret
		.set_rate:
			mov dx, floppy_DSR
			out dx, al
			mov dx, floppy_CCR
			out dx, al
			ret
	.specify_ok:
		mov word [Floppy_State.last_op], floppy_SELDRV
		mov ah, [Floppy_State.motor]
		shl ah, 4
		mov cl, [Floppy_State.drive]
		shl ah, cl
		or ah, [Floppy_State.drive]
		or ah, 00001100b
		mov dx, floppy_DOR
		in al, dx
		xchg al, ah
		out dx, al
		mov byte [Floppy_State.DOR], al
		and ax, 1111000011110000b	;motor bits before and after
		cmp al, ah
		je .return
		cmp byte [Floppy_State.motor], 0
		je .return
		;motor was turned on
		mov eax, floppy_select_drive_delay
		call k_wait_short
	.return:
		mov al, [Floppy_State.drive]
		mov [Floppy_Disk.drive], al
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret
	.dead:
		mov byte [Floppy_Disk.drive], floppy_NULLDRV
		ret
	.ignore_drive_error db 0		;set to 1 to ignore

floppy_update_drives:
	mov al, 0x10	;TODO: some way to check if NMI needs to be enabled or disabled
	out 70h, al		;TODO: small delay between selecting/accessing registers
	in al, 71h
	mov ah, al
	shr ah, 4
	mov [Floppy_State.drv0], ah
	and al, 0x0f
	mov [Floppy_State.drv1], al
	ret

;IN: bl = type
;OUT: ebx = size, other registers unmodified
floppy_size_by_type:
		cmp bl, 1
		je .type1
		cmp bl, 2
		je .type2
		cmp bl, 3
		je .type3
		cmp bl, 4
		je .type4
		cmp bl, 5
		je .type5
		.type1:
			mov ebx, 360 * 1024
			ret
		.type2:
			mov ebx, 1200 * 1024
			ret
		.type3:
			mov ebx, 720 * 1024
			ret
		.type4:
			mov ebx, 1440 * 1024
			ret
		.type5:
			mov ebx, 2880 * 1024
			ret

%define floppy_recalibrate_tries 4
%define floppy_sense_int_tries 2
floppy_recalibrate_drive:
	mov word [Floppy_State.last_op], floppy_RECDRV
	mov byte [.rec_tries], floppy_recalibrate_tries
	.rec:
		mov byte [.sense_tries], floppy_sense_int_tries
		call floppy_recalibrate
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .sense
	.rec_retry:
		dec byte [.rec_tries]
		cmp byte [.rec_tries], 0
		je .give_up
		jmp .rec
	.sense:
		call floppy_sense_int
		cmp word [Floppy_State.dead], 0xdead
		je .dead
		cmp al, floppy_SUCCES
		je .sense_done
	.sense_retry:
		dec byte [.sense_tries]
		cmp byte [.sense_tries], 0
		je .give_up
		jmp .sense
	.sense_done:
		mov al, [floppy_sense_int.st0]
		and al, 11100000b						;TODO: according to wiki st0 should be (0x20 | drive number) after recalibrate, so test for the right drive number
		cmp al, 00100000b
		jne .rec_retry
		mov al, [floppy_sense_int.cyl]			;cylinder should be 0 after recalibrate
		cmp al, 0
		jne .rec_retry
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret
	.give_up:
		mov al, byte [Floppy_State.last_ret]
		ret
	.dead:
		ret
	.rec_tries db floppy_recalibrate_tries
	.sense_tries db floppy_sense_int_tries

%define floppy_reset_timeout 2000d
floppy_reset:		;set DOR value in Floppy_State before calling
	mov word [Floppy_State.last_op], floppy_RESET
	call Floppy_IRQ_6.wait_ready
	push ebx
	mov al, 0
	mov dx, floppy_DOR
	out dx, al
	mov eax, 1	;only need to wait a few microseconds
	call k_wait_short
	mov al, [Floppy_State.DOR]
	mov dx, floppy_DOR
	out dx, al
	mov eax, floppy_reset_timeout
	pop ebx
	call Floppy_IRQ_6.wait			;al = 1 means it timed out, so just give up
	ret

%define floppy_cmd_ready_timeout 500d
floppy_cmd_ready:
	mov word [Floppy_State.last_op], floppy_CMDRDY
	mov ebx, [IRQ_0.counter]
	add ebx, floppy_cmd_ready_timeout
	.loop:
		mov dx, floppy_MSR
		in al, dx
		and al, 0xc0
		cmp al, 0x80
		je .ready
		cmp ebx, [IRQ_0.counter]
		jae .loop
		jmp .timeout
	.ready:
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret
	.timeout:
		mov byte [Floppy_State.last_ret], floppy_TIMEOUT
		mov al, floppy_TIMEOUT
		ret

floppy_select_disk:
	mov word [Floppy_State.last_op], floppy_SELDSK
	mov byte [Floppy_State.motor], 1
	mov cl, [Floppy_State.drive]
	cmp [Floppy_Disk.drive], cl
	je .motor
	call floppy_select_drive
	ret
	.motor:
		mov al, 00010000b
		shl al, cl
		mov ah, [Floppy_State.DOR]
		and ah, 00001111b
		or al, ah
		mov dx, floppy_DOR
		out dx, al
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret

floppy_motors_off:		;doesn't return anything, just a quick call
	mov al, [Floppy_State.DOR]
	and al, 00001111b
	mov dx, floppy_DOR
	out dx, al
	mov byte [Floppy_State.motor], 0
	ret

floppy_transfer:
	mov ax, [Floppy_Transfer.op]
	cmp ax, floppy_DMAR
	je .read
	cmp ax, floppy_DMAW
	je .write
	mov word [Floppy_State.last_op], floppy_DMAU
	jmp .error
	.read:
		mov byte [floppy_rw.command], floppy_READ
		xor eax, eax
		mov al, [Floppy_Transfer.sectors]
		shl eax, 9d	; * 512
		mov [DMA.floppy_length], eax
		call DMA_floppy_init_read
		jmp .transfer
	.write:
		mov byte [floppy_rw.command], floppy_WRITE
		xor eax, eax
		mov al, [Floppy_Transfer.sectors]
		shl eax, 9d	; * 512
		mov [DMA.floppy_length], eax
		call DMA_floppy_init_write
		jmp .transfer
	.transfer:
		mov al, [Floppy_Transfer.head]
		mov [floppy_rw.p2], al
		shl al, 2
		or al, [Floppy_Transfer.drive]
		mov [floppy_rw.p0], al
		mov al, [Floppy_Transfer.cyl]
		mov [floppy_rw.p1], al
		mov al, [Floppy_Transfer.sector]
		mov [floppy_rw.p3], al
		mov byte [floppy_rw.p4], 2
		mov al, [Floppy_Transfer.sectors]
		mov [floppy_rw.p5], al
		mov al, [Floppy_Transfer.gap]
		mov [floppy_rw.p6], al
		mov byte [floppy_rw.p7], 0xff
		call floppy_rw
		;error handling
		mov al, [floppy_rw.st0]
		and al, 11000000b
		cmp al, 0
		jne .rw_error
		mov byte [Floppy_State.last_ret], floppy_SUCCES
		mov al, floppy_SUCCES
		ret
	.rw_error:
		mov al, [floppy_rw.st1]
		test al, 00000010b
		jnz .wp
		test al, 10000000b
		jnz .eoc
		jmp .error
	.error:
		mov byte [Floppy_State.last_ret], floppy_ERROR
		mov al, floppy_ERROR
		ret
	.eoc:
		mov byte [Floppy_State.last_ret], floppy_CYL_END
		mov al, floppy_CYL_END
		ret
	.wp:
		mov byte [Floppy_State.last_ret], floppy_READONLY
		mov al, floppy_READONLY
		ret

%include "Kernel\Floppy\FloppyCmd.asm"
%include "Kernel\Floppy\FloppyIO.asm"
floppy_bootsector:
incbin "Build\Bootsector.bin"
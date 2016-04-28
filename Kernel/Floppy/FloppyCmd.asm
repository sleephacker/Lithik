%define floppy_rw_out_timeout 500d
%define floppy_rw_in_timeout 500d
%define floppy_rw_wait_timeout 8000d
floppy_rw:
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	ret				;return error, FDC needs reset + drive select
	.ok:
		xor ah, ah
		mov al, [.command]
		mov word [Floppy_State.last_op], ax
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_rw_out_timeout
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p0]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p1]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p2]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p3]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p4]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p5]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		mov al, [.p6]
		out dx, al
		call .out_wait
		cmp al, floppy_SUCCES
		jne .ret
		call Floppy_IRQ_6.wait_ready	;save ebx
		mov dx, floppy_FIFO
		mov al, [.p7]
		out dx, al
		
		call Floppy_IRQ_6.wait
		
		mov ebx, floppy_rw_in_timeout
		add ebx, [IRQ_0.counter]
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.st0], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.st1], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.st2], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.cyl], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.head], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.sect], al
		call .in_wait
		cmp al, floppy_SUCCES
		jne .ret
		mov dx, floppy_FIFO
		in al, dx
		mov [.res7], al
		ret
	.ret:
		ret
	.out_wait:
		mov dx, floppy_MSR
		in al, dx
		and al, 0xc0
		cmp al, 0x80
		je .out_ready
		cmp ebx, [IRQ_0.counter]
		jae .out_wait
		mov byte [Floppy_State.last_ret], floppy_TIMEOUT
		mov al, floppy_TIMEOUT
		ret
		.out_ready:
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			mov al, floppy_SUCCES
			ret
	.in_wait:
		mov dx, floppy_MSR
		in al, dx
		and al, 0xc0
		cmp al, 0xc0
		je .in_ready
		cmp ebx, [IRQ_0.counter]
		jae .in_wait
		mov byte [Floppy_State.last_ret], floppy_TIMEOUT
		mov al, floppy_TIMEOUT
		ret
		.in_ready:
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			mov al, floppy_SUCCES
			ret
	.command db 0
	.p0 db 0		;head << 2 | drive
	.p1 db 0		;cylinder
	.p2 db 0		;head
	.p3 db 0		;start sector
	.p4 db 2		;trust the wiki
	.p5 db 0		;sectors to tranfer
	.p6 db 0		;gap length
	.p7 db 0xff		;trust the wiki
	.st0 db 0
	.st1 db 0
	.st2 db 0
	.cyl db 0
	.head db 0
	.sect db 0
	.res7 db 0		;7th result byte, trust the wiki

%define floppy_recalibrate_io_timeout 1000d
%define floppy_recalibrate_wait_timeout 4000d
floppy_recalibrate:								;sense interrupt required after this
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	call floppy_reset
	cmp al, floppy_SUCCES
	je .ok
	mov word [Floppy_State.dead], 0xdead
	ret
	.ok:
		mov word [Floppy_State.last_op], floppy_RECALIBRATE
		mov al, floppy_RECALIBRATE
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_recalibrate_io_timeout
		.loop:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send
			cmp ebx, [IRQ_0.counter]
			jae .loop
			jmp .timeout
		.send:
			cmp byte [boot_data.bochs_e9_hack], 0xe9
			je .bochs
			call Floppy_IRQ_6.wait_ready
			;push ebx
			mov al, [Floppy_State.drive]
			mov dx, floppy_FIFO
			out dx, al
			;pop ebx
			mov eax, floppy_recalibrate_wait_timeout
			call Floppy_IRQ_6.wait
			ret
			.bochs:
				mov al, [Floppy_State.drive]
				mov dx, floppy_FIFO
				out dx, al
				mov byte [Floppy_State.last_ret], floppy_SUCCES
				mov al, floppy_SUCCES
				ret
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret

%define floppy_sense_int_timout 1000d
%define floppy_SENSE_INT_INVALID 80h
floppy_sense_int:
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	call floppy_reset
	cmp al, floppy_SUCCES
	je .ok
	mov word [Floppy_State.dead], 0xdead
	ret
	.ok:
		mov word [Floppy_State.last_op], floppy_SENSE_INT
		mov al, floppy_SENSE_INT
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_sense_int_timout
		.loop0:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0xc0
			je .result0
			cmp ebx, [IRQ_0.counter]
			jae .loop0
			jmp .timeout
		.result0:
			mov dx, floppy_FIFO
			in al, dx
			mov [.st0], al
			cmp al, floppy_SENSE_INT_INVALID
			je .error
		.loop1:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0xc0
			je .result1
			cmp ebx, [IRQ_0.counter]
			jae .loop1
			jmp .timeout
		.result1:
			mov dx, floppy_FIFO
			in al, dx
			mov [.cyl], al
			mov al, floppy_SUCCES
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			ret
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret
		.error:
			mov byte [Floppy_State.last_ret], floppy_ERROR
			mov al, floppy_ERROR
			ret
	.st0 db 0
	.cyl db 0

%define floppy_specify_timeout 1000d
floppy_specify:
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	call floppy_reset
	cmp al, floppy_SUCCES
	je .ok
	mov word [Floppy_State.dead], 0xdead
	ret
	.ok:
		mov word [Floppy_State.last_op], floppy_SPECIFY
		mov al, floppy_SPECIFY
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_specify_timeout
		.loop0:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send0
			cmp ebx, [IRQ_0.counter]
			jae .loop0
			jmp .timeout
		.send0:
			mov al, 0	;SRT and HUT
			mov dx, floppy_FIFO
			out dx, al
		.loop1:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send1
			cmp ebx, [IRQ_0.counter]
			jae .loop1
			jmp .timeout
		.send1:
			mov al, 0	;HLT and NDMA
			mov dx, floppy_FIFO
			out dx, al
		.return:
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			mov al, floppy_SUCCES
			ret
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret

%define floppy_lock_timeout 1000d
floppy_lock:							;al = lock enable, result: al = 0 on succes, 1 if timed out
	cmp al, 0
	je .unlock
	mov byte [.lock], floppy_LOCK
	jmp .command
	.unlock:
	mov byte [.lock], floppy_UNLOCK
	.command:
		mov dx, floppy_MSR
		in al, dx
		and al, 0xc0
		cmp al, 0x80
		je .ok
		call floppy_reset
		cmp al, floppy_SUCCES
		je .ok
		mov word [Floppy_State.dead], 0xdead
		ret
	.ok:
		mov word [Floppy_State.last_op], floppy_LOCK
		mov al, [.lock]
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_lock_timeout
		.loop:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0xc0
			je .result
			cmp ebx, [IRQ_0.counter]
			jae .loop
			jmp .timeout
		.result:
			mov dx, floppy_FIFO
			in al, dx
			mov bl, al
			and bl, 00010000b			;bit 4 = lock bit in result, bit 7 = lock bit in command, see if they match
			shl bl, 3
			mov bh, [.lock]
			and bh, 0x80
			cmp bl, bh
			jne .error
			mov ah, al
			mov al, floppy_SUCCES
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			ret
		.error:
			mov byte [Floppy_State.last_ret], floppy_ERROR
			mov al, floppy_ERROR
			ret
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret
	.lock db 0

%define floppy_configure_timeout 1000d
floppy_configure:						;al = 0 means succes, 1 means timed out
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	call floppy_reset
	cmp al, floppy_SUCCES
	je .ok
	mov word [Floppy_State.dead], 0xdead
	ret
	.ok:
		mov word [Floppy_State.last_op], floppy_CONFIG
		mov al, floppy_CONFIG
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_configure_timeout
		.loop0:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send0
			cmp ebx, [IRQ_0.counter]
			jae .loop0
			jmp .timeout
		.send0:
			mov al, 0
			mov dx, floppy_FIFO
			out dx, al
		.loop1:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send1
			cmp ebx, [IRQ_0.counter]
			ja .loop1
			jmp .timeout
		.send1:
			mov al, [Floppy_State.config]
			mov dx, floppy_FIFO
			out dx, al
		.loop2:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0x80
			je .send2
			cmp ebx, [IRQ_0.counter]
			jae .loop2
			jmp .timeout
		.send2:
			mov al, 0				;precompensation, use default
			mov dx, floppy_FIFO
			out dx, al
		.return:
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			mov al, floppy_SUCCES
			ret
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret

%define floppy_version_timeout 1000d
floppy_version:							;ah = result, al = 0 means succes, 1 means timed out
	call floppy_cmd_ready
	cmp al, floppy_SUCCES
	je .ok
	call floppy_reset
	cmp al, floppy_SUCCES
	je .ok
	mov word [Floppy_State.dead], 0xdead
	ret
	.ok:
		mov word [Floppy_State.last_op], floppy_VERSION
		mov al, floppy_VERSION
		mov dx, floppy_FIFO
		out dx, al
		mov ebx, [IRQ_0.counter]
		add ebx, floppy_version_timeout
		.loop:
			mov dx, floppy_MSR
			in al, dx
			and al, 0xc0
			cmp al, 0xc0
			je .result
			cmp ebx, [IRQ_0.counter]
			jae .loop
		.timeout:
			mov byte [Floppy_State.last_ret], floppy_TIMEOUT
			mov al, floppy_TIMEOUT
			ret
		.result:
			mov dx, floppy_FIFO
			in al, dx
			mov ah, al
			mov al, floppy_SUCCES
			mov byte [Floppy_State.last_ret], floppy_SUCCES
			ret

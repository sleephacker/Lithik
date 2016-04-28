DMA:
	.floppy_base dd 1000h
	.floppy_length dd 2400h	;18 * 512 = cylinder

DMA_floppy_init_read:
	mov al, 00000110b	;mask on, channel 2
	out 0ah, al
	out 0ch, al			;reset flip-flop, can be any value
	mov ebx, [DMA.floppy_base]
	mov ecx, [DMA.floppy_length]
	dec cx
	mov al, bl
	out 04h, al			;base low
	mov al, bh
	out 04h, al			;base 'middle'
	out 0ch, al			;reset flip-flop
	mov al, cl
	out 05h, al			;count low
	mov al, ch
	out 05h, al			;count high
	shr ebx, 10h
	mov al, bl
	out 81h, al			;base high
	mov al, 01000110b	;single transfer, non-reversed, no auto-init, write to memory, channel 2
	out 0bh, al
	mov al, 00000010b	;mask off, channel 2
	out 0ah, al
	ret

DMA_floppy_init_write:
	mov al, 00000110b	;mask on, channel 2
	out 0ah, al
	out 0ch, al			;reset flip-flop, can be any value
	mov ebx, [DMA.floppy_base]
	mov ecx, [DMA.floppy_length]
	dec cx
	mov al, bl
	out 04h, al			;base low
	mov al, bh
	out 04h, al			;base 'middle'
	out 0ch, al			;reset flip-flop
	mov al, cl
	out 05h, al			;count low
	mov al, ch
	out 05h, al			;count high
	shr ebx, 10h
	mov al, bl
	out 81h, al			;base high
	mov al, 01001010b	;single transfer, non-reversed, no auto-init, write to memory, channel 2
	out 0bh, al
	mov al, 00000010b	;mask off, channel 2
	out 0ah, al
	ret

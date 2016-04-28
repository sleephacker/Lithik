%include "Kernel\Network\Drivers\8254_def.asm"

;flag definitions
%define i8254_DISCARD_ALL	1			;discard all incoming packets right away.
%define i8254_HANDLE_FAST	2			;handle all incoming packets within the interrupt handler. save all incoming packets to a list if not set (TODO: implement).
%define i8254_EARLY_ACK		4			;acknowledge interrupts before they're done, allowing other interrupts to be handled while handling incoming packets (TODO: implement).

%define i8254_init_flags	i8254_HANDLE_FAST

struc i8254
	.netDevice	resd 1	;the netDevice structure associated with this device
	.pci		resd 1	;PCI address
	.devId		resw 1	;PCI device id
	.INT		resb 1	;interrupt line
	.memAddr	resd 1	;memory register space AKA memory mapped internal registers and memories AKA BAR0
	.RDT		resd 1	;Receive Descriptor Tail
	.TDT		resd 1	;Transmit Descriptor Tail
	.rxBuffer	resd 1	;buffer for packet reception
	.rxBufferU	resd 1	;unaligned address, may be used to free the memory if needed
	.txBuffer	resd 1	;buffer for packet transmission
	.txBufferU	resd 1	;unaligned address, may be used to free the memory if needed
	.flags		resd 1	;flags
	.struc_size:
endstruc
;TODO: weird stuff happens when i8254_buffers is a big number
%define i8254_buffers	8192			;number of receive and transmit buffers, must be a multiple of 256. TODO: don't hardcode this, allow it to be changed somewhat dynamically

;IN: eax = PCI address
;OUT: eax = address of netDevice structure
i8254_init:
	push eax
	mov eax, netDevice.struc_size + i8254.struc_size	;allocate both in one go while adding the netDevice to the list.
	mov ebx, [network.deviceList]
	call list_add
	mov ebx, eax
	add ebx, netDevice.struc_size
	push eax
	push ebx
	
	;[esp + 8] = PCI address
	;[esp + 4] = netDevice address
	;[esp + 0] = i8254 address
	
	;setup structures
	mov [ebx + i8254.netDevice], eax
	mov [eax + netDevice.devAddr], ebx
	mov [eax + netDevice.devType], word NETD_8254
	mov [eax + netDevice.transmit], dword i8254_transmit
	;TODO: receive
	call list_new
	mov ebx, [esp + 4]
	mov [ebx + netDevice.rList], eax
	
	mov eax, [esp + 8]
	mov ebx, [esp]
	mov [ebx + i8254.pci], eax
	mov [ebx + i8254.flags], dword i8254_init_flags
	add eax, PCI_H0.device_id
	call PCI_read_16
	mov ebx, [esp]
	mov [ebx + i8254.devId], ax
	mov eax, [esp + 8]
	add eax, PCI_H0.BAR0
	call PCI_read_32
	and eax, 0xfffffff0		;physical address
	mov esi, eax
	mov ecx, 20000h			;128 KB
	call memory_map_static	
	mov esi, [esp]
	mov [esi + i8254.memAddr], edi
	mov [i8254_INT.device], esi		;TODO: remove this, determine device by IRQ number
	;mask all interrupts and set interrupt handler
	mov [edi + i8254_IMC], dword 0xffffffff
	mov eax, [esp + 8]
	add eax, PCI_H0.INT_line
	call PCI_read_8
	mov esi, [esp]
	mov [esi + i8254.INT], al
	and eax, 0xff
	mov ebx, i8254_IRQ
	call IRQ_set_handler
	;read mac address
	mov esi, [esp]
	mov edi, [esp + 4]
	mov ah, 0
	call i8254_eeprom_read	;first read doesn't work sometimes in bochs
	mov ah, 0				;ethernet address byte 1 & 2
	call i8254_eeprom_read
	mov [edi + netDevice.mac], al
	mov [edi + netDevice.mac+1], ah
	mov ah, 1				;ethernet address byte 3 & 4
	call i8254_eeprom_read
	mov [edi + netDevice.mac+2], al
	mov [edi + netDevice.mac+3], ah
	mov ah, 2				;ethernet address byte 5 & 6
	call i8254_eeprom_read
	mov [edi + netDevice.mac+4], al
	mov [edi + netDevice.mac+5], ah
	
	;initialize MTA
	mov edi, [esp]
	mov edi, [edi + i8254.memAddr]
	add edi, i8254_MTA(0)
	mov ecx, 128d			;128 entries
	xor eax, eax
	rep stosd				;fill them all with 0's
	;initialize RAR[0]
	mov edi, [esp]
	mov edi, [edi + i8254.memAddr]
	mov esi, [esp + 4]
	mov eax, [esi + netDevice.mac]
	mov [edi + i8254_RAL(0)], eax
	mov eax, 80000000h		;Adress Valid (AV), destination (AS)
	mov ax, [esi + netDevice.mac + 4]
	mov [edi + i8254_RAH(0)], eax
	
	;initialize registers
	
	;initialize CTRL (LRST, ASDE, SLU, VME, PHY_RST)
	mov esi, [esp]
	mov esi, [esi + i8254.memAddr]
	mov eax, [esi + i8254_CTRL]							;read initial value
	and eax, ~(1 << 3 | 1 << 30 | 1 << 31) & 0xffffffff	;clear LRST, VME, PHY_RST
	or eax, (1 << 5 | 1 << 6)							;set ASDE, SLU
	mov [esi + i8254_CTRL], eax							;write new value
	;initialize CTRL_EXT (LINK_MODE)
	;mov eax, [esi + i8254_CTRL_EXT]
	;and eax, 0xff3fffff								;LINK_MODE = 00b = internal PHY
	;mov [esi + i8254_CTRL_EXT], eax
	
	;setup interrupts
	mov [esi + i8254_IMC], dword 0xffffffff				;mask everything to ensure future compatibility
	mov eax, [esi + i8254_ICR]							;acknowledge pending interrupts by reading ICR
	;mov [esi + i8254_RDTR], dword 0					;stop any form of interrupt throttling
	;mov [esi + i8254_RADV], dword 0
	;mov [esi + i8254_TIDV], dword 0
	;mov [esi + i8254_TADV], dword 0
	;mov [esi + i8254_ITR], dword 0
	mov [esi + i8254_IMS], dword 11111011011011111b		;unmask all known interrupts
	
	;initialize RCTL, TCTL and TIPG
	;enable: SECRC, BSEX, DPF, BAM, LPE, MPE, UPE, SBP
	;set: BSIZE = 4096, MO = ???, RDMTS = 1/8, LBM = no loopback
	;110010000111000001000111110b
	mov [esi + i8254_RCTL], dword 110010000111000001000111110b
	;check for full duplex
	mov eax, [esi + i8254_STATUS]
	test eax, 1
	jnz .FD
	;enable: PSP
	;set: CT = 0fh, COLD = 200h
	mov [esi + i8254_TCTL], dword 1 << 3 | 0fh << 4 | 200h << 12
	jmp .skipFD
	.FD:
	;enable: PSP
	;set: CT = 0fh, COLD = 40h
	mov [esi + i8254_TCTL], dword 1 << 3 | 0fh << 4 | 40h << 12
	.skipFD:
	;initialize TIPG, TODO: device specific values, currently all set to 10 which should work on any device.
	mov [esi + i8254_TIPG], dword 10 | 10 << 10 | 10 << 20
	
	;allocate memory for receive buffers
	mov eax, i8254_buffers * (4096+16) + 4095
	call mm_allocate
	mov esi, [esp]
	mov [esi + i8254.rxBufferU], eax
	add eax, 4095
	and eax, 0xfffff000					;page aligned
	mov ecx, (i8254_buffers*16+4095)>>12;number of pages
	mov edi, [memory_kernel.chain]		;kernel chain
	call memory_phys_contiguous
	mov esi, [esp]
	mov [esi + i8254.rxBuffer], eax
	;setup ring buffer
	push eax
	mov ebx, eax
	add eax, i8254_buffers * 16
	mov ecx, i8254_buffers
	.loop_rx:
		push ecx
		push eax
		push ebx
		call memory_virt_to_phys
		pop ebx
		mov [ebx], eax
		mov [ebx + 4], dword 0
		mov [ebx + 8], dword 0
		mov [ebx + 12], dword 0
		add ebx, 16
		pop eax
		add eax, 4096
		pop ecx
		loop .loop_rx
	;set receive buffer registers
	pop eax
	call memory_virt_to_phys
	mov esi, [esp]
	mov esi, [esi + i8254.memAddr]
	mov [esi + i8254_RDBAL], eax
	mov [esi + i8254_RDBAH], dword 0
	mov [esi + i8254_RDLEN], dword i8254_buffers * 16
	mov [esi + i8254_RDH], dword 0
	mov [esi + i8254_RDT], dword 0		;if head = tail, the ring buffer is empty (see specification)
	
	;allocate memory for transmit descriptors
	mov eax, i8254_buffers * 16 + 4095	;this alignment stuff wastes a lot of memory, TODO: implement an aligned memory allocator
	call mm_allocate
	mov esi, [esp]
	mov [esi + i8254.txBufferU], eax
	add eax, 4095
	and eax, 0xfffff000					;page aligned
	mov [esi + i8254.txBuffer], eax
	;setup ring buffer
	mov ebx, eax
	mov edi, eax
	xor eax, eax
	mov ecx, i8254_buffers * 4
	rep stosd							;clear it
	mov eax, ebx
	call memory_virt_to_phys
	mov esi, [esp]
	mov esi, [esi + i8254.memAddr]
	mov [esi + i8254_TDBAL], eax
	mov [esi + i8254_TDBAH], dword 0
	mov [esi + i8254_TDLEN], dword i8254_buffers * 16
	mov [esi + i8254_TDH], dword 0
	mov [esi + i8254_TDT], dword 0		;if head = tail, the ring buffer is empty (see specification)
	
	;enable reception and transmission
	mov esi, [esp]
	mov esi, [esi + i8254.memAddr]
	mov eax, [esi + i8254_RCTL]
	or eax, 1 << 1
	mov [esi + i8254_RCTL], eax
	mov eax, [esi + i8254_TCTL]
	or eax, 1 << 1
	mov [esi + i8254_TCTL], eax
	
	%macro printMac 1
	mov esi, [esp + 4]
	mov al, [esi + netDevice.mac + %1]
	call boot_log_byte_default
	%endmacro
	printMac 0
	printMac 1
	printMac 2
	printMac 3
	printMac 4
	printMac 5
	mov esi, [esp]
	mov ax, [esi + i8254.devId]
	call boot_print_word_default
	
	mov eax, [esp + 4]
	add esp, 12
	ret

;reads from the EEPROM
;IN: ah = word to read, esi = i8254 structure
;OUT: ax = value
;NOTE: doesn't modify esi, doesn't use edi
i8254_eeprom_read:
	mov al, 1						;set START bit in EERD
	mov ebx, [esi + i8254.memAddr]
	mov [ebx + i8254_EERD], eax		;write to EERD
	.poll:
		mov eax, [ebx + i8254_EERD]	;read EERD
		test al, 1 << 4				;test DONE bit in EERD
		jz .poll
	shr eax, 16						;shift DATA word into ax
	ret

;transmits a packet
;IN: ebx = packet base addresss, ecx = packet byte count, edx = i8254 structure
i8254_transmit:
	push edx
	push ecx
	push ebx
	
	;[esp + 8] = i8254 structure
	;[esp + 4] = length
	;[esp + 0] = base address
	
	mov eax, ecx
	add eax, 4095
	call mm_allocate
	pop esi
	push eax
	add eax, 4095
	and eax, 0xfffff000
	mov edi, eax
	mov ecx, [esp + 4]
	shr ecx, 2										;move most of it 4 bytes at a time
	rep movsd
	mov ecx, [esp + 4]
	and ecx, 11b									;last couple of bytes
	rep movsb
	call memory_virt_to_phys
	push eax
	
	;[esp + 12] = i8254 structure
	;[esp + 8] = length
	;[esp + 4] = allocated address
	;[esp + 0] = physical address
	
	mov esi, [esp + 12]
	mov edi, [esi + i8254.txBuffer]
	mov esi, [esi + i8254.memAddr]
	mov eax, [esi + i8254_TDT]
	and eax, 0xffff
	mov edx, eax
	shl eax, 4										;16 bytes per descriptor
	add edi, eax
	mov eax, [esp]
	mov [edi + i8254_TDESC.buffer], eax
	mov [edi + i8254_TDESC.buffer + 4], dword 0
	mov ecx, [esp + 8]
	mov [edi + i8254_TDESC.length], cx				;TODO: more than 16 bits length???
	mov [edi + i8254_TDESC.CMD], word 1011b			;report status, insert FCS/CRC, End Of Packet, write 0's to STA and RSV(reserved)
	mov eax, edx
	inc ax											;tail is a 16 bits value
	xor edx, edx
	mov bx, i8254_buffers
	div bx
	mov [esi + i8254_TDT], edx						;update tail
	.wait:
		hlt											;wait for interrupt
		test byte [edi + i8254_TDESC.STA], 0x0f		;test Status Field (low nibble only), TODO: test STA for multi-descriptor packets
		jz .wait
	mov eax, [esp + 4]
	call mm_free
	add esp, 16
	ret

;handles incoming packets
;IN: esi = i8254 structure
i8254_handle_receive:
	mov edi, [esi + i8254.memAddr]
	.loop:
		mov eax, [esi + i8254.RDT]
		mov ebx, [esi + i8254.rxBuffer]
		;pusha
		;call boot_print_dword_default
		;popa
		push ebx
		xor ecx, ecx
	.scan_loop:
		;eax = tail pointer
		;ebx = [esp] = ring buffer base address
		;ecx = packet length
		;esi = i8254 structure
		;edi = i8254 memory
		shl eax, 4									;16 bytes per descriptor
		add ebx, eax
		test byte [ebx + i8254_RDESC.status], 01b	;Descriptor Done (DD)
		jz .quit_scan
		xor edx, edx
		mov dx, [ebx + i8254_RDESC.length]
		add ecx, edx								;accumulate total packet length
		test byte [ebx + i8254_RDESC.status], 10b	;EOP
		jnz .copy
		shr eax, 4
		inc eax										;next descriptor
		xor edx, edx
		mov bx, i8254_buffers
		div bx
		mov eax, edx								;use remainder
		mov ebx, [esp]
		jmp .scan_loop
		.quit_scan:
			add esp, 4
			ret
	.copy:
		push ecx
		push esi
		push edi
		mov eax, ecx
		call mm_allocate							;allocate a buffer for the packet
		push eax
		;[esp + 16] = ring buffer base
		;[esp + 12] = packet size
		;[esp + 8] = i8254 structure
		;[esp + 4] = IO base address
		;[esp + 0] = allocated memory
		mov esi, [esp + 8]
		mov edi, eax
		mov eax, [esi + i8254.RDT]
		mov esi, [esi + i8254.rxBuffer]
		add esi, 16 * i8254_buffers
		push esi
		;[esp + 20] = ring buffer base
		;[esp + 16] = packet size
		;[esp + 12] = i8254 structure
		;[esp + 8] = IO base address
		;[esp + 4] = allocated memory
		;[esp + 0] = ring buffer base + 16 * i8254_buffers
	.copy_loop:
		mov ebx, [esp + 20]
		shl eax, 4									;16 byte descriptors
		add ebx, eax
		shl eax, 8									;4096 byte buffers
		add esi, eax
		shr eax, 12
		inc eax										;increment tail pointer
		xor edx, edx
		mov cx, i8254_buffers
		div cx
		mov eax, edx								;use remainder
		xor ecx, ecx
		mov cx, [ebx + i8254_RDESC.length]
		rep movsb									;TODO: do this more efficiently (4 bytes at a time, aligned)	
		test byte [ebx + i8254_RDESC.status], 10b	;End Of Packet
		mov byte [ebx + i8254_RDESC.status], 0		;clear the status byte
		jnz .copy_done
		mov esi, [esp]
		jmp .copy_loop
	.copy_done:
		add esp, 4
		;[esp + 16] = ring buffer base
		;[esp + 12] = packet size
		;[esp + 8] = i8254 structure
		;[esp + 4] = IO base address
		;[esp + 0] = allocated memory
		mov edi, [esp + 4]
		mov esi, [esp + 8]
		mov [esi + i8254.RDT], eax					;update tail pointers
		mov [edi + i8254_RDT], eax
		mov eax, [esi + i8254.netDevice]
		mov ebx, [eax + netDevice.rList]
		call list_first
		pop edx
		mov ecx, [esp + 12]
		;[esp + 12] = ring buffer base
		;[esp + 8] = packet size
		;[esp + 4] = i8254 structure
		;[esp + 0] = IO base address
		;eax = handler
		;ebx = List
		;ecx = packet size
		;edx = packet address / allocated memory
	.handle_loop:
		cmp eax, LIST_NULL
		je .handle_done
		mov esi, eax
		mov eax, [esi + netPacketHandler.pointer]
		xchg ebx, edx
		call [esi + netPacketHandler.handler]
		mov eax, esi
		xchg ebx, edx
		call list_next
		jmp .handle_loop
	.handle_done:
		;free the buffer and clear up the stack
		mov eax, edx
		call mm_free
		pop edi
		pop esi
		add esp, 8
		jmp .loop
	.ret:
		ret

i8254_IRQ:
	push edi
	push esi
	push eax
	push ebx
	push ecx
	push edx
	pushfd
	
	call i8254_INT
	
	mov eax, [.counter]
	inc eax
	mov [.counter], eax
	cmp byte [VBE_On], 1
	je .skip
	mov edi, VGA_strings.dword
	call format_hex_dword
	mov ax, 784					;5*160-8*2
	mov bl, 04h
	mov bh, 07h
	mov esi, VGA_strings.dword
	call boot_print
	.skip:
	mov al, 20h
	out 00a0h, al
	out 0020h, al
	.return:
		popfd
		pop edx
		pop ecx
		pop ebx
		pop eax
		pop esi
		pop edi
		iret
	.counter dd 0

i8254_INT:
	mov esi, [.device]
	mov edi, [esi + i8254.memAddr]
	mov eax, [edi + i8254_ICR]
	push eax
	
	;[esp] = ICR
	test dword [esp], 11b
	jnz .transmit
	.trsret:
	test dword [esp], 1 << 2
	jnz .LSC
	.lscret:
	test dword [esp], 1 << 7
	jnz .receive
	.recret:
	;TODO
	
	pop eax
	ret
	.transmit:
		mov al, 0x77
		mov bx, 0xc00c
		call boot_log_byte
		jmp .trsret
	.LSC:
		mov eax, [edi + i8254_CTRL]
		or eax, 1 << 6		;set link up
		mov [edi + i8254_CTRL], eax
		jmp .lscret
	.receive:
		test dword [esi + i8254.flags], i8254_DISCARD_ALL
		jnz .discard
		
		pushad
		call i8254_handle_receive
		popad
		
		jmp .recret
		.discard:
			mov ebx, [esi + i8254.rxBuffer]
			add ebx, i8254_RDESC.status			;offset of status byte
			mov eax, [esi + i8254.RDT]			
			and eax, 0xffff						;max 64K descriptors (16 bits)
			.discard_loop:
				shl eax, 4						;16 byte descriptors
				test byte [ebx + eax], 0xff		;test for non-zero status byte
				jz .discard_done
				mov byte [ebx + eax], 0			;ready for reuse by hardware
				shr eax, 4
				inc ax							;max 64K descriptors (16 bits)
				xor edx, edx
				mov cx, i8254_buffers
				div cx
				mov eax, edx
				jmp .discard_loop
			.discard_done:
				shr eax, 4
				mov [esi + i8254.RDT], eax		;update tail
				mov [edi + i8254_RDT], eax		;update tail
				jmp .recret
	.device dd 0		;TODO: determine device by IRQ number
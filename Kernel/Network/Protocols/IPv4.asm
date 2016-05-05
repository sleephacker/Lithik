;IP protocol numbers
%define IP_NULL		0xff		;used to indicate that a handler accepts all protocols
%define IP_ICMP		0x01
%define IP_IGMP		0x02
%define IP_TCP		0x06
%define IP_UDP		0x11

struc IPv4Header
	.version:					;(4 bits) IP version, should be 4
	.IHL			resb 1		;(4 bits) Internet Header Length
	.DSCP:						;(6 bits) Differentiated Services Code Point
	.ECN			resb 1		;(2 bits) Explicit Congestion Notification
	.length			resw 1		;total length, including header
	.id				resw 1		;identification
	.flags:						;(3 bits)
	.offset			resw 1		;(13 bits) fragment offset
	.TTL			resb 1		;Time To Live
	.protocol		resb 1		;protocol number
	.checksum		resw 1		;header checksum
	.source			resb 4		;source IPv4 address
	.destination	resb 4		;destination IPv4 address
	.options:
	.struc_size:				;NOTE: header length is variable
endstruc

struc IPv4Handler
	.netDevice		resd 1		;the netDevice this handler belongs to
	.subHandlers	resd 1		;list of netPacketHandlers, where the .netType field indicates the IP protocol number
	.struc_size:
endstruc

;adds an IPv4Handler to a ethernetHandler
;IN: eax = ethernetHandler
;OUT: eax = IPv4Handler
IPv4_add_handler:
	push eax
	call list_new
	push eax
	mov eax, IPv4Handler.struc_size
	call mm_allocate
	pop dword [eax + IPv4Handler.subHandlers]
	pop ebx
	mov ecx, [ebx + ethernetHandler.netDevice]
	mov [eax + IPv4Handler.netDevice], ecx
	push eax
	mov ebx, [ebx + ethernetHandler.subHandlers]
	mov esi, eax
	mov edi, IPv4_handler
	mov eax, EtherType_IPv4
	call network_add_handler
	pop eax
	ret

;handles IPv4 packets
;IN: eax = IPv4Handler, ebx = packet address, ecx = packet length in bytes
;NOTE: must preserve all registers!
IPv4_handler:
	pushad
	xor eax, eax
	mov esi, ebx
	xor ecx, ecx
	xor edx, edx
	mov cl, [ebx + IPv4Header.IHL]
	and cl, 0x0f									;IHL is in the low (?) nibble
	shl cl, 1										;number of words
	.checksum:
		lodsw
		rol ax, 8									;convert little to big endian
		add dx, ax
		jc .carry
		loop .checksum
		jmp .check
	.carry:
		inc dx
		jz .carry									;carry generated carry
		loop .checksum
	.check:
		xor dx, 0xffff
		jnz .drop
	mov edx, [ebx + IPv4Header.destination]
	mov eax, [esp + pushad_stack.eax]
	mov eax, [eax + IPv4Handler.netDevice]
	cmp edx, [eax + netDevice.ip]
	je .handle
	cmp edx, 0xffffffff
	je .handle
	popad
	ret
	.handle:
		mov dx, [ebx + IPv4Header.flags]
		and dx, 0xfffc								;check if MF and fragment offset are zero, TODO: handle fragmented packets
		jnz .drop
		mov al, [ebx + IPv4Header.protocol]
		;xor ecx, ecx								;ecx is zero after checksum loop
		xor edx, edx
		mov cx, [ebx + IPv4Header.length]			;recalculate the length
		rol cx, 8
		mov dl, [ebx + IPv4Header.IHL]
		and dl, 0x0f								;IHL is in the low (?) nibble
		shl dl, 2
		add ebx, edx
		sub ecx, edx
		cmp ecx, [esp + pushad_stack.ecx]
		ja .drop									;length according to IPv4 header is more than what was received, drop it!
		mov dl, al
		mov edi, ebx
		mov eax, [esp + pushad_stack.eax]
		mov ebx, [eax + IPv4Handler.subHandlers]
		call list_first								;NOTE: this handler depends on list_first preserving all registers but eax
		.loop:
			cmp eax, LIST_NULL
			je .done
			mov esi, eax
			cmp [esi + netPacketHandler.netType], dl
			je .call
			cmp [esi + netPacketHandler.netType], byte IP_NULL
			jne .next
		.call:
			mov eax, [esi + netPacketHandler.pointer]
			xchg ebx, edi
			xchg edx, [esp + pushad_stack.ebx]		;load IP header address, while saving the protocol number
			call [esi + netPacketHandler.handler]
			xchg ebx, edi
			xchg edx, [esp + pushad_stack.ebx]
			mov eax, esi
		.next:
			call list_next
			jmp .loop
		.done:
			popad
			ret
	.drop:
		mov ax, dx
		call boot_print_word_default
		popad
		ret

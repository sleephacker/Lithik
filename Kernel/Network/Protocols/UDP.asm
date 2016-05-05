%define UDP_Port_NULL		0		;handler accepts any destination port
%define UDP_Port_ECHO		7		;echo protocol
%define UDP_Port_BOOTPS		67		;BOOTP / DHCP server port
%define UDP_Port_BOOTPC		68		;BOOTP / DHCP client port

struc UDPHeader
	.source				resw 1		;source port, not mandatory
	.destination		resw 1		;destination port, mandatory
	.length				resw 1		;length of UDP header and data
	.checksum			resw 1		;checksum of pseudo header and data, not mandatory over IPv4, mandatory over IPv6
	.struc_size:
endstruc

;adds an UDP handler to an IPv4Handler, and creates a list of netPacketsHandlers where the .netType field indicates the UDP port.
;IN: eax = IPv4Handler
;OUT: eax = UDP listeners
UDP_add_handler_IPv4:
	push eax
	call list_new
	mov esi, eax
	xchg eax, [esp]
	mov ebx, [eax + IPv4Handler.subHandlers]
	mov eax, IP_UDP
	mov edi, UDP_handler
	call network_add_handler
	pop eax
	ret

;handles UDP packets
;IN: eax = UDP listners, ebx = packet address, ecx = packet length in bytes, edx = IP header address if available
;NOTE: must preserve all registers!
UDP_handler:
	pushad
	mov al, [edx]
	and al, 0xf0
	cmp al, 0x40							;IPv4
	je .IPv4
	.drop:
		mov eax, ecx
		call boot_print_dword_default
		popad
		ret
	.IPv4:
		mov ax, [ebx + UDPHeader.checksum]
		cmp ax, 0							;checksum is not mandatory over IPv4
		je .handle
		lea esi, [edx + IPv4Header.source]
		mov dh, [edx + IPv4Header.protocol]
		mov ecx, 4							;source + destination = 4 words
		xor dl, dl
		;clc								;xor clears carry
	.checksum0:
		lodsw
		adc dx, ax
		loop .checksum0
		adc dx, 0
		adc dx, 0
		mov esi, ebx
		mov ecx, [esp + pushad_stack.ecx]
		shr ecx, 1
		jnc .checksum1
		add dl, [ebx + ecx * 2]
		adc dh, 0
	.checksum1:
		lodsw
		adc dx, ax
		loop .checksum1
		adc dx, [ebx + UDPHeader.length]	;the length field is appearantly twice as important, as it is included twice in the checksum. this is pretty stupid IMO.
		jnc .check
		inc dx
		jnz .check
		inc dx
	.check:
		xor dx, 0xffff
		jnz .drop
	.handle:
		xor ecx, ecx
		mov cx, [ebx + UDPHeader.length]
		rol cx, 8
		cmp ecx, [esp + pushad_stack.ecx]	;sanity check
		ja .drop
		mov dx, [ebx + UDPHeader.destination]
		rol dx, 8
		add ebx, UDPHeader.struc_size
		sub ecx, UDPHeader.struc_size
		mov edi, ebx
		mov ebx, [esp + pushad_stack.eax]
		call list_first
		.loop:
			cmp eax, LIST_NULL
			je .done
			mov esi, eax
			cmp [esi + netPacketHandler.netType], dx
			je .call
			cmp [esi + netPacketHandler.netType], byte UDP_Port_NULL
			jne .next
		.call:
			mov eax, [esi + netPacketHandler.pointer]
			xchg ebx, edi
			xchg edx, [esp + pushad_stack.edx]
			call [esi + netPacketHandler.handler]
			xchg ebx, edi
			xchg edx, [esp + pushad_stack.edx]
			mov eax, esi
		.next:
			call list_next
			jmp .loop
		.done:
			popad
			ret

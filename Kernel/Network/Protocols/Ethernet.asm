;ethertypes:
%define EtherType_NULL		0		;generic null type, handler accepts all ethertypes
%define EtherType_IPv4		0x0800	;Internet Protocol version 4
%define EtherType_ARP		0x0806	;Address Resolution Protocol
%define EtherType_IPv6		0x86DD	;Internet Protocol version 6
%define EtherType_0xc0de	0xc0de	;homemade debug logging protocol

;Ethernet II
struc ethernetHeader
	.destination		resb 6		;destination MAC address
	.source				resb 6		;source MAC address
	.etherType			resb 2		;etherType, little endian
	.struc_size:
endstruc

struc ethernetHandler
	.netDevice			resd 1		;the netDevice this handler belongs to
	.subHandlers		resd 1		;list of netPacketHandlers, where the .netType field indicates the etherType (big endian word)
	.struc_size:
endstruc

;adds an ethernetHandler to a netDevice
;IN: eax = netDevice
;OUT: eax = ethernetHandler
ethernet_add_handler:
	push eax
	call list_new
	push eax
	mov eax, ethernetHandler.struc_size
	call mm_allocate
	pop dword [eax + ethernetHandler.subHandlers]
	pop ebx
	mov [eax + ethernetHandler.netDevice], ebx
	push eax
	mov ebx, [ebx + netDevice.handlers]
	mov esi, eax
	mov edi, ethernet_handler
	mov eax, NETH_ETHERNET
	call network_add_handler
	pop eax
	ret

;handles ethernet packets
;IN: eax = ethernetHandler, ebx = packet address, ecx = packet length in bytes
;NOTE: must preserve all registers!
ethernet_handler:
	pushad
	mov esi, [eax + ethernetHandler.netDevice]
	add esi, netDevice.mac
	mov edi, ebx										;destination MAC is at offset 0
	;add ebx, ethernetHeader.destination
	mov ecx, 3											;6 bytes = 3 words
	repe cmpsw
	jcxz .handle										;destination equals netDevice.mac
	mov ax, [ebx]
	and ax, [ebx + 2]
	and ax, [ebx + 4]
	cmp ax, 0xffff
	je .handle											;broadcast packet
	popad
	ret													;drop the packet, TODO: more filters, IPv6 broadcast address, other special MAC addresses...
	.handle:
		mov dx, [ebx + ethernetHeader.etherType]
		rol dx, 8										;convert little to big endian
		add ebx, ethernetHeader.struc_size				;skip the ethernet header
		mov ecx, [esp + pushad_stack.ecx]
		sub ecx, ethernetHeader.struc_size
		mov edi, ebx
		mov eax, [esp + pushad_stack.eax]
		mov ebx, [eax + ethernetHandler.subHandlers]
		call list_first									;NOTE: this handler depends on list_first preserving all registers but eax
		.loop:
			cmp eax, LIST_NULL
			je .done
			mov esi, eax
			cmp [esi + netPacketHandler.netType], dx
			je .call
			cmp [esi + netPacketHandler.netType], word EtherType_NULL
			jne .next
		.call:
			mov eax, [esi + netPacketHandler.pointer]
			xchg ebx, edi
			call [esi + netPacketHandler.handler]
			xchg ebx, edi
			mov eax, esi
		.next:
			call list_next
			jmp .loop
		.done:
			popad
			ret

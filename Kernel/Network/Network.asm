;network device types:
%define NETD_VIRT		0		;virtual network device, TODO
%define NETD_8254		1		;Intel 8254x device
%define NETD_8255		2		;Intel 8254x device

;network handler types:
%define NETH_NULL		0		;no specific type
%define NETH_ETHERNET	1		;ethernet handler

struc netDevice
	.mac		resb 6	;mac address
	.ip			resb 4	;IPv4 address
	.transmit	resd 1	;packet transmit function
	.receive	resd 1	;packet receive function
	.handlers	resd 1	;list of netPacketHandlers to call on packet reception
	.devType	resw 1	;device type
	.devAddr	resd 1	;device structure address
	.struc_size:
endstruc				;TODO: min/max packet size, offloading capabilities, etc.

;handles packets
;IN: eax = pointer, ebx = packet address, ecx = packet length in bytes
;NOTE: must preserve all registers!
struc netPacketHandler
	.handler	resd 1	;handler to call
	.pointer	resd 1	;pointer given to the handler so it knows where the call came from
	.netType	resd 1	;general purpose type field
	.struc_size:
endstruc

;used to dump packets in memory fo later processing
struc netPacketDump
	.length		resd 1
	.packet:
	.struc_size:
endstruc

%include "Kernel\Network\Protocols\Ethernet.asm"
%include "Kernel\Network\Protocols\IPv4.asm"
%include "Kernel\Network\Protocols\UDP.asm"

network:
	.mainDevice dd 0
	.deviceList dd 0

network_init:	;TODO: page fault when executing this twice...
	call list_new
	mov [network.deviceList], eax
	
	call PCI_find_ethernet
	and eax, eax
	jz .ret
	call i8254_init
	mov [network.mainDevice], eax
	
	call network_init_stack
	
	mov eax, NETH_NULL
	mov ebx, [network.mainDevice]
	mov ebx, [ebx + netDevice.handlers]
	xor esi, esi
	mov edi, network_handle_0xc0de
	call network_add_handler
	
	mov eax, [network.mainDevice]
	mov ebx, .helloPacket
	mov ecx, [.helloLength]
	call network_transmit
	mov eax, 1000d
	call k_wait_short
	mov eax, [network.mainDevice]
	mov ebx, .helloPacket
	mov ecx, [.helloLength]
	call network_transmit
	.ret:
		ret
	.helloPacket db 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, "Lithik", 0xc0, 0xde, "Hello world!", 0
	.helloLength dd .helloLength - .helloPacket

;adds handlers to a netDevice
;IN: eax = netDeivce
network_init_stack:
	call ethernet_add_handler
	call IPv4_add_handler
	mov ebx, [eax + IPv4Handler.subHandlers]
	mov eax, IP_UDP
	xor esi, esi
	mov edi, UDP_handler
	call network_add_handler
	ret

;transmits a packet
;IN: [eax] = netDevice, [ebx] = packet, ecx = packet length in bytes
network_transmit:
	mov edx, [eax + netDevice.devAddr]
	call [eax + netDevice.transmit]
	ret

;add a netPacketHandler to a list
;IN: eax = netType, ebx = list, esi = pointer, edi = handler
network_add_handler:
	push eax
	push esi
	push edi
	mov eax, netPacketHandler.struc_size
	call list_begin_add
	pop dword [eax + netPacketHandler.handler]
	pop dword [eax + netPacketHandler.pointer]
	pop dword [eax + netPacketHandler.netType]
	call list_finish_add
	ret

network_handle_0xc0de:
	pushad
	cmp word [ebx + 12], 0xdec0
	jne .ret
	lea esi, [ebx + 14]
	call boot_print_default
	.ret:
	popad
	ret

%include "Kernel\Network\Drivers\8254.asm"
%include "Kernel\Network\Drivers\8255.asm"
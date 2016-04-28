;network device types:
%define NETD_VIRT		0		;virtual network device, TODO
%define NETD_8254		1		;Intel 8254x device
%define NETD_8255		2		;Intel 8254x device

struc netDevice
	.mac		resb 6	;mac address
	.ip			resb 4	;ip address
	.transmit	resd 1	;packet transmit function
	.receive	resd 1	;packet receive function
	.rList		resd 1	;list of netPacketHandlers to call on packet reception
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
	.struc_size:
endstruc

;used to dump packets in memory fo later processing
struc netPacketDump
	.length		resd 1
	.packet:
	.struc_size:
endstruc

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
	
	mov ebx, [eax + netDevice.rList]
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

;transmits a packet
;IN: [eax] = netDevice, [ebx] = packet, ecx = packet length in bytes
network_transmit:
	mov edx, [eax + netDevice.devAddr]
	call [eax + netDevice.transmit]
	ret

;add a netPacketHandler to a list
;IN: ebx = list, esi = pointer, edi = handler
network_add_handler:
	push esi
	push edi
	mov eax, netPacketHandler.struc_size
	call list_begin_add
	pop dword [eax + netPacketHandler.handler]
	pop dword [eax + netPacketHandler.pointer]
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

%include "Kernel\Network\Protocols\Ethernet.asm"

%include "Kernel\Network\Drivers\8254.asm"
%include "Kernel\Network\Drivers\8255.asm"
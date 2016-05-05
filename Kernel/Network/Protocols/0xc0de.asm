;0xc0de is a homemade protocol intended to log debug messages of the network.
;it works over ethernet as ethertype 0xc0de, over IPv4 as protocol number 0x3f and over UDP port 0xc0de.

;IN: eax = ethernetHandler
;OUT: eax = ethernetHandler
_0xc0de_add_handler_ethernet:
	push eax
	mov ebx, [eax + ethernetHandler.subHandlers]
	mov eax, 0xc0de
	xor esi, esi
	mov edi, _0xc0de_handler
	call network_add_handler
	pop eax
	ret

;IN: eax = IPv4Handler
;OUT: eax = IPv4Handler
_0xc0de_add_handler_IPv4:
	push eax
	mov ebx, [eax + IPv4Handler.subHandlers]
	mov eax, 0x3f
	xor esi, esi
	mov edi, _0xc0de_handler
	call network_add_handler
	pop eax
	ret

;IN: eax = list of UDP listeners
;OUT: eax = list of UDP listeners
_0xc0de_add_handler_UDP:
	push eax
	mov ebx, eax
	mov eax, 0xc0de
	xor esi, esi
	mov edi, _0xc0de_handler
	call network_add_handler
	pop eax
	ret

;IN: ebx = 0xc0de message
_0xc0de_handler:
	cmp byte [VBE_On], 0
	jne .ret
	pushad
	mov esi, ebx
	call boot_print_default
	popad
	.ret:ret

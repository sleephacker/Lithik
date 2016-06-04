%define BOOT_MMAP						;make a memory map at boot time, before entering the boot console

%define page_tables_p_addr 		0x00800000
%define page_directory_p_addr 	0x007ff000
%define phys_table_p_addr	 	0x003ff000

%define kernel_p_address 		0x00100000
%define kernel_v_address 		0x80000000
%define kernel_realsegment 		0x0e00
%define kernel_stack_esp 		0x0007f000
%define kernel_stack_ebp 		0x0007b000
%define kernel_size KERNEL_END - KERNEL_START

;special physical adresses:
;1000h		floppy DMA
;10000h		backup of GDT for realmode
;20000h		begin of temorary memory
;60000h		end of temorary memory
;60000h		realmode
;70000h		memory map
;100000h	kernel
;3fe000h	physical memory table
;7fe000h	page directory
;800000h	page tables

;special virtual addresses:
;100000h	user memory
;80000000h	kernel memory
;c0000000h	static memory

bits 32
org kernel_v_address

%include "Kernel\Define\Macros.asm"

KERNEL_START:
boot:
	;cli	;cli already done in bootloader
	mov ax, 10h
	mov ds, ax
	mov ss, ax
	mov esp, kernel_stack_esp
	mov ebp, kernel_stack_ebp
	mov es, ax
	mov fs, ax
	mov gs, ax
	
	call VGA_boot
	
	mov eax, 0
	mov bl, 02h
	mov bh, 0xa0
	mov esi, boot_strings.boot
	call boot_print
	
	%ifdef DEBUGBOOT
	
	mov al, 42h
	mov bl, 02h
	mov bh, 0xa0
	call boot_log_byte
	
	%endif
	
	call load_boot_GDT
	
	call real_boot
	
	call PS2_boot
	;TODO: move PIC and RTC setup to its own file
	;intialize PIC
	;ICW1
	mov al, 00010001b
	out 0020h, al
	out 00a0h, al
	;ICW 2
	mov al, 20h	;after reserved interrupts
	out 0021h, al
	mov al, 28h
	out 00a1h, al
	;ICW 3
	mov al, 4
	out 0021h, al
	mov al, 2
	out 00a1h, al
	;ICW 4
	mov al, 1
	out 0021h, al
	out 00a1h, al
	
	;enable IRQ 0 and 6, unmask IRQ 2 (used by the slave PIC)
	in al, 0x21
	and al, 10111010b
	out 0x21, al
	;enable IRQ 8
	in al, 0xa1
	and al, 11111110b
	out 0xa1, al
	;enable RTC
	mov al, 8bh
	out 70h, al
	in al, 71h
	or al, 01000000b
	and al, 11001111b
	xchg bl, al
	mov al, 8bh
	out 70h, al
	xchg bl, al
	out 71h, al
	;set RTC frequency
	%define RTC_rate 256
	;TODO: automatically update this with RTC_rate
	mov al, 8ah
	out 70h, al
	in al, 71h
	and al, 0xf0
	or al, 08h	;256Hz
	;mov al, 00101000b
	xchg al, bl
	mov al, 8ah
	out 70h, al
	xchg al, bl
	out 71h, al
	;initialize PIT
	mov al, 00110100b
	out 43h, al
	mov ax, 1193d		;frequency: 4661 = 255.9926Hz, 1193 = 1000.1523Hz
	out 40h, al			;Set low byte of reload value
	mov al, ah
	out 40h, al			;Set high byte of reload value
	
	lidt [IDTR]
	sti
	
	call memory_boot
	call library_boot
	
	in al, 0xe9
	mov [boot_data.bochs_e9_hack], al
	
	;http://forum.osdev.org/viewtopic.php?f=1&t=30091&start=0
	;sending an EOI doesn't fix it
	;mov al, 20h
	;out 0x20, al
	;out 0xa0, al
	int 28h		;IRQ 8, needed only for bochs as far as I know, because the IRQ line can get stuck to high after rebooting somehow https://sourceforge.net/p/bochs/mailman/message/13777138/
	
	call Tasking_Init
	
	;thread testing
	;push word "0"
	;mov eax, 400h
	;call mm_allocate
	;mov ebx, eax
	;mov eax, 400h
	;mov ecx, 1
	;mov edx, 1
	;mov edi, test_thread_e9
	;call Thread_Fork
	push word 1
	mov eax, 400h
	call mm_allocate
	mov ebx, eax
	mov eax, 400h
	mov ecx, 1
	mov edx, 2
	mov edi, test_thread
	call Thread_Fork
	mov eax, 500
	call k_wait_short
	push word 2
	mov eax, 400h
	call mm_allocate
	mov ebx, eax
	mov eax, 400h
	mov ecx, 1
	mov edx, 2
	mov edi, test_thread
	call Thread_Fork
	mov eax, 500
	call k_wait_short
	push word 3
	mov eax, 400h
	call mm_allocate
	mov ebx, eax
	mov eax, 400h
	mov ecx, 1
	mov edx, 2
	mov edi, test_thread
	call Thread_Fork
	
	%ifdef DEBUGBOOT
	
	mov esi, strings.anykey
	mov ax, [VGA.boot_safe_print]
	mov bx, 0xa402					;don't newline
	call boot_print
	call PS2_device_flush_response	;avoid key release from bootloader confirmation
	call PS2_get_key				;wait for a key
	call boot_console_clear	
	cmp byte [boot_debug.boot], 0
	je .boot
	jmp boot_console
	
	%endif
	
.boot:
	call boot_console_clear
	
	mov byte [floppy_init.output], 2		;completion message only
	call floppy_init
	mov byte [floppy_init.output], 0
	
	;disable all IRQs
	mov al, 0xff
	out 0x21, al
	out 0xa1, al
	
	call VBE_boot_0				;TODO: no more interrupts after this, probably solved by actually setting the right addresses.
	
	call VBE_boot_1
	
	;enable all IRQs
	mov al, 0
	out 0x21, al
	out 0xa1, al
	
	jmp user_default
	
	jmp $

test_thread:
	mov eax, 2000d
	call k_wait_short
	mov ax, [esp]
	call boot_log_byte_default
	jmp test_thread

test_thread_e9:
	mov ax, [esp]
	out 0xe9, al
	mov eax, 1000d
	call k_wait_short
	jmp test_thread

boot_die:
	mov esp, kernel_stack_esp
	mov ebp, kernel_stack_ebp
	push esi
	call boot_clear_screen
	pop esi
	xor eax, eax
	mov bx, 0xd005
	call boot_print
	jmp $

boot_exception:			;TODO: wrong value for ebx?
	cli
	cmp byte [.enabled], 1
	je .dump
	jmp dword [.return]
	.dump:
		mov [.eax], eax
		cmp byte [.error], 0
		je .no_error0
		mov eax, [esp]
		mov [.errorcode], eax
		add esp, 4
		.no_error0:
		mov eax, esp
		add esp, 12		;get original esp
		mov [.esp], esp
		mov [.ebp], ebp
		mov esp, kernel_stack_esp
		mov ebp, kernel_stack_ebp
		mov ebx, [eax]
		mov [.eip], ebx
		mov ebx, [eax+4]
		mov [.cs], ebx
		mov ebx, [eax+8]
		mov [.eflags], ebx
		push edi
		push esi
		push edx
		push ecx
		push ebx
		
		call boot_console_clear
		mov dword [VGA.video_defaults], 0xd405d005		
		mov esi, .str_exception
		call boot_print_log_default
		mov eax, [.exception]
		call boot_print_dword_default
		cmp byte [.error], 0
		je .no_error1
		mov esi, .str_errorcode
		call boot_print_log_default
		mov eax, [.errorcode]
		call boot_print_dword_default
		.no_error1:
		mov esi, .str_eax
		call boot_print_log_default
		mov eax, [.eax]
		call boot_print_dword_default
		mov esi, .str_ebx
		call boot_print_log_default
		pop eax
		call boot_print_dword_default
		mov esi, .str_ecx
		call boot_print_log_default
		pop eax
		call boot_print_dword_default
		mov esi, .str_edx
		call boot_print_log_default
		pop eax
		call boot_print_dword_default
		mov esi, .str_esi
		call boot_print_log_default
		pop eax
		call boot_print_dword_default
		mov esi, .str_edi
		call boot_print_log_default
		pop eax
		call boot_print_dword_default
		mov esi, .str_esp
		call boot_print_log_default
		mov eax, [.esp]
		call boot_print_dword_default
		mov esi, .str_ebp
		call boot_print_log_default
		mov eax, [.ebp]
		call boot_print_dword_default
		mov esi, .str_eip
		call boot_print_log_default
		mov eax, [.eip]
		call boot_print_dword_default
		mov esi, .str_cs
		call boot_print_log_default
		mov eax, [.cs]
		call boot_print_dword_default
		mov esi, .str_eflags
		call boot_print_log_default
		mov eax, [.eflags]
		call boot_print_dword_default
		mov esi, .str_cr0
		call boot_print_log_default
		mov eax, cr0
		call boot_print_dword_default
		mov esi, .str_cr2
		call boot_print_log_default
		mov eax, cr2
		call boot_print_dword_default
		mov esi, .str_cr3
		call boot_print_log_default
		mov eax, cr3
		call boot_print_dword_default
		mov esi, .str_cr4
		call boot_print_log_default
		mov eax, cr4
		call boot_print_dword_default
		mov eax, [.eip]
		mov eax, [eax]
		call boot_print_dword_default
		mov eax, [.eip]
		mov eax, [eax+4]
		call boot_print_dword_default
		mov eax, [.eip]
		mov eax, [eax+8]
		call boot_print_dword_default
		mov eax, [.eip]
		mov eax, [eax+12]
		call boot_print_dword_default
		
		jmp dword [.return]
	.exception dd 0
	.errorcode dd 0
	.error db 0			;0 = no error code, 1 = error code, set by int handler
	.eax dd 0
	.esp dd 0
	.ebp dd 0
	.eip dd 0
	.cs dd 0
	.eflags dd 0
	.return dd 0		;set by int handler
	.enabled db 1		;1 = enabled, 0 = disabled
	.str_exception db "Exception: ", 0
	.str_errorcode db "Errorcode: ", 0
	.str_eax db "EAX: ", 0
	.str_ebx db "EBX: ", 0
	.str_ecx db "ECX: ", 0
	.str_edx db "EDX: ", 0
	.str_esi db "ESI: ", 0
	.str_edi db "EDI: ", 0
	.str_esp db "ESP: ", 0
	.str_ebp db "EBP: ", 0
	.str_eip db "EIP: ", 0
	.str_cs db "CS: ", 0
	.str_eflags db "EFLAGS: ", 0
	.str_cr0 db "CR0: ", 0
	.str_cr2 db "CR2: ", 0
	.str_cr3 db "CR3: ", 0
	.str_cr4 db "CR4: ", 0

%include "Kernel\Memory.asm"
%include "Kernel\Tasking\Tasking.asm"

%include "Library\List.asm"
library_boot:
	mov [list_callback.allocate], dword mm_allocate
	mov [list_callback.free], dword mm_free
	ret

%include "Kernel\BootConsole.asm"
	
boot_strings:
	.boot db "Booting Lithik "
	.version db "0.0.1", 0
	.date:							;TODO
		.date_dayname db "DAY, "
		.date_monthname db "MMM "
		.date_daynum db "DDDD '"
		.date_year db "YY", 0
	.time:							;TODO
		.time_hour db "HH:"
		.time_min db "MM:"
		.time_sec db "SS", 0

boot_data:
	.video_base dw 0
	.bochs_e9_hack db 0		;set to 0xe9 if enabled

%ifdef DEBUGBOOT

boot_debug:
	.boot db 1
	.vga db 0
	.pci db 0
	.ps2 db 0
	.int db 0

%endif

;TODO: don't forget to update changes to this in the realmode binary.
%define KERNEL_CS CODE - GDT_START
%define KERNEL_DS DATA - GDT_START
%define USER_CS USRC - GDT_START
%define USER_DS USRD - GDT_START
%define BIT16_CS CS16 - GDT_START
%define BIT16_DS DS16 - GDT_START

%include "Kernel\Interrupt.asm"

%include "Kernel\String.asm"
%include "Kernel\VGA.asm"
%include "Kernel\PCI.asm"
%include "Kernel\PS2.asm"

GDT_DESCRIPTOR:
	.bytes dw GDT_END - GDT_START - 1
	.address dd GDT_START

GDT_START:
GDT_ZERO:
	.zero dq 0

CODE:	;08h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10011010b
	.limit1_flags db 11001111b
	.base2 db 0x00

DATA:	;10h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10010010b
	.limit1_flags db 11001111b
	.base2 db 0x00

USRC:	;18h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 11111010b		;ring 3
	.limit1_flags db 11001111b
	.base2 db 0x00

USRD:	;20h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 11110010b		;ring 3
	.limit1_flags db 11001111b
	.base2 db 0x00

CS16:	;28h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10011010b
	.limit1_flags db 10001111b	;16 bit protected mode
	.base2 db 0x00

DS16:	;30h
	.limit0 dw 0xffff
	.base0 dw 0x0000
	.base1 db 0x00
	.access db 10010010b
	.limit1_flags db 10001111b	;16 bit protected mode
	.base2 db 0x00

GDT_END:

load_boot_GDT:				;interrupt flag needs to be clear!
	lgdt [GDT_DESCRIPTOR]	;TODO: why do is there a function for just one instruction? this doesn't make sense.
	ret

k_wait_short:	;uses eax (millis)
	add eax, [IRQ_0.counter]
	.loop:
		hlt
		cmp eax, [IRQ_0.counter]
		ja .loop
	ret

k_wait_long:	;uses eax (millis)
	add eax, [IRQ_0.millis]
	.loop:
		hlt
		cmp eax, [IRQ_0.millis]
		ja .loop
	ret

KERNEL_POINTER:
	dd KP_INFO
	;kernel
	dd k_wait_short
	dd k_wait_long
	;realmode
	dd real_BIOS_INT
	;string
	dd find_string_256
	dd format_hex_byte
	dd format_hex_word
	dd format_hex_dword
	dd parse_hex_byte
	dd parse_hex_word
	dd parse_hex_dword
	;vga
	dd VGA_set_palette
	dd VGA_get_palette
	dd boot_clear_screen
	dd boot_newline
	dd boot_print
	dd boot_print_default
	dd boot_log_char
	dd boot_log_char_default
	dd boot_log_string
	dd boot_log_string_default
	dd boot_log_byte
	dd boot_log_byte_default
	dd boot_print_byte_default
	dd boot_log_word
	dd boot_log_word_default
	dd boot_print_word_default
	dd boot_log_dword
	dd boot_log_dword_default
	dd boot_print_dword_default
	;vbe
	dd vbe_begin_render
	dd vbe_end_render
	dd vbe_make_color
	dd vbe_calc_pixel
	dd vbe_set_pixel
	dd vbe_fill_rect
	dd vbe_draw_rect
	;pci
	dd PCI_read_32
	;ps2
	dd PS2_device_flush_response
	dd PS2_device_get_response
	dd PS2_device_get_response_wait
	dd PS2_device_send_command_wait
	dd PS2_device_send_command_data_wait
	dd PS2_controller_send_command_wait
	dd PS2_controller_send_command_data_wait
	dd PS2_get_key
	dd PS2_set_led
	;floppy
	dd Floppy_State
	dd Floppy_Transfer
	dd Floppy_Disk
	dd floppy_select_disk
	dd floppy_read_sector
	dd floppy_read_sectors
	dd floppy_write_sector
	dd floppy_write_sectors
KP_END:

KP_INFO:											;NOTE: update kpinfo command when updating this as well
	.limit dd KP_END - KERNEL_POINTER
	.max_index dw (KP_END - KERNEL_POINTER)/4 - 1	;length - 1 = max index

%include "Kernel\RealMode\RealPortal.asm"

%include "Kernel\VBE\VBE.asm"
%include "Kernel\Floppy\Floppy.asm"
%include "Kernel\DMA.asm"
%include "Kernel\Network\Network.asm"

%include "Kernel\User\User.asm"

%include "Fonts\8x12_128x192.bin"

KERNEL_END:

;Real Mode code needs to be relocated BEFORE memory init
REALMODE:
incbin "Build\RealMode.bin"
REALMODE_END:

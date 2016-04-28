%include "Library\MM.asm"

%define memory_SMAP 534d4150h
%define e820_entry 24d	;must be 24 at least

struc e820_s
	.base_low		resd 1
	.base_high		resd 1
	.length_low		resd 1
	.length_high	resd 1
	.mem_type		resd 1
	.acpi3			resd 1
endstruc

memory_e820_map:
	.address dd 70000h
	.size dd 0	;of map in bytes

memory_temp:
	.base dd 20000h
	.size dd 40000h
	.block_size dd 8d
	.block_count dd 8000h
	.bitmap_base dd 6f000h
	.bitmap_size dd 1000h

%define memory_static_base 0xc0000000
%define memory_static_size 0x40000000
memory_static_pointer dd memory_static_base

%define memory_user_base 00100000h
%define memory_user_size 7ff00000h

page_directory_v_addr dd page_directory_p_addr
page_tables_v_addr dd page_tables_p_addr

;physical memory table
;32bits FAT-like structure, using only the high 20 bits, so that the offset from the table base is also the 'cluster'/page number
memory_phys:
	.base dd 100000h
	.size dd 0xe00000		;assume this if memory map not present
	.table_base dd phys_table_p_addr
	.table_size dd 0
	.pages dd 0

memory_kernel:
	.base dd KERNEL_END + 4096 - ((KERNEL_END - $$ + kernel_v_address) % 4096)
	.chain dd 0

%macro TEST_MM_A 1
	mov eax, %1
	call mm_allocate
	push eax
	mov edi, eax
	mov ecx, %1
	mov eax, 0xcc
	rep stosb
%endmacro
%macro TEST_MM_F 1
	mov eax, [esp + ( %1 * 4 )]
	call mm_free
%endmacro
%macro TEST_MM 0
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	TEST_MM_A 42069h	;free 4		7	11
	TEST_MM_A 4269h		;free 7		6	10
	TEST_MM_A 69420h	;free 1		5	9
	TEST_MM_A 420h		;free 6		4	8
	TEST_MM_A 42h		;free 0		3	7
	TEST_MM_A 1337h		;free 2		2	6
	TEST_MM_A 31337h	;free 5		1	5
	TEST_MM_A 0xc0de	;free 3		0	4
	
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	TEST_MM_F 3
	TEST_MM_F 5
	TEST_MM_F 2
	TEST_MM_F 0
	
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	TEST_MM_A 123456h	;free 11		3
	TEST_MM_A 987654h	;free 8			2
	TEST_MM_A 4204242h	;free 10		1
	TEST_MM_A 3133700h	;free 9			0
	
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	TEST_MM_F 11
	TEST_MM_F 5
	
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	TEST_MM_F 8
	TEST_MM_F 10
	TEST_MM_F 2
	TEST_MM_F 0
	TEST_MM_F 1
	TEST_MM_F 3
	
	call boot_console_clear
	call boot_mlist
	call boot_console_confirm
	
	add esp, 48
%endmacro

memory_boot:
	call memory_boot_map
	call memory_boot_init_temp
	call memory_boot_init_static
	call memory_boot_init_paging_0
	call memory_boot_init_phys
	call memory_boot_init_paging_1
	call memory_boot_init_kernel
	
	;TODO: remove
	;TEST_MM
	
	mov eax, [memory_phys.size]		;TODO: print in decimal + message
	call boot_print_dword_default
	mov esi, .msg
	call boot_print_default
	ret
	.msg db "Memory initialization complete.", 0

memory_boot_map:
	mov eax, [memory_e820_map.address]
	mov ebx, 0
	call memory_next_e820_entry
	cmp ebx, 0
	je .map_die
	cmp edx, memory_SMAP
	jne .map_die
	cmp cl, 24d
	je .map_next
	mov byte [eax-4], 1		;don't ignore
	.map_next:
		add dword [memory_e820_map.size], e820_entry
		call memory_next_e820_entry
		cmp edx, memory_SMAP
		jne .map_die
		cmp cl, 24d
		je .skip
		mov byte [eax-4], 1		;don't ignore
		.skip:
		cmp ebx, 0
		je .map_done
		jmp .map_next
	.map_done:
		ret
	.map_die:
		mov esi, .map_fatal
		jmp boot_die
	.map_fatal db "Couldn't detect memory!", 0

;gets the next int 15, ax=e820 memory map entry
;IN: eax = pointer to 24 byte buffer (in low memory), ebx = continuation value
;OUT: eax += e820_entry, ebx = continuation value, or 0 at last entry, BIOS returned eax stored in edx, ecx in ecx
memory_next_e820_entry:
	push eax
	mov byte [real_BIOS_INT.int], 15h
	mov [real_BIOS_INT.eax], dword 0000e820h
	mov [real_BIOS_INT.ebx], ebx
	mov [real_BIOS_INT.ecx], dword e820_entry
	mov [real_BIOS_INT.edx], dword memory_SMAP
	mov [real_BIOS_INT.di], ax
	and eax, 0xffff0000
	shr eax, 4
	mov [real_BIOS_INT.es], ax
	call real_BIOS_INT
	cmp dword [real_BIOS_INT.ebx], 0
	je .last
	test word [real_BIOS_INT.flags], 1	;carry flag
	jnz .last
	mov ebx, [real_BIOS_INT.ebx]
	mov ecx, [real_BIOS_INT.ecx]
	mov edx, [real_BIOS_INT.eax]
	pop eax
	add eax, e820_entry
	ret
	.last:
		pop eax
		add eax, e820_entry
		mov ebx, 0
		ret

memory_boot_init_temp:
	mov ecx, [memory_temp.bitmap_size]
	.loop:
		mov eax, [memory_temp.bitmap_base]
		dec eax
		add eax, ecx
		mov byte [eax], 0
		loop .loop
	ret

memory_boot_init_static:
	mov eax, page_directory_p_addr + (memory_static_base >> 20)
	mov ebx, page_tables_p_addr + (memory_static_base >> 10) | 3
	mov ecx, memory_static_size >> 22
	.loop:
		mov [eax], ebx
		add eax, 4
		add ebx, 1000h
		loop .loop
	ret

memory_boot_init_paging_0:
	;set all page tables
	mov eax, page_directory_p_addr
	mov ebx, page_tables_p_addr | 3
	mov ecx, 400h
	.loop:
		mov [eax], ebx
		add eax, 4
		add ebx, 1000h
		loop .loop
	mov esi, page_tables_p_addr
	mov ecx, 400000h		;4 MB
	call memory_map_static
	mov [page_tables_v_addr], edi
	mov esi, page_directory_p_addr
	mov ecx, 1000h			;4 KB
	call memory_map_static
	mov [page_directory_v_addr], edi
	ret

memory_boot_init_paging_1:
	;clear user memory
	mov edi, [page_tables_v_addr]
	add edi, memory_user_base >> 10
	mov ecx, memory_user_size >> 12
	rep stosd
	;reload cr3
	mov eax, page_directory_p_addr
	mov cr3, eax
	ret

memory_boot_init_phys:		;TODO: do it properly
	%ifndef BOOT_MMAP
		jmp .done
	%endif
	mov dword [memory_phys.size], 0
	mov edx, kernel_p_address
	.find_all:
		mov esi, [memory_e820_map.address]
		mov ecx, [memory_e820_map.size]
		.find_next:
			cmp dword [esi + e820_s.mem_type], 1
			jne .skip
			cmp dword [esi + e820_s.base_high], 0
			jne .skip
			mov eax, [esi + e820_s.base_low]
			cmp eax, edx
			jb .b
			ja .skip
			cmp dword [esi + e820_s.length_high], 0
			jne .infinite
			mov eax, [esi + e820_s.length_low]
			add dword [memory_phys.size], eax
			add edx, eax
			jc .infinite
			jmp .find_all
			.b:			;TODO: not all cases of large memory chunks may be handled properly
				cmp dword [esi + e820_s.length_high], 0
				jne .infinite
				add eax, [esi + e820_s.length_low]
				sub eax, edx
				jc .skip
				jz .skip
				add dword [memory_phys.size], eax
				add edx, eax
				jc .infinite
				jmp .find_all
			.infinite:
				mov dword [memory_phys.size], 100000000h-kernel_p_address
				jmp .done
			.skip:
			add esi, e820_entry
			sub ecx, e820_entry
			jnz .find_next
	.done:
	;create the table
	mov ecx, [memory_phys.size]
	shr ecx, 12-2	;divide by 4kb pages, multiply by 4 byte addresses
	mov [memory_phys.table_size], ecx
	mov edi, [memory_phys.table_base]
	xor eax, eax
	shr ecx, 2		;divide by dword
	mov [memory_phys.pages], ecx
	rep stosd		;clear the area
	;mark kernel as used
	mov edi, kernel_p_address
	mov ecx, kernel_size
	call memory_phys_mark
	;mark the table as used
	mov edi, [memory_phys.table_base]
	mov ecx, [memory_phys.table_size]
	call memory_phys_mark
	;mark the paging structures as used
	mov edi, page_directory_p_addr
	mov ecx, 4096d		;size of page directory
	call memory_phys_mark
	mov edi, page_tables_p_addr
	mov ecx, 400000h	;size of page tables (4 MB)
	call memory_phys_mark
	;now map it to static memory
	mov esi, [memory_phys.table_base]
	mov ecx, [memory_phys.table_size]
	call memory_map_static
	mov [memory_phys.table_base], edi
	ret

%define init_kernel_pages 1000h
memory_boot_init_kernel:
	;allocate physical memory
	mov ecx, init_kernel_pages
	call memory_phys_allocate_chain
	mov [memory_kernel.chain], edi
	mov esi, edi
	mov edi, [memory_kernel.base]
	call memory_map_chain
	;setup the memory manager
	mov eax, init_kernel_pages * 1000h
	mov ebx, [memory_kernel.base]
	call mm_init
	mov dword [mm_callback.endOfMemory], memory_EOM
	mov dword [mm_callback.panic], memory_panic
	ret

;IN: eax = bit index, OUT: al = 0 if bit is 0
memory_read_temp_bitmap:
	xor edx, edx
	mov ebx, 8
	div ebx	;eax = byte, dl = bit
	add eax, [memory_temp.bitmap_base]
	mov cl, 1
	xchg cl, dl
	shl dl, cl
	mov al, [eax]
	and al, dl
	ret

;IN: eax = bit index
memory_set_temp_bitmap:
	xor edx, edx
	mov ebx, 8
	div ebx	;eax = byte, dl = bit
	add eax, [memory_temp.bitmap_base]
	mov cl, 1
	xchg cl, dl
	shl dl, cl
	mov bl, [eax]
	or bl, dl
	mov [eax], bl
	ret

;IN: eax = bit index
memory_clear_temp_bitmap:
	xor edx, edx
	mov ebx, 8
	div ebx	;eax = byte, dl = bit
	add eax, [memory_temp.bitmap_base]
	mov cl, 11111110b
	xchg cl, dl
	rol dl, cl
	mov bl, [eax]
	and bl, dl
	mov [eax], bl
	ret

;allocates memory for temporal use
;IN: eax = size in bytes
;OUT: eax = base of allocated area, or 0 on error
memory_allocate_temp:
	cmp byte [.busy], 0
	jne memory_allocate_temp
	mov byte [.busy], 1
	cmp eax, [memory_temp.size]
	ja .error
	cmp eax, 0
	je .error
	xor edx, edx
	mov ebx, [memory_temp.block_size]
	div ebx
	cmp edx, 0
	je .skip
	inc eax
	.skip:
	mov edx, eax
	mov ecx, [memory_temp.block_count]
	xor ebx, ebx
	.loop:
		push edx
		push ecx
		push ebx
		mov eax, ecx
		dec eax
		call memory_read_temp_bitmap
		cmp al, 0
		je .free
		add esp, 4
		xor ebx, ebx
		pop ecx
		pop edx
		loop .loop
		jmp .error
		.free:
			pop ebx
			pop ecx
			pop edx
			inc ebx
			cmp ebx, edx
			je .done
			loop .loop
			jmp .error
	.done:
		mov eax, ecx
		dec eax
		push eax
		mov ecx, ebx
		.claim_loop:
			push ecx
			push eax
			add eax, ecx
			dec eax
			call memory_set_temp_bitmap
			pop eax
			pop ecx
			loop .claim_loop
		pop eax
		xor edx, edx
		mul dword [memory_temp.block_size]		
		add eax, [memory_temp.base]
		mov byte [.busy], 0
		ret
	.error:
		xor eax, eax
		mov byte [.busy], 0
		ret
	.busy db 0

;frees a temporarely claimed memory area
;IN: eax = size in bytes, ebx = base address
memory_free_temp:
	cmp eax, 0
	je .ret
	xor edx, edx
	mov ecx, [memory_temp.block_size]
	div ecx
	cmp edx, 0
	je .skip
	inc eax
	.skip:
	mov ecx, eax
	mov eax, ebx
	sub eax, [memory_temp.base]
	xor edx, edx
	mov ebx, [memory_temp.block_size]
	div ebx
	mov ebx, eax
	.loop:
		push ecx
		push ebx
		mov eax, ebx
		add eax, ecx
		dec eax
		call memory_clear_temp_bitmap
		pop ebx
		pop ecx
		loop .loop
	.ret:
		ret

;maps an area to static memory
;IN: esi = base address, ecx = size in bytes
;OUT: edi = virtual pointer to mapped area
memory_map_static:
	mov edi, [memory_static_pointer]
	mov eax, esi
	and eax, 0xfff	;mod 4096
	add edi, eax
	test ecx, 0xfff
	jz .noround
	add ecx, 1000h
	.noround:
	mov eax, [memory_static_pointer]
	mov ebx, eax
	add [memory_static_pointer], ecx
	and [memory_static_pointer], dword 0xfffff000
	shr ecx, 12
	shr eax, 10
	add eax, [page_tables_v_addr]
	and esi, 0xfffff000
	or esi, 3
	.loop:
		mov [eax], esi
		add eax, 4
		add esi, 1000h
		add ebx, 1000h
		invlpg [ebx]		;TODO: check if supported
		loop .loop
	ret

;marks an area as used
;IN: edi = base address, ecx = size in bytes
;NOTE: edi must be a valid physical address
memory_phys_mark:
	sub edi, [memory_phys.base]
	shr edi, 12-2	;offset = (address - base) / 4096 * 4
	test ecx, 0fffh	;modulo 4096
	jnz .round
	shr ecx, 12		;divide by 4kb pages
	jmp .mark
	.round:
	shr ecx, 12		;divide by 4kb pages
	inc ecx			;round up
	.mark:
	add edi, [memory_phys.table_base]
	mov eax, 0xfffff000
	rep stosd
	ret

;allocates a new chain
;IN: ecx = number of pages to allocate to the new chain
;OUT: edi = starting page number of the chain, or 0 on error
memory_phys_allocate_chain:
	mov edx, ecx
	mov ecx, [memory_phys.pages]
	mov esi, [memory_phys.table_base]
	.first:
		lodsd
		and eax, eax
		jz .init
		loop .first
		mov edi, 0
		ret
	.init:
		mov edi, esi
		sub edi, 4
		sub edi, [memory_phys.table_base]
		shl edi, 10
		dec edx
		jz .done
		mov ebx, esi
		sub ebx, 4
		jmp .next
	.chain:
		mov eax, esi
		sub eax, 4
		sub eax, [memory_phys.table_base]
		shl eax, 10
		mov [ebx], eax
		mov ebx, esi
		sub ebx, 4
		dec edx
		jz .done
		.next:
			lodsd
			and eax, eax
			jz .chain
			loop .next
			mov edi, 0
			ret
	.done:
		mov dword [esi - 4], 0xfffff000
		ret

;allocates a number of pages to an existing chain
;IN: ecx = number of pages to allocate to the new chain, edi = starting page number
;OUT: edi = first allocated page number, or 0 on error
;TODO: switch to esi
memory_phys_allocate:
	mov ebx, [memory_phys.table_base]
	mov esi, edi
	shr esi, 10
	add esi, ebx
	mov eax, [esi]
	.last:
		cmp eax, 0xfffff000
		je .init
		mov esi, eax
		shr esi, 10
		add esi, ebx
		mov eax, [esi]
		jmp .last
	.init:
		mov edx, ecx
		mov ebx, esi
		mov esi, [memory_phys.table_base]
		mov ecx, [memory_phys.pages]
	.start:
		lodsd
		and eax, eax
		loopz .first
		loop .start
		mov edi, 0
		ret
	.first:
		mov eax, esi
		sub eax, 4
		sub eax, [memory_phys.table_base]
		shl eax, 10
		mov edi, eax	;allows caller to only map new pages
		jmp .link
	.chain:
		mov eax, esi
		sub eax, 4
		sub eax, [memory_phys.table_base]
		shl eax, 10
	.link:
		mov [ebx], eax
		mov ebx, esi
		sub ebx, 4
		dec edx
		jz .done
		.next:
			lodsd
			and eax, eax
			loopz .chain		;TODO: loopz .chain???
			loop .next
			mov edi, 0
			ret
	.done:
		mov dword [esi - 4], 0xfffff000
		ret

;frees an entire chain
;IN: edi = starting page number
memory_phys_free_chain:
	mov ebx, [memory_phys.table_base]
	shr edi, 10
	add edi, ebx
	.free:
		mov eax, [edi]
		mov dword [edi], 0
		cmp eax, 0xfffff000
		je .done
		mov edi, eax
		shr edi, 10
		add edi, ebx
		jmp .free
	.done:
		ret

;maps a physical memory chain to a virtual address
;IN: esi = start of chain, edi = virtual address (assumed to be page aligned)
;NOTE: not for usermode mapping
memory_map_chain:
	mov ecx, [memory_phys.base]
	mov edx, edi
	mov eax, esi
	shr edi, 10
	add edi, [page_tables_v_addr]
	shr esi, 10
	add esi, [memory_phys.table_base]
	.map:
		mov ebx, [esi]
		;and eax, 0xfffff000
		add eax, ecx
		or eax, 3
		mov [edi], eax
		invlpg [edx]
		cmp ebx, 0xfffff000
		je .done
		add edi, 4
		add edx, 1000h
		mov eax, ebx
		mov esi, ebx
		shr esi, 10
		add esi, [memory_phys.table_base]
		jmp .map
	.done:
		ret
		;sub esi, [memory_phys.table_base]
		;shl esi, 10
		;add esi, ecx
		;or esi, 3
		;add edi, 4
		;mov [edi], esi
		;add edx, 1000h
		;invlpg [edx]
		;ret

;remaps part of a chain to make it physically contiguous
;IN: eax = virtual page aligned address, ecx = number of pages, edi = start of chain
;OUT: eax = unchanged on success, eax = 0 on error
;NOTE: assumes eax is page aligned, and is NOT the first page in a chain.
;TODO: acs weird when many pages are requested
memory_phys_contiguous:
	push eax
	shr eax, 10
	mov esi, [page_tables_v_addr]
	mov eax, [esi + eax]				;get physical address
	and eax, 0xfffff000
	mov esi, [memory_phys.table_base]
	sub eax, [memory_phys.base]
	.find:								;find what points to the first page to be replaced
		shr edi, 10
		add edi, esi
		mov ebx, [edi]
		cmp ebx, eax
		je .found
		cmp ebx, 0xfffff000
		je .error
		mov edi, ebx
		jmp .find
	.found:
		;[edi] = pointer to start of cutout
		shr eax, 10
		add eax, esi
		push ecx
		;[esp + 4] = virtual address
		;[esp + 0] = number of pages
	.free:								;free the pages
		mov ebx, [eax]
		mov [eax], dword 0
		mov eax, ebx
		shr eax, 10
		add eax, esi
		loop .free
	;ebx = rest of the chain
	mov ecx, [memory_phys.pages]
	.first:								;find the first free page
		lodsd
		and eax, eax
		jz .check
		loop .first
		add esp, 4
		jmp .error
	.check:
		mov edx, ecx
		mov ecx, [esp]
		dec ecx
		jz .good
	.check_loop:						;check if there is a large enough free area
		dec edx
		lodsd
		and eax, eax
		loopz .check_loop
		jz .good
		mov ecx, edx
		jmp .first						;continue looking for the next free page
	.good:
		mov ecx, [esp]
		shl ecx, 2
		sub esi, ecx					;revert esi back to the start of the free area
		shr ecx, 2
		mov eax, esi
		sub eax, [memory_phys.table_base]
		shl eax, 10
		add eax, [memory_phys.base]
		mov [edi], dword eax			;link the old chain to the new area
		mov edi, esi
		dec ecx
		jz .last_link
	.link:
		add eax, 1000h
		stosd							;link the new area to itself...
		loop .link
	.last_link:
		mov [edi], ebx					;...and back to the old chain
		
		;now map it all
		pop ecx
		sub esi, [memory_phys.table_base]
		shl esi, 10
		add esi, [memory_phys.base]
		mov edi, [page_tables_v_addr]
		mov eax, [esp]
		mov ebx, eax
		shr eax, 10
		add edi, eax
		mov eax, esi
		or eax, 3						;supervisor, present
	.map:
		stosd
		invlpg [ebx]
		add eax, 1000h
		add ebx, 1000h
		loop .map
		pop eax
		ret
	.error:
		mov eax, 0
		add esp, 4
		ret

;IN: eax = virtual address
;OUT: eax = physical address
;NOTE: assumes valid addresses
memory_virt_to_phys:
	mov ebx, eax
	and ebx, 0xfff
	and eax, 0xfffff000
	shr eax, 10
	mov esi, [page_tables_v_addr]
	mov eax, [esi + eax]
	and eax, 0xfffff000
	add eax, ebx
	ret

;end of memory has been reached
;IN: eax = extra memory needed in bytes
;OUT: all registers preserved on success, eax = 0 on error, may not return on error
memory_EOM:
	pushad
	add eax, 4095d
	shr eax, 12
	push eax
	mov ecx, eax
	mov edi, [memory_kernel.chain]
	call memory_phys_allocate		;TODO: paging exceptions when trying to allocate more memory than there is, most likely by trying to access nonexisting phys_table entries
	cmp edi, 0
	jne .good
	add esp, 4
	jmp .error
	.good:
	mov esi, edi
	mov edi, [mm.eom]
	call memory_map_chain
	pop eax
	shl eax, 12
	call mm_add
	popad
	ret
	.error:
		popad
		xor eax, eax
		ret

memory_panic:
	mov edi, .num
	call format_hex_dword
	mov esi, .msg
	jmp boot_die
	ret
	.msg db "Memory Panic: "
	.num db "--------", 0

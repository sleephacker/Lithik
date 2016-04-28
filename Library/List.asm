%define LIST_NULL	0xffffffff

struc List
	.first	resd 1	;first item in list
	.last	resd 1	;last item in list
	.count	resd 1	;number of items in list, bit 31 used as lock for adding/removing items
	.struc_size:
endstruc

struc ListItem		;NOTE: it is assumed that the client knows the size of each ListItem.item
	.next	resd 1	;next item in list, NULL for the last item
	.prev	resd 1	;previous item in list, NULL for the first item
	.item:
	.struc_size:
endstruc

list_callback:
	;memory allocation
	;IN: eax = size in bytes
	;OUT: eax = address
	.allocate dd LIST_NULL
	
	;freeing memory
	;IN: eax = address
	.free dd LIST_NULL

;creates a new empty list
;OUT: eax = pointer to List structure
list_new:
	mov eax, List.struc_size
	call [list_callback.allocate]
	mov [eax + List.first], dword LIST_NULL
	mov [eax + List.last], dword LIST_NULL
	mov [eax + List.count], dword 0
	ret

;frees all memory allocated for a list
;IN: eax = pointer to List structure
list_destroy:
	;TODO
	ret

;list_add
;adds an item to the list
;IN: eax = size of item in bytes, ebx = List structure
;OUT: eax = address of the ListItem.item, ebx = List structure
list_add_spin:
	pause										;give the CPU a hint
	test [ebx + List.count], dword 1 << 31
	jnz list_add_spin
list_add:
	lock bts dword [ebx + List.count], 31		;test and set lock on count
	jc list_add_spin
	cmp [ebx + List.count], dword 1 << 31 | 0	;lock set, count is zero
	je .first
	push ebx
	add eax, ListItem.struc_size
	call [list_callback.allocate]
	pop ebx
	mov ecx, [ebx + List.last]
	mov [ebx + List.last], eax
	mov [eax + ListItem.next], dword LIST_NULL
	mov [eax + ListItem.prev], ecx
	mov [ecx + ListItem.next], eax
	add eax, ListItem.item
	inc dword [ebx + List.count]
	lock btr dword [ebx + List.count], 31		;release the lock
	ret
	.first:
		push ebx
		add eax, ListItem.struc_size
		call [list_callback.allocate]
		pop ebx
		mov [ebx + List.first], eax
		mov [ebx + List.last], eax
		mov [eax + ListItem.next], dword LIST_NULL
		mov [eax + ListItem.prev], dword LIST_NULL
		add eax, ListItem.item
		inc dword [ebx + List.count]
		lock btr dword [ebx + List.count], 31	;release the lock
		ret

;list_begin_add
;begins to add an item to the list
;IN: eax = size of item in bytes, ebx = List structure
;OUT: eax = address of the ListItem.item, ebx = List structure
list_begin_add_spin:
	pause										;give the CPU a hint
	test [ebx + List.count], dword 1 << 31
	jnz list_begin_add_spin
list_begin_add:
	lock bts dword [ebx + List.count], 31		;test and set lock on count
	jc list_begin_add_spin
	push ebx
	add eax, ListItem.struc_size
	call [list_callback.allocate]
	pop ebx
	add eax, ListItem.item
	ret

;finishes adding an item to the list
;IN: eax = address of the ListItem.item, ebx = List structure
;OUT: eax = address of the ListItem.item, ebx = List structure
list_finish_add:
	sub eax, ListItem.item
	cmp [ebx + List.count], dword 1 << 31 | 0	;lock set, count is zero
	je .first
	mov [eax + ListItem.next], dword LIST_NULL
	mov [eax + ListItem.prev], ecx
	mov ecx, [ebx + List.last]
	mov [ebx + List.last], eax
	mov [ecx + ListItem.next], eax
	add eax, ListItem.item
	inc dword [ebx + List.count]
	lock btr dword [ebx + List.count], 31		;release the lock
	ret
	.first:
		mov [eax + ListItem.next], dword LIST_NULL
		mov [eax + ListItem.prev], dword LIST_NULL
		mov [ebx + List.first], eax
		mov [ebx + List.last], eax
		inc dword [ebx + List.count]
		add eax, ListItem.item
		lock btr dword [ebx + List.count], 31	;release the lock
		ret

;list_remove
;removes an item from a list and frees the memory associated with it
;IN: eax = address of the ListItem.item, ebx = List structure
;OUT: ebx = List structure
list_remove_spin:
	pause										;give the CPU a hint
	test [ebx + List.count], dword 1 << 31
	jnz list_remove_spin
list_remove:									;TODO: test
	lock bts dword [ebx + List.count], 31		;test and set lock on count
	jc list_remove_spin
	sub eax, ListItem.item
	mov ecx, [eax + ListItem.next]
	mov edx, [eax + ListItem.prev]
	push ebx
	push ecx
	push edx
	call [list_callback.free]
	pop edx
	pop ecx
	pop ebx
	cmp dword [ebx + List.count], 1
	je .only
	cmp ecx, LIST_NULL
	je .last
	cmp edx, LIST_NULL
	je .first
	mov [ecx + ListItem.prev], edx
	mov [edx + ListItem.next], ecx
	dec dword [ebx + List.count]
	lock btr dword [ebx + List.count], 31		;release the lock
	ret
	.first:
		mov [ebx + List.first], ecx
		mov dword [ecx + ListItem.prev], LIST_NULL
		dec dword [ebx + List.count]
		lock btr dword [ebx + List.count], 31	;release the lock
		ret
	.last:
		mov [ebx + List.last], edx
		mov dword [edx + ListItem.next], LIST_NULL
		dec dword [ebx + List.count]
		lock btr dword [ebx + List.count], 31	;release the lock
		ret
	.only:
		mov dword [ebx + List.first], LIST_NULL
		mov dword [ebx + List.last], LIST_NULL
		mov dword [ebx + List.count], 0
		lock btr dword [ebx + List.count], 31	;release the lock
		ret

;gets the first item in the list
;IN: ebx = List structure
;OUT: eax = first ListItem.item item
;NOTE: only eax is modified, all other registers are preserved
;NOTE: may return LIST_NULL is the list is empty
list_first:
	mov eax, [ebx + List.first]
	cmp eax, LIST_NULL
	je .ret
	add eax, ListItem.item
	.ret:ret

;gets the last item in the list
;IN: ebx = List structure
;OUT: eax = first ListItem.item item
;NOTE: only eax is modified, all other registers are preserved
;NOTE: may return LIST_NULL is the list is empty
list_last:
	mov eax, [ebx + List.last]
	cmp eax, LIST_NULL
	je .ret
	add eax, ListItem.item
	.ret:ret

;gets the next item in the list
;IN: eax = ListItem.item, ebx = List
;OUT: eax = next item
;NOTE: only eax is used, all other registers are preserved
;NOTE: may return LIST_NULL
list_next:
	cmp eax, LIST_NULL
	je .ret
	mov eax, [eax - ListItem.item + ListItem.next]
	cmp eax, LIST_NULL
	je .ret
	add eax, ListItem.item
	.ret:ret

;gets the previous item in the list
;IN: eax = ListItem.item, ebx = List
;OUT: eax = previous item
;NOTE: only eax is used, all other registers are preserved
;NOTE: may return LIST_NULL
list_prev:
	cmp eax, LIST_NULL
	je .ret
	mov eax, [eax - ListItem.item + ListItem.prev]
	cmp eax, LIST_NULL
	je .ret
	add eax, ListItem.item
	.ret:ret

struc Thread
	.id						resd 1
	.flags					resd 1		;flags == 0 -> "ideal" thread
	.pool					resd 1
	.Q						resd 1
	.priority				resd 1
	
	.esp					resd 1
	.ebp					resd 1
	
	.next					resd 1
	
	.struc_size:
endstruc
%define Thread_SUSPENDED	0x00000001

struc ThreadQ;ueue
	.count					resd 1		;total number in queue
	.active					resd 1		;number of active threads in queue
	.first					resd 1
	.last					resd 1
	
	.struc_size:
endstruc
%define ThreadQ_pow			4
%if 1 << ThreadQ_pow != ThreadQ.struc_size
%error "Wrong ThreadQ.struc_size!"
%endif

struc ThreadPool
	.nextId					resd 1
	.count					resd 1
	.Qnum					resd 1
	.Qs:
endstruc
%define ThreadPoolQ(priority) ThreadPool.Qs + priority << ThreadQ_pow
%define ThreadPoolSize(Qnum) ThreadPool.Qs + Qnum << ThreadQ_pow

;creates a new thread in the current pool
;IN: eax = stack size, ebx = stack base, ecx = number of words from stack to copy, edx = priority, edi = child eip
;OUT(parent): eax = child id
;OUT(child): eax = parent id
;NOTE: might enable interrupts if they were disabled before calling
;NOTE: doesn't check if any input is valid
Thread_Fork:
	call Tasking_Pause
	push edi
	push edx
	push ecx
	push eax
	push ebx
	mov eax, Thread.struc_size
	call mm_allocate
	pop edi
	mov [eax + Thread.ebp], edi
	pop ecx
	add edi, ecx
	pop ecx
	shl ecx, 1
	sub edi, ecx
	mov [eax + Thread.esp], edi
	mov esi, esp
	add esi, 12	;1x call(=1x push) + 5x push - 3x pop = 3 dwords = 12 bytes
	shr ecx, 1
	rep movsw
	mov edi, [Scheduler.currentThreadPool]
	mov ebx, [edi + ThreadPool.nextId]
	mov [eax + Thread.id], ebx
	mov [eax + Thread.pool], edi
	inc dword [edi + ThreadPool.count]
	inc dword [edi + ThreadPool.nextId]
	mov esi, [Scheduler.currentThread]
	mov ebx, [esi + Thread.flags]
	mov [eax + Thread.flags], ebx
	pop edx
	mov [eax + Thread.priority], edx
	cmp edx, [esi + Thread.priority]
	jb .higher
	shl edx, ThreadQ_pow
	add edi, edx
	add edi, ThreadPool.Qs
	mov [eax + Thread.Q], edi
	mov ebx, [edi + ThreadQ.last]
	mov [ebx + Thread.next], eax
	mov [edi + ThreadQ.last], eax
	inc dword [edi + ThreadQ.count]
	sub dword [eax + Thread.esp], pushad_stack.struc_size + int_stack.struc_size
	mov edi, [eax + Thread.esp]
	;fake an interrupt
	pushfd
	pop dword [edi + int_stack.eflags + pushad_stack.struc_size]
	pop dword [edi + int_stack.eip + pushad_stack.struc_size]
	mov [edi + int_stack.cs + pushad_stack.struc_size], cs
	mov [edi + int_stack.cs + 2 + pushad_stack.struc_size], word 0
	;fake a pushad after being interrupted
	mov [edi + pushad_stack.esp], edi
	mov ecx, [eax + Thread.ebp]
	mov [edi + pushad_stack.ebp], ecx
	mov ecx, [Scheduler.currentThread]
	mov ecx, [ecx + Thread.id]
	mov [edi + pushad_stack.eax], ecx
	xor eax, eax
	stosd		;esi
	stosd		;edi
	add edi, 8	;skip ebp & esp
	stosd		;ebx
	stosd		;edx
	stosd		;ecx
	jmp .return
	.higher:
		shl edx, ThreadQ_pow
		add edi, edx
		add edi, ThreadPool.Qs
		mov [eax + Thread.Q], edi
		mov ebx, [edi + ThreadQ.first]
		mov [edi + ThreadQ.first], eax
		mov [eax + Thread.next], ebx
		inc dword [edi + ThreadQ.count]
		inc dword [edi + ThreadQ.active]	;flags are copied from parent, which called this function and is therefore active
		;prepare for the switch
		pop edx
		;fake an interrupt
		;eip was pushed on the stack when this function was called
		pop esi
		pushfd			;eflags
		push word 0		;cs is padded
		push word cs	;cs
		push esi
		;do a pushad
		pushad
		;save the stack
		mov ebx, [Scheduler.currentThread]
		mov [ebx + Thread.esp], esp
		mov [ebx + Thread.ebp], ebp
		;manually switch to the newborn thread
		mov [Scheduler.currentThreadQ], edi
		mov [Scheduler.currentThread], eax
		cli		;can't have interrupts when setting up the stack
		mov esp, [eax + Thread.esp]
		mov ebp, [eax + Thread.ebp]
		sti
		;push the 'return' address
		push edx
		;jmp .return
	.return:
		call Tasking_Resume
		ret

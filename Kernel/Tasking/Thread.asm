struc Thread							;TODO: give threads some form of garbage list, so their memory can be freed on termination
	.id						resd 1
	.flags					resd 1		;flags == 0 -> "ideal" thread
	.pool					resd 1		;since the ThreadPool struc is embedded in the Process struc, this can also be used to find the Process
	.Q						resd 1
	.priority				resd 1
	
	.esp					resd 1
	.ebp					resd 1
	
	.next					resd 1
	.prev					resd 1
	
	.struc_size:
endstruc
%define Thread_SUSPENDED	0x00000001

struc ThreadQ;ueue						;TODO: seperate the queue into active and inactive
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
	.active					resd 1
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
;TODO: write a Thread_SaveFork function that doesn't mess with interrupts an doesn't switch to the new thread at all
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
	inc dword [edi + ThreadPool.active]
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
	mov [eax + Thread.prev], ebx
	cmp ebx, Tasking_NULLADDR
	je .empty
	mov [ebx + Thread.next], eax
	jmp .skipEmpty
	.empty:
	mov [edi + ThreadQ.first], eax
	.skipEmpty:
	mov [edi + ThreadQ.last], eax
	mov [eax + Thread.next], dword Tasking_NULLADDR
	inc dword [edi + ThreadQ.count]
	inc dword [edi + ThreadQ.active]
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
	mov ecx, [ecx + Thread.id]	;parent id
	mov [edi + pushad_stack.eax], ecx
	mov ebx, [eax + Thread.id]	;child id
	xor eax, eax
	stosd			;esi
	stosd			;edi
	add edi, 8		;skip ebp & esp
	stosd			;ebx
	stosd			;edx
	stosd			;ecx
	mov eax, ebx
	jmp .return
	.higher:
		shl edx, ThreadQ_pow
		add edi, edx
		add edi, ThreadPool.Qs
		mov [eax + Thread.Q], edi
		mov ebx, [edi + ThreadQ.first]
		mov [edi + ThreadQ.first], eax
		mov [eax + Thread.prev], dword Tasking_NULLADDR
		mov [eax + Thread.next], ebx
		cmp ebx, Tasking_NULLADDR
		jne .skipLast
		mov [edi + ThreadQ.last], eax
		jmp .skipPrev
		.skipLast:
		mov [ebx + Thread.prev], eax
		.skipPrev:
		inc dword [edi + ThreadQ.count]
		inc dword [edi + ThreadQ.active]	;flags are copied from parent, which called this function and is therefore active
		;prepare for the switch
		pop edx
		;fake an interrupt
		;eip was pushed on the stack when this function was called
		pop esi
		pushfd			;eflags
		xor ebx, ebx
		mov bx, cs
		push ebx		;cs
		push esi		;eip
		;do a pushad
		mov ecx, [eax + Thread.id]
		xchg ecx, eax				;child id in eax
		pushad
		;save the stack
		mov ebx, [Scheduler.currentThread]
		mov [ebx + Thread.esp], esp
		mov [ebx + Thread.ebp], ebp
		;manually switch to the newborn thread
		mov [Scheduler.currentThreadQ], edi
		mov [Scheduler.currentThread], ecx
		cli		;can't have interrupts when setting up the stack
		mov esp, [ecx + Thread.esp]
		mov ebp, [ecx + Thread.ebp]
		sti
		mov eax, [ebx + Thread.id]	;parent id in eax
		;push the 'return' address
		push edx
	.return:
		call Tasking_Resume
		ret

;kills the current thread
Thread_Die:
	call Tasking_Pause
	;save pointer to current thread
	mov eax, [Scheduler.currentThread]
	mov [.thread], eax
	;mark thread as suspended
	mov [eax + Thread.flags], dword Thread_SUSPENDED
	mov ebx, [eax + Thread.pool]
	mov ecx, [eax + Thread.Q]
	dec dword [ebx + ThreadPool.active]
	dec dword [ecx + ThreadQ.active]
	;switch to the next thread's stack
	call Scheduler_NextThread
	mov eax, [.thread]
	;delete thread from ThreadQ
	mov ebx, [eax + Thread.prev]
	mov ecx, [eax + Thread.next]
	mov edx, [eax + Thread.Q]
	cmp ebx, Tasking_NULLADDR
	je .first
	mov [ebx + Thread.next], ecx
	jmp .skipFirst
	.first:
	mov [edx + ThreadQ.first], ecx
	mov [ecx + Thread.prev], dword Tasking_NULLADDR
	.skipFirst:
	cmp ecx, Tasking_NULLADDR
	je .last
	mov [ecx + Thread.prev], ebx
	jmp .skipLast
	.last:
	mov [edx + ThreadQ.last], ebx
	mov [ebx + Thread.next], dword Tasking_NULLADDR
	.skipLast:
	dec dword [edx + ThreadQ.count]
	mov ebx, [eax + Thread.pool]
	dec dword [ebx + ThreadPool.count]
	;free the Thread structure and its stack
	push eax
	mov eax, [eax + Thread.ebp]
	call mm_free
	pop eax
	call mm_free
	;resume tasking
	call Tasking_Resume
	;return to the interrupted thread
	popad
	iret
	.thread dd 0	;this isn't thread-safe, should only be accesed while tasking is paused

;IN: eax = millis
Thread_Sleep:
	pushad
	call Tasking_Pause
	mov ebx, [IRQ_0.millis]
	sub ebx, [Scheduler.millis]
	sub eax, ebx
	mov eax, SchedulerTimer.struc_size
	call mm_allocate
	mov ecx, [esp + pushad_stack.eax]
	mov [eax + SchedulerTimer.delta], ecx
	mov edx, [Scheduler.currentThread]
	mov [eax + SchedulerTimer.pointer], edx
	mov ebx, [Scheduler.threadTimers]
	cmp ebx, Tasking_NULLADDR
	jne .loop
	mov [Scheduler.threadTimers], eax
	mov [eax + SchedulerTimer.next], dword Tasking_NULLADDR
	mov [eax + SchedulerTimer.prev], dword Tasking_NULLADDR
	jmp .yield
	.loop:
		cmp ecx, [ebx + SchedulerTimer.delta]
		jb .found
		sub ecx, [ebx + SchedulerTimer.delta]
		cmp [ebx + SchedulerTimer.next], dword Tasking_NULLADDR
		je .last
		mov ebx, [ebx + SchedulerTimer.next]
		jmp .loop
	.found:
		mov [eax + SchedulerTimer.delta], ecx
		sub [ebx + SchedulerTimer.delta], ecx
		mov edx, [ebx + SchedulerTimer.prev]
		cmp edx, Tasking_NULLADDR
		je .first
		mov [edx + SchedulerTimer.next], eax
		mov [eax + SchedulerTimer.next], ebx
		mov [eax + SchedulerTimer.prev], edx
		mov [ebx + SchedulerTimer.prev], eax
		jmp .yield
	.first:
		mov [Scheduler.threadTimers], eax
		mov [eax + SchedulerTimer.next], ebx
		mov [ebx + SchedulerTimer.prev], eax
		mov [eax + SchedulerTimer.prev], dword Tasking_NULLADDR
		jmp .yield
	.last:
		mov [eax + SchedulerTimer.delta], ecx
		mov [ebx + SchedulerTimer.next], eax
		mov [eax + SchedulerTimer.prev], ebx
		mov [eax + SchedulerTimer.next], dword Tasking_NULLADDR
	.yield:
		mov eax, [Scheduler.currentThread]
		or [eax + Thread.flags], dword Thread_SUSPENDED
		mov ebx, [eax + Thread.pool]
		dec dword [ebx + ThreadPool.active]
		mov ebx, [eax + Thread.Q]
		dec dword [ebx + ThreadQ.active]
		popad
		;fake an interrupt on this thread
		pushfd
		push dword 0
		push dword .ret
		pushad
		xor eax, eax
		mov ax, cs
		mov [esp + int_stack.cs + pushad_stack.struc_size], eax
		;switch to the next thread
		call Scheduler_NextThread
		;resume tasking
		call Tasking_Resume
		;return to the interrupted thread
		popad
		iret
	.ret:ret

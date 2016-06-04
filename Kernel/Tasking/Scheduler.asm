%define SchedulerTickRate		256
%define SchedulerTickToRTC		RTC_rate / SchedulerTickRate
%if SchedulerTickToRTC < 1
%error "RTC frequency to slow for scheduler!"
%endif
%define ProcessQuantum			4 * SchedulerTickToRTC
%define ThreadQuantum			1 * SchedulerTickToRTC

%define Scheduler_DISABLED	0x00000001		;prevents switching thread or process

Scheduler:
	.flags					dd Scheduler_DISABLED
	.processTimer 			dd ProcessQuantum
	.threadTimer 			dd ThreadQuantum
	.currentProcess 		dd KernelProcess
	.currentThreadPool 		dd KernelThreads
	.currentThreadQ 		dd KernelThreadQs.mediumPriority
	.currentThread 			dd KernelMainThread

Scheduler_RTC:
	test [Scheduler.flags], dword Scheduler_DISABLED
	jnz .ret
	;dec dword [Scheduler.processTimer]
	;...
	dec dword [Scheduler.threadTimer]
	jz Scheduler_NextThread
	.ret:ret

;Thread Scheduler

;schedules and switches to the next thread
;NOTE: assumes flags, processTimer, threadTimer, currentProcess and currentThreadPool are all valid (for this purpose)
Scheduler_NextThread:
	mov eax, [Scheduler.currentThreadPool]
	cmp [eax + ThreadPool.count], dword 1
	je .return
	;TODO: check if currentThreadQ and currentThread are valid
	;if so: put the current thread at the end of the current queue
	;set the currentThreadQ.first to the currentThread.next pointer
	mov ebx, [Scheduler.currentThreadQ]
	cmp ebx, dword Tasking_NULLADDR
	je .skipReQ
	mov ecx, [Scheduler.currentThread]
	cmp ecx, dword Tasking_NULLADDR
	je .skipReQ
	mov edx, [ebx + ThreadQ.last]
	mov [edx + Thread.next], ecx
	mov [ebx + ThreadQ.last], ecx
	mov edx, [ecx + Thread.next]
	mov [ecx + Thread.next], dword Tasking_NULLADDR
	mov [ebx + ThreadQ.first], edx
	.skipReQ:
	;TODO: find the first (and thus highest priority) ThreadQ in the pool that has at least one thread ready to be scheduled
	;make that queue the currentThreadQ and make its first thread the currentThread if it's ready to be scheduled
	;if not: put it at the end of the queue and repeat the process until a good thread is found
	;unless the new currentThread equals the old one: save the old context and load the new one
	mov esi, [Scheduler.currentThread]	;save it for later comparison
	mov ecx, [eax + ThreadPool.Qnum]
	add eax, ThreadPool.Qs
	.loopQ:
		cmp [eax + ThreadQ.active], dword 0
		jne .Qfound
		add eax, ThreadQ.struc_size
		loop .loopQ
		jmp .noThread
	.Qfound:
		xchg bx, bx
		mov ebx, [eax + ThreadQ.first]
		mov ecx, [eax + ThreadQ.count]
		cmp ecx, dword 1
		je .threadFound		;ThreadQ.active > 0 & ThreadQ.count == 1
	.loopThread:
		xchg bx, bx
		cmp [ebx + Thread.flags], dword 0
		je .threadFound
		mov edx, [eax + ThreadQ.last]
		mov [edx + Thread.next], ebx
		mov [eax + ThreadQ.last], ebx
		mov edx, [ebx + Thread.next]
		mov [eax + ThreadQ.first], edx
		mov [ebx + Thread.next], dword Tasking_NULLADDR
		mov ebx, edx
		loop .loopThread
		jmp .noThread		;should be impossible
	.threadFound:
		xchg bx, bx
		cmp esi, ebx
		je .return
		mov [Scheduler.currentThreadQ], eax
		mov [Scheduler.currentThread], ebx
		pop eax				;caller eip, points to interrupt handler
		mov [esi + Thread.esp], esp
		mov [esi + Thread.ebp], ebp
		mov esp, [ebx + Thread.esp]
		mov ebp, [ebx + Thread.ebp]
		push eax			;return as a different thread
	.return:
		mov [Scheduler.threadTimer], dword ThreadQuantum
		ret
	.noThread:				;no thread found, act like the main kernel thread was found
		mov eax, KernelMainQ
		mov ebx, KernelMainThread
		jmp .threadFound

;Process Scheduler
;no multitasking for now, just multithreading
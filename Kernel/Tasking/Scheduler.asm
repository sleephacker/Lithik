%define SchedulerTickRate		256
%define SchedulerTickToRTC		RTC_rate / SchedulerTickRate
%if SchedulerTickToRTC < 1
%error "RTC frequency to slow for scheduler!"
%endif
%define ProcessQuantum			4 * SchedulerTickToRTC
%define ThreadQuantum			1 * SchedulerTickToRTC

%define Scheduler_DISABLED		0x00000001	;prevents switching thread or process

struc SchedulerTimer
	.next						resd 1
	.prev						resd 1
	.delta						resd 1
	.pointer					resd 1
	.struc_size:
endstruc

Scheduler:
	.flags						dd Scheduler_DISABLED
	.millis						dd 0
	.threadTimers				dd Tasking_NULLADDR		;points to the first SchedulerTimer in the list
	.processTimers				dd Tasking_NULLADDR		;same as .threadTimers, but for processes
	.processQuantum				dd ProcessQuantum
	.threadQuantum 				dd ThreadQuantum
	.currentProcess 			dd KernelProcess
	.currentThreadPool 			dd KernelThreads
	.currentThreadQ 			dd KernelThreadQs.mediumPriority
	.currentThread 				dd KernelMainThread

Scheduler_Heartbeat:
	test [Scheduler.flags], dword Scheduler_DISABLED
	jnz .ret
	mov eax, [IRQ_0.millis]
	mov ebx, eax
	sub eax, [Scheduler.millis]				;delta time
	mov [Scheduler.millis], ebx
	cmp [Scheduler.threadTimers], dword Tasking_NULLADDR
	je .skipThreads
	mov ebx, [Scheduler.threadTimers]
	.wakeThreads:
		sub [ebx + SchedulerTimer.delta], eax
		jc .wake
		jnz .skipThreads
	.wake:
		mov ecx, [ebx + SchedulerTimer.pointer]
		and [ecx + Thread.flags], dword ~Thread_SUSPENDED
		mov edx, [ecx + Thread.pool]
		inc dword [edx + ThreadPool.active]
		mov edx, [ecx + Thread.Q]
		inc dword [edx + ThreadQ.active]
		push dword [ebx + SchedulerTimer.delta]
		push dword [ebx + SchedulerTimer.next]
		mov eax, ebx
		call mm_free
		pop ebx
		pop eax
		mov [Scheduler.threadTimers], ebx
		mov [ebx + SchedulerTimer.prev], dword Tasking_NULLADDR
		cmp ebx, Tasking_NULLADDR
		je .skipThreads
		neg eax	;CF = (eax != 0)
		jc .wakeThreads
	.skipThreads:
	;cmp [Scheduler.processTimers], dword Tasking_NULLADDR
	;...
	;dec dword [Scheduler.processTimer]
	;...
	dec dword [Scheduler.threadQuantum]
	jz Scheduler_NextThread
	.ret:ret

;Thread Scheduler

;schedules and switches to the next thread
;NOTE: assumes the return address is an interrupt handler
;NOTE: assumes flags, processTimer, threadTimer, currentProcess and currentThreadPool are all valid (for this purpose)
Scheduler_NextThread:
	mov esi, [Scheduler.currentThread]		;save it for later comparison
	mov eax, [Scheduler.currentThreadPool]
	mov ebx, [Scheduler.currentThreadQ]
	cmp ebx, dword Tasking_NULLADDR
	je .skipReQ
	mov ecx, [Scheduler.currentThread]
	cmp ecx, dword Tasking_NULLADDR
	je .skipReQ
	mov edx, [ebx + ThreadQ.last]
	mov [edx + Thread.next], ecx
	mov [ecx + Thread.prev], edx
	mov [ebx + ThreadQ.last], ecx
	mov edx, [ecx + Thread.next]
	mov [ecx + Thread.next], dword Tasking_NULLADDR
	mov [edx + Thread.prev], dword Tasking_NULLADDR
	mov [ebx + ThreadQ.first], edx
	.skipReQ:
	mov ecx, [eax + ThreadPool.Qnum]
	add eax, ThreadPool.Qs
	.loopQ:
		cmp [eax + ThreadQ.active], dword 0
		jne .Qfound
		add eax, ThreadQ.struc_size
		loop .loopQ
		jmp .noThread
	.Qfound:
		mov ebx, [eax + ThreadQ.first]
		mov ecx, [eax + ThreadQ.count]
	.loopThread:
		cmp [ebx + Thread.flags], dword 0
		je .threadFound
		mov edx, [eax + ThreadQ.last]
		mov [edx + Thread.next], ebx
		mov [ebx + Thread.prev], edx
		mov [eax + ThreadQ.last], ebx
		mov edx, [ebx + Thread.next]
		mov [ebx + Thread.next], dword Tasking_NULLADDR
		mov [edx + Thread.prev], dword Tasking_NULLADDR
		mov [eax + ThreadQ.first], edx
		mov ebx, edx
		loop .loopThread
		jmp .noThread						;should be impossible
	.threadFound:
		cmp esi, ebx
		je .return
		mov [Scheduler.currentThreadQ], eax
		mov [Scheduler.currentThread], ebx
		pop eax								;caller eip, points to interrupt handler
		mov [esi + Thread.esp], esp
		mov [esi + Thread.ebp], ebp
		mov esp, [ebx + Thread.esp]
		mov ebp, [ebx + Thread.ebp]
		push eax							;return as a different thread
	.return:
		mov [Scheduler.threadQuantum], dword ThreadQuantum
		ret
	.noThread:								;no thread found, act like the main kernel thread was found
		mov eax, KernelMainQ
		mov ebx, KernelMainThread
		jmp .threadFound

;Process Scheduler
;no multitasking for now, just multithreading
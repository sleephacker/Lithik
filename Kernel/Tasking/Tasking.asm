%define Tasking_NULLADDR 0xffffffff

%define KernelMainQ KernelThreadQs.mediumPriority

%include "Kernel\Tasking\Thread.asm"
%include "Kernel\Tasking\Process.asm"
%include "Kernel\Tasking\Scheduler.asm"

KernelProcess:
istruc Process
	at Process.id, 				dd 0
	at Process.cr3,				dd Tasking_NULLADDR
	at Process.threads,			KernelThreads:
iend
	istruc ThreadPool
		at ThreadPool.nextId,	dd 1
		at ThreadPool.count,	dd 1
		at ThreadPool.active,	dd 1
		at ThreadPool.Qnum,		dd 4
		at ThreadPool.Qs,		KernelThreadQs:
	iend
		.maxPriority:
		istruc ThreadQ
			at ThreadQ.count,	dd 0
			at ThreadQ.active,	dd 0
			at ThreadQ.first,	dd Tasking_NULLADDR
			at ThreadQ.last,	dd Tasking_NULLADDR
		iend
		.highPriority:
		istruc ThreadQ
			at ThreadQ.count,	dd 0
			at ThreadQ.active,	dd 0
			at ThreadQ.first,	dd Tasking_NULLADDR
			at ThreadQ.last,	dd Tasking_NULLADDR
		iend
		.mediumPriority:
		istruc ThreadQ
			at ThreadQ.count,	dd 1
			at ThreadQ.active,	dd 1
			at ThreadQ.first,	dd KernelMainThread
			at ThreadQ.last,	dd KernelMainThread
		iend
		.lowPriority:
		istruc ThreadQ
			at ThreadQ.count,	dd 0
			at ThreadQ.active,	dd 0
			at ThreadQ.first,	dd Tasking_NULLADDR
			at ThreadQ.last,	dd Tasking_NULLADDR
		iend

KernelMainThread:
istruc Thread
	at Thread.id,				dd 0
	at Thread.flags,			dd Thread_SUSPENDED
	at Thread.pool,				dd KernelThreads
	at Thread.priority,			dd 2
	at Thread.esp,				dd Tasking_NULLADDR
	at Thread.ebp,				dd Tasking_NULLADDR
	at Thread.next,				dd Tasking_NULLADDR
iend

Tasking_Init:
	mov [KernelMainThread + Thread.esp], esp
	mov [KernelMainThread + Thread.ebp], ebp
	and [KernelMainThread + Thread.flags], dword ~Thread_SUSPENDED
	
	and [Scheduler.flags], dword ~Scheduler_DISABLED
	ret

;TODO: allow multiple consecutive calls to Tasking_Pause and Tasking_Resume, by incrementing/decrementing a counter.

;NOTE: doesn't modify registers
Tasking_Pause:
	push eax
	mov eax, Scheduler_DISABLED
	xchg [Scheduler.flags], eax		;swap them in one instruction to prevent being interrupted
	mov [.savedFlags], eax
	pop eax
	ret
	.savedFlags dd 0

;NOTE: doesn't modify registers
Tasking_Resume:
	push eax
	mov eax, [Tasking_Pause.savedFlags]
	mov [Scheduler.flags], eax
	pop eax
	ret

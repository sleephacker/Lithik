;TODO: use 'lock cmpxchg [lock_dword], reg_my_thread_id' with eax = 0 to check if a lock is occupied, and if so check if the owner thread is running, if so: use spinlock, otherwise: donate CPU time.
;TODO: let scheduler set extra bit to indicate if the owner thread is currently running
;TODO: (maybe) make locks 64 bytes in size, which might be just enough to contain all information plus the actual spin-wait code, therefore improving cache usage

%macro spinlock_acquire_dword 2				;[lock], bit
lock bts dword %1, %2
jnc %%done
%%wait:
	pause
	test dword %1, 1 << %2
	jnz %%wait
lock bts dword %1, %2
jc %%wait
%%done:
%endmacro

%macro spinlock_soft_acquire_dword 2		;[lock], bit
%%wait:
	pause
	test dword %1, 1 << %2
	jnz %%wait
lock bts dword %1, %2
jc %%wait
%endmacro

%macro spinlock_function_acquire_dword 3	;function label name, [lock], bit
%%wait:
	pause
	test dword %2, 1 << %3
	jnz %%wait
%1:
	lock bts dword %2, %3
	jc %%wait
%endmacro

%macro spinlock_acquire_dword_jump 3		;[lock], bit, destination
lock bts dword %1, %2
jc %%wait
jmp %3
%%wait:
	pause
	test dword %1, 1 << %2
	jnz %%wait
lock bts dword %1, %2
jc %%wait
jmp %3
%endmacro

%macro spinlock_acquire_dword_jump_near 3	;[lock], bit, destination
lock bts dword %1, %2
jnc %3
%%wait:
	pause
	test dword %1, 1 << %2
	jnz %%wait
lock bts dword %1, %2
jnc %3
jmp %%wait
%endmacro

%macro spinlock_release_dword 2
	lock btr dword %1, %2
%endmacro

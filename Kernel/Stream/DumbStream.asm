%ifndef PPP_AUTO_CONSTANT;const

%define DumbStream_DEFAULT_SIZE		4096

%endif;const

;NOTE: if DumbStream.lock and CommonStream.readers/writersCP must be locked at the same time, DumbStream.lock must be locked first to avoid deadlock due to DumbStream_destroyReader

struc DumbStream							;placeholder implementation of Stream
	.common							resb CommonStream.struc_size
	.lock							resd 1	;tlock_2x16 for accessing .head, .tail and the ringbuffer
	.base							resd 1	;base of ringbuffer
	.size							resd 1	;size of ringbuffer
	.head							resd 1	;next byte to write to
	.tail							resd 1	;next byte to read from
	.struc_size:
endstruc

struc DumbStreamReader
	.reader							resb StreamReader.struc_size
	.tail							resd 1	;before reading or modifying this, DumbStream.lock should be locked to prevent race conditions
	.struc_size:
endstruc

struc DumbStreamWriter
	.writer							resb StreamWriter.struc_size
	.struc_size:
endstruc

DumbStreamType:
istruc CommonStreamType
	at CommonStreamType.streamType, istruc StreamType
		;IN: eax = ringbuffer size
		at StreamType.create,		dd DumbStream_create
		at StreamType.createD,		dd DumbStream_createD
		at StreamType.destroy,		dd DumbStream_destroy
		at StreamType.newReader,	dd DumbStream_newReader
		at StreamType.newWriter,	dd DumbStream_newWriter
		at StreamType.newReaderD,	dd DumbStream_newReader
		at StreamType.newWriterD,	dd DumbStream_newWriter
		at StreamType.setNotifyR,	dd CommonStream_setNotifyR
		at StreamType.setNotifyW,	dd CommonStream_setNotifyW
		at StreamType.setFlush,		dd CommonStream_setFlush
		at StreamType.setDrain,		dd CommonStream_setDrain
		at StreamType.clearNotifyR,	dd CommonStream_clearNotifyR
		at StreamType.clearNotifyW,	dd CommonStream_clearNotifyW
		at StreamType.clearFlush,	dd CommonStream_clearFlush
		at StreamType.clearDrain,	dd CommonStream_clearDrain
	iend
	at CommonStreamType.notifyR,	dd CommonStream_notifyR
	at CommonStreamType.notifyW,	dd CommonStream_notifyW
	at CommonStreamType.flush,		dd CommonStream_flush
	at CommonStreamType.drain,		dd CommonStream_drain
iend

;OUT: eax = DumbStream
DumbStream_createD:
	mov eax, DumbStream_DEFAULT_SIZE
	;jmp DumbStream_create
;IN: eax = ringbuffer size
;OUT: eax = DumbStream
DumbStream_create:	;TODO: a lot of this code should be part of a CommonStream function/macro
	push eax
	call mm_allocate
	push eax
	call list_new
	push eax
	call list_new
	push eax
	mov eax, DumbStream.struc_size
	call mm_allocate
	xor ebx, ebx
	mov ecx, Stream_NULL_FUNCTION
	mov dword [eax + Stream.streamType], DumbStreamType
	mov dword [eax + Stream.notifyR], ecx
	mov dword [eax + Stream.notifyW], ecx
	mov dword [eax + Stream.flush], ecx
	mov dword [eax + Stream.drain], ecx
	pop dword [eax + CommonStream.readers]
	pop dword [eax + CommonStream.writers]
	mov dword [eax + CommonStream.readersCP], ebx
	mov dword [eax + CommonStream.writersCP], ebx
	mov dword [eax + CommonStream.numNotifyR], ebx
	mov dword [eax + CommonStream.numNotifyW], ebx
	mov dword [eax + CommonStream.numFlush], ebx
	mov dword [eax + CommonStream.numDrain], ebx
	mov byte [eax + CommonStream.nullNR], bl
	mov byte [eax + CommonStream.nullNW], bl
	mov byte [eax + CommonStream.nullF], bl
	mov byte [eax + CommonStream.nullD], bl
	pop dword [eax + DumbStream.base]
	pop dword [eax + DumbStream.size]
	mov dword [eax + DumbStream.lock], ebx
	mov dword [eax + DumbStream.tail], ebx
	mov dword [eax + DumbStream.head], ebx
	ret

;IN: eax = DumbStream
;NOTE: it is assumed there are no more references to this DumbStream and its readers and writers, and therefore all code is thread-safe and memory-safe by definition
;NOTE: this function depends on the register saving behaviour of most List functions, be cautious when adding new function calls
DumbStream_destroy:
	push eax
	call CommonStream_destroy
	mov eax, [esp]
	mov eax, [eax + DumbStream.base]
	call mm_free											;free ringbuffer
	pop eax
	call mm_free											;free DumbStream
	ret

;IN: eax = DumbStream
;OUT: eax = DumbStreamReader
DumbStream_newReader:
	push eax
	mov eax, DumbStreamReader.struc_size
	call mm_allocate
	mov ebx, [esp]
	xor ecx, ecx
	mov edx, Stream_NULL_FUNCTION
	mov dword [eax + Reader.read], DumbStream_read
	mov dword [eax + Reader.flush], edx
	mov dword [eax + Reader.notify], edx
	mov dword [eax + Reader.die], edx
	mov dword [eax + Reader.destroy], DumbStream_destroyReader
	mov dword [eax + Reader.identity], ecx					;TODO: this takes time, but isn't necessary according to Stream specs... remove? or standardize?
	mov dword [eax + StreamReader.flags], StreamReader_MT_BLOCK
	mov dword [eax + StreamReader.ops], ecx
	mov dword [eax + StreamReader.stream], ebx
	tlock_2x16_acquire_cd [ebx + DumbStream.lock]			;lock ringbuffer
	mov ecx, [ebx + DumbStream.head]
	mov [eax + DumbStreamReader.tail], ecx					;Reader.tail = Stream.head, new readers have no data available to read at the time of creation
	push eax
	cp_16_ref ebx + CommonStream.readersCP, eax, al
	mov ebx, [ebx + CommonStream.readers]
	mov eax, 4												;size of dword
	call list_begin_add										;allow pointer to be initialised before adding it to the list
	pop ecx
	mov [eax], ecx											;set pointer to reader
	mov [ecx + CommonStreamReader.entry], eax
	call list_finish_add
	pop ebx
	tlock_2x16_release [ebx + DumbStream.lock]				;release lock on ringbuffer
	cp_16_clear ebx + CommonStream.readersCP
	mov eax, [eax]											;read pointer back into eax before returning
	ret

;IN: eax = DumbStream
;OUT: eax = DumbStreamWriter
DumbStream_newWriter:
	push eax
	mov eax, DumbStreamWriter.struc_size
	call mm_allocate
	mov ebx, [esp]
	xor ecx, ecx
	mov edx, Stream_NULL_FUNCTION
	mov dword [eax + Writer.write], DumbStream_write
	mov dword [eax + Writer.drain], edx
	mov dword [eax + Writer.notify], edx
	mov dword [eax + Writer.die], edx
	mov dword [eax + Writer.destroy], DumbStream_destroyWriter
	mov dword [eax + Writer.identity], ecx					;TODO: this takes time, but isn't necessary according to Stream specs... remove? or standardize?
	mov dword [eax + StreamWriter.flags], StreamWriter_MT_BLOCK 
	mov dword [eax + StreamWriter.ops], ecx
	mov dword [eax + StreamWriter.stream], ebx
	push eax
	cp_16_ref ebx + CommonStream.writersCP, eax, al
	mov ebx, [ebx + CommonStream.writers]
	mov eax, 4												;size of dword
	call list_begin_add										;allow pointer to be initialised before adding it to the list
	pop ecx
	mov [eax], ecx											;set pointer to writer
	mov [ecx + CommonStreamReader.entry], eax
	call list_finish_add
	pop ebx
	cp_16_clear ebx + CommonStream.writersCP
	mov eax, [eax]											;read pointer back into eax before returning
	ret

;IN: ebx = DumbStreamReader
%macro DumbStream_destroyReaderTest 1
	test dword [ebx + StreamReader.flags], StreamReader_DEAD
	jnz %1
%endmacro

;IN: eax = DumbStreamReader
DumbStream_destroyReader:
	test dword [eax + StreamReader.flags], StreamReader_DEAD
	jnz .dead
	lock inc dword [eax + StreamReader.ops]
	test dword [eax + StreamReader.flags], StreamReader_DEAD
	jnz .dec_dead
	;it is now safe to reference .stream
	;clear functions
	mov ebx, eax
	mov eax, [ebx + StreamReader.stream]
	call CommonStream_clearNotifyR
	call CommonStream_clearFlush							;NOTE: relies on register saving behaviour of CommonStream_clearNotifyR/Flush
	;remove from list
	tlock_2x16_acquire_cd [eax + DumbStream.lock]
	mov ecx, eax
	cp_16_lock_or_abort_jmp ecx + CommonStream.readersCP, DumbStream_destroyReaderTest, .abort
	push ebx
	push ecx
	mov eax, [ebx + CommonStreamReader.entry]
	mov ebx, [ecx + CommonStream.readers]
	call list_remove 										;ebx is saved
	;update DumbStream.tail to exclude the .tail of this Reader
	call list_first
	cmp eax, LIST_NULL
	je .lastReader
	pop ecx
	xor ebx, ebx
	mov edi, [ecx + DumbStream.head]
	.loop:
		mov esi, [eax]
		mov edx, [ecx + DumbStream.head]
		sub edx, [esi + DumbStreamReader.tail]
		jns .skip0
		add edx, [ecx + DumbStream.size]
		.skip0:
		cmp edx, ebx
		jna .skip1
		mov ebx, edx
		mov edi, [esi + DumbStreamReader.tail]
		.skip1:
		call list_next
		cmp eax, LIST_NULL
		jne .loop
	mov [ecx + DumbStream.tail], edi
	;release locks and free memory
	tlock_2x16_release [ecx + DumbStream.lock]
	cp_16_unlock ecx + CommonStream.readersCP
	pop eax
	jmp mm_free												;free memory and return to caller
	.lastReader:
		;this was the last reader, set .head to .tail
		pop ecx
		mov eax, [ecx + DumbStream.head]
		mov [ecx + DumbStream.tail], eax					;stream is empty
		tlock_2x16_release [ecx + DumbStream.lock]
		cp_16_unlock ecx + CommonStream.readersCP
		pop eax
		jmp mm_free											;free memory and return to caller
	.abort:
		tlock_2x16_release [ecx + DumbStream.lock]
		mov eax, ebx
	.dec_dead:
		lock dec dword [eax + StreamReader.ops]
	.dead:													;.stream is dead, no need to do housekeeping, wait for REMOVED bit to avoid accesses to freed memory during stream destruction
		pause
		test dword [eax + StreamReader.flags], StreamReader_REMOVED
		jz .dead
		jmp mm_free											;free memory and return to caller

;IN: ebx = DumbStreamWriter
%macro DumbStream_destroyWriterTest 1
	test dword [ebx + StreamWriter.flags], StreamWriter_DEAD
	jnz %1
%endmacro

;IN: eax = DumbStreamWriter
DumbStream_destroyWriter:
	test dword [eax + StreamWriter.flags], StreamWriter_DEAD
	jnz .dead
	lock inc dword [eax + StreamWriter.ops]
	test dword [eax + StreamWriter.flags], StreamWriter_DEAD
	jnz .dec_dead
	;it is now safe to reference .stream
	;clear functions
	mov ebx, eax
	mov eax, [ebx + StreamWriter.stream]
	call CommonStream_clearNotifyW
	call CommonStream_clearDrain							;NOTE: relies on register saving behaviour of CommonStream_clearNotifyW/Drain
	;remove from list
	tlock_2x16_acquire_cd [eax + DumbStream.lock]
	mov ecx, eax
	cp_16_lock_or_abort_jmp ecx + CommonStream.writersCP, DumbStream_destroyWriterTest, .abort
	push ebx
	push ecx
	mov eax, [ebx + CommonStreamWriter.entry]
	mov ebx, [ecx + CommonStream.writers]
	call list_remove 										;ebx is saved
	;release locks and free memory
	pop ecx
	tlock_2x16_release [ecx + DumbStream.lock]
	cp_16_unlock ecx + CommonStream.writersCP
	pop eax
	jmp mm_free												;free memory and return to caller
	.abort:
		tlock_2x16_release [ecx + DumbStream.lock]
		mov eax, ebx
	.dec_dead:
		lock dec dword [eax + StreamWriter.ops]
	.dead:													;.stream is dead, no need to do housekeeping, wait for REMOVED bit to avoid accesses to freed memory during stream destruction
		pause
		test dword [eax + StreamWriter.flags], StreamWriter_REMOVED
		jz .dead
		jmp mm_free											;free memory and return to caller

;IN: eax = Reader, ebx = buffer, ecx = length
;OUT: eax = number of bytes read
DumbStream_read:
	test dword [eax + StreamWriter.flags], StreamWriter_DEAD
	jnz .dead
	lock inc dword [eax + StreamWriter.ops]
	test dword [eax + StreamWriter.flags], StreamWriter_DEAD
	jnz .dec_dead
	mov edi, ebx
	mov esi, ecx
	mov ebx, [eax + StreamReader.stream]
	tlock_2x16_acquire_cd [ebx + DumbStream.lock]
	mov ecx, [ebx + DumbStream.head]
	sub ecx, [eax + DumbStreamReader.tail]
	jz .no_bytes
	jns .single_copy
	.dual_copy:												;tail addresswise ahead of head
		add ecx, [ebx + DumbStream.size]
		push ecx
		cmp ecx, esi
		jna .skip0
		mov ecx, esi
		.skip0:
		mov esi, [ebx + DumbStream.size]
		sub esi, [ebx + DumbStream.head]
		cmp esi, ecx
		ja .do_single_copy
		push ecx
		mov edx, ecx
		sub edx, esi
		mov ecx, esi
		mov esi, [eax + DumbStreamReader.tail]
		add esi, [ebx + DumbStream.base]
		rep movsb
		mov esi, [ebx + DumbStream.base]
		mov ecx, edx
		rep movsb
		mov [eax + DumbStreamReader.tail], edx
		pop ecx
		jmp .update
	.single_copy:											;tail addresswise behind head, or difference between .head and .size less than number of bytes to read
		push ecx
		cmp ecx, esi
		jna .do_single_copy
		mov ecx, esi
	.do_single_copy:
		mov esi, [eax + DumbStreamReader.tail]
		add esi, [ebx + DumbStream.base]
		mov edx, ecx
		rep movsb
		mov ecx, edx
		add edx, [eax + DumbStreamReader.tail]
		mov [eax + DumbStreamReader.tail], edx
	.update:												;update DumbStream.tail
		push ecx
		push eax
		mov esi, ebx
		cp_16_ref esi + CommonStream.readersCP, eax, al
		mov ebx, [esi + CommonStream.readers]
		call list_first										;saves all registers except eax
		mov ebx, [esp + 8]									;pop difference between .tail of this reader and .head of DumbStream
		sub ebx, ecx										;substract number of bytes read
		.loop:
			cmp eax, LIST_NULL
			je .done
			mov edi, [eax]
			mov ecx, [esi + DumbStream.head]
			sub ecx, [edi + DumbStreamReader.tail]
			jns .skip1
			add ecx, [esi + DumbStream.size]
			.skip1:
			cmp ecx, ebx
			jna .skip2
			mov ebx, ecx
			mov edx, [edi + DumbStreamReader.tail]
			.skip2:
			call list_next
			jmp .loop
		.done:
		mov ecx, edx
		sub ecx, [esi + DumbStream.tail]
		jns .skip3
		add ecx, [esi + DumbStream.size]
		.skip3:
		mov [esi + DumbStream.tail], edx					;update tail
		tlock_2x16_release [esi + DumbStream.lock]			;release lock before calling .notifyW
		test ecx, ecx
		jz .skipNotify										;don't notify writers of a change in .tail if the change in .tail is zero
		mov eax, esi
		push esi
		call [eax + Stream.notifyW]
		pop esi
		.skipNotify:
	.return:												;release lock, clear references and return
		cp_16_clear esi + CommonStream.readersCP
		pop eax
		lock dec dword [eax + StreamReader.ops]
		pop eax												;pop number of bytes read
		add esp, 4
		ret
	.dec_dead:
		lock dec dword [eax + StreamReader.ops]
	.dead:
		xor eax, eax										;zero bytes read
		ret
	.no_bytes:												;tail equal to head, send .notify to writers
		tlock_2x16_release [ebx + DumbStream.lock]
		push eax
		;ecx is already zero
		mov eax, ebx
		call [eax + Stream.notifyW]
		pop eax
		lock dec dword [eax + StreamReader.ops]
		xor eax, eax
		ret

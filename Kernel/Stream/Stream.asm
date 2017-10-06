;TODO: add a unit size definition to Stream (or Reader & Writer) to properly support 16 bit characters, sound samples and other multi-byte units
;TODO: handle different (variable-width) character formats... or not
;TODO: add a 'aligned' flag to Stream, therefore allowing fast reads and writes when possible (almost always, except for e.g. unaligned payload of network packets)
;TODO: way for reading client to know how many bytes are available
;TODO: add standardized hints about usage to reader/writer creation functions (e.g. permanent/long-term/short-term) 

;NOTE: .notify, .flush and .drain functions must either read/write or not, but must not wait in order to prevent deadlocks (e.g. read -> notify -> write -> notify -> wait for first read -> deadlock)
;NOTE: owner of Stream must make sure there are no references to a Stream (e.g. using smart pointers) before destroying it
;NOTE: the way readers and writers are stored is implementation dependent, but any list structures must be destroyed when the corresponding Stream is destroyed

%ifndef PPP_AUTO_CONSTANT;const

%define Stream_NULL				0xffffffff

;StreamReader flag definitions
%define StreamReader_DEAD		1			;indicates a dead stream, no reads should start when this flag is set, should not be cleared once set
%define StreamReader_REMOVED	2			;when set in combination with StreamReader_DEAD, indicates that the StreamReader can no longer be referenced by the Stream
%define StreamReader_MT_BLOCK	4			;StreamReaders with this bit set may block or cause significant performance penalties if .read is called by multiple threads at once

;StreamWriter flag definitions
%define StreamWriter_DEAD		1			;indicates a dead stream, no writes should start when this flag is set, should not be cleared once set
%define StreamWriter_REMOVED	2			;when set in combination with StreamWriter_DEAD, indicates that the StreamWriter can no longer be referenced by the Stream
%define StreamWriter_MT_BLOCK	4			;StreamWriters with this bit set may block or cause significant performance penalties if .write is called by multiple threads at once

%endif;const

struc Stream				;abstract
	.streamType		resd 1	;type of this stream
	.notifyR		resd 1	;calls .notify on all readers, IN: eax = Stream, ecx = number of bytes written
	.notifyW		resd 1	;calls .notify on all writers, IN: eax = Stream, ecx = number of bytes fully read
	.flush			resd 1	;calls .flush on all readers, IN: eax = Stream
	.drain			resd 1	;calls .drain on all writers, IN: eax = Stream
	.struc_size:
endstruc

struc CommonStream			;half-implementation, provides common fields and functions for Stream implementations
	.stream			resb Stream.struc_size
	.readers		resd 1	;List of pointers to StreamReaders, TODO: should be list of smart pointers
	.readersCP		resb cp_16.struc_size
	.writers		resd 1	;List of pointers to StreamWriters, TODO: should be list of smart pointers
	.writersCP		resb cp_16.struc_size
	.numNotifyR		resd 1	;number of readers with .notify enabled
	.numNotifyW 	resd 1	;number of writers with .notify enabled
	.numFlush		resd 1	;number of readers with .flush enabled
	.numDrain		resd 1	;number of writers with .drain enabled
	.nullNR			resb 1	;flag for setting .notifyR to null, must be 1 or 0
	.nullNW			resb 1	;flag for setting .notifyW to null, must be 1 or 0
	.nullF			resb 1	;flag for setting .flush to null, must be 1 or 0
	.nullD			resb 1	;flag for setting .drain to null, must be 1 or 0
							;.null must be set to 1 and .num must be checked afterwards before setting a function to null
	.struc_size:
endstruc
%if CommonStream.struc_size % 4 != 0
%error "CommonStream.struc_size is not DWORD aligned!"
%endif

;TODO: get rid of function pointers in StreamType, instead embed function pointers in Stream structure to allow specialized functions for certain situations to be used

;TODO: how to recognise? remember pointers, name, id?
;TODO: maybe add a .compatible pointer to allow different but compatible implementations to be used properly
struc StreamType
	;creates a new Stream structure
	;IN: implementation dependent
	;OUT: eax = Stream, or Stream_NULL
	.create			resd 1
	;creates a new Stream structure, using default parameters
	;OUT: eax = Stream
	;NOTE: may NOT fail
	.createD		resd 1
	;frees all resources associated with a Stream of this type
	;IN: eax = Stream
	;NOTE: owner of stream is resposible for ensuring there are no more references to this stream apart from any readers / writers
	;NOTE: owners of readers and writers of this stream are resposible for freeing their own structures, .destroy only sets their DEAD flag and clears their reference to this Stream
	.destroy		resd 1
	;creates (and connects) a new StreamReader for the specified Stream
	;IN: eax = Stream, other parameters are implementation dependent
	;OUT: eax = StreamReader
	;NOTE: on StreamReader creation, there are initially per definition 0 bytes available to read
	.newReader		resd 1
	;creates (and connects) a new StreamWriter for the specified Stream
	;IN: eax = Stream, other parameters are implementation dependent
	;OUT: eax = StreamWriter
	.newWriter		resd 1
	;creates (and connects) a new StreamReader for the specified Stream, using default parameters
	;IN: eax = Stream
	;OUT: eax = StreamReader
	.newReaderD		resd 1
	;creates (and connects) a new StreamWriter for the specified Stream, using default parameters
	;IN: eax = Stream
	;OUT: eax = StreamWriter
	.newWriterD		resd 1
	;sets .notify on a StreamReader of the specified Stream, guarantees Stream.notifyR is correct for other Readers during and for this Reader after the call
	;IN: eax = Stream, ebx = StreamReader, ecx = function
	.setNotifyR		resd 1
	;sets .notify on a StreamWriter of the specified Stream, guarantees Stream.notifyW is correct for other Writers during and for this Writer after the call
	;IN: eax = Stream, ebx = StreamWriter, ecx = function
	.setNotifyW		resd 1
	;sets .flush on a StreamReader of the specified Stream, guarantees Stream.flush is correct for other Readers during and for this Reader after the call
	;IN: eax = Stream, ebx = StreamReader, ecx = function
	.setFlush		resd 1
	;sets .drain on a StreamWriter of the specified Stream, guarantees Stream.drain is correct for other Writers during and for this Writer after the call
	;IN: eax = Stream, ebx = StreamWriter, ecx = function
	.setDrain		resd 1
	;sets .notify to null on a StreamReader of the specified Stream, guarantees Stream.notifyR is correct for other Readers during and for this Reader after the call
	;IN: eax = Stream, ebx = StreamReader
	.clearNotifyR	resd 1
	;sets .notify to null on a StreamWriter of the specified Stream, guarantees Stream.notifyW is correct for other Writers during and for this Writer after the call
	;IN: eax = Stream, ebx = StreamWriter
	.clearNotifyW	resd 1
	;sets .flush to null on a StreamReader of the specified Stream, guarantees Stream.flush is correct for other Readers during and for this Reader after the call
	;IN: eax = Stream, ebx = StreamReader
	.clearFlush		resd 1
	;sets .drain to null on a StreamWriter of the specified Stream, guarantees Stream.drain is correct for other Writers during and for this Writer after the call
	;IN: eax = Stream, ebx = StreamWriter
	.clearDrain		resd 1
	.struc_size:
	;NOTE: additional implementation dependent fields may follow
endstruc

struc CommonStreamType
	.streamType		resb StreamType.struc_size
	.notifyR		resd 1	;default .notifyR
	.notifyW		resd 1	;default .notifyR
	.flush			resd 1	;default .flush
	.drain			resd 1	;default .drain
endstruc

;TODO: Reader & Writer .die handler (to be called after (or before?) the target resource has been destroyed)?

struc Reader				;abstract
	;read function
	;IN: eax = Reader, ebx = buffer, ecx = length
	;OUT: eax = number of bytes read
	.read			resd 1
	;flush handler, may only be implemented by client
	;IN: eax = Reader
	;NOTE: the flush handler should read all available bytes before returning, otherwise loss of data and an unnoticed decrease in the number of available bytes may occur.
	;NOTE: must be called before discarding any unread data
	.flush			resd 1
	;notification handler, must be called whenever the number of available bytes increases, may only be implemented by client
	;IN: eax = Reader, ecx = number of extra available bytes
	;TODO: choose:
	;OLD NOTE: must be called at the end of every write operation, after the written data is ready to be read but before returning
	;NEW NOTE: every write operation must result in a .notify call ASAP
	;NEW NOTE: multiple increases in available bytes to read may be combined into a single .notify (should only be done if this doesn't increase latency in any situation at all)
	;NEW NOTE: .notify calls should only be delayed by starting and/or communicating with another thread to offload the call
	.notify			resd 1
	;die handler, signals the end of the resource this Reader was reading from, may only be implemented by client
	;IN: eax = Reader
	;NOTE: must be called once reading is no longer possible, .flush is reccomended to be called before resource destruction
	.die			resd 1
	;frees all resources associated with this Reader, excluding the resource this Reader was reading from
	;IN: eax = Reader
	;NOTE: the owner of the Reader is responsible for ensuring there are no more references made to the Reader
	;NOTE: .destroy must not perform any read operations
	;NOTE: it is recommended that buffered readers provide a function for the client to call before calling .destroy to read any remaining data in the buffer
	.destroy		resd 1
	.identity		resd 1	;dword to be used by client to identify this Reader
	.struc_size:
endstruc

struc Writer				;abstract
	;write function
	;IN: eax = Writer, ebx = buffer, ecx = length
	;OUT: number of bytes written
	.write			resd 1
	;drain handler, may only be implemented by client
	;IN: eax = Writer
	;NOTE: the drain handler should write any data that is ready to be written before returning
	.drain			resd 1
	;notification handler, may be called when the receiving end is ready for more data, may be implemented by client
	;IN: eax = Writer, ecx = number of bytes consumed / increase in size of empty space in buffer (may be a lie, must only be 0 if no bytes are available to read)
	;NOTE: must not be called within a read operation
	;NOTE: should only be called with the intention of reading at least some of the data that is written as a result of the call
	;NOTE: should not be called repeatedly (e.g. a polling read loop should (first of all be avoided) read once, call .notify if the read failed, then read in a loop without calling .notify again)
	.notify			resd 1
	;die handler, signals the end of the resource this Writer was writing to, may only be implemented by client
	;IN: eax = Writer
	;NOTE: must be called once writing is no longer possible, .drain is recommended to be called before resource destruction
	.die			resd 1
	;frees all resources associated with this Writer, excluding the resource this Writer was writing to
	;IN: eax = Writer
	;NOTE: the owner of the Writer is responsible for ensuring there are no more references made to the Writer
	;NOTE: .destroy must not perform any write operations
	;NOTE: it is recommended that buffered writers provide a function for the client to call before calling .destroy to write any remaining data in the buffer to the target resource
	.destroy		resd 1
	.identity		resd 1	;dword to be used by client to identify this Writer
	.struc_size:
endstruc

struc StreamReader			;abstract
	.reader			resb Reader.struc_size
	.flags			resd 1	;
	.ops			resd 1	;number of ongoing operations that refer to .stream, must be incremented atomically WHILE the StreamReader_DEAD flag is not set before referring to .stream
	.stream			resd 1	;pointer to Stream structure, it is safe to set this to Stream_NULL once .ops has reached zero AFTER the StreamReader_DEAD flag has been set
	.struc_size:
endstruc

struc StreamWriter			;abstract
	.writer			resb Writer.struc_size
	.flags			resd 1	;
	.ops			resd 1	;number of ongoing operations that refer to .stream, must be incremented atomically WHILE the StreamWriter_DEAD flag is not set before referring to .stream
	.stream			resd 1	;pointer to Stream structure, it is safe to set this to Stream_NULL once .ops has reached zero AFTER the StreamWriter_DEAD flag has been set
	.struc_size:
endstruc

struc CommonStreamReader
	.streamReader	resb StreamReader.struc_size
	.entry			resd 1	;pointer to the enty in the list of pointers to all readers that belongs to this StreamReader, only safe if .stream is safe
	.struc_size:
endstruc

struc CommonStreamWriter
	.streamWriter	resb StreamWriter.struc_size
	.entry			resd 1	;pointer to the enty in the list of pointers to all writers that belongs to this StreamWriter, only safe if .stream is safe
	.struc_size:
endstruc

;StreamReader / StreamWriter .stream referencing procedure:
;check if .flags permits a reference to .stream
;if so, atomically increment .ops
;check again
;if everything is OK, read .stream and assume a correct value

;StreamReader / StreamWriter .stream clearing procedure:
;set DEAD flag in .flags
;wait until .ops is zero (exit wait loop as soon as a zero has been atomically read)
;set .stream to Stream_NULL

;CommonStreamWriter / CommonStreamReader removal procedure:
;reference stream (or abort if stream is dead)
;lock respective list using cp_16_lock_or_abort (abort if stream dies while attempting to lock)
;remove .entry from list
;unlock list and clear reference to stream

%include "Kernel\Stream\DumbStream.asm"

;TODO: RingBufferStream, PacketStream, RingPacketStream (where packets are allocated on a ringbuffer)
;TODO: write a PacketStream where default writes (other than writePacket) are done as in a RingPacketStream, make it the default implementation
;TODO: reset ringbuffers' head and tail to zero to improve the chance of cache hits for streams that are often empty
;TODO: StressedStream, reads don't naturally occur, each write causes a .notify (which should be disabled) followed by a .flush on the reader side,
;   ...can be used to convert writes into function calls using written data as input, without the need to copy any data to a buffer (because .flush allows it to be trashed if not read)
;TODO: CallStream, Stream object has a default function that is to be called on every write, a list of additional calls (CallReaders?), and a list of actual StreamReaders

;TODO: optimize Stream (related) funtions based on present readers and writers (e.g. don't traverse the list of readers/writers on .notify if it is known that none of them actually implement .notify)
;TODO: define functions for changing fields in ways that might require function pointers to be changed (e.g. changing .notify pointer, or .flags)
;TODO: allow notifications to be sent (.notify to be called) from a separate thread from the one that does the reading/writing to obtain better parellelism where beneficial
;	...could be done using function pointers (e.g. one for each mode: "my .notify on my thread", "my .notify on one central per-Stream thread", "my .notify on a separate thread, one per call")
;	...maybe have a per-Stream default function for this to get Readers and Writer that don't care to follow that default
;	...or leave it to the implementation, probably the best option because all those previously named features would increase complexity unnecessarily

;TODO: define a Stream_Forward function that forwards writes to one stream to another (by creating a Reader on the first Stream and a Writer on the second)
;TODO: maybe separate "Forwarders" from regular Readers, allowing writes to be immediately redirected to the next Stream if only a Forwarder and no Readers are present
;	...can also be used to completely shortcut Streams that only have a Forwarder as input and a Forwarder as output

;must be used as a placeholder for unused optional functions (e.g. .notify)
;all function pointers must be initialised to a valid function or to this address
;allows the assumption that a function is present to be made without crashing in situations where verifying this would increase average overhead
;allows the assumption that a function is not present to be verified in situations where this can be used perform certain optimisations
Stream_NULL_FUNCTION:
	ret

;TODO: create functions optimized for a single writer (should require less saving of registers and calling list functions)
;MACRO IN: writer.function, ecx? (0 = no, 1 = yes)
;FUNCTION IN: eax = Stream, ecx (if applicable)
%macro CommonStream_callFunctionRMacro 2
	push eax
	cp_16_ref eax + CommonStream.writersCP, edx, dl
	mov ebx, [eax + CommonStream.writers]
	call list_first
	cmp eax, LIST_NULL
	je .ret
	%if %2 == 1
		push ecx
	%endif
	.loop:
		push eax
		mov eax, [eax]
		%if %2 == 1
			mov ecx, [esp + 4]
		%endif
		call [eax + %1]
		pop eax
		call list_next
		cmp eax, LIST_NULL
		jne .loop
	%if %2 == 1
		add esp, 4
	%endif
	.ret:
		pop eax
		cp_16_clear eax + CommonStream.writersCP
		ret
%endmacro

;TODO: create functions optimized for a single reader (should require less saving of registers and calling list functions)
;MACRO IN: reader.function, ecx? (0 = no, 1 = yes)
;FUNCTION IN: eax = Stream, ecx (if applicable)
%macro CommonStream_callFunctionWMacro 2
	push eax
	cp_16_ref eax + CommonStream.readersCP, edx, dl
	mov ebx, [eax + CommonStream.readers]
	call list_first
	cmp eax, LIST_NULL
	je .ret
	%if %2 == 1
		push ecx
	%endif
	.loop:
		push eax
		mov eax, [eax]
		%if %2 == 1
			mov ecx, [esp + 4]
		%endif
		call [eax + %1]
		pop eax
		call list_next
		cmp eax, LIST_NULL
		jne .loop
	%if %2 == 1
		add esp, 4
	%endif
	.ret:
		pop eax
		cp_16_clear eax + CommonStream.readersCP
		ret
%endmacro

;TODO: should be uninterruptible
;MACRO IN: object.function, stream.function, stream.counter, stream.null, type.default
;sets .function on a object of the specified Stream, guarantees Stream.function is correct for other objects during and for this object after the call
;FUNCTION IN: eax = Stream, ebx = object, ecx = function
;FUNCTION OUT: eax and ebx are preserved
;NOTE: ecx must be a valid non-null function
%macro CommonStream_setFunctionMacro 5
	xchg [ebx + %1], ecx							;[ebx + object.function]
	cmp ecx, Stream_NULL_FUNCTION
	jne .valid2valid
	.null2valid:
		mov edx, 1
		lock inc dword [eax + %3]					;[eax + stream.counter]
		cmp byte [eax + %4], 0						;[eax + stream.null]
		je .skip
		.wait:										;stream.null was 1, wait untill it is 0 to prevent the new value from being overwritten
			pause
			cmp byte [eax + %4], 0					;[eax + stream.null]
			jne .wait								;TODO: this could potentially spin forever, needs good testing and perhaps a timeout
		.skip:										;at this point any code trying to set the function to null will have to test the stream.counter first
		mov edx, [eax + Stream.streamType]
		mov edx, [edx + %5]							;[edx + type.default]
		mov [eax + %2], edx							;[eax + stream.function]
	.valid2valid:
		ret
%endmacro

;TODO: should be uninterruptible
;MACRO IN: object.function, stream.function, stream.counter, stream.null
;sets .function to null on a object of the specified Stream, guarantees Stream.function is correct for other objects during and for this object after the call
;FUNCTION IN: eax = Stream, ebx = object
;FUNCTION OUT: eax and ebx are preserved
%macro CommonStream_clearFunctionMacro 4
	cmp dword [ebx + %1], Stream_NULL_FUNCTION		;[ebx + object.function]
	mov dword [ebx + %1], Stream_NULL_FUNCTION		;[ebx + object.function]
	je .null2null									;mov does not affect flags
	.valid2null:
		lock dec dword [eax + %3]					;[eax + stream.counter]
		jnz .skip
		mov dl, 1
		.wait:										;stream.null was 1, wait untill it is 0 to prevent the new value from being overwritten
			pause
			cmp byte [eax + %4], 0					;[eax + stream.null], avoid #LOCK
			jne .wait
			xchg [eax + %4], dl						;[eax + stream.null]
			and dl, dl								;can only be 1 or 0
			jnz .wait								;TODO: this could potentially spin forever, needs good testing and perhaps a timeout
		mov dword [eax + %2], Stream_NULL_FUNCTION	;[eax + stream.function]
		.skip:
	.null2null:
		ret
%endmacro

;frees all resources except for the Stream structure itself, since additional implementation specific resoucres might need to be freed afterwards
;IN: eax = CommonStream
CommonStream_destroy:
	cp_16_ref eax + CommonStream.readersCP, ebx, bl
	mov ebx, [eax + CommonStream.readers]
	push ebx
	push eax
	call list_first
	.readersLoop:											;clear all StreamReader.stream references 
		cmp eax, LIST_NULL
		je .readersDone
		push eax
		mov eax, [eax]
		lock or dword [eax + StreamReader.flags], StreamReader_DEAD
		.waitROps:
			pause											;this is essentially a spinloop, so PAUSE
			cmp dword [eax + StreamReader.ops], 0			;test without lock to limit lock usage
			jne .waitROps
			lock or dword [eax + StreamReader.ops], 0		;test with lock to be sure
			jnz .waitROps
		;from this point on no other code should dare to touch StreamReader.stream or CommonStreamReader.entry
		mov dword [eax + StreamReader.stream], Stream_NULL	;set to Stream_NULL to leave no doubt
		mov dword [eax + CommonStreamReader.entry], Stream_NULL
		call dword [eax + Reader.die]						;eax = Reader, no verification needed due to Stream_NULL_FUNCTION
		pop eax
		mov ebx, [eax]
		lock or dword [ebx + StreamReader.flags], StreamReader_REMOVED
		call list_next
		jmp .readersLoop
	.readersDone:
	pop ebx
	cp_16_clear ebx + CommonStream.readersCP
	cp_16_ref ebx + CommonStream.writersCP, eax, al			;after next loop there will be no more references to this Stream, so no cp_16_clear needed for this one
	mov ebx, [ebx + CommonStream.writers]
	push ebx
	call list_first
	.writersLoop:											;clear all StreamWriter.stream references 
		cmp eax, LIST_NULL
		je .writersDone
		push eax
		mov eax, [eax]
		lock or dword [eax + StreamWriter.flags], StreamWriter_DEAD
		.waitWOps:
			pause											;this is essentially a spinloop, so PAUSE
			cmp dword [eax + StreamWriter.ops], 0			;test without lock to limit lock usage
			jne .waitWOps
			lock or dword [eax + StreamWriter.ops], 0		;test with lock to be sure
			jnz .waitWOps
		;from this point on no other code should dare to touch StreamWriter.stream or CommonStreamWriter.entry
		mov dword [eax + StreamWriter.stream], Stream_NULL	;set to Stream_NULL to leave no doubt
		mov dword [eax + CommonStreamWriter.entry], Stream_NULL
		call dword [eax + Writer.die]						;eax = Writer, no verification needed due to Stream_NULL_FUNCTION
		pop eax
		mov ebx, [eax]
		lock or dword [ebx + StreamWriter.flags], StreamWriter_REMOVED
		call list_next
		jmp .writersLoop
	.writersDone:
	;from this point on it is considered safe to assume there are no more references to this Stream or any of its resources
	pop eax											
	call list_destroy										;free List of writers
	pop eax
	call list_destroy										;free List of readers
	ret

CommonStream_notifyR:
	CommonStream_callFunctionWMacro Reader.notify, 1

CommonStream_notifyW:
	CommonStream_callFunctionRMacro Writer.notify, 1

CommonStream_flush:
	CommonStream_callFunctionWMacro Reader.flush, 0

CommonStream_drain:
	CommonStream_callFunctionRMacro Writer.drain, 0

CommonStream_setNotifyR:
	CommonStream_setFunctionMacro Reader.notify, Stream.notifyR, CommonStream.numNotifyR, CommonStream.nullNR, CommonStreamType.notifyR

CommonStream_setNotifyW:
	CommonStream_setFunctionMacro Writer.notify, Stream.notifyW, CommonStream.numNotifyW, CommonStream.nullNW, CommonStreamType.notifyW

CommonStream_setFlush:
	CommonStream_setFunctionMacro Reader.flush, Stream.flush, CommonStream.numFlush, CommonStream.nullF, CommonStreamType.flush

CommonStream_setDrain:
	CommonStream_setFunctionMacro Writer.drain, Stream.drain, CommonStream.numDrain, CommonStream.nullD, CommonStreamType.drain

CommonStream_clearNotifyR:
	CommonStream_clearFunctionMacro Reader.notify, Stream.notifyR, CommonStream.numNotifyR, CommonStream.nullNR

CommonStream_clearNotifyW:
	CommonStream_clearFunctionMacro Writer.notify, Stream.notifyW, CommonStream.numNotifyW, CommonStream.nullNW

CommonStream_clearFlush:
	CommonStream_clearFunctionMacro Reader.flush, Stream.flush, CommonStream.numFlush, CommonStream.nullF

CommonStream_clearDrain:
	CommonStream_clearFunctionMacro Writer.drain, Stream.drain, CommonStream.numDrain, CommonStream.nullD

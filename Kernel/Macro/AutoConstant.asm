%define PPP_AUTO_CONSTANT

;Library\MM.asm
;panic codes
%define MM_PANIC_UNDEFINED	0				;undefined callback
%define MM_PANIC_EOM		1				;end of memory

;constants
%define MM_MIN_SIZE			16				;minimal size of an allocation, must be a power of two
%define MM_MIN_SPLIT_SIZE	256				;minimal size of the free block after splitting a block

;info flags, use with OR
%define MM_FREE 			1				;used to indicate a free block
%define MM_START 			2				;used to indicate the start of memory
%define MM_END 				4				;used to indicate the end of memory
;info flags, use with AND
%define MM_USED				~MM_FREE		;used to indicate a used block

;Library\List.asm
LIST_NULL equ 0xffffffff

;Kernel\Stream\Stream.asm
%define Stream_NULL				0xffffffff

;StreamReader flag definitions
%define StreamReader_DEAD		1			;indicates a dead stream, no reads should start when this flag is set, should not be cleared once set
%define StreamReader_REMOVED	2			;when set in combination with StreamReader_DEAD, indicates that the StreamReader can no longer be referenced by the Stream
%define StreamReader_MT_BLOCK	4			;StreamReaders with this bit set may block or cause significant performance penalties if .read is called by multiple threads at once

;StreamWriter flag definitions
%define StreamWriter_DEAD		1			;indicates a dead stream, no writes should start when this flag is set, should not be cleared once set
%define StreamWriter_REMOVED	2			;when set in combination with StreamWriter_DEAD, indicates that the StreamWriter can no longer be referenced by the Stream
%define StreamWriter_MT_BLOCK	4			;StreamWriters with this bit set may block or cause significant performance penalties if .write is called by multiple threads at once

;Kernel\Stream\DumbStream.asm
%define DumbStream_DEFAULT_SIZE		4096

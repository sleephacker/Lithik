struc pushad_stack
	.esi	resd 1
	.edi	resd 1
	.ebp	resd 1
	.esp	resd 1
	.ebx	resd 1
	.edx	resd 1
	.ecx	resd 1
	.eax	resd 1		;A, C, D, B...
	.struc_size:
endstruc

struc int_stack			;only valid for 'normal' interrupts: no taskswitch, 32-bits pmode, etc...
	.eip	resd 1
	.cs		resd 1
	.eflags	resd 1
	.struc_size:
endstruc

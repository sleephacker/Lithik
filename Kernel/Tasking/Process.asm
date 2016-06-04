struc Process
	.id						resd 1
	.cr3					resd 1		;virtual address space, set to Process_NULLADDR for the kernel (which is always mapped in any address space)
	.threads:							;ThreadPool structure
endstruc

;adresses
%define Storage_NULL		0xffffffff
%define Storage_NOT_LOADED	0xfffffffe

;return codes, (low word reserved for device specific codes)
%define Storage_SUCCES		0x00000000
%define Storage_ERROR		0x00010000

;device types
%define Storage_UNKNOWN_DEV	0
%define Storage_FDC			1

;filesystem types
%define Storage_NO_FS		0
%define Storage_FAT12		1
%define Storage_FAT16		2
%define Storage_FAT32		3

struc StorageDevice
	.devType		resw 1		;device type
	.pointer		resd 1		;pointer to device specific structure
	.readSector		resd 1		;IN: eax = LBA sector, ebx = buffer, edx = pointer, OUT: eax = return code
	.readSectors	resd 1		;IN: eax = LBA sector, ebx = buffer, ecx = number of sectors to read, edx = pointer, OUT: eax = return code
	.writeSector	resd 1		;IN: eax = LBA sector, ebx = buffer, edx = pointer, OUT: eax = return code
	.writeSectors	resd 1		;IN: eax = LBA sector, ebx = buffer, ecx = number of sectors to write, edx = pointer, OUT: eax = return code
	.struc_size:
endstruc

struc StorageVolume
	.letter			resb 1		;Windows drive letter
	.device			resd 1		;pointer to the StorageDevice structure this volume belongs to
	.size			resq 1		;size of this volume in bytes
	.baseSector		resd 1		;base sector of this volume on the device
	.sectors		resd 1		;number of sectors on the volume
	.sectorSize		resd 1		;sector size in bytes
	.fsType			resw 1		;filesystem type
	.fsPointer		resd 1		;pointer to filesystem specific structure
	.name			resd 1		;pointer to the volume's name/label string (0 terminated)
	.struc_size:
endstruc

Storage:
	.devices dd Storage_NULL
	.volumes dd Storage_NULL

Storage_Init:
	call list_new
	mov [Storage.devices], eax
	call list_new
	mov [Storage.volumes], eax
	ret

;creates a new StorageDevice
;OUT: eax = StorageDevice
Storage_NewDevice:
	mov eax, StorageDevice.struc_size
	mov ebx, [Storage.devices]
	call list_begin_add
	mov [eax + StorageDevice.devType], word Storage_UNKNOWN_DEV
	mov [eax + StorageDevice.pointer], dword Storage_NULL
	mov [eax + StorageDevice.readSector], dword Storage_NULL
	mov [eax + StorageDevice.readSectors], dword Storage_NULL
	mov [eax + StorageDevice.writeSector], dword Storage_NULL
	mov [eax + StorageDevice.writeSectors], dword Storage_NULL
	call list_finish_add
	ret

;creates a new StorageVolume
;OUT: eax = StorageVolume
Storage_NewVolume:
	mov eax, StorageVolume.struc_size
	mov ebx, [Storage.volumes]
	call list_begin_add
	mov [eax + StorageVolume.letter], byte 0
	mov [eax + StorageVolume.device], dword Storage_NULL
	mov [eax + StorageVolume.size], dword 0
	mov [eax + StorageVolume.size + 4], dword 0
	mov [eax + StorageVolume.baseSector], dword 0
	mov [eax + StorageVolume.sectors], dword 0
	mov [eax + StorageVolume.sectorSize], dword 0
	mov [eax + StorageVolume.fsType], word Storage_NO_FS
	mov [eax + StorageVolume.fsPointer], dword Storage_NULL
	mov [eax + StorageVolume.name], dword Storage_NULL
	call list_finish_add
	ret

;IN: dl = drive letter
;OUT: eax = volume or Storage_NULL
Storage_GetVolumeByLetter:
	mov ebx, [Storage.volumes]
	call list_first
	.loop:
		cmp [eax + StorageVolume.letter], dl
		je .ret
		call list_next
		cmp eax, LIST_NULL
		jne .loop
		%if Storage_NULL != LIST_NULL
		mov eax, Storage_NULL
		%endif
	.ret:ret

%include "Kernel\Storage\FileSystem.asm"
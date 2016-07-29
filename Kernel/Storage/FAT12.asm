%define FAT12_NULL_CLUSTER	0xffff

struc FAT12_FS
	.fileSystem			resb FileSystem.struc_size
	.sectorsPerCluster	resd 1
	.clusters			resd 1
	.FATSector			resd 1	;first sector of the FAT
	.FATSize			resd 1	;size of the FAT in bytes
	.FAT				resd 1	;the FAT loaded in memory
	.rootDirSector		resd 1	;first sector of the root directory
	.rootDirSize		resd 1	;size of the root directory in bytes
	.struc_size:
endstruc

struc FAT12_Directory
	.directory			resb Directory.struc_size
	.startCluster		resw 1
	.attributes			resb 1
	.size				resd 1	;size of the directory in bytes
	.physicalSize		resd 1	;physical size of the directory on disk in bytes
	.dirData			resd 1	;directory data loaded in memory
	.struc_size:
endstruc

struc FAT12_File
	.file				resb File.struc_size
	.startCluster		resw 1
	.attributes			resb 1
	.struc_size:
endstruc

;IN: eax = volume, ebx = VBR, ecx = clusters
FAT12_InitFS:
	push eax
	push ebx
	push ecx
	mov eax, FAT12_FS.struc_size
	call mm_allocate
	pop ecx
	mov esi, [esp]
	mov edi, [esp + 4]
	mov [eax  + FAT12_FS.clusters], ecx
	xor ecx, ecx
	mov cl, [esi + FAT1x_VBR.sectorsPerCluster]
	mov [eax + FAT12_FS.sectorsPerCluster], ecx
	mov cx, [esi + FAT1x_VBR.reservedSectors]
	mov [eax + FAT12_FS.FATSector], ecx				;reserved sectors = LBA of first FAT
	mov cx, [esi + FAT1x_VBR.sectorsPerFAT]
	push ecx
	xchg ecx, eax
	xor ebx, ebx
	mov bl, [esi + FAT1x_VBR.FATs]
	mul ebx
	add eax, [ecx + FAT12_FS.FATSector]
	mov [ecx + FAT12_FS.rootDirSector], eax			;reserved sectors + sectors occupied by FATs = LBA of first root directory sector
	pop eax
	mov ebx, [edi + StorageVolume.sectorSize]
	mul ebx											;FAT sectors * sector size = FAT size
	mov [ecx + FAT12_FS.FATSize], eax
	xor eax, eax
	mov ax, [esi + FAT1x_VBR.rootEntries]
	shl eax, 5										;entries * 32 = size
	mov [ecx + FAT12_FS.rootDirSize], eax
	push ecx
	;[esp + 8] = volume
	;[esp + 4] = VBR
	;[esp + 0] = FS
	mov eax, [ecx + FAT12_FS.FATSize]
	call mm_allocate
	mov ebx, eax
	mov eax, [esp]
	mov eax, [eax + FAT12_FS.FATSector]
	mov esi, [esp + 8]
	add eax, [esi + StorageVolume.baseSector]
	mov esi, [esi + StorageVolume.device]
	mov edx, [esp + 4]
	xor ecx, ecx
	mov cx, [edx + FAT1x_VBR.sectorsPerFAT]
	mov edx, [esi + StorageDevice.pointer]
	push ebx
	call [esi + StorageDevice.readSectors]
	mov eax, [esp + 4]
	pop dword [eax + FAT12_FS.FAT]
	mov eax, FAT12_Directory.struc_size
	call mm_allocate
	mov [eax + Directory.references], dword 1
	mov ebx, [esp]
	mov [ebx + FileSystem.rootDir], eax
	mov [eax + Directory.parent], dword Storage_NULL
	mov [eax + Directory.name], dword Storage_NULL
	mov [eax + Directory.subDirectories], dword Storage_NOT_LOADED
	mov [eax + Directory.files], dword Storage_NOT_LOADED
	mov [eax + FAT12_Directory.attributes], byte FAT_ATTR_DIRECTORY
	mov [eax + FAT12_Directory.startCluster], word FAT12_NULL_CLUSTER
	mov ecx, [ebx + FAT12_FS.rootDirSize]
	mov [eax + FAT12_Directory.size], ecx
	mov [eax + FAT12_Directory.physicalSize], ecx
	push eax
	;[esp + 12] = volume
	;[esp + 8 ] = VBR
	;[esp + 4 ] = FS
	;[esp + 0 ] = root directory
	mov eax, ecx
	call mm_allocate
	mov ebx, [esp]
	mov [ebx + FAT12_Directory.dirData], eax
	mov ebx, eax
	mov esi, [esp + 4]
	mov ecx, [esi + FAT12_FS.rootDirSector]
	mov eax, [esi + FAT12_FS.rootDirSize]
	mov esi, [esp + 12]
	mov edi, [esi + StorageVolume.sectorSize]
	xor edx, edx
	div edi
	xchg eax, ecx
	mov esi, [esi + StorageVolume.device]
	mov edx, [esi + StorageDevice.pointer]
	call [esi + StorageDevice.readSectors]
	mov eax, [esp]
	mov edx, [esp + 4]
	call FAT12_LoadSubDirectories
	add esp, 16
	ret

;TODO: lock
;IN: eax = directory, edx = filesystem
FAT12_LoadSubDirectories:
	cmp [eax + Directory.subDirectories], dword Storage_NOT_LOADED
	jne .ret
	cmp [eax + FAT12_Directory.dirData], dword Storage_NOT_LOADED
	jne .loadDirs
	;TODO: load directory data
	jmp $
	.loadDirs:
	push edx
	push eax
	call list_new
	mov ebx, eax
	mov esi, [esp]
	mov ecx, [esi + FAT12_Directory.size]
	shr ecx, 5														;size / 32 = number of entries
	mov esi, [esi + FAT12_Directory.dirData]
	.loop0:
		cmp [esi], byte 0x00
		je .done
		cmp [esi], byte 0xe5
		je .next
		cmp [esi], byte 0x05
		je .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_DIRECTORY
		jz .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_LFN			;TODO: support long file names
		jnz .next
		mov eax, FAT12_Directory.struc_size
		push esi
		call list_add
		pop esi
		mov [eax + Directory.references], dword 0
		mov [eax + Directory.subDirectories], dword Storage_NOT_LOADED
		mov [eax + Directory.files], dword Storage_NOT_LOADED
		mov edx, [esp]
		mov [eax + Directory.parent], edx
		push eax
		push ebx
		push ecx
		call FAT_GetFilename
		pushad
		mov esi, eax
		call boot_print_default
		popad
		mov edx, eax
		pop ecx
		pop ebx
		pop eax
		mov [eax + Directory.name], edx
		mov dx, [esi + FAT_DirEntry.startClusterLow]
		mov [eax + FAT12_Directory.startCluster], dx
		push eax
		push ebx
		push ecx
		mov ax, dx
		mov ebx, [esp + 16]
		call FAT12_GetPhysicalSize
		mov edx, eax
		pop ecx
		pop ebx
		pop eax
		mov [eax + FAT12_Directory.physicalSize], edx
		mov dl, [esi + FAT_DirEntry.attributes]
		mov [eax + FAT12_Directory.attributes], dl
		mov edx, [esi + FAT_DirEntry.size]
		mov [eax + FAT12_Directory.size], edx
	.next:
		add esi, FAT_DirEntry.struc_size
		loop .loop1
	.done:
		add esp, 8
	.ret:ret
	.loop1:jmp .loop0

;IN: ax = start cluster, ebx = FAT12_FS
;OUT: eax = physical size, esi = unmodified
FAT12_GetPhysicalSize:
	xor edx, edx
	mov dx, ax
	mov ecx, [ebx + FileSystem.volume]
	mov ecx, [ecx + StorageVolume.sectorSize]
	mov ebx, [ebx + FAT12_FS.FAT]
	mov eax, ecx
	.loop:
		mov edi, edx
		shr edi, 1
		add edi, edx
		test dl, 1
		jz .odd
		mov dx, [ebx + edi]
		shr dx, 4
		jmp .count
	.odd:
		mov dx, [ebx + edi]
		and dx, 0x0fff
	.count:
		cmp dx, 0x0ff8
		jae .done
		add eax, ecx
		jmp .loop
	.done:
		ret

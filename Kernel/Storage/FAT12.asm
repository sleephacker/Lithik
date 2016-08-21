%define FAT12_NULL_CLUSTER	0	;used for zero-length files/directories, root directory, etc.

struc FAT12_FS
	.fileSystem			resb FileSystem.struc_size
	.sectorsPerCluster	resd 1
	.clusters			resd 1
	.FATSector			resd 1	;first sector of the FAT
	.FATSize			resd 1	;size of the FAT in bytes
	.FAT				resd 1	;the FAT loaded in memory
	.rootDirSector		resd 1	;first sector of the root directory
	.rootDirSize		resd 1	;size of the root directory in bytes
	.dataSector			resd 1	;first sector of the data area
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
	mov ebx, [esp + 8]
	mov [eax + FileSystem.volume], ebx
	mov [eax + FileSystem.loadFile], dword Storage_NULL;TODO
	mov [eax + FileSystem.loadFiles], dword FAT12_LoadFiles
	mov [eax + FileSystem.loadSubDirs], dword FAT12_LoadSubDirectories
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
	mul dword [edi + StorageVolume.sectorSize]		;FAT sectors * sector size = FAT size
	mov [ecx + FAT12_FS.FATSize], eax
	xor eax, eax
	mov ax, [esi + FAT1x_VBR.rootEntries]
	shl eax, 5										;entries * 32 = size
	mov [ecx + FAT12_FS.rootDirSize], eax
	xor edx, edx
	div dword [edi + StorageVolume.sectorSize]
	add eax, [ecx + FAT12_FS.rootDirSector]
	mov [ecx + FAT12_FS.dataSector], eax
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
	mov edx, [esp + 4]
	call FAT12_LoadFiles
	mov eax, [esp + 12]
	mov ebx, [esp + 4]
	mov [eax + StorageVolume.fsPointer], ebx
	add esp, 16
	ret

;IN: eax = directory, edx = filesystem
;OUT: eax = directory, ebx = return code
FAT12_LoadSubDirectories_spin:
	pause
	test [eax + Directory.references], dword 1 << 31
	jnz FAT12_LoadSubDirectories_spin
FAT12_LoadSubDirectories:
	lock bts dword [eax + Directory.references], 31
	jc FAT12_LoadSubDirectories_spin
	cmp [eax + Directory.subDirectories], dword Storage_NOT_LOADED
	jne .succes
	cmp [eax + FAT12_Directory.dirData], dword Storage_NOT_LOADED
	jne .loadDirs
	push edx
	push eax
	mov eax, [eax + FAT12_Directory.physicalSize]
	call mm_allocate
	push eax
	mov ecx, eax
	mov eax, [esp + 4]
	mov ax, [eax + FAT12_Directory.startCluster]
	mov ebx, [esp + 8]
	call FAT12_LoadChain
	cmp eax, Storage_SUCCES
	jne .loadError
	mov eax, [esp + 4]
	pop dword [eax + FAT12_Directory.dirData]
	jmp .dataLoaded
	.loadError:
	mov ebx, eax
	pop eax
	add esp, 4
	lock btr dword [eax + Directory.references], 31						;release lock
	ret																	;return error
	.loadDirs:
	push edx
	push eax
	.dataLoaded:
	call list_new
	mov ebx, eax
	mov esi, [esp]
	mov ecx, [esi + FAT12_Directory.size]
	shr ecx, 5															;size / 32 = number of entries
	mov esi, [esi + FAT12_Directory.dirData]
	.loop0:
		cmp [esi], byte 0x00
		je .done
		cmp [esi], byte 0xe5
		je .next
		cmp [esi], byte 0x05
		je .next
		cmp [esi], byte "."												;if it starts with a dot it's either a reference to the current/parent directory or an illegal filename, so skip it.
		je .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_DIRECTORY
		jz .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_VOLUME_ID
		jnz .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_LFN			;TODO: support long file names
		jnz .next
		mov eax, FAT12_Directory.struc_size
		push esi
		push ecx
		call list_add
		pop ecx
		pop esi
		mov [eax + Directory.references], dword 0
		mov [eax + Directory.subDirectories], dword Storage_NOT_LOADED
		mov [eax + Directory.files], dword Storage_NOT_LOADED
		mov [eax + FAT12_Directory.dirData], dword Storage_NOT_LOADED
		mov edx, [esp]
		mov [eax + Directory.parent], edx
		push eax
		push ebx
		push ecx
		call FAT_GetFilename
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
		pop eax
		mov [eax + Directory.subDirectories], ebx
		add esp, 4
	.succes:
		lock btr dword [eax + Directory.references], 31					;release lock
		mov ebx, Storage_SUCCES
		ret
	.loop1:jmp .loop0

;IN: eax = directory, edx = filesystem
;OUT: eax = directory, ebx = return code
FAT12_LoadFiles_spin:
	pause
	test [eax + Directory.references], dword 1 << 31
	jnz FAT12_LoadSubDirectories_spin
FAT12_LoadFiles:
	lock bts dword [eax + Directory.references], 31
	jc FAT12_LoadSubDirectories_spin
	cmp [eax + Directory.files], dword Storage_NOT_LOADED
	jne .succes
	cmp [eax + FAT12_Directory.dirData], dword Storage_NOT_LOADED
	jne .loadFiles
	push edx
	push eax
	mov eax, [eax + FAT12_Directory.physicalSize]
	call mm_allocate
	push eax
	mov ecx, eax
	mov eax, [esp + 4]
	mov ax, [eax + FAT12_Directory.startCluster]
	mov ebx, [esp + 8]
	call FAT12_LoadChain
	cmp eax, Storage_SUCCES
	jne .loadError
	mov eax, [esp + 4]
	pop dword [eax + FAT12_Directory.dirData]
	jmp .dataLoaded
	.loadError:
	mov ebx, eax
	pop eax
	add esp, 4
	lock btr dword [eax + Directory.references], 31						;release lock
	ret																	;return error
	.loadFiles:
	push edx
	push eax
	.dataLoaded:
	call list_new
	mov ebx, eax
	mov esi, [esp]
	mov ecx, [esi + FAT12_Directory.size]
	shr ecx, 5															;size / 32 = number of entries
	mov esi, [esi + FAT12_Directory.dirData]
	.loop0:
		cmp [esi], byte 0x00
		je .done
		cmp [esi], byte 0xe5
		je .next
		cmp [esi], byte 0x05
		je .next
		cmp [esi], byte "."												;if it starts with a dot it's either a reference to the current/parent directory or an illegal filename, so skip it.
		je .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_DIRECTORY
		jnz .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_VOLUME_ID
		jnz .next
		test [esi + FAT_DirEntry.attributes], byte FAT_ATTR_LFN			;TODO: support long file names
		jnz .next
		mov eax, FAT12_File.struc_size
		push esi
		push ecx
		call list_add
		pop ecx
		pop esi
		mov edx, [esp]
		mov [eax + File.parent], edx
		push eax
		push ebx
		push ecx
		call FAT_GetFilename
		mov edx, eax
		pop ecx
		pop ebx
		pop eax
		mov [eax + File.name], edx
		mov dx, [esi + FAT_DirEntry.startClusterLow]
		mov [eax + FAT12_File.startCluster], dx
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
		mov [eax + File.physicalSize], edx
		mov dl, [esi + FAT_DirEntry.attributes]
		mov [eax + FAT12_File.attributes], dl
		mov edx, [esi + FAT_DirEntry.size]
		mov [eax + File.size], edx
	.next:
		add esi, FAT_DirEntry.struc_size
		loop .loop1
	.done:
		pop eax
		mov [eax + Directory.files], ebx
		add esp, 4
	.succes:
		lock btr dword [eax + Directory.references], 31					;release lock
		mov ebx, Storage_SUCCES
		ret
	.loop1:jmp .loop0

;IN: ax = start cluster, ebx = FAT12_FS
;OUT: eax = physical size, esi = unmodified
FAT12_GetPhysicalSize:
	cmp ax, FAT12_NULL_CLUSTER
	jne .ok
	mov eax, 0
	ret
	.ok:
	xor edx, edx
	mov dx, ax
	mov ecx, [ebx + FileSystem.volume]
	mov ecx, [ecx + StorageVolume.sectorSize]
	mov eax, ecx
	mov edi, edx
	mul dword [ebx + FAT12_FS.sectorsPerCluster]
	mov edx, edi
	mov ecx, eax
	mov ebx, [ebx + FAT12_FS.FAT]
	.loop:
		mov edi, edx
		shr edi, 1
		add edi, edx
		test dl, 1
		jz .even
		mov dx, [ebx + edi]
		shr dx, 4
		jmp .count
	.even:
		mov dx, [ebx + edi]
		and dx, 0x0fff
	.count:
		cmp dx, 0x0ff8
		jae .done
		add eax, ecx
		jmp .loop
	.done:
		ret

;IN: ax = start cluster, ebx = FAT12_FS, ecx = buffer
;OUT: eax = return code
FAT12_LoadChain:
	cmp ax, FAT12_NULL_CLUSTER
	jne .ok
	mov eax, Storage_ERROR
	ret
	.ok:
	push ecx
	push ebx
	xor edx, edx
	mov dx, ax
	mov ecx, [ebx + FileSystem.volume]
	push ecx
	mov ecx, [ecx + StorageVolume.sectorSize]
	mov eax, ecx
	mov edi, edx
	mul dword [ebx + FAT12_FS.sectorsPerCluster]
	mov edx, edi
	mov ecx, eax
	xor eax, eax
	mov ebx, [ebx + FAT12_FS.FAT]
	;[esp + 8] = buffer
	;[esp + 4] = FAT12_FS
	;[esp + 0] = volume
	.loop:
		push eax
		push ebx
		push ecx
		push edx
		push edi
		mov ebx, [esp + 8 + 20]
		add ebx, eax
		mov eax, edx
		sub eax, 2						;data sector 0 = cluster 2
		mov ecx, [esp + 4 + 20]
		mul dword [ecx + FAT12_FS.sectorsPerCluster]
		add eax, [ecx + FAT12_FS.dataSector]
		mov ecx, [ecx + FAT12_FS.sectorsPerCluster]
		mov edi, [esp + 0 + 20]
		add eax, [edi + StorageVolume.baseSector]
		mov esi, [edi + StorageVolume.device]
		mov edx, [esi + StorageDevice.pointer]
		call [esi + StorageDevice.readSectors]
		cmp eax, Storage_SUCCES
		jne .error
		pop edi
		pop edx
		pop ecx
		pop ebx
		pop eax
		mov edi, edx
		shr edi, 1
		add edi, edx
		test dl, 1
		jz .even
		mov dx, [ebx + edi]
		shr dx, 4
		jmp .next
	.even:
		mov dx, [ebx + edi]
		and dx, 0x0fff
	.next:
		cmp dx, 0x0ff8
		jae .done
		add eax, ecx
		jmp .loop
	.done:
		add esp, 12
		ret
	.error:
		add esp, 32
		ret


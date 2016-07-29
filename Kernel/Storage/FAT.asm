%define FAT_ATTR_READ_ONLY	01h
%define FAT_ATTR_HIDDEN		02h
%define FAT_ATTR_SYSTEM		04h
%define FAT_ATTR_VOLUME_ID	08h
%define FAT_ATTR_DIRECTORY	10h
%define FAT_ATTR_ARCHIVE	20h
%define FAT_ATTR_LFN		0fh

struc FAT_DirEntry
	.name				resb 8	;name padded with spaces
	.extension			resb 3	;extension padded with spaces
	.attributes			resb 1
	.reservedForNT		resb 1
	.creation10ths		resb 1	;creation time in tenths of a second
	.creationTime		resb 2
	.creationDate		resb 2
	.accessDate			resb 2
	.startClusterHigh	resw 1	;always zero for FAT12/16
	.modificationTime	resb 2
	.modificationDate	resb 2
	.startClusterLow	resw 1
	.size				resd 1	;size in bytes
	.struc_size:
endstruc

struc FAT_VBR			;applies to all FAT types
	.BPB:
	.jmp				resb 3
	.oem				resb 8
	.bytesPerSector		resw 1
	.sectorsPerCluster	resb 1
	.reservedSectors	resw 1
	.FATs				resb 1
	.rootEntries		resw 1
	.sectors			resw 1
	.mediaType			resb 1
	.sectorsPerFAT		resw 1
	.sectorsPerTrack	resw 1
	.sides				resw 1
	.hiddenSectors		resd 1
	.sectorsLarge		resd 1
	.EBPB:
endstruc

struc FAT1x_VBR			;applies to FAT12 and FAT16
	.BPB:
	.jmp				resb 3
	.oem				resb 8
	.bytesPerSector		resw 1
	.sectorsPerCluster	resb 1
	.reservedSectors	resw 1
	.FATs				resb 1
	.rootEntries		resw 1
	.sectors			resw 1
	.mediaType			resb 1
	.sectorsPerFAT		resw 1
	.sectorsPerTrack	resw 1
	.sides				resw 1
	.hiddenSectors		resd 1
	.sectorsLarge		resd 1
	.EBPB:
	.drive				resb 1
	.flagsForNT			resb 1
	.signature			resb 1
	.volumeID			resd 1
	.volumeLabel		resb 11
	.filesystem			resb 8
	.bootcode			resb 448
	.magicWord			resw 1
endstruc

;IN: eax = StorageVolume
;OUT: eax = Storage return code
FAT_InitVolume:
	push eax
	mov eax, [eax + StorageVolume.sectorSize]
	call mm_allocate
	xchg bx, bx
	push eax
	mov ebx, eax
	mov esi, [esp + 4]
	mov eax, [esi + StorageVolume.baseSector]
	mov esi, [esi + StorageVolume.device]
	mov edx, [esi + StorageDevice.pointer]
	call [esi + StorageDevice.readSector]
	cmp eax, Storage_SUCCES
	jne .error
	pop ebx
	cmp [ebx + FAT_VBR.sectors], word 0
	je .large
	xor ecx, ecx
	mov cx, [ebx + FAT_VBR.sectors]
	jmp .fat_type
	.large:
	mov ecx, [ebx + FAT_VBR.sectorsLarge]
	.fat_type:
	xor eax, eax
	mov ax, [ebx + FAT_VBR.reservedSectors]
	sub ecx, eax
	mov ax, [ebx + FAT_VBR.rootEntries]
	shr ax, 4										;32 byte entries / 16 = 512 byte sectors
	sub ecx, eax
	mov al, [ebx + FAT_VBR.FATs]
	xor ah, ah
	mul word [ebx + FAT_VBR.sectorsPerFAT]
	shl edx, 16
	or eax, edx
	sub ecx, eax									;sectors - reservedSectors - rootEntries / 16 - FATs * sectorsPerFAT = total data sectors
	mov eax, ecx
	xor edx, edx
	xor ecx, ecx
	mov cl, [ebx + FAT_VBR.sectorsPerCluster]
	jcxz .error0
	div ecx											;total data sectors / sectors per cluster = number of clusters
	cmp ecx, 4085
	jb .fat12
	cmp ecx, 65525
	jb .fat16
	.fat32:
		pop eax
		mov [eax + StorageVolume.fsType], word Storage_FAT32
		mov eax, ebx 
		call mm_free
		;TODO
		mov eax, Storage_SUCCES
		ret
	.fat16:
		mov eax, [esp]
		mov [eax + StorageVolume.fsType], word Storage_FAT16
		call .fat1x_label
		pop eax
		mov [eax + StorageVolume.name], edx
		;TODO
		mov eax, ebx 
		call mm_free
		mov eax, Storage_SUCCES
		ret
	.fat12:
		push eax
		mov eax, [esp + 4]
		mov [eax + StorageVolume.fsType], word Storage_FAT12
		call .fat1x_label
		pop ecx
		pop eax
		mov [eax + StorageVolume.name], edx
		push ebx
		call FAT12_InitFS
		pop eax
		call mm_free
		mov eax, Storage_SUCCES
		ret
	.error:
		pop eax
		call mm_free
		add esp, 4
		mov eax, Storage_ERROR
		ret
	.error0:
		add esp, 4
		mov eax, ebx
		call mm_free
		mov eax, Storage_ERROR
		ret
	.fat1x_label:
		push ebx
		mov eax, 12
		call mm_allocate
		mov [eax + 11], byte 0			;end of string
		pop ebx
		mov edx, eax
		mov edi, eax
		mov esi, ebx
		add esi, FAT1x_VBR.volumeLabel
		mov ecx, 11
		.loop:
			lodsb
			stosb
			cmp al, " "
			loopne .loop
			jcxz .ret
			mov [edi - 1], byte 0		;end of string
	.ret:ret

;IN: esi = FAT_DirEntry
;OUT: eax = pointer to 0 terminated name string, esi = FAT_DirEntry
FAT_GetFilename:
	push esi
	mov eax, 13
	call mm_allocate
	mov [eax + 12], byte 0
	push eax
	mov esi, [esp + 4]
	mov edi, eax
	mov ecx, 8
	.loopname:
		lodsb
		stosb
		cmp al, " "
		loopne .loopname
	jcxz .full8
	dec edi
	.full8:
	mov esi, [esp + 4]
	add esi, FAT_DirEntry.extension
	cmp [esi], byte " "
	je .done
	mov [edi], byte "."
	inc edi
	mov ecx, 3
	.loopext:
		lodsb
		stosb
		cmp al, " "
		loopne .loopext
	.done:
	jcxz .full3
	dec edi
	.full3:
	mov [edi], byte 0
	pop eax
	pop esi
	ret

struc FileSystem
	.volume				resd 1	;the volume this filesystem is on
	.loadFile			resd 1	;IN: eax = file, ebx = buffer, edx = FileSystem
	.loadFiles			resd 1	;IN: eax = directory, edx = FileSystem
	.loadSubDirs		resd 1	;IN: eax = directory, edx = FileSystem
	.rootDir			resd 1	;the root directory
	.struc_size:
endstruc

struc Directory
	.references			resd 1	;number of references to this directory, bit 31 is a lock for adding/removing/referencing any subdirectories/files.
	.subDirectories		resd 1	;a list of subdirectories
	.parent				resd 1	;parent directory or Storage_NULL if this is a root directory
	.files				resd 1	;a list of files in this directory
	.name				resd 1	;pointer to the name of this directory (0 terminated string), Storage_NULL if this is a root directory
	.struc_size:
endstruc

struc File
	.references			resd 1	;number of references to this file
	.parent				resd 1	;parent directory
	.size				resd 1	;size of this file in bytes
	.physicalSize		resd 1	;physical size of this file in bytes
	.name				resd 1	;pointer to the name of this file (0 terminated string)
	.struc_size:
endstruc

%include "Kernel\Storage\FAT.asm"
%include "Kernel\Storage\FAT12.asm"

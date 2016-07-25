struc FAT12_FS
	.fileSystem			resb FileSystem.struc_size
	.sectorsPerCluster	resd 1
	.clusters			resd 1
	.FATSector			resd 1	;first sector of the FAT
	.FATSize			resd 1	;size of the FAT in bytes
	.FAT				resd 1	;the FAT loaded in memory
	.rootDirSector		resd 1	;first sector of the root directory
	.rootDirTSize		resd 1	;size of the root directory in bytes
	.rootDir			resd 1	;the root directory structure
	.struc_size:
endstruc

struc FAT12_Directory
	.directory			resb Directory.struc_size
	.startCluster		resw 1
	.attributes			resb 1
	.size				resd 1	;size of the directory in bytes
	.physicalSize		resd 1	;physical size of the directory on disk in bytes
	.pointer			resd 1	;directory data loaded in memory
	.struc_size:
endstruc

struc FAT12_File
	.file				resb File.struc_size
	.startCluster		resw 1
	.attributes			resb 1
	.struc_size:
endstruc

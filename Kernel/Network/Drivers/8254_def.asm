struc i8254_RDESC
	.buffer		resq 1
	.length		resw 1
	.checksum	resw 1
	.status		resb 1
	.errors		resb 1
	.special	resw 1
endstruc

struc i8254_TDESC			;Legacy Mode Descriptor
	.buffer		resq 1
	.length		resw 1
	.CSO		resb 1		;Checksum Offset
	.CMD		resb 1		;Command Field
	.STA		resb 1		;Status Field. Note: high nibble of this byte is reserved and should be written with 0b for future compatibility
	.CSS		resb 1		;Checksum Start
	.special	resw 1
endstruc

%define i8254_CTRL			00000h		;Device Control
%define i8254_STATUS		00008h		;Device Status
%define i8254_EECD			00010h		;EEPROM/Flash Control/Data
%define i8254_EERD			00014h		;EEPROM Read (not applicable to the 82544GC/EI)
%define i8254_FLA			0001ch		;Flash Access (applicable to the 82541xx and 82547GI/EI only)
%define i8254_CTRL_EXT		00018h		;Extended Device Control
%define i8254_MDIC			00020h		;MDI Control
%define i8254_FCAL			00028h		;Flow Control Address Low
%define i8254_FCAH			0002ch		;Flow Control Address High
%define i8254_FCT			00030h		;Flow Control Type
%define i8254_VET			00038h		;VLAN EtherType
%define i8254_FCTTV			00170h		;Flow Control Transmit Timer Value
%define i8254_TXCW			00178h		;Transmit Configuration Word (not applicable to the 82540EP/EM, 82541xx and 82547GI/EI)
%define i8254_RXCW			00180h		;Receive Configuration Word (not applicable to the 82540EP/EM, 82541xx and 82547GI/EI)
%define i8254_LEDCTL		00e00h		;LED Control (not applicable to the 82544GC/EI)
%define i8254_PBA			01000h		;Packet Buffer Allocation
%define i8254_ICR			000c0h		;Interrupt Cause Read
%define i8254_ITR			000c4h		;Interrupt Throttling
%define i8254_ICS			000c8h		;Interrupt Cause Set
%define i8254_IMS			000d0h		;Interrupt Mask Set/Read
%define i8254_IMC			000d8h		;Interrupt Mask Clear
%define i8254_RCTL			00100h		;Receive Control
%define i8254_FCRTL			02160h		;Flow Control Receive Threshold Low
%define i8254_FCRTL			02168h		;Flow Control Receive Threshold High
%define i8254_RDBAL			02800h		;Receive Descriptor Base Low
%define i8254_RDBAH			02804h		;Receive Descriptor Base High
%define i8254_RDLEN			02808h		;Receive Descriptor Length
%define i8254_RDH			02810h		;Receive Descriptor Head
%define i8254_RDT			02818h		;Receive Descriptor Tail
%define i8254_RDTR			02820h		;Receive Delay Timer
%define i8254_RADV			0282ch		;Receive Interrupt Absolute Delay Timer (not applicable to the 82544GC/EI)
%define i8254_RSRPD			02c00h		;Receive Small Packet Detect Interrupt (not applicable to the 82544GC/EI)
%define i8254_TCTL			00400h		;Transmit Control
%define i8254_TIPG			00410h		;Transmit IPG
%define i8254_AIFS			00458h		;Adaptive IFS Throttle - AIT
%define i8254_TDBAL			03800h		;Transmit Descriptor Base Low
%define i8254_TDBAH			03804h		;Transmit Descriptor Base High
%define i8254_TDLEN			03808h		;Transmit Descriptor Length
%define i8254_TDH			03810h		;Transmit Descriptor Head
%define i8254_TDT			03818h		;Transmit Descriptor Tail
%define i8254_TIDV			03820h		;Transmit Interrupt Delay Value
%define i8254_TXDMAC		03000h		;TX DMA Control (applicable to the 82544GC/EI only)
%define i8254_TXDCTL		03828h		;Transmit Descriptor Control
%define i8254_TADV			0282Ch		;Transmit Absolute Interrupt Delay Timer (not applicable to the 82544GC/EI)
%define i8254_TSPMT			03830h		;TCP Segmentation Pad and Threshold
%define i8254_RXDCTL		02828h		;Receive Descriptor Control
%define i8254_RXCSUM		05000h		;Receive Checksum Control

%define i8254_MTA(n)	05200h + 4 * n	;Multicast Table Array (n)
%define i8254_RAL(n)	05400h + 8 * n	;Receive Adrress Low (n)
%define i8254_RAH(n)	05404h + 8 * n	;Receive Adrress High (n)
%define i8254_VFTA(n)	05600h + 4 * n	;VLAN Filter Table Array (n) Not applicable to the 82541ER

%define i8254_WUC			05800h		;Wakeup Control
%define i8254_WUFC			05808h		;Wakeup Filter Control
%define i8254_WUS			05810h		;Wakeup Status
%define i8254_IPAV			05838h		;IP Address Valid

%define i8254_IP4AT(n)	05840h + 4 * n	;IPv4 Address Table. IP Address Table (82544GC/EI)

%define i8254_IP6AT			05880h		;IPv6 Address Table (not applicable to the 82544GC/EI)
%define i8254_WUPL			05900h		;Wakeup Packet Length
%define i8254_WUPM			05A00h		;Wakeup Packet Memory (128 bytes)

%define i8254_FFLT(n)	05F00h + 4 * n	;Flexible Filter Length Table
%define i8254_FFMT(n)	09000h + 4 * n	;Flexible Filter Mask Table
%define i8254_FFVT(n)	09800h + 4 * n	;Flexible Filter Value Table
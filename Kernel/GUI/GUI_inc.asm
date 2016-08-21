%define GUI_NULL			0xffffffff
%define GUI_NEWLINE			0ah

;GUI events
;draws the component
;IN: ecx = Yoffset << 16 | Xoffset
%define GE_Draw				0

struc GUI_Component
	.position:							;Y << 16 | X
	.X 						resw 1
	.Y 						resw 1
	.size:								;H << 16 | W
	.W						resw 1
	.H						resw 1
	.parent					resd 1		;parent component
	.event 					resd 1		;all-purpose event handler, IN: eax = event, ebx = GUI_Component, other registers = undefined
	.struc_size:
endstruc

struc GUI_Container
	.component				resb GUI_Component.struc_size
	.children				resd 1		;list of pointers to child components
	.struc_size:
endstruc

struc GUI_Desktop
	.container				resb GUI_Container.struc_size
	.background				resd 1		;background color
	.struc_size:
endstruc

struc GUI_Window
	.container				resb GUI_Container.struc_size
	.background				resd 1		;background color
	.canvas:							;this is where child components are drawn
	.cX						resw 1		;relative to the position of the window
	.cY						resw 1		;relative to the position of the window
	.cW						resw 1
	.cH						resw 1
	.struc_size:
endstruc

struc GUI_Console
	.component				resb GUI_Component.struc_size
	.foreground				resd 1		;foreground color
	.background				resd 1		;background color
	.charsFit				resw 1		;number of characters that fit on a line
	.linesFit				resw 1		;number of lines that fit on the console
	.text					resb GUI_Text.struc_size
	.struc_size:
endstruc

struc GUI_Text
	.lines					resd 1		;number of lines in this text, bit 31 is used as a lock for adding / removing lines
	.first					resd 1		;first line in the text
	.last					resd 1
	.struc_size:
endstruc

struc GUI_Line
	.next					resd 1
	.prev					resd 1
	.length					resd 1
	.struc_size:
	.line:
endstruc

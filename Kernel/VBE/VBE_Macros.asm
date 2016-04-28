;IN: X0, Y0, X1, Y1
;OUT: ebx = Y << 16 | X, ecx = H << 16 | W
%macro make_rect 4
	mov_XY ebx, %1, %2
	mov_XY ecx, %3, %4
%endmacro

;IN: dest, X, Y
%macro mov_XY 3
	%ifnum %3
		%ifnum %2
			mov %1, %3 << 16 | %2
		%else
			mov %1, %3 << 16
			or %1, %2
		%endif
	%else
		mov %1, %3
		shl %1, 16
		or %1, %2
	%endif
%endmacro

%define color(A, R, G, B) A << 24 | R << 16 | G << 8 | B
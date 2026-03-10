; Compilateur C V1.1
; Processing: int main() {
; Function declaration: main
; Function: main
main:
; Main function entry point
; Statement processed
; Processing:     int i;
; Statement processed
; Processing:     
; Expression statement
; Statement processed
; Processing:     i = 0;
; Declared variable: i (int)
i: rmb 2
; Size: 2 bytes
; Initializing variable: i (int)
	ldd  #0
	std  i
; Statement processed
; Processing:     while (i < 5) {
L2:
; WHILE loop start
; WHILE condition
; Warning: Undeclared variable i
	ldd  i
	tstd
	lbeq L3
; WHILE body
; Expression statement
	lbra L2
L3:
; End WHILE
; Statement processed
; Processing:         if (i == 3) {
; IF condition
; Warning: Undeclared variable i
	ldd  i
	tstd
	lbeq L4
; IF then block
; Expression statement
L4:
; End IF
; Statement processed
; Processing:             break;
; BREAK statement
; Statement processed
; Processing:         }
; Expression statement
; Statement processed
; Processing:         i = i + 1;
; Declared variable: i (int)
i: rmb 2
; Size: 2 bytes
; Initializing variable: i (int)
; Warning: Undeclared variable i
	ldd  i
	pshs d
	ldd  #1
	addd ,s++
	std  i
; Statement processed
; Processing:     }
; Expression statement
; Statement processed
; Processing:     
; Expression statement
; Statement processed
; Processing:     return 0;
; RETURN statement
	ldd  #0
	rts
; Statement processed
; Processing: }
; Expression statement
; Statement processed
;    .end

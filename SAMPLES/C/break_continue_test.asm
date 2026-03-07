; Compilateur C V1.1
; Processing: void test() {
; Function declaration: test
; Function: test
test:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
; Processing:     while (1) {
L2:
; WHILE loop start
; WHILE condition
	ldd  #1
	tstd
	lbeq L3
; WHILE body
; Compound statement start
; IF condition
	ldd  #0
	tstd
	lbeq L4
; IF then block
; BREAK statement
	lbra L3
L4:
; End IF
; IF condition
	ldd  #1
	tstd
	lbeq L6
; IF then block
; CONTINUE statement
	lbra L2
L6:
; End IF
; Compound statement end
; End of function: test
	puls x,y  ; restore frame pointer
	rts       ; return to caller
	lbra L2
L3:
; End WHILE
; Statement processed
; Processing: }
; Unknown: }
;    .end

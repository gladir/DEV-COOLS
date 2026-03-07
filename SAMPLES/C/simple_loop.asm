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

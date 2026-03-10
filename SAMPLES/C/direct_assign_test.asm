; Compilateur C V1.1
; Processing: void test() {
; Function declaration: test
; Function: test
test:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
; Processing:     x = 10;
; Warning: Undeclared variable x
	ldd  #10
	std  x
; Assignment to variable: x
; Statement processed
; Processing: }
; Unknown: }
;    .end

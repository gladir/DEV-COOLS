; Compilateur C V1.1
; Processing: void test() {
; Function declaration: test
; Function: test
test:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
; Processing:     int x = 5;
; Initializing variable: x (int)
	ldd  #5
	std  x
; Statement processed
; Processing:     x = 10;
; Warning: Undeclared variable x
	ldd  x
; Expression statement
; Statement processed
; Processing: }
; Unknown: }
;    .end

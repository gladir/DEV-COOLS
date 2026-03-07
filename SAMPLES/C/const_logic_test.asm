; Compilateur C V1.1
; Processing: void test() {
; Function declaration: test
; Function: test
test:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
; Processing:     consttest = 10;  // This should fail with const error
; const qualifier detected
; Warning: Undeclared variable test
	ldd  test
; Expression statement
; Statement processed
; Processing: }
; Unknown: }
;    .end

; Compilateur C V1.1
; Processing: void test() {
; Function declaration: test
; Function: test
test:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
; Processing:     const int x = 5;
; const qualifier detected
; Initializing variable: x (const int)
	ldd  #5
; const variable initialized
	std  x
; Statement processed
; Processing: }
; Unknown: }
;    .end

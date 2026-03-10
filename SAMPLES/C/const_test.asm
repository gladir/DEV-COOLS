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
; Processing:     int y = 10;
; Declared variable: y (int)
y: rmb 2
; Size: 2 bytes
; Initializing variable: y (int)
	ldd  #10
	std  y
; Statement processed
; Processing:     
; Unknown:     
; Processing:     y = 20;  // Should work - regular variable
; Warning: Undeclared variable y
	ldd  y
; Expression statement
; Statement processed
; Processing:     x = 30;  // Should fail - const variable
; Warning: Undeclared variable x
	ldd  x
; Expression statement
; Statement processed
; Processing: }
; Unknown: }
;    .end

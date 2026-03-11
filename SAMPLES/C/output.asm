; Compilateur C V1.1
; Defined macro: MAX = 42
; Expanded macro: MAX -> 42
; Line after macro expansion: int x = 42;
; Processing: int x = 42;
; Declared variable: x (int)
x: rmb 2
; Size: 2 bytes
; Initializing variable: x (int)
	ldd  #42
	std  x
; Statement processed
;    .end
; Cleared 1 macro definitions from table

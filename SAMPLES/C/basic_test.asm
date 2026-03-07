; Compilateur C V1.1
; Processing: int main() {
; Function declaration: main
; Function: main
main:
; Main function entry point
; Statement processed
; Processing:     int i;
; Statement processed
; Processing:     i = 0;
; Declared variable: i (int)
i: rmb 2
; Size: 2 bytes
; Initializing variable: i (int)
	ldd  #0
	std  i
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

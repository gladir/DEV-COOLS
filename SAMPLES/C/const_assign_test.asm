; Compilateur C V1.1
; Processing: // Declare const variable
; Unknown: // Declare const variable
; Processing: const int x = 5;
; const qualifier detected
; Initializing variable: x (const int)
	ldd  #5
; const variable initialized
	std  x
; Statement processed
; Processing: // Try to assign (should fail)
; Function found: // Try to assign (should fail)
	nop ; placeholder for function
; Unknown: // Try to assign (should fail)
; Processing: x = 10;
; Warning: Undeclared variable x
	ldd  x
; Expression statement
; Statement processed
;    .end

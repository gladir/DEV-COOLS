; Compilateur C V1.1
; Processing: void f() {}
; Function declaration: f
; Function: f
f:
	pshs x,y  ; save frame pointer and return address context
	tfr  s,x  ; set up frame pointer
; Function body detected - will be parsed by main loop
; Statement processed
;    .end

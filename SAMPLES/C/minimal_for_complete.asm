; Compilateur C V1.1
; Processing: int main() {
; Déclaration de fonction: main (type: int)
main:
; Corps de fonction main
; Fin du corps de fonction main
; Toutes les étiquettes goto sont correctement définies
; Statement processed
; Processing:     int i;
; Variable déclarée: i
: rmb (taille)
; Taille de variable en octets
; Statement processed
; Processing:     for (i = 0; i < 5; i = i + 1) {
; FOR loop start
; FOR initialization


; Assignment to variable: i

L3:
; FOR increment

L2:
; FOR condition check
	tstd

; FOR body

L4:
; End FOR
; Statement processed
; Processing:         i = i + 0;

	pshs d

	addd ,s++

; Assignment to variable: i
; Statement processed
; Processing:     }
; Unknown:     }
; Processing:     return i;
; RETURN statement

	rts
; Statement processed
; Processing: }
; Unknown: }
;    .end
; Cleared macro definitions from table
; Freed symbols from heap
; Libéré structures du tas

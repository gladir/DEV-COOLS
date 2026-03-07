; Compilateur C V1.1
; Defined macro: DEBUG = 1
; Defined macro: PLATFORM_X86 = 1
; Processing: int main() {
; Déclaration de fonction: main (type: int)
main:
; Corps de fonction main
; Fin du corps de fonction main
; Toutes les étiquettes goto sont correctement définies
; Statement processed
; Processing:     int result = 0;
; Variable déclarée: result
: rmb (taille)
; Taille de variable en octets
; Initializing variable: result (int)


; Statement processed
; Processing:     
; Unknown:     
; Expanded macro: DEBUG -> 1
; Line after macro expansion: #if 1
; #if  = 0
; Expanded macro: DEBUG -> 1
; Line after macro expansion:     // This should be included when 1 is defined and non-zero
; #else
; Processing:     // This should be skipped
; Unknown:     // This should be skipped
; Processing:     result = result + 1;

	pshs d

	addd ,s++

; Assignment to variable: result
; Statement processed
; #endif
; Expanded macro: PLATFORM_X86 -> 1
; Line after macro expansion: #ifdef 1
; #ifdef  = 0
; Expanded macro: PLATFORM_X86 -> 1
; Line after macro expansion:     // This should be included when 1 is defined
; #endif
; #ifndef RM_ARM = 1
; Processing:     // This should be included when PLATFORM_ARM is NOT defined
; Unknown:     // This should be included when PLATFORM_ARM is NOT defined
; Processing:     result = result + 1000;

	pshs d

	addd ,s++

; Assignment to variable: result
; Statement processed
; #endif
; Expanded macro: DEBUG -> 1
; Line after macro expansion: #if 1
; #if  = 0
; #elif 
; Expanded macro: DEBUG -> 1
; Line after macro expansion:     // This should be skipped because 1 is true
; #else
; Processing:     // This should also be skipped
; Unknown:     // This should also be skipped
; Processing:     result = result + 3;

	pshs d

	addd ,s++

; Assignment to variable: result
; Statement processed
; #endif
; Processing:     return result;
; RETURN statement

	rts
; Statement processed
; Processing: }
; Unknown: }
;    .end
; Cleared macro definitions from heap
; Contexte de compilation conditionnelle effacé
; Freed symbols from heap
; Libéré structures du tas

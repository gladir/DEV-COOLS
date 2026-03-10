; Compilateur C V1.1
; Processing: static int internal_var = 42;
; Spécificateur de classe de stockage: static
; Variable déclarée: internal
: rmb (taille)
; Variable statique: internal
; Statement processed
; Processing: extern int external_var;
; Spécificateur de classe de stockage: extern
; Variable déclarée: external
; Variable externe: external (définie ailleurs)
; Statement processed
; Processing: int normal_var;
; Variable déclarée: normal_v
: rmb (taille)
; Taille de variable en octets
; Statement processed
;    .end
; Cleared macro definitions from table
; Freed symbols from heap
; Libéré structures du tas

; inc_test_data.asm - Deuxieme fichier inclus par test_include.asm (TODO 21)
; Contient des donnees pour verifier l'inclusion multiple

; --- Table de donnees incluse ---
data_table:
    DC.W    $0001,$0002,$0003,$0004
    DC.W    $0005,$0006,$0007,$0008
    DC.B    'Inclus OK',0
    EVEN

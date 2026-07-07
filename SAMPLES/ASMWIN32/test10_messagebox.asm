; test10_messagebox.asm - Test 10 : boite de dialogue Win32 (user32.dll)
; INVOKE MessageBoxA avec ADDR (adresse de buffers .DATA).

.386
.MODEL FLAT
EXTERN MessageBoxA:PROC
EXTERN ExitProcess:PROC

.DATA
caption DB 'ML.PAS - test10', 0
text    DB 'Ceci est une vraie boite de dialogue Win32,', 13, 10, \
          'generee par un executable assemble avec ML.PAS.', 0

.CODE
start:
        INVOKE MessageBoxA, 0, ADDR text, ADDR caption, 0
        INVOKE ExitProcess, 0

END start

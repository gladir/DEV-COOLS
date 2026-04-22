*----------------------------------------------------------------*
* test_call_extern.abap                                          *
*----------------------------------------------------------------*
* Demontre CALL FUNCTION externe sans linker.                     *
*                                                                 *
* Le compilateur resout dynamiquement les FM externes via        *
* LoadLibraryA + GetProcAddress au runtime :                      *
*   - La FM 'NOM_FM' est recherchee dans 'NOM_FM.DLL'.           *
*   - L export attendu porte le meme nom (ASCIIZ, non decore).    *
*   - Si la DLL ou l export est introuvable : SY-SUBRC = 4.       *
*   - Sinon la fonction est appelee (sans marshalling d args).   *
*----------------------------------------------------------------*
REPORT ztest_call_extern.

DATA rc TYPE I.

* FM externe inexistante - doit produire SY-SUBRC = 4
CALL FUNCTION 'INEXISTANT_FM'
  EXCEPTIONS
    others = 1.
rc = sy-subrc.
WRITE: 'SY-SUBRC apres appel externe inexistant =', rc, /.

* FM externe ciblant kernel32 via un nom non standard
CALL FUNCTION 'NO_SUCH_MODULE'.
rc = sy-subrc.
WRITE: 'SY-SUBRC apres 2eme appel inexistant    =', rc, /.

WRITE: 'Fin du test CALL FUNCTION externe.', /.

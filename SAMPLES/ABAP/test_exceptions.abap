REPORT ztest_exceptions.

* Test du runtime d exceptions ABAP (TRY / CATCH / CLEANUP / RAISE).
* Ce sample valide :
*   - capture d une exception typee (CX_SY_ZERODIVIDE)
*   - CATCH CX_ROOT comme catch-all
*   - TRY imbriques (propagation vers le handler englobant)

* Cas 1 : dispatch vers le bon CATCH
WRITE: 'cas 1 : dispatch typee', /.
TRY.
  WRITE: '  dans try', /.
  RAISE EXCEPTION TYPE cx_sy_zerodivide.
  WRITE: '  apres raise (ne doit pas apparaitre)', /.
CATCH cx_sy_arithmetic_error.
  WRITE: '  mauvaise branche', /.
CATCH cx_sy_zerodivide.
  WRITE: '  capture zerodivide OK', /.
ENDTRY.

* Cas 2 : CX_ROOT comme catch-all
WRITE: 'cas 2 : catch-all', /.
TRY.
  RAISE EXCEPTION TYPE cx_unknown.
CATCH cx_root.
  WRITE: '  catch-all OK', /.
ENDTRY.

* Cas 3 : propagation vers TRY englobant
WRITE: 'cas 3 : TRY imbriquees', /.
TRY.
  TRY.
    RAISE EXCEPTION TYPE cx_bar.
  CATCH cx_other.
    WRITE: '  non atteint', /.
  ENDTRY.
CATCH cx_bar.
  WRITE: '  capture par TRY externe OK', /.
ENDTRY.

WRITE: 'fin', /.

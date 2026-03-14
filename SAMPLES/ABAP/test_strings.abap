REPORT ZTEST_STRINGS.
* Test TODO 17 : Operations sur chaines de caracteres

DATA gv_str1 TYPE C LENGTH 30.
DATA gv_str2 TYPE C LENGTH 30.
DATA gv_str3 TYPE C LENGTH 30.
DATA gv_result TYPE C LENGTH 80.
DATA gv_off TYPE I.

* --- CONCATENATE ---
gv_str1 = 'Hello'.
gv_str2 = 'World'.
CONCATENATE gv_str1 gv_str2 INTO gv_result.
WRITE: 'CONCAT:', gv_result, /.

CONCATENATE gv_str1 gv_str2 INTO gv_result SEPARATED BY ' '.
WRITE: 'CONCAT SEP:', gv_result, /.

CONCATENATE 'A' 'B' 'C' INTO gv_result SEPARATED BY '-'.
WRITE: 'CONCAT LIT:', gv_result, /.

* --- TRANSLATE ---
gv_str1 = 'Hello World'.
TRANSLATE gv_str1 TO UPPER CASE.
WRITE: 'UPPER:', gv_str1, /.

TRANSLATE gv_str1 TO LOWER CASE.
WRITE: 'LOWER:', gv_str1, /.

* --- CONDENSE ---
gv_str1 = 'Hello World'.
CONDENSE gv_str1.
WRITE: 'CONDENSE:', gv_str1, /.

gv_str1 = 'Hello World'.
CONDENSE gv_str1 NO-GAPS.
WRITE: 'NO-GAPS:', gv_str1, /.

* --- SHIFT ---
gv_str1 = 'ABCDEF'.
SHIFT gv_str1.
WRITE: 'SHIFT L1:', gv_str1, /.

gv_str1 = 'ABCDEF'.
SHIFT gv_str1 LEFT BY 3 PLACES.
WRITE: 'SHIFT L3:', gv_str1, /.

gv_str1 = 'ABCDEF'.
SHIFT gv_str1 RIGHT BY 2 PLACES.
WRITE: 'SHIFT R2:', gv_str1, /.

* --- FIND ---
gv_str1 = 'Hello World'.
FIND 'World' IN gv_str1 MATCH OFFSET gv_off.
WRITE: 'FIND off:', gv_off, /.
WRITE: 'SUBRC:', SY-SUBRC, /.

FIND 'XYZ' IN gv_str1.
WRITE: 'FIND miss SUBRC:', SY-SUBRC, /.

* --- REPLACE ---
gv_str1 = 'Hello World'.
REPLACE 'World' IN gv_str1 WITH 'ABAP'.
WRITE: 'REPLACE:', gv_str1, /.

* --- SPLIT ---
gv_str1 = 'HelloWorld'.
SPLIT gv_str1 AT '-' INTO gv_str2 gv_str3.
WRITE: 'SPLIT t1:', gv_str2, /.

WRITE 'Done.'.

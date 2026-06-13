/* test_ceilz.sas - CEILZ : plafond vers zero */
data _null_;
  /* CEILZ(5) = 5 */
  a = ceilz(5);
  put 'CEILZ(5) = ' a;
  /* CEILZ(-5) = -5 (entiers : identique) */
  b = ceilz(-5);
  put 'CEILZ(-5) = ' b;
  /* CEILZ(0) = 0 */
  c = ceilz(0);
  put 'CEILZ(0) = ' c;
run;

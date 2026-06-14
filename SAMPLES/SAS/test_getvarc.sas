/* test_getvarc.sas - GETVARC : valeur d une variable caractere d un dataset (stub) */
data _null_;
  dsid = 0;
  val = getvarc(dsid, 1);
  put 'GETVARC(0,1) = ' val;
run;

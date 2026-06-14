/* test_fpoint.sas - FPOINT : positionner le pointeur de lecture (stub) */
data _null_;
  fid = 0;
  note = 0;
  rc = fpoint(fid, note);
  put 'FPOINT(0,0) = ' rc;
run;

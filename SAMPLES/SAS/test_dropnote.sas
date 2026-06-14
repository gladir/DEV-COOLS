/* test_dropnote.sas - DROPNOTE : effacer un marqueur note (stub) */
data _null_;
  dsid = 0;
  note = 0;
  rc = dropnote(dsid, note);
  put 'DROPNOTE(0,0) = ' rc;
run;

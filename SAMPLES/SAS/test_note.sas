/* test_note.sas - NOTE : ID d observation courante (stub) */
data _null_;
  dsid = 0;
  nid = note(dsid);
  put 'NOTE(0) = ' nid;
run;

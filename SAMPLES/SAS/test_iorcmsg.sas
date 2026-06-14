/* test_iorcmsg.sas - IORCMSG : message d erreur formate pour _IORC_ (stub) */
data _null_;
  msg = iorcmsg();
  put 'IORCMSG() = ' msg;
run;

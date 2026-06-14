/* test_htmlencode.sas - HTMLENCODE : encoder une chaine en HTML (stub) */
data _null_;
  s = htmlencode('<b>texte</b>');
  put 'HTMLENCODE = ' s;
run;

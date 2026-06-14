/* test_htmldecode.sas - HTMLDECODE : décoder une chaine HTML (stub) */
data _null_;
  s = htmldecode('&lt;b&gt;texte&lt;/b&gt;');
  put 'HTMLDECODE = ' s;
run;

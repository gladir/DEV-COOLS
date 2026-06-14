/* test_fileexist.sas - FILEEXIST : existence d un fichier physique */
data _null_;
  /* Tester avec un fichier qui existe (chemin Windows) */
  a = fileexist('C:\Windows\notepad.exe');
  put 'FILEEXIST(notepad.exe) = ' a;
  b = fileexist('C:\FICHIER_INEXISTANT.txt');
  put 'FILEEXIST(inexistant) = ' b;
run;

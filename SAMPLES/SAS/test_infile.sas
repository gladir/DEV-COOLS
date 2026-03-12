/* test_infile.sas - test INFILE / INPUT / FILE */
data result;
  infile 'donnees.dat' dlm=',' firstobs=2;
  input nom $ age salaire;
  file 'sortie.dat';
  put nom age salaire;
run;

/* test_columns.sas - test INPUT colonnes et PUT colonnes */
data columns;
  input nom $ 1-10 age 11-13;
  put nom 1-10 age 11-13;
  put 'Fin du test colonnes';
run;

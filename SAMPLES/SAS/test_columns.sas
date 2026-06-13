/* test_columns.sas - test INPUT colonnes et PUT colonnes */
data columns;
  infile cards;
  input nom $ 1-10 age 11-13;
  put nom age;
  cards;
Alice      30
Bob        25
;
run;

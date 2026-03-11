/* test_cards.sas - test FILE PRINT et INFILE CARDS */
data cartes;
  file print;
  infile cards;
  input x y;
  total = x + y;
  put 'Total :' total;
run;

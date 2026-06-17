/* test_kurtosis.sas - KURTOSIS : indicateur entier de kurtosis */
data _null_;
  z = kurtosis(0);
  put 'KURTOSIS(0) = ' z '  (attendu: 0)';
  k = kurtosis(1);
  put 'KURTOSIS(1) = ' k '  (attendu: 1)';
  n = kurtosis(-3);
  put 'KURTOSIS(-3) = ' n '  (attendu: 9)';
run;

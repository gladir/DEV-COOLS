/* test_kurtosis.sas - KURTOSIS : valeur du kurtosis (stub) */
data _null_;
  k = kurtosis(1);
  put 'KURTOSIS(1) = ' k;
run;

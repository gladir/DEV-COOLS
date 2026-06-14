/* test_datepart.sas - DATEPART : extraire date d un datetime (stub) */
data _null_;
  dt = 1000000;
  d = datepart(dt);
  put 'DATEPART(1000000) = ' d;
run;

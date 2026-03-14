/* test_merge.sas - Tests pour TODO 23 : MERGE / SET / BY */
/* Test 1 : SET avec un seul dataset */
data work1;
  set sales;
  total = price * qty;
run;

/* Test 2 : SET avec concatenation verticale (deux datasets) */
data combined;
  set ds_jan ds_feb;
run;

/* Test 3 : SET avec option NOBS= */
data info;
  set customers nobs=total_obs;
  if _n_ = 1 then put total_obs;
run;

/* Test 4 : SET avec option END= */
data last_check;
  set orders end=eof;
  if eof then put 'Fin du dataset';
run;

/* Test 5 : SET avec option POINT= */
data direct;
  n = 5;
  set records point=n;
run;

/* Test 6 : MERGE avec BY (fusion horizontale) */
data merged;
  merge customers orders;
  by cust_id;
run;

/* Test 7 : MERGE sans BY (fusion un-a-un par position) */
data merged_pos;
  merge ds_a ds_b;
run;

/* Test 8 : BY avec FIRST. et LAST. */
data grouped;
  set sorted_data;
  by region;
  if first.region then total = 0;
  total + amount;
  if last.region then output;
run;

/* Test 9 : BY avec plusieurs variables */
data multi_by;
  set sales_data;
  by region product;
  if first.product then count = 0;
  count + 1;
run;

/* Test 10 : UPDATE (maitre + transaction) */
data updated;
  update master trans;
  by id;
run;

/* Test 11 : MODIFY (modification en place) */
data inventory;
  modify inventory;
  if qty = 0 then delete;
run;

/* Test 12 : SET avec trois datasets (concatenation multiple) */
data all_year;
  set q1 q2 q3;
run;

/* Test 13 : MERGE avec trois datasets */
data full;
  merge emp dept sal;
  by emp_id;
run;

/* Test 14 : BY avec DESCENDING */
data sorted_desc;
  set mydata;
  by descending score;
run;

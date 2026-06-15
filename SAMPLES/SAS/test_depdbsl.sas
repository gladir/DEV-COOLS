data _null_;
  /* life=10, factor=2: SL overtakes DDB in period 9 */
  d8 = depdbsl(10000, 1000, 10, 8, 2);
  put 'DEPDBSL(10000,1000,10,8,2) = [' d8 '] (attendu: [419])';
  d9 = depdbsl(10000, 1000, 10, 9, 2);
  put 'DEPDBSL(10000,1000,10,9,2) = [' d9 '] (attendu: [339] SL>DDB ici)';
  d10 = depdbsl(10000, 1000, 10, 10, 2);
  put 'DEPDBSL(10000,1000,10,10,2) = [' d10 '] (attendu: [340])';
  /* DEPDB same periods for comparison */
  e9 = depdb(10000, 1000, 10, 9, 2);
  put 'DEPDB(10000,1000,10,9,2)   = [' e9 '] (attendu: [335] avant bascule)';
  /* DACCDBSL cumul sur 10 periodes = cost-sal = 9000 */
  a10 = daccdbsl(10000, 1000, 10, 10, 2);
  put 'DACCDBSL(10000,1000,10,10,2) = [' a10 '] (attendu: [9000])';
  a9 = daccdbsl(10000, 1000, 10, 9, 2);
  put 'DACCDBSL(10000,1000,10,9,2) = [' a9 '] (attendu: [8660])';
  /* edge: per=1 */
  d1 = depdbsl(10000, 1000, 5, 1, 2);
  put 'DEPDBSL(10000,1000,5,1,2) = [' d1 '] (attendu: [4000])';
run;

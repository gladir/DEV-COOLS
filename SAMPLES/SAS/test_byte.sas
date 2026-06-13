/* test_byte.sas - BYTE : code ASCII d un caractere */
data _null_;
  /* BYTE(65) = code ASCII de 'A' = 65 */
  a = byte(65);
  put 'BYTE(65) = ' a;
  /* BYTE(48) = code ASCII de '0' = 48 */
  b = byte(48);
  put 'BYTE(48) = ' b;
  /* BYTE(32) = espace = 32 */
  c = byte(32);
  put 'BYTE(32) = ' c;
run;

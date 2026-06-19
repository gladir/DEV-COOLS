MODULE CharOrdChr;

IMPORT InOut;

VAR
  letter : CHAR;
  code   : INTEGER;

BEGIN
  letter := CHR(65);
  code := ORD(letter);
  InOut.WriteString('Caractere ');
  InOut.WriteChar(letter);
  InOut.WriteString(', code ');
  InOut.WriteInt(code, 0);
  InOut.WriteLn
END CharOrdChr.

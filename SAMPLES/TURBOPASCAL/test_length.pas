Program TestLength;

Uses Strings;

Var
 S:String;
 P:PChar;

BEGIN
 S:='TEST';
 P:='TEST';
 WriteLn('Length(''TEST'')=S[0], S[0]=4:');
 WriteLn('Length(''TEST'')=',Length(S));
 WriteLn('S[0]=',Ord(S[0]));
 WriteLn;
 WriteLn('StrLen(''TEST'')=4, P[0]=84');
 WriteLn('StrLen(''TEST'')=',StrLen(P));
 WriteLn('P[0]=',Ord(P[0]));
END.

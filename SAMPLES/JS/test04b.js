// Test direct ParseExprPrec via constante folding attendu
// Ces expressions seront evaluees en ParseExpr quand ParseStmt sera implante
2 + 3 * 4;
(2 + 3) * 4;
true && false;
null ?? 42;
1 < 2 ? 10 : 20;
!false;
~0;
1 === 1;

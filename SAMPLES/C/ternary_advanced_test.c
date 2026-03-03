/* Test avancé de l'opérateur ternaire avec imbrication */

int main()
{
    int x, y, z, result;
    
    x = 10;
    y = 20;
    z = 30;
    
    /* Ternaire simple */
    result = (x > y) ? x : y;     /* max(10, 20) = 20 */
    
    /* Ternaire avec expressions arithmétiques */
    result = (x + y > z) ? (x + y) : z;   /* (10+20 > 30) ? 30 : 30 = 30 */
    
    /* Ternaire imbriqué - trouver le maximum de trois nombres */
    result = (x > y) ? ((x > z) ? x : z) : ((y > z) ? y : z);
    /* x=10, y=20, z=30
       (10 > 20) = faux, donc évaluer ((20 > 30) ? 20 : 30) = 30 */
    
    /* Ternaire avec conditions logiques */
    x = 5;
    y = 0;
    result = (x && y) ? 1 : (x || y) ? 2 : 3;
    /* (5 && 0) = 0 (faux), donc (5 || 0) = 1 (vrai), résultat = 2 */
    
    /* Ternaire avec opérateurs de comparaison */
    x = 15;
    y = 15;
    result = (x == y) ? 100 : (x != y) ? 200 : 300;
    /* (15 == 15) = vrai, résultat = 100 */
    
    /* Ternaire avec négation */
    x = 0;
    result = !x ? 42 : 0;     /* !0 = 1 (vrai), résultat = 42 */
    
    /* Chaîne de ternaires (évaluation de droite à gauche) */
    x = 3;
    result = x == 1 ? 10 : x == 2 ? 20 : x == 3 ? 30 : 40;
    /* x == 1 ? 10 : (x == 2 ? 20 : (x == 3 ? 30 : 40))
       3 == 1 = faux, donc évaluer (3 == 2 ? 20 : (3 == 3 ? 30 : 40))
       3 == 2 = faux, donc évaluer (3 == 3 ? 30 : 40)
       3 == 3 = vrai, résultat = 30 */
    
    return 0;
}

/* test25_namespaces.cs : test des espaces de noms (TODO 18)           */
/* - namespace simple : namespace MonApp { class ... }                 */
/* - namespace qualifie : namespace A.B.C { class ... }               */
/* - namespace imbrique : namespace Outer { namespace Inner { ... } }   */
/* - plusieurs namespaces dans un fichier                              */
/* - namespace avec qualificateurs de visibilite                       */
/* - namespace avec constantes                                        */
/* - classes dans namespace avec methodes statiques                    */

using System;

/* Cas 1 : namespace simple avec une classe */
namespace SimpleApp
{
    class Program
    {
        static void Main()
        {
            int x = 10;
            int y = 20;
            int z = x + y;
        }
    }
}

/* Cas 2 : namespace qualifie avec point */
namespace MyCompany.MyProduct
{
    class Config
    {
        static int version = 1;
        static int maxItems = 100;
    }
}

/* Cas 3 : namespace imbrique */
namespace Outer
{
    namespace Inner
    {
        class Helper
        {
            static int value = 42;

            static int GetValue()
            {
                return 42;
            }
        }
    }
}

/* Cas 4 : namespace avec qualificateur de visibilite */
namespace PublicApp
{
    public class PublicClass
    {
        static int data = 0;

        static void Reset()
        {
            int temp = 0;
        }
    }

    internal class InternalClass
    {
        static int code = 99;
    }
}

/* Cas 5 : namespace qualifie long */
namespace A.B.C.D
{
    class Deep
    {
        static int level = 4;
    }
}

/* Cas 6 : namespace avec plusieurs classes */
namespace MultiClass
{
    class First
    {
        static int a = 1;
    }

    class Second
    {
        static int b = 2;
    }

    class Third
    {
        static int c = 3;
    }
}

/* Cas 7 : namespace vide */
namespace EmptyNamespace
{
}

// hello.js - Exemple JS86 : console.log, var/let/const, +, template literals
// Compile : JS86.EXE hello.js hello.asm

// Variables et constantes
var message = "Hello";
let world = "World";
const bang = "!";

// Concatenation de chaines
var greeting = message + " " + world + bang;
console.log(greeting);

// Affichage de nombres
var x = 42;
let y = -7;
console.log(x);
console.log(y);

// Expressions arithmetiques
var sum = x + y;
console.log(sum);

// Template literal basique
var name = "JS86";
console.log(`Bienvenue dans ${name}`);

// Constante booleenne
const flag = true;
console.log(flag);

// Valeurs speciales
console.log(null);
console.log(undefined);

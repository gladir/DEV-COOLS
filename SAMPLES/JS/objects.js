// objects.js - Exemple JS86 : objets litteraux, acces proprietes, Object.keys
// Compile : JS86.EXE objects.js objects.asm

// Objet litteral (une ligne pour eviter ASI)
var person = {name: "Alice", age: 30, city: "Paris"};

// Acces proprietes
console.log(person.name);
// attendu : Alice

console.log(person.age);
// attendu : 30

// Modification de propriete
person.age = 31;
console.log(person.age);
// attendu : 31

// Ajout de propriete
person.email = "alice@example.com";

// Object.keys
var keys = Object.keys(person);
console.log(keys.length);
// attendu : 4

// Objet simple
var config = {host: "localhost", port: 8080};

console.log(config.host);
// attendu : localhost

console.log(config.port);
// attendu : 8080

// Object.assign
var defaults = {color: "red", size: 10};
var custom = {size: 20};
var merged = Object.assign(defaults, custom);
console.log(merged.size);
// attendu : 20

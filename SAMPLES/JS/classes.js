// classes.js - Exemple JS86 : class, constructor, extends, super, new
// Compile : JS86.EXE classes.js classes.asm

// Classe de base
class Animal {
  constructor(name, sound) {
    this.name = name;
    this.sound = sound;
  }

  speak() {
    console.log(this.sound);
  }
}

// Heritage
class Dog extends Animal {
  constructor(name) {
    super(name, "Woof");
  }
}

class Cat extends Animal {
  constructor(name) {
    super(name, "Meow");
  }
}

// Instanciation
var dog = new Dog("Rex");
dog.speak();
// attendu : Woof

var cat = new Cat("Mimi");
cat.speak();
// attendu : Meow

// Acces aux proprietes
console.log(dog.name);
// attendu : Rex

console.log(cat.name);
// attendu : Mimi

// Classe simple
class Counter {
  constructor() {
    this.count = 0;
  }

  increment() {
    this.count = this.count + 1;
  }

  getCount() {
    return this.count;
  }
}

var c = new Counter();
c.increment();
c.increment();
c.increment();
console.log(c.getCount());
// attendu : 3

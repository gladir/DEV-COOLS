// test21.js - Classes et heritage (TODO 21)

// --- Test 1 : Classe simple avec constructeur ---
class Animal {
  constructor(name, sound) {
    this.name = name;
    this.sound = sound;
  }
  speak() {
    console.log(this.sound);
  }
}

let a = new Animal("Cat", 42);
console.log(a.name);
console.log(a.sound);

// --- Test 2 : Appel de methode ---
a.speak();

// --- Test 3 : Heritage ---
class Dog extends Animal {
  constructor(name) {
    super(name, 99);
    this.legs = 4;
  }
  info() {
    console.log(this.legs);
  }
}

let d = new Dog("Rex");
console.log(d.name);
console.log(d.sound);
d.info();

// --- Test 4 : instanceof ---
let r1 = d instanceof Dog;
console.log(r1);

// --- Test 5 : Methode statique ---
class MathUtil {
  constructor() {
  }
  static add(x, y) {
    return x + y;
  }
}

// --- Test 6 : Classe sans constructeur ---
class Empty {
}
let e = new Empty();
console.log(0);

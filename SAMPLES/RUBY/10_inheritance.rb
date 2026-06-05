class Animal
  def speak
    "sound"
  end
end

class Cat < Animal
  def speak
    "meow"
  end
end

pet = Cat.new
puts pet.speak

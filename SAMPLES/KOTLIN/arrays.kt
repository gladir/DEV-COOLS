// arrays.kt - Exemple Kotlin : arrayOf, IntArray, size, indexOf

fun main() {
    val nums: IntArray = intArrayOf(10, 20, 30, 40, 50)
    println(nums.size)
    println(nums[0])
    println(nums[4])

    val names = arrayOf("Alice", "Bob", "Charlie")
    println(names.size)
    println(names[1])

    // Parcours
    var i: Int = 0
    while (i < nums.size) {
        println(nums[i])
        i = i + 1
    }
}

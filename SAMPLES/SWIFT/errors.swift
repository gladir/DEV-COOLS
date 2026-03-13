// errors.swift - Gestion d erreurs compilee par SWIFT86
// Demontre : do/try/catch, throw, defer, try?, try!

enum FileError {
    case notFound
    case noPermission
}

func openFile(_ name: String) -> Int {
    return 1
}

func process() -> Int {
    let status: Int = openFile("test.txt")
    if status == 0 {
        return 0
    }
    return 1
}

defer {
    print(99)
}

let ok: Int = process()
print(ok)

import Foundation

class Todo {
    var id: String?
    var title: String?
    var colorHex: String?
    var createdAt: String?
    var items: [Items]?
    
    init(id: String, title: String, colorHex: String, createdAt: String, items: [Items] ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.createdAt = createdAt
        self.items = items
    }
    
    init() {
        self.id = ""
        self.title = ""
        self.colorHex = ""
        self.createdAt = ""
        self.items = [Items]()
    }
}

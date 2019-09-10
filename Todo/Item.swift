import Foundation

class Items {
    var id: String?
    var title: String?
    var search_title: String?
    var done: Bool?
    var colorHex: String?
    var createdAt: String?
    
    init(id: String, title: String, search_title: String, done: Bool, createdAt: String, colorHex: String) {
        self.id = id
        self.title = title
        self.search_title = search_title
        self.done = done
        self.createdAt = createdAt
        self.colorHex = colorHex
    }
}

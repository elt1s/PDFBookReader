import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID = UUID()
    var title: String = ""
    var paragraphs: [String] = []
    var lastReadIndex: Int = 0
    var lastUpdated: Date = Date()

    init(title: String, paragraphs: [String], lastReadIndex: Int = 0) {
        self.id = UUID()
        self.title = title
        self.paragraphs = paragraphs
        self.lastReadIndex = lastReadIndex
        self.lastUpdated = Date()
    }
}

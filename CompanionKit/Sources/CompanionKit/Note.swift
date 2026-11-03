import Foundation

public struct Note: Codable, Equatable {
    public let displayName: String?
    public let width: Int
    public let height: Int
    public let duration: Double
    public let marks: [NoteMark]
    public let phrases: [NotePhrase]

    public init(displayName: String?, width: Int, height: Int, duration: Double, marks: [NoteMark], phrases: [NotePhrase]) {
        self.displayName = displayName
        self.width = width
        self.height = height
        self.duration = duration
        self.marks = marks
        self.phrases = phrases
    }
}

public struct NoteMark: Codable, Equatable {
    public let number: Int
    public let start: Double
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let on: String?

    public init(number: Int, start: Double, x: Int, y: Int, width: Int, height: Int, on: String?) {
        self.number = number
        self.start = start
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.on = on
    }
}

public struct NotePhrase: Codable, Equatable {
    public let start: Double
    public let end: Double
    public let text: String
    public let marks: [Int]

    public init(start: Double, end: Double, text: String, marks: [Int]) {
        self.start = start
        self.end = end
        self.text = text
        self.marks = marks
    }
}

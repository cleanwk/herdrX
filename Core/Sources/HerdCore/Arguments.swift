import Foundation

/// Shell-like words, with no expansions or evaluation. Herdr receives an argv array.
public enum Arguments {
    public static func parse(_ text: String) throws -> [String] {
        var result: [String] = [], word = "", quote: Character?, escaped = false, started = false
        for character in text {
            if escaped { word.append(character); escaped = false; started = true; continue }
            if character == "\\", quote != "'" { escaped = true; started = true; continue }
            if let delimiter = quote {
                if character == delimiter { quote = nil } else { word.append(character) }
                continue
            }
            if character == "'" || character == "\"" { quote = character; started = true }
            else if character.isWhitespace { if started { result.append(word); word = ""; started = false } }
            else { word.append(character); started = true }
        }
        guard quote == nil, !escaped else { throw Failure("Close the quote or finish the escape in Arguments.") }
        if started { result.append(word) }
        return result
    }
}

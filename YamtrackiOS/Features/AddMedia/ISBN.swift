import Foundation

enum ISBN {
    static func normalize(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var cleaned = String()
        cleaned.reserveCapacity(trimmed.count)

        for character in trimmed {
            switch character {
            case "0"..."9":
                cleaned.append(character)
            case "x", "X":
                cleaned.append("X")
            case "-", " ", "\t", "\n", "\r":
                continue
            default:
                return nil
            }
        }

        switch cleaned.count {
        case 10:
            return isValidISBN10(cleaned) ? cleaned : nil
        case 13:
            return isValidISBN13(cleaned) ? cleaned : nil
        default:
            return nil
        }
    }

    static func isValid(_ rawValue: String) -> Bool {
        normalize(rawValue) != nil
    }

    private static func isValidISBN10(_ value: String) -> Bool {
        guard value.count == 10 else { return false }

        let digits = Array(value)
        guard digits.prefix(9).allSatisfy({ $0.isNumber }) else { return false }

        var checksum = 0
        for (index, digit) in digits.prefix(9).enumerated() {
            guard let number = digit.wholeNumberValue else { return false }
            checksum += (10 - index) * number
        }

        let lastDigit: Int
        switch digits[9] {
        case "X":
            lastDigit = 10
        case let character where character.isNumber:
            guard let number = character.wholeNumberValue else { return false }
            lastDigit = number
        default:
            return false
        }

        checksum += lastDigit
        return checksum.isMultiple(of: 11)
    }

    private static func isValidISBN13(_ value: String) -> Bool {
        guard value.count == 13, value.allSatisfy(\.isNumber) else { return false }

        let digits = value.compactMap(\.wholeNumberValue)
        guard digits.count == 13 else { return false }

        let checksum = digits
            .prefix(12)
            .enumerated()
            .reduce(0) { partialResult, element in
                let (index, digit) = element
                return partialResult + digit * (index.isMultiple(of: 2) ? 1 : 3)
            }

        let expectedCheckDigit = (10 - (checksum % 10)) % 10
        return digits[12] == expectedCheckDigit
    }
}

import Foundation
import PDFKit

enum PDFExtractionError: LocalizedError {
    case securityAccessFailed
    case documentLoadFailed
    case emptyDocument

    var errorDescription: String? {
        switch self {
        case .securityAccessFailed:
            return "Не удалось получить доступ к файлу (ограничение песочницы)."
        case .documentLoadFailed:
            return "Не удалось открыть PDF-файл. Возможно, он поврежден или защищен паролем."
        case .emptyDocument:
            return "В документе нет страниц или не удалось извлечь текст."
        }
    }
}

final class PDFExtractor {
    
    /// Извлекает, фильтрует мусор и собирает текст в массив аккуратных абзацев
    static func extractParagraphs(from url: URL) async throws -> [String] {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        return try await Task.detached(priority: .userInitiated) {
            guard let document = PDFDocument(url: url) else {
                throw PDFExtractionError.documentLoadFailed
            }
            
            let pageCount = document.pageCount
            guard pageCount > 0 else {
                throw PDFExtractionError.emptyDocument
            }
            
            // 1. Сбор всех сырых строк и фильтрация колонтитулов/номеров
            var collectedLines: [String] = []
            let pageSignatureRegex = try? NSRegularExpression(
                pattern: #"^\d+\s*[-–—]\s*Dżum[aa]\s*\d*$"#,
                options: .caseInsensitive
            )
            
            for pageIndex in 0..<pageCount {
                guard let page = document.page(at: pageIndex),
                      let pageText = page.string else {
                    continue
                }
                
                let lines = pageText.components(separatedBy: .newlines)
                for rawLine in lines {
                    let line = rawLine.trimmingCharacters(in: .whitespaces)
                    if line.isEmpty { continue }
                    
                    // Фильтр колонтитулов сайта
                    if line.localizedCaseInsensitiveContains("logos.astral-life.pl") ||
                       line.localizedCaseInsensitiveContains("KRAINA LOGOS") {
                        continue
                    }
                    
                    // Пропускаем колонтитулы браузера и сайтов
                    if line.localizedCaseInsensitiveContains("booksite.ru") ||
                       line.localizedCaseInsensitiveContains("logos") ||
                       line.hasPrefix("http://") ||
                       line.hasPrefix("https://") {
                        continue
                    }

                    
                    // Фильтр номеров страниц (строки, состоящие только из цифр)
                    if Int(line) != nil {
                        continue
                    }
                    
                    // Фильтр типографских меток книги (например "5 - Dżuma 65")
                    if let regex = pageSignatureRegex {
                        let range = NSRange(location: 0, length: line.utf16.count)
                        if regex.firstMatch(in: line, range: range) != nil {
                            continue
                        }
                    }
                    
                    collectedLines.append(line)
                }
            }
            
            // 2. Склейка разорванных слов и формирование абзацев
            var paragraphs: [String] = []
            var currentParagraphLines: [String] = []
            
            let sentencePunctuation: Set<Character> = [".", "!", "?", "”", "»", ";"]
            let dialoguePrefixes = ["-", "—", "–"]
            let chapterRomanRegex = try? NSRegularExpression(pattern: #"^(I|II|III|IV|V|VI|VII|VIII|IX|X)$"#)
            
            for line in collectedLines {
                guard !currentParagraphLines.isEmpty else {
                    currentParagraphLines.append(line)
                    continue
                }
                
                let prevLine = currentParagraphLines.last!
                
                // Склеиваем слова, разбитые переносом дефиса: "współoby-" + "watele" -> "współobywatele"
                if prevLine.hasSuffix("-") || prevLine.hasSuffix("—") || prevLine.hasSuffix("–") {
                    let trimmedPrev = String(prevLine.dropLast()).trimmingCharacters(in: .whitespaces)
                    if let lastChar = trimmedPrev.last, lastChar.isLetter,
                       let firstChar = line.first, firstChar.isLetter {
                        currentParagraphLines[currentParagraphLines.count - 1] = trimmedPrev + line
                        continue
                    }
                }
                
                // Критерии нового абзаца:
                // а) Диалог (строка начинается с тире / дефиса)
                let isDialogue = dialoguePrefixes.contains { line.starts(with: $0) } ||
                                 dialoguePrefixes.contains { line.trimmingCharacters(in: CharacterSet(charactersIn: "\"'„»« ")).starts(with: $0) }
                
                // б) Номер части или главы (римские цифры I, II, III...)
                var isChapter = false
                if let chapRegex = chapterRomanRegex {
                    let range = NSRange(location: 0, length: line.utf16.count)
                    isChapter = (chapRegex.firstMatch(in: line, range: range) != nil)
                }
                
                // в) Предыдущая строка была короткой (< 65 знаков) и закончилась точкой / знаком препинания
                let prevEndsPunct = prevLine.last.map { sentencePunctuation.contains($0) } ?? false
                let prevIsShort = prevLine.count < 65
                
                if isDialogue || isChapter || (prevEndsPunct && prevIsShort) {
                    paragraphs.append(currentParagraphLines.joined(separator: " "))
                    currentParagraphLines = [line]
                } else {
                    currentParagraphLines.append(line)
                }
            }
            
            if !currentParagraphLines.isEmpty {
                paragraphs.append(currentParagraphLines.joined(separator: " "))
            }
            
            return paragraphs
        }.value
    }
}

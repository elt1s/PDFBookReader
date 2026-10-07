# 📖 PDFBookReader

An elegant, high-performance iOS reading application built with **SwiftUI**, **PDFKit**, and **SwiftData**. 

Standard PDF viewing on mobile devices often suffers from fixed-layout constraints requiring constant pinch-to-zoom. **PDFBookReader** solves this by extracting textual content, stripping document artifacts (headers, footers, pagination noise), reconstructing broken hyphenated words, and reflowing the book into a native, modern typography stream.

---

## 🚀 Key Features & Engineering Highlights

* **Intelligent Text Reflow & Cleanup:**
  * Regex-powered heuristic pipeline that eliminates running headers, web watermarks, and isolated page numbering.
  * Hyphenation resolution: detects and automatically rejoins words split across page lines (e.g., `connec-` + `tion` → `connection`).
  * Boundary detection: formats distinct dialogue entries and chapter delimiters into clean, readable paragraphs.

* **Non-Blocking Swift Concurrency:**
  * Heavy PDF extraction and parsing runs entirely in the background via `Task.detached(priority: .userInitiated)`.
  * The main thread remains responsive at 120 FPS without UI freezes during multi-hundred-page book processing.

* **SwiftData Persistence Layer:**
  * Complete offline storage using Apple's modern `@Model` and `@Query` architecture.
  * Once a book is imported, its parsed structure and reading metadata live locally—eliminating repetitive file-picking and re-parsing.

* **Memory-Efficient Virtualized UI:**
  * Rendered via `LazyVStack` inside `ScrollView`, dynamically instantiating views only as they enter the viewport.
  * Native scroll synchronization using `.scrollTargetLayout()` and `.scrollPosition(id:)` to accurately track and restore reading position across app launches.

* **iOS Security-Scoped Resource Management:**
  * Proper handling of sandboxed iOS file URLs (`startAccessingSecurityScopedResource` and `defer { stopAccessingSecurityScopedResource() }`) preventing permission leaks and crashes.

---

## 🛠 Tech Stack

| Layer | Technology |
| :--- | :--- |
| **Language** | Swift 5.9+ / Swift 6 Ready |
| **UI Framework** | SwiftUI (Declarative UI, ProMotion 120Hz support) |
| **Document Processing** | PDFKit |
| **Persistence** | SwiftData (`@ModelContainer`, `@Query`, `@Model`) |
| **Concurrency** | Modern Swift Concurrency (`async/await`, `Task.detached`, `@MainActor`) |
| **Platform Target** | iOS 17.0+ |

---

## 🏗 Architecture & Code Structure

```text
PDFBookReader/
├── App/
│   └── MyApp.swift            # App entry point initializing the SwiftData ModelContainer
├── Models/
│   └── Book.swift             # SwiftData entity model (title, paragraphs, lastReadIndex, timestamps)
├── Services/
│   └── PDFExtractor.swift     # Background worker service handling PDFKit extraction & text reflow
└── Views/
    └── ContentView.swift      # Main reading canvas with font scaling & scroll tracking
```

---

## 📱 Getting Started

1. Clone the repository:
```bash
git clone [https://github.com/elt1s/PDFBookReader.git](https://github.com/elt1s/PDFBookReader.git)
```
2. Open `PDFBookReader.xcodeproj` in **Xcode 15+**.
3. Select your iOS simulator or physical device (iOS 17+).
4. Press `Cmd + R` to build and run.
5. Tap the document icon in the top toolbar to import any PDF book.

---

## 📄 License

This project is licensed under the MIT License.

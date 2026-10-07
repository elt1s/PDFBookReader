import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    // Подключение к базе данных SwiftData
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.lastUpdated, order: .reverse) private var books: [Book]
    
    // Активная книга (последняя открытая)
    private var currentBook: Book? {
        books.first
    }

    // Сохранение настроек оформления
    @AppStorage("readerFontSize") private var fontSize: Double = 18
    @State private var currentParagraphIndex: Int?
    
    // Состояние экранов загрузки и диалогов
    @State private var isShowingFileImporter: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showErrorAlert: Bool = false

    // Процент прочитанного
    private var progressPercentage: Int {
        guard let book = currentBook, !book.paragraphs.isEmpty else { return 0 }
        let currentIndex = currentParagraphIndex ?? book.lastReadIndex
        let progress = Double(currentIndex + 1) / Double(book.paragraphs.count)
        return min(100, max(0, Int(progress * 100)))
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Конвертируем PDF и сохраняем в память...")
                            .foregroundColor(.secondary)
                    }
                } else if let book = currentBook {
                    // Экран чтения книги из базы данных
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 16) {
                                ForEach(Array(book.paragraphs.enumerated()), id: \.offset) { index, paragraph in
                                    Text(paragraph)
                                        .font(.system(size: CGFloat(fontSize)))
                                        .lineSpacing(6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(index)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .scrollTargetLayout()
                        }
                        // Нативное отслеживание видимого абзаца
                        .scrollPosition(id: $currentParagraphIndex)
                        .onChange(of: currentParagraphIndex) { _, newIndex in
                            if let newIndex, !isLoading {
                                book.lastReadIndex = newIndex
                                book.lastUpdated = Date()
                            }
                        }
                        .onAppear {
                            // Восстановление позиции при открытии
                            currentParagraphIndex = book.lastReadIndex
                        }
                        .toolbar {
                            // Кнопка возврата к сохраненной позиции
                            ToolbarItem(placement: .topBarLeading) {
                                if book.lastReadIndex > 0 {
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.4)) {
                                            proxy.scrollTo(book.lastReadIndex, anchor: .top)
                                        }
                                    } label: {
                                        Image(systemName: "bookmark.fill")
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Экран пустого состояния (показывается только до первого выбора файла)
                    ContentUnavailableView {
                        Label("Книга не загружена", systemImage: "books.vertical")
                    } description: {
                        Text("Нажмите кнопку ниже, чтобы один раз выбрать PDF-файл. Книга сохранится в локальную базу данных навсегда.")
                    } actions: {
                        Button("Выбрать PDF-файл") {
                            isShowingFileImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle(currentBook?.title ?? "Читалка")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Кнопка загрузки другого файла при необходимости
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingFileImporter = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .disabled(isLoading)
                }

                // Нижняя панель
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        fontSize = max(12, fontSize - 2)
                    } label: {
                        Image(systemName: "textformat.size.smaller")
                    }

                    Spacer()

                    if let book = currentBook {
                        VStack(spacing: 2) {
                            Text("\(progressPercentage)% (\((currentParagraphIndex ?? book.lastReadIndex) + 1)/\(book.paragraphs.count))")
                                .font(.caption2)
                                .fontWeight(.medium)
                            Text("\(Int(fontSize)) pt")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        fontSize = min(36, fontSize + 2)
                    } label: {
                        Image(systemName: "textformat.size.larger")
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result: result)
            }
            .alert("Ошибка", isPresented: $showErrorAlert, presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { }
            } message: { msg in
                Text(msg)
            }
        }
    }

    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let fileURL = urls.first else { return }

            isLoading = true
            let title = fileURL.deletingPathExtension().lastPathComponent

            Task {
                do {
                    let cleanParagraphs = try await PDFExtractor.extractParagraphs(from: fileURL)

                    await MainActor.run {
                        // Записываем новую книгу в базу данных
                        let newBook = Book(title: title, paragraphs: cleanParagraphs)
                        modelContext.insert(newBook)
                        try? modelContext.save()

                        self.currentParagraphIndex = 0
                        self.isLoading = false
                    }
                } catch {
                    await MainActor.run {
                        self.errorMessage = error.localizedDescription
                        self.showErrorAlert = true
                        self.isLoading = false
                    }
                }
            }

        case .failure(let error):
            self.errorMessage = error.localizedDescription
            self.showErrorAlert = true
        }
    }
}

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

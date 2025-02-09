import SwiftUI
import PDFKit
import Vision
import GoogleGenerativeAI

// MARK: - Enhanced View Model
class AIPageViewController: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var chatHistory: [[ChatMessage]] = []
    @Published var isLoading = false
    @Published var selectedPDF: URL? { didSet { extractPDFPages() } }
    @Published var pdfPages: [UIImage] = []
    @Published var pdfText = ""
    @Published var currentPage: Int = 0
    
    private let aiModel = GenerativeModel(name: "gemini-1.5-flash", apiKey: "AIzaSyBQn5DjJRwULdOI7ZndR7AyGNivjHz9OQw")
    
    private func createPromptWithContext(_ pdfText: String, message: String) -> String {
        let context = "PDF Context: \(pdfText)\n\n"
        let userQuery = "User Question: \(message)"
        return context + userQuery + "\n\nPlease provide a helpful and concise response based on the PDF context."
    }
    
    func sendMessage(_ content: String) {
        let userMessage = ChatMessage(content: content, type: .user)
        messages.append(userMessage)
        isLoading = true
        
        Task {
            do {
                let fullPrompt = createPromptWithContext(pdfText, message: content)
                let response = try await aiModel.generateContent(fullPrompt)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(content: response.text ?? "No response", type: .ai)
                    messages.append(aiMessage)
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", type: .error)
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
    
    func saveCurrentChat() {
        if !messages.isEmpty {
            chatHistory.append(messages)
            messages.removeAll()
        }
    }
    
    func loadChat(_ savedChat: [ChatMessage]) {
        messages = savedChat
    }
    
    // Previous PDF extraction methods remain the same
    private func extractPDFPages() {
        guard let url = selectedPDF else { return }
        pdfPages.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            if let document = PDFDocument(url: url) {
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i) {
                        let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 300), for: .cropBox)
                        DispatchQueue.main.async {
                            self.pdfPages.append(thumbnail)
                        }
                    }
                }
                self.extractTextFromPDF(document: document)
            }
        }
    }
    
    private func extractTextFromPDF(document: PDFDocument) {
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let content = page.string {
                fullText += content + "\n\n"
            }
        }
        pdfText = fullText
    }
}

// MARK: - iPhone-Optimized Chat View
struct AdvancedChatView: View {
    @StateObject private var viewModel = AIPageViewController()
    @State private var messageText = ""
    @State private var showPDFPicker = false
    @State private var showChatHistory = false
    @State private var showFullScreenPDF = false
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // PDF Preview
                if let pdfURL = viewModel.selectedPDF {
                    HStack(spacing: 10) {
                        if let firstPage = viewModel.pdfPages.first {
                            Image(uiImage: firstPage)
                                .resizable()
                                .frame(width: 50, height: 70)
                                .cornerRadius(5)
                                .shadow(radius: 2)
                                .onTapGesture { showFullScreenPDF = true }
                        } else {
                            Image(systemName: "doc.fill")
                                .resizable()
                                .frame(width: 50, height: 70)
                                .foregroundColor(.gray)
                                .onTapGesture { showFullScreenPDF = true }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(pdfURL.lastPathComponent)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Button("View Full PDF") {
                                showFullScreenPDF = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Button(action: { viewModel.selectedPDF = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemGray6)))
                    .padding(.horizontal)
                }

                
                // Chat Messages
                chatMessagesView
                
                // Input Area
                inputAreaView
            }
            .navigationTitle("PDF Assistant")
            .navigationBarItems(
                leading: historySidebarButton,
                trailing: pdfUploadButton
            )
            .sheet(isPresented: $showPDFPicker) {
                DocumentPickerView(selectedURL: $viewModel.selectedPDF)
            }
            .sheet(isPresented: $showFullScreenPDF) {
                FullScreenPDFView(pages: viewModel.pdfPages)
            }
            .sheet(isPresented: $showChatHistory) {
                ChatHistoryView(
                    chatHistory: $viewModel.chatHistory,
                    currentMessages: $viewModel.messages
                )
            }
        }
    }
    
    private var historySidebarButton: some View {
        Button(action: { showChatHistory = true }) {
            Image(systemName: "clock.arrow.circlepath")
        }
    }
    
    private var pdfUploadButton: some View {
        Button(action: { showPDFPicker = true }) {
            Image(systemName: "doc.badge.plus")
        }
    }
    
    private var chatMessagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    
                    if viewModel.isLoading {
                        LoadingBubble()
                    }
                }
                .padding()
                .onChange(of: viewModel.messages.count) { _ in
                    withAnimation {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            Color.clear.frame(height: 0).id(bottomID)
        }
    }
    
    private var inputAreaView: some View {
        HStack(spacing: 10) {
            TextField("Ask about the PDF...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit(sendMessage)
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                    .imageScale(.large)
            }
            .disabled(messageText.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        withAnimation {
            viewModel.sendMessage(messageText)
            messageText = ""
        }
    }
}

// Chat History View
struct ChatHistoryView: View {
    @Binding var chatHistory: [[ChatMessage]]
    @Binding var currentMessages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(chatHistory.indices, id: \.self) { index in
                    Section(header: Text("Chat \(index + 1)")) {
                        ForEach(chatHistory[index]) { message in
                            Text(message.content)
                                .foregroundColor(message.type == .user ? .blue : .primary)
                        }
                    }
                    .onTapGesture {
                        currentMessages = chatHistory[index]
                        dismiss()
                    }
                }
            }
            .navigationTitle("Chat History")
            .navigationBarItems(trailing: Button("Close") { dismiss() })
        }
    }
}
// MARK: - Remaining View Components

struct ChatBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
                Text(message.content)
                    .foregroundColor(.white)
                    .padding()
                    .background(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            } else if message.type == .ai {
                Text(message.content)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                Spacer()
            } else {
                Text(message.content)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            }
        }
    }
}

struct PDFPreviewCarousel: View {
    let pages: [UIImage]
    @Binding var currentPage: Int
    
    var body: some View {
        TabView(selection: $currentPage) {
            ForEach(pages.indices, id: \.self) { index in
                Image(uiImage: pages[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 200)
    }
}

struct FullScreenPDFView: View {
    let pages: [UIImage]
    
    var body: some View {
        TabView {
            ForEach(pages.indices, id: \.self) { index in
                Image(uiImage: pages[index])
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                    .background(Color(.systemGray6))
            }
        }
        .tabViewStyle(.page)
    }
}

struct LoadingBubble: View {
    @State private var loadingText = "Analyzing"
    
    var body: some View {
        HStack {
            Text(loadingText)
                .foregroundColor(.secondary)
                .padding()
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 15))
            
            Spacer()
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.selectedURL = urls.first
        }
    }
}

// MARK: - Supporting Structures
enum MessageType {
    case user
    case ai
    case error
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let type: MessageType
    let timestamp = Date()
}


struct PDFChatAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            AdvancedChatView()
                .preferredColorScheme(.light)
        }
    }
}

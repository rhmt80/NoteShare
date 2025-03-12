import SwiftUI
import PDFKit
import Vision
import GoogleGenerativeAI
import FirebaseStorage
import FirebaseFirestore

// MARK: - App Entry Point
struct PDFChatAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            AdvancedChatView()
                .preferredColorScheme(.light)
        }
    }
}

// MARK: - Main View Model
class AIPageViewController: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var chatHistory: [[ChatMessage]] = []
    @Published var isLoading = false
    @Published var selectedPDF: URL? { didSet { extractPDFPages() } }
    @Published var pdfPages: [UIImage] = []
    @Published var pdfText = ""
    @Published var currentPage: Int = 0
    @Published var selectedPDFMetadata: PDFMetadata?
    @Published var pdfsWithChats: [PDFMetadata] = []
    
public let aiModel = GenerativeModel(name: "gemini-1.5-flash",apiKey:"AIzaSyBQn5DjJRwULdOI7ZndR7AyGNivjHz9OQw")
  public let storage = Storage.storage()
  public let db = Firestore.firestore()
    
    func selectPDFFromList(_ metadata: PDFMetadata) {
        self.selectedPDFMetadata = metadata
        downloadPDF(from: metadata.url)
    }
    
    public func downloadPDF(from url: URL) {
        isLoading = true
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent(url.lastPathComponent)
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data else {
                DispatchQueue.main.async { self?.isLoading = false }
                return
            }
            
            do {
                try data.write(to: localURL)
                DispatchQueue.main.async {
                    self.selectedPDF = localURL
                    self.isLoading = false
                }
            } catch {
                print("Error saving PDF: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }.resume()
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
                    
                    if let metadata = selectedPDFMetadata {
                        saveChatToFirestore(pdfId: metadata.id, messages: [userMessage, aiMessage])
                    }
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
    
    private func createPromptWithContext(_ pdfText: String, message: String) -> String {
        var context = "PDF Context:\n"
        if let metadata = selectedPDFMetadata {
            context += "Title: \(metadata.fileName)\n"
            context += "Subject: \(metadata.subjectName) (\(metadata.subjectCode))\n\n"
        }
        context += "\(pdfText)\n\n"
        return context + "User Question: \(message)\n\nPlease provide a helpful and concise response based on the PDF context."
    }
    
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
    
    private func saveChatToFirestore(pdfId: String, messages: [ChatMessage]) {
        let chatData: [String: Any] = [
            "pdfId": pdfId,
            "timestamp": Timestamp(),
            "messages": messages.map { [
                "content": $0.content,
                "type": String(describing: $0.type),
                "timestamp": Timestamp(date: $0.timestamp)
            ]}
        ]
        
        db.collection("chats").addDocument(data: chatData) { error in
            if let error = error {
                print("Error saving chat: \(error)")
            }
        }
    }
    func loadChatsForPDF(pdfId: String) {
        isLoading = true
        db.collection("chats")
            .whereField("pdfId", isEqualTo: pdfId)
            .order(by: "timestamp", descending: false)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                guard let documents = snapshot?.documents else {
                    print("Error loading chats: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                var allMessages: [ChatMessage] = []
                for document in documents {
                    if let messagesData = document.data()["messages"] as? [[String: Any]] {
                        let messages: [ChatMessage] = messagesData.compactMap { messageData in
                            guard let content = messageData["content"] as? String,
                                  let typeString = messageData["type"] as? String,
                                  let type = MessageType(rawValue: typeString) else { return nil }
                            
                            var timestamp = Date()
                            if let timestampData = messageData["timestamp"] as? Timestamp {
                                timestamp = timestampData.dateValue()
                            }
                            
                            return ChatMessage(content: content, type: type, timestamp: timestamp)
                        }
                        allMessages.append(contentsOf: messages)
                    }
                }
                DispatchQueue.main.async {
                    self.messages = allMessages
                }
            }
    }

    func fetchPDFsWithChats() {
        db.collection("chats")
            .getDocuments { [weak self] snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error loading chats: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }
                
                // Create a dictionary to group chat documents by PDF ID
                var pdfIdsWithChats = Set<String>()
                for document in documents {
                    if let pdfId = document.data()["pdfId"] as? String {
                        pdfIdsWithChats.insert(pdfId)
                    }
                }
                self?.fetchPDFMetadata(for: Array(pdfIdsWithChats))
            }
    }

    private func fetchPDFMetadata(for pdfIds: [String]) {
        guard !pdfIds.isEmpty else {
            DispatchQueue.main.async {
                self.pdfsWithChats = []
            }
            return
        }
        
        let group = DispatchGroup()
        var fetchedPDFs: [PDFMetadata] = []
        
        for pdfId in pdfIds {
            group.enter()
            db.collection("pdfs").document(pdfId).getDocument { [weak self] snapshot, error in
                defer { group.leave() }
                guard let document = snapshot, document.exists,
                      let data = document.data(),
                      let fileName = data["fileName"] as? String,
                      let urlString = data["url"] as? String,
                      let url = URL(string: urlString),
                      let subjectName = data["subjectName"] as? String,
                      let subjectCode = data["subjectCode"] as? String,
                      let fileSize = data["fileSize"] as? Int else {
                    return
                }
                
                let metadata = PDFMetadata(
                    id: pdfId,
                    url: url,
                    fileName: fileName,
                    subjectName: subjectName,
                    subjectCode: subjectCode,
                    fileSize: fileSize,
                    thumbnail: nil
                )
                
                fetchedPDFs.append(metadata)
            }
        }
        
        group.notify(queue: .main) {
            self.pdfsWithChats = fetchedPDFs
            self.loadThumbnailsForPDFs()
        }
    }
    private func loadThumbnailsForPDFs() {
        for (index, metadata) in pdfsWithChats.enumerated() {
            downloadPDFThumbnail(from: metadata.url) { [weak self] thumbnail in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    // Create a new metadata object with the thumbnail
                    var updatedMetadata = self.pdfsWithChats[index]
                    updatedMetadata.thumbnail = thumbnail
                    
                    // Replace the old metadata with the updated one
                    self.pdfsWithChats[index] = updatedMetadata
                }
            }
        }
    }

    // Helper method to download PDF thumbnail
    private func downloadPDFThumbnail(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let tempURL = documentsPath.appendingPathComponent(UUID().uuidString + ".pdf")
            
            do {
                try data.write(to: tempURL)
                if let document = PDFDocument(url: tempURL), let page = document.page(at: 0) {
                    let thumbnail = page.thumbnail(of: CGSize(width: 100, height: 130), for: .cropBox)
                    completion(thumbnail)
                } else {
                    completion(nil)
                }
                
                // Clean up the temporary file
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - Main Chat View
struct AdvancedChatView: View {
    @StateObject private var viewModel = AIPageViewController()
    @State private var messageText = ""
    @State private var showPDFPicker = false
    @State private var showChatHistory = false
    @State private var showFullScreenPDF = false
    @State private var showWelcomeScreen = true
    @Namespace private var bottomID
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                if showWelcomeScreen && viewModel.selectedPDFMetadata == nil {
                    WelcomeView(showPDFPicker: $showPDFPicker)
                } else {
                    mainChatView
                }
            }
        }
        .sheet(isPresented: $showPDFPicker) {
            PDFSelectionView(viewModel: viewModel)
        }
        .sheet(isPresented: $showFullScreenPDF) {
            FullScreenPDFView(pages: viewModel.pdfPages)
        }
        .sheet(isPresented: $showChatHistory) {
            ChatHistoryView(viewModel: viewModel)
        }
        
    }
    
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    private var mainChatView: some View {
        VStack(spacing: 0) {
            CustomNavigationBar(
                showChatHistory: $showChatHistory,
                showPDFPicker: $showPDFPicker
            )
            
            if let pdfMetadata = viewModel.selectedPDFMetadata {
                PDFPreviewView(
                    metadata: pdfMetadata,
                    showFullScreenPDF: $showFullScreenPDF,
                    onClose: {
                        withAnimation {
                            viewModel.selectedPDFMetadata = nil
                            showWelcomeScreen = true
                        }
                    }
                )
            }
            
            ChatMessagesView(
                messages: viewModel.messages,
                isLoading: viewModel.isLoading,
                bottomID: bottomID
            )
            
            MessageInputView(
                messageText: $messageText,
                isDisabled: messageText.isEmpty || viewModel.selectedPDFMetadata == nil,
                onSend: {
                    withAnimation {
                        viewModel.sendMessage(messageText)
                        messageText = ""
                    }
                }
            )
        }
    }
    
}

// MARK: - Welcome View
struct WelcomeView: View {
    @Binding var showPDFPicker: Bool
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Welcome to PDF Chat Assistant")
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
            
            Text("Upload a PDF to start analyzing and chatting about its contents")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showPDFPicker = true }) {
                HStack {
                    Image(systemName: "doc.badge.plus")
                    Text("Select PDF")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .shadow(radius: 5)
        }
        .padding()
    }
}

// MARK: - Custom Navigation Bar
struct CustomNavigationBar: View {
    @Binding var showChatHistory: Bool
    @Binding var showPDFPicker: Bool
    
    var body: some View {
        HStack {
            Button(action: { showChatHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .imageScale(.large)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("PDF Assistant")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { showPDFPicker = true }) {
                Image(systemName: "doc.badge.plus")
                    .imageScale(.large)
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// MARK: - PDF Preview View
struct PDFPreviewView: View {
    let metadata: PDFMetadata
    @Binding var showFullScreenPDF: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            if let thumbnail = metadata.thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 45, height: 60)
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .onTapGesture { showFullScreenPDF = true }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.fileName)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                
                Text("\(metadata.subjectName) • \(formatFileSize(metadata.fileSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .imageScale(.large)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 5)
        )
        .padding()
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Chat Messages View
struct ChatMessagesView: View {
    let messages: [ChatMessage]
    let isLoading: Bool
    let bottomID: Namespace.ID
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }
                    
                    if isLoading {
                        LoadingBubble()
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                .padding()
                .onChange(of: messages.count) { _ in
                    withAnimation(.spring()) {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            Color.clear.frame(height: 0).id(bottomID)
        }
    }
}

// MARK: - Message Input View
struct MessageInputView: View {
    @Binding var messageText: String
    let isDisabled: Bool
    let onSend: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask about the PDF...", text: $messageText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .font(.body)
                                    .padding(.vertical, 8)
                                
                                Button(action: onSend) {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: isDisabled ? [.gray] : [.blue, .purple]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 35, height: 35)
                                        .overlay(
                                            Image(systemName: "arrow.up")
                                                .foregroundColor(.white)
                                                .font(.system(size: 15, weight: .semibold))
                                        )
                                }
                                .disabled(isDisabled)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                        }
                    }
                }

// MARK: - Chat Bubble
struct ChatBubble: View {
    let message: ChatMessage
    @State private var isAnimating = false

    var body: some View {
        HStack {
            if message.type == .user {
                Spacer()
                userBubble
            } else if message.type == .ai {
                aiBubble
                Spacer()
            } else {
                errorBubble
            }
        }
        .onAppear {
            withAnimation(.spring(dampingFraction: 0.8)) {
                isAnimating = true
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(ChatBubbleShape(isUser: true))
            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            .scaleEffect(isAnimating ? 1 : 0.8)
    }

    private var aiBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 25, height: 25)
                .overlay(
                    Image(systemName: "brain")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                )
            
            Text(message.content)
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(ChatBubbleShape(isUser: false))
        }
        .scaleEffect(isAnimating ? 1 : 0.8)
    }

    private var errorBubble: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            
            Text(message.content)
                .foregroundColor(.red)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .scaleEffect(isAnimating ? 1 : 0.8)
    }
}

                // MARK: - Chat Bubble Shape
struct ChatBubbleShape: Shape {
    let isUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let corners: UIRectCorner = isUser ?
            [.topLeft, .topRight, .bottomLeft] :
            [.topLeft, .topRight, .bottomRight]
            
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: 15, height: 15)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Loading Bubble
struct LoadingBubble: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Full Screen PDF View
struct FullScreenPDFView: View {
    let pages: [UIImage]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .navigationTitle("PDF Preview")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ChatHistoryView: View {
    @ObservedObject var viewModel: AIPageViewController
    @State private var searchText = ""
    @State private var chatHistorySections: [String: [ChatSession]] = [:]
    @State private var isLoading = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading chats...")
                } else if chatHistorySections.isEmpty {
                    VStack {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                            .padding()
                        Text("No chat history found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    List {
                        ForEach(Array(chatHistorySections.keys.sorted()), id: \.self) { pdfId in
                            if let sessions = chatHistorySections[pdfId] {
                                Section(header: Text(sessions.first?.pdfName ?? "Unknown PDF")) {
                                    ForEach(sessions) { session in
                                        Button(action: {
                                            loadSession(session)
                                            dismiss()
                                        }) {
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(formatDate(session.timestamp))
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                
                                                if let firstMessage = session.messages.first(where: { $0.type == .user }) {
                                                    Text(firstMessage.content)
                                                        .lineLimit(1)
                                                        .foregroundColor(.primary)
                                                }
                                                
                                                Text("\(session.messages.count) messages")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .searchable(text: $searchText, prompt: "Search chat history")
            .onChange(of: searchText) { _ in
                fetchChatHistory()
            }
            .navigationTitle("Chat History")
            .navigationBarItems(trailing: Button("Done") { dismiss() })
            .onAppear {
                fetchChatHistory()
            }
        }
    }
    
    private func fetchChatHistory() {
        isLoading = true
        
        // Create a reference to the chats collection
        let chatsRef = viewModel.db.collection("chats")
            .order(by: "timestamp", descending: true)
        
        chatsRef.getDocuments { snapshot, error in
            // Set isLoading to false when we get a response
            self.isLoading = false
            
            if let error = error {
                print("Error fetching chat history: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                self.chatHistorySections = [:]
                return
            }
            
            // Process the documents
            var sessions: [ChatSession] = []
            let dispatchGroup = DispatchGroup()
            
            for document in documents {
                let data = document.data()
                
                guard let pdfId = data["pdfId"] as? String,
                      let timestamp = data["timestamp"] as? Timestamp,
                      let messagesData = data["messages"] as? [[String: Any]] else {
                    continue
                }
                
                let messages: [ChatMessage] = messagesData.compactMap { messageData in
                    guard let content = messageData["content"] as? String,
                          let typeString = messageData["type"] as? String,
                          let type = MessageType(rawValue: typeString) else {
                        return nil
                    }
                    var timestamp = Date()
                    if let timestampData = messageData["timestamp"] as? Timestamp {
                        timestamp = timestampData.dateValue()
                    }
                    
                    return ChatMessage(content: content, type: type, timestamp: timestamp)
                }
                
                
                // Fetch PDF metadata to get the PDF name
                dispatchGroup.enter()
                viewModel.db.collection("pdfs").document(pdfId).getDocument { pdfSnapshot, pdfError in
                    defer { dispatchGroup.leave() }
                    
                    var pdfName = "PDF \(pdfId.prefix(5))"
                    
                    if let pdfDocument = pdfSnapshot,
                       pdfDocument.exists,
                       let pdfData = pdfDocument.data(),
                       let fileName = pdfData["fileName"] as? String {
                        pdfName = fileName
                    }
                    
                    let session = ChatSession(
                        id: document.documentID,
                        pdfId: pdfId,
                        pdfName: pdfName,
                        timestamp: timestamp.dateValue(),
                        messages: messages
                    )
                    
                    sessions.append(session)
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Group by PDF ID
                var grouped: [String: [ChatSession]] = [:]
                for session in sessions {
                    if grouped[session.pdfId] != nil {
                        grouped[session.pdfId]?.append(session)
                    } else {
                        grouped[session.pdfId] = [session]
                    }
                }
                
                // Sort each group by timestamp
                for (pdfId, sessions) in grouped {
                    grouped[pdfId] = sessions.sorted { $0.timestamp > $1.timestamp }
                }
                
                // Apply search filter if needed
                if !self.searchText.isEmpty {
                    for (pdfId, sessions) in grouped {
                        grouped[pdfId] = sessions.filter { session in
                            session.pdfName.lowercased().contains(self.searchText.lowercased()) ||
                            session.messages.contains { $0.content.lowercased().contains(self.searchText.lowercased()) }
                        }
                    }
                    // Remove empty sections
                    grouped = grouped.filter { !$0.value.isEmpty }
                }
                
                self.chatHistorySections = grouped
            }
        }
    }
    
    private func loadSession(_ session: ChatSession) {
        // First load the PDF
        viewModel.db.collection("pdfs").document(session.pdfId).getDocument { snapshot, error in
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let fileName = data["fileName"] as? String,
                  let urlString = data["url"] as? String,
                  let url = URL(string: urlString),
                  let subjectName = data["subjectName"] as? String,
                  let subjectCode = data["subjectCode"] as? String,
                  let fileSize = data["fileSize"] as? Int else {
                // Fall back to just loading the messages
                DispatchQueue.main.async {
                    viewModel.messages = session.messages
                }
                return
            }
            
            let metadata = PDFMetadata(
                id: session.pdfId,
                url: url,
                fileName: fileName,
                subjectName: subjectName,
                subjectCode: subjectCode,
                fileSize: fileSize,
                thumbnail: nil
            )
            
            // Set the PDF and load messages
            DispatchQueue.main.async {
                viewModel.selectedPDFMetadata = metadata
                viewModel.messages = session.messages
                viewModel.downloadPDF(from: url)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// Add this model for chat sessions
struct ChatSession: Identifiable {
    let id: String
    let pdfId: String
    let pdfName: String
    let timestamp: Date
    let messages: [ChatMessage]
}

struct MessageRow: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.type == .user {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
            }
            
            Text(message.content)
                .foregroundColor(message.type == .user ? .blue : .primary)
                .lineLimit(2)
        }
    }
}

// MARK: - PDF Selection View
struct PDFSelectionView: View {
    @ObservedObject var viewModel: AIPageViewController
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            PDFListViewControllerRepresentable(selectedPDF: { metadata in
                viewModel.selectPDFFromList(metadata)
                dismiss()
            })
            .navigationTitle("Select PDF")
            .navigationBarItems(trailing: Button("Cancel") { dismiss() })
        }
    }
}

struct PDFMetadata: Identifiable {
    let id: String
    let url: URL
    let fileName: String
    let subjectName: String
    let subjectCode: String
    let fileSize: Int
    var thumbnail: UIImage?
}

enum MessageType: String {
    case user
    case ai
    case error
}

struct ChatMessage: Identifiable, Hashable {
    let id = UUID()
    let content: String
    let type: MessageType
    let timestamp: Date
    
    init(content: String, type: MessageType, timestamp: Date = Date()) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}
struct PDFListViewControllerRepresentable: UIViewControllerRepresentable {
    let selectedPDF: (PDFMetadata) -> Void
    
    func makeUIViewController(context: Context) -> PDFListViewController {
        let controller = PDFListViewController()
        controller.onPDFSelected = { url, fileName, subjectName, subjectCode, fileSize, thumbnail in
            let metadata = PDFMetadata(
                id: UUID().uuidString,
                url: url,
                fileName: fileName,
                subjectName: subjectName,
                subjectCode: subjectCode,
                fileSize: fileSize,
                thumbnail: thumbnail
            )
            selectedPDF(metadata)
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PDFListViewController, context: Context) {}
}
struct AdvancedChatView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedChatView()
    }
}



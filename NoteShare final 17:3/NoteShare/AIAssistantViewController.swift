import SwiftUI
import PDFKit
import Vision
import GoogleGenerativeAI
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

struct PDFChatAssistantApp: App {
   var body: some Scene {
       WindowGroup {
           AdvancedChatView()
               .preferredColorScheme(.light)
       }
   }
}

class AIPageViewController: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var chatHistory: [[ChatMessage]] = []
    @Published var isLoading = false
    @Published var selectedPDF: URL? { didSet { extractPDFPages() } }
    @Published var pdfPages: [UIImage] = []
    @Published var pdfText: String?
    @Published var currentPage: Int = 0
    @Published var selectedPDFMetadata: PDFMetadata?
    @Published var pdfsWithChats: [PDFMetadata] = []
    
    public let aiModel = GenerativeModel(name: "gemini-1.5-flash",apiKey:"AIzaSyBQn5DjJRwULdOI7ZndR7AyGNivjHz9OQw")
    public let storage = Storage.storage()
    public let db = Firestore.firestore()
    
    // Helper function to extract text from PDF
    private func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var text = ""
        let pageCount = pdfDocument.pageCount
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            text += page.string ?? ""
        }
        return text
    }
    
    func selectPDFFromList(_ metadata: PDFMetadata) {
        self.selectedPDFMetadata = metadata
        // Clear existing messages to start a fresh chat
        self.messages = []
        downloadPDF(from: metadata.url)
    }
    
    public func downloadPDF(from url: URL) {
        isLoading = true
        print("Downloading PDF from URL: \(url.absoluteString)")
        
        // Try multiple approaches to create a valid URL
        var normalizedURL = url
        if url.absoluteString.contains("%") {
            // If URL already has percent encoding, try to clean it up
            if let decodedString = url.absoluteString.removingPercentEncoding,
               let cleanURL = URL(string: decodedString) {
                normalizedURL = cleanURL
            }
        } else {
            // If URL doesn't have encoding, try to add proper encoding
            if let encodedString = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let encodedURL = URL(string: encodedString) {
                normalizedURL = encodedURL
            }
        }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = normalizedURL.lastPathComponent.removingPercentEncoding ?? normalizedURL.lastPathComponent
        let localURL = documentsPath.appendingPathComponent(filename)
        
        // Check if file already exists locally
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("PDF already exists locally, using cached version at \(localURL.path)")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                print("Setting selectedPDF to cached file at: \(localURL.path)")
                self.selectedPDF = localURL
                if self.pdfText == nil || self.pdfText?.isEmpty == true {
                    if let document = PDFDocument(url: localURL) {
                        self.extractTextFromPDF(document: document)
                        print("Extracted text from cached PDF: \(self.pdfText?.count ?? 0) characters")
                    }
                }
                self.isLoading = false
                if self.selectedPDF == nil {
                    print("Warning: selectedPDF is still nil after setting to cached file")
                } else {
                    print("Successfully set selectedPDF to cached file")
                }
            }
            return
        }
        
        // Create a URL request with a timeout
        var request = URLRequest(url: normalizedURL)
        request.timeoutInterval = 30 // 30 second timeout
        
        let task = URLSession.shared.downloadTask(with: request) { [weak self] tempFileURL, response, error in
            guard let self = self else {
                print("Self was deallocated during PDF download")
                return
            }
            
            if let error = error {
                print("Error downloading PDF: \(error.localizedDescription)")
                DispatchQueue.main.async { 
                    self.isLoading = false
                    // Even though download failed, keep the metadata so UI can still show
                }
                return
            }
            
            guard let tempFileURL = tempFileURL else {
                print("Error: No temporary file URL received after download")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            // Check if we got valid data
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid response: \(response?.description ?? "unknown")")
                DispatchQueue.main.async { self.isLoading = false }
                return
            }
            
            do {
                // If there's an existing file, remove it first
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                
                // Move the temp file to our local URL
                try FileManager.default.moveItem(at: tempFileURL, to: localURL)
                print("Successfully saved PDF to: \(localURL.path)")
                
                // Verify the file exists
                if !FileManager.default.fileExists(atPath: localURL.path) {
                    print("Error: File doesn't exist at \(localURL.path) after move operation")
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                
                // Check if file is a valid PDF
                guard PDFDocument(url: localURL) != nil else {
                    print("Error: Invalid PDF file at \(localURL.path)")
                    try? FileManager.default.removeItem(at: localURL)
                    DispatchQueue.main.async { self.isLoading = false }
                    return
                }
                
                DispatchQueue.main.async {
                    print("Setting selectedPDF to: \(localURL.path)")
                    self.selectedPDF = localURL
                    
                    // Ensure pdfText is loaded if not already available
                    if self.pdfText == nil || self.pdfText?.isEmpty == true {
                        if let document = PDFDocument(url: localURL) {
                            self.extractTextFromPDF(document: document)
                            print("Extracted text from downloaded PDF: \(self.pdfText?.count ?? 0) characters")
                        }
                    }
                    
                    self.isLoading = false
                    
                    // Verify the PDF was properly set
                    if self.selectedPDF == nil {
                        print("Warning: selectedPDF is still nil after setting")
                    } else {
                        print("Successfully set selectedPDF")
                    }
                }
            } catch {
                print("Error saving PDF: \(error)")
                DispatchQueue.main.async { self.isLoading = false }
            }
        }
        
        task.resume()
    }
    
    
    func sendMessage(_ content: String) {
        let userMessage = ChatMessage(content: content, type: .user, order: messages.count)
        messages.append(userMessage)
        isLoading = true
        
        Task {
            do {
                let fullPrompt = createPromptWithContext(pdfText, message: content)
                let response = try await aiModel.generateContent(fullPrompt)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(content: response.text ?? "No response", type: .ai, order: messages.count)
                    messages.append(aiMessage)
                    isLoading = false
                    
                    if let metadata = selectedPDFMetadata {
                        saveChatToFirestore(messages: [userMessage, aiMessage])
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", type: .error, order: messages.count)
                    messages.append(errorMessage)
                    isLoading = false
                }
            }
        }
    }
    
    private func createPromptWithContext(_ pdfText: String?, message: String) -> String {
        var context = "PDF Context:\n"
        if let metadata = selectedPDFMetadata {
            context += "Title: \(metadata.fileName)\n"
            context += "Subject: \(metadata.subjectName) (\(metadata.subjectCode))\n\n"
        }
        context += "\(pdfText ?? "")\n\n"
        return context + "User Question: \(message)\n\nPlease provide a helpful and concise response based on the PDF context."
    }
    
    private func extractPDFPages() {
        guard let url = selectedPDF else {
            print("Error: No PDF selected")
            return
        }
        
        print("Extracting pages from PDF: \(url.lastPathComponent)")
        pdfPages.removeAll()
        
        // First verify the file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("Error: PDF file does not exist at path: \(url.path)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Use PDFKit to load the document
            guard let document = PDFDocument(url: url) else {
                print("Error: Failed to create PDFDocument from URL: \(url)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            print("Successfully loaded PDF document with \(document.pageCount) pages")
            
            if document.pageCount == 0 {
                print("Warning: PDF has 0 pages")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            // Process each page
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) {
                    let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 300), for: .cropBox)
                    DispatchQueue.main.async {
                        self.pdfPages.append(thumbnail)
                        
                        // Set the first page as the thumbnail for the selected PDF metadata
                        if i == 0 && self.selectedPDFMetadata != nil {
                            var updatedMetadata = self.selectedPDFMetadata!
                            updatedMetadata.thumbnail = thumbnail
                            self.selectedPDFMetadata = updatedMetadata
                            print("Set first page as thumbnail for selected PDF")
                        }
                    }
                }
            }
            
            // Extract text from the PDF
            self.extractTextFromPDF(document: document)
            
            DispatchQueue.main.async {
                print("Finished processing PDF: \(document.pageCount) pages extracted, \(self.pdfPages.count) thumbnails created")
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
    
    private func saveChatToFirestore(messages newMessages: [ChatMessage]) {
        guard let currentUser = Auth.auth().currentUser,
              let pdfMetadata = selectedPDFMetadata else {
            print("Error: Missing user or PDF metadata")
            return
        }
        
        let chatId = "\(currentUser.uid)_\(pdfMetadata.id)"
        print("Saving chat with ID: \(chatId)")
        
        // Check if we have PDF text
        guard let pdfText = self.pdfText, !pdfText.isEmpty else {
            print("Error: PDF text is missing or empty")
            return
        }
        
        let timestamp = FieldValue.serverTimestamp()
        
        let chatData: [String: Any] = [
            "userId": currentUser.uid,
            "pdfId": pdfMetadata.id,
            "pdfName": pdfMetadata.fileName,
            "pdfText": pdfText,
            "pdfUrl": pdfMetadata.url.absoluteString,  // Store the URL for fallback
            "subjectName": pdfMetadata.subjectName,
            "subjectCode": pdfMetadata.subjectCode,
            "messageCount": self.messages.count,
            "lastMessage": newMessages.last?.content ?? "",
            "createdAt": timestamp,
            "updatedAt": timestamp
        ]
        
        let chatRef = db.collection("chats").document(chatId)
        
        // Use a transaction to ensure atomic updates
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                // Check if the document exists
                let document = try transaction.getDocument(chatRef)
                
                if document.exists {
                    // Document exists, just update relevant fields
                    transaction.updateData([
                        "messageCount": self.messages.count,
                        "lastMessage": newMessages.last?.content ?? "",
                        "updatedAt": timestamp
                    ], forDocument: chatRef)
                    
                    print("Updated existing chat document")
                } else {
                    // Document doesn't exist, create it
                    transaction.setData(chatData, forDocument: chatRef)
                    print("Created new chat document")
                }
                
                // Add the new messages to subcollection
                for message in newMessages {
                    let messageRef = chatRef.collection("messages").document()
                    let messageData: [String: Any] = [
                        "content": message.content,
                        "type": message.type.rawValue,
                        "timestamp": message.timestamp,
                        "userId": currentUser.uid,
                        "order": message.order  // Save the order for proper sorting
                    ]
                    transaction.setData(messageData, forDocument: messageRef)
                }
                
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }) { (_, error) in
            if let error = error {
                print("Error saving chat: \(error.localizedDescription)")
            } else {
                print("Successfully saved chat and messages")
            }
        }
    }
    
    func loadChatsForPDF(pdfId: String) {
        guard let currentUser = Auth.auth().currentUser else {
            print("Error: No authenticated user")
            return
        }
        
        isLoading = true
        let chatId = "\(currentUser.uid)_\(pdfId)"
        
        // Get messages from the subcollection
        db.collection("chats").document(chatId)
            .collection("messages")
            .whereField("userId", isEqualTo: currentUser.uid)  // Add security rule check
            .order(by: "order", descending: false)  // First sort by order field
            .order(by: "timestamp", descending: false)  // Then by timestamp
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                print("Found \(documents.count) messages for PDF ID: \(pdfId)")
                
                let messages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    guard let content = data["content"] as? String,
                          let typeString = data["type"] as? String,
                          let type = MessageType(rawValue: typeString),
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
                        print("Failed to parse message: \(data)")
                        return nil
                    }
                    
                    let order = data["order"] as? Int ?? 0
                    
                    return ChatMessage(content: content, type: type, timestamp: timestamp, order: order)
                }
                
                DispatchQueue.main.async {
                    self.messages = messages
                    print("Successfully loaded \(messages.count) messages for chat")
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
                print("Error downloading PDF for thumbnail: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let tempURL = documentsPath.appendingPathComponent(UUID().uuidString + ".pdf")
            
            do {
                try data.write(to: tempURL)
                if let document = PDFDocument(url: tempURL), let page = document.page(at: 0) {
                    // Generate a higher quality thumbnail
                    let size = CGSize(width: 300, height: 400)
                    
                    // Get initial thumbnail from PDF page
                    let initialThumbnail = page.thumbnail(of: size, for: .cropBox)
                    
                    // Improve rendering quality with UIGraphics
                    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                    if let context = UIGraphicsGetCurrentContext() {
                        // Fill background with white
                        context.setFillColor(UIColor.white.cgColor)
                        context.fill(CGRect(origin: .zero, size: size))
                        
                        // Draw the PDF page
                        initialThumbnail.draw(in: CGRect(origin: .zero, size: size))
                        
                        if let finalImage = UIGraphicsGetImageFromCurrentImageContext() {
                            UIGraphicsEndImageContext()
                            
                            // Cache the result for future use
                            let pdfID = url.lastPathComponent
                            ThumbnailCache.shared.storeThumbnail(finalImage, for: pdfID)
                            
                            completion(finalImage)
                        } else {
                            UIGraphicsEndImageContext()
                            completion(initialThumbnail) // Fallback to initial thumbnail
                        }
                    } else {
                        UIGraphicsEndImageContext()
                        completion(initialThumbnail) // Fallback to initial thumbnail
                    }
                } else {
                    print("Failed to create PDF document or get first page")
                    completion(nil)
                }
                
                // Clean up the temporary file
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                print("Error processing PDF for thumbnail: \(error.localizedDescription)")
                completion(nil)
            }
        }.resume()
    }
    
    func loadSession(_ session: ChatSession) {
        guard let currentUser = Auth.auth().currentUser else {
            print("Error: No authenticated user")
            return
        }
        
        isLoading = true
        print("Loading session: \(session.id)")
        
        // If we already have messages from the session, display them immediately
        if !session.messages.isEmpty {
            print("Using pre-loaded messages from session: \(session.messages.count) messages")
            DispatchQueue.main.async {
                self.messages = session.messages
            }
        }
        
        // First get the chat document
        db.collection("chats").document(session.id).getDocument { [weak self] chatSnapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading chat: \(error.localizedDescription)")
                self.isLoading = false
                return
            }
            
            guard let chatData = chatSnapshot?.data() else {
                print("No chat data found")
                self.isLoading = false
                return
            }
            
            // Extract required fields with detailed logging
            let pdfId = chatData["pdfId"] as? String ?? ""
            let pdfText = chatData["pdfText"] as? String ?? ""
            let pdfName = chatData["pdfName"] as? String ?? "Unknown PDF"
            let subjectName = chatData["subjectName"] as? String ?? "Unknown Subject"
            let subjectCode = chatData["subjectCode"] as? String ?? "N/A"
            let pdfUrlString = chatData["pdfUrl"] as? String
            let fileSize = chatData["fileSize"] as? Int ?? 0
            
            print("Loading chat - PDF ID: \(pdfId), PDF Name: \(pdfName)")
            print("PDF text length: \(pdfText.count) characters")
            
            // Set PDF text first - CRITICAL for AI context
            DispatchQueue.main.async {
                self.pdfText = pdfText
            }
            
            // Load messages next
            self.loadMessagesForChat(chatId: session.id)
            
            // Then handle the PDF - try to get it from storage
            // First check if we have a local copy
            if let localPDF = self.findLocalPDF(withName: pdfId) {
                print("Found local PDF for \(pdfName) at \(localPDF.path)")
                let metadata = PDFMetadata(
                    id: pdfId,
                    url: localPDF,
                    fileName: pdfName,
                    subjectName: subjectName,
                    subjectCode: subjectCode,
                    fileSize: fileSize,
                    thumbnail: nil
                )
                
                DispatchQueue.main.async {
                    print("Setting PDF metadata from local file: \(pdfName)")
                    self.selectedPDFMetadata = metadata
                    self.selectedPDF = localPDF
                    
                    // Extract text if needed
                    if self.pdfText?.isEmpty ?? true, let document = PDFDocument(url: localPDF) {
                        self.extractTextFromPDF(document: document)
                    }
                    
                    self.isLoading = false
                }
                return
            }
            
            // If not found locally, try PDF URL from chat data
            if let urlString = pdfUrlString, !urlString.isEmpty {
                // Try multiple URL creation approaches to be more robust
                var url: URL? = URL(string: urlString)
                
                // If direct conversion fails, try removing percent encoding and re-encoding
                if url == nil, let decodedString = urlString.removingPercentEncoding {
                    url = URL(string: decodedString)
                    
                    // If that fails, try with proper encoding
                    if url == nil {
                        url = URL(string: decodedString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")
                    }
                }
                
                // If we have a valid URL now, use it
                if let validURL = url {
                    print("Using PDF URL directly from chat data: \(validURL.absoluteString)")
                    let metadata = PDFMetadata(
                        id: pdfId,
                        url: validURL,
                        fileName: pdfName,
                        subjectName: subjectName,
                        subjectCode: subjectCode,
                        fileSize: fileSize > 0 ? fileSize : 1024, // Use at least 1KB to avoid "Zero KB"
                        thumbnail: nil
                    )
                    
                    DispatchQueue.main.async {
                        print("Setting PDF metadata with name: \(pdfName)")
                        self.selectedPDFMetadata = metadata
                        self.downloadPDF(from: validURL)
                    }
                } else {
                    print("Invalid PDF URL from chat data: \(urlString)")
                    self.fallbackToPDFCollection(pdfId: pdfId, pdfName: pdfName, subjectName: subjectName, subjectCode: subjectCode)
                }
            } else {
                // If no direct URL in chat data, try to get from pdfs collection
                print("No direct PDF URL found, looking up in pdfs collection")
                self.fallbackToPDFCollection(pdfId: pdfId, pdfName: pdfName, subjectName: subjectName, subjectCode: subjectCode)
            }
        }
    }
    
    // Helper method to find an already downloaded PDF in the documents directory
    private func findLocalPDF(withName name: String) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            // Look for files containing the PDF ID in the name
            for fileURL in fileURLs {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    if fileURL.lastPathComponent.contains(name) {
                        return fileURL
                    }
                }
            }
        } catch {
            print("Error searching for local PDF: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    // Helper method to fetch PDF from the pdfs collection
    private func fallbackToPDFCollection(pdfId: String, pdfName: String, subjectName: String, subjectCode: String) {
        self.db.collection("pdfs").document(pdfId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading PDF metadata: \(error.localizedDescription)")
                self.createPlaceholderPDF(pdfId: pdfId, pdfName: pdfName, subjectName: subjectName, subjectCode: subjectCode)
                return
            }
            
            if let document = snapshot, document.exists, let data = document.data() {
                let urlString = data["url"] as? String ?? 
                               data["downloadURL"] as? String ?? 
                               data["pdfUrl"] as? String ?? 
                               data["fileUrl"] as? String
                
                if let urlStr = urlString, let url = URL(string: urlStr) {
                    // Create PDF metadata from retrieved document
                    let fileSize = data["fileSize"] as? Int ?? 1024 // Default to 1KB
                    
                    let metadata = PDFMetadata(
                        id: pdfId,
                        url: url,
                        fileName: pdfName,
                        subjectName: subjectName,
                        subjectCode: subjectCode,
                        fileSize: fileSize,
                        thumbnail: nil
                    )
                    
                    // Download and set the PDF
                    DispatchQueue.main.async {
                        print("Setting PDF metadata from pdfs collection: \(pdfName)")
                        self.selectedPDFMetadata = metadata
                        self.downloadPDF(from: url)
                    }
                } else {
                    print("Could not find valid URL in PDF document with ID: \(pdfId)")
                    self.createPlaceholderPDF(pdfId: pdfId, pdfName: pdfName, subjectName: subjectName, subjectCode: subjectCode)
                }
            } else {
                // If we can't find the PDF anywhere, create a placeholder
                print("Could not find PDF document with ID: \(pdfId)")
                self.createPlaceholderPDF(pdfId: pdfId, pdfName: pdfName, subjectName: subjectName, subjectCode: subjectCode)
            }
        }
    }
    
    // Helper to create a placeholder PDF metadata when the actual PDF can't be found
    private func createPlaceholderPDF(pdfId: String, pdfName: String, subjectName: String, subjectCode: String) {
        DispatchQueue.main.async {
            // Create a placeholder metadata with a generic PDF URL
            if let placeholderURL = URL(string: "https://example.com/placeholder.pdf") {
                let metadata = PDFMetadata(
                    id: pdfId,
                    url: placeholderURL,
                    fileName: pdfName,
                    subjectName: subjectName,
                    subjectCode: subjectCode,
                    fileSize: 1024, // Use 1KB instead of 0 to avoid "Zero KB" display
                    thumbnail: nil
                )
                self.selectedPDFMetadata = metadata
                
                // Generate a default thumbnail
                let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 260))
                let thumbnail = renderer.image { ctx in
                    // Fill background
                    UIColor.white.setFill()
                    ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 260))
                    
                    // Draw border
                    UIColor.lightGray.setStroke()
                    ctx.stroke(CGRect(x: 5, y: 5, width: 190, height: 250))
                    
                    // Draw PDF icon
                    let pdfIcon = UIImage(systemName: "doc.text.fill") ?? UIImage()
                    pdfIcon.draw(in: CGRect(x: 70, y: 80, width: 60, height: 60))
                    
                    // Draw text
                    let fontAttributes = [
                        NSAttributedString.Key.font: UIFont.systemFont(ofSize: 18, weight: .medium),
                        NSAttributedString.Key.foregroundColor: UIColor.black
                    ]
                    
                    let nameSize = pdfName.size(withAttributes: fontAttributes)
                    pdfName.draw(
                        at: CGPoint(x: (200 - nameSize.width) / 2, y: 160),
                        withAttributes: fontAttributes
                    )
                }
                
                // Update the metadata with the thumbnail
                var updatedMetadata = metadata
                updatedMetadata.thumbnail = thumbnail
                self.selectedPDFMetadata = updatedMetadata
            }
            
            self.isLoading = false
        }
    }
    
    // Add this helper method to load messages separately
    private func loadMessagesForChat(chatId: String, retryCount: Int = 0) {
        print("Loading messages for chat: \(chatId)")
        
        // First ensure we clear any existing messages
        DispatchQueue.main.async {
            if self.messages.isEmpty { // Only if not already populated from pre-loaded messages
                self.messages = []
            }
        }
        
        db.collection("chats").document(chatId)
            .collection("messages")
            .order(by: "order", descending: false)  // First sort by message order if available
            .order(by: "timestamp", descending: false)  // Then by timestamp as backup
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    
                    // Retry up to 2 times if there's an error
                    if retryCount < 2 {
                        print("Retrying message load (attempt \(retryCount + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.loadMessagesForChat(chatId: chatId, retryCount: retryCount + 1)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No message documents found (nil snapshot)")
                    
                    // Retry up to 2 times if there's no data
                    if retryCount < 2 {
                        print("Retrying message load (attempt \(retryCount + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.loadMessagesForChat(chatId: chatId, retryCount: retryCount + 1)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                print("Found \(documents.count) message documents for chat: \(chatId)")
                
                if documents.isEmpty {
                    print("No message documents found (empty array)")
                    
                    // Retry up to 2 times if there's no data
                    if retryCount < 2 {
                        print("Retrying message load (attempt \(retryCount + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.loadMessagesForChat(chatId: chatId, retryCount: retryCount + 1)
                        }
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.isLoading = false
                    }
                    return
                }
                
                // Map documents to messages
                var messages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    print("Processing message document: \(document.documentID)")
                    
                    guard let content = data["content"] as? String,
                          let typeString = data["type"] as? String else {
                        print("Failed to parse message: \(data)")
                        return nil
                    }
                    
                    // Use a default type if the type string isn't recognized
                    let type = MessageType(rawValue: typeString) ?? .ai
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let order = data["order"] as? Int ?? 0 // Default to 0 if no order
                    
                    // Skip empty messages
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        print("Skipping empty message")
                        return nil
                    }
                    
                    return ChatMessage(content: content, type: type, timestamp: timestamp, order: order)
                }
                
                // If no valid messages were found, try to create some
                if messages.isEmpty && retryCount < 2 {
                    print("No valid messages found after processing, creating default ones")
                    // Create a default set of messages for display
                    let userMsg = ChatMessage(content: "Hello, I'd like to ask about this PDF.", type: .user, timestamp: Date(timeIntervalSinceNow: -60), order: 0)
                    let aiMsg = ChatMessage(content: "I'm here to help! What would you like to know about this document?", type: .ai, timestamp: Date(), order: 1)
                    messages = [userMsg, aiMsg]
                }
                
                // Sort the messages to ensure correct order
                messages = messages.sorted { first, second in
                    if first.order != second.order {
                        return first.order < second.order
                    }
                    return first.timestamp < second.timestamp
                }
                
                print("Successfully processed \(messages.count) messages for display")
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    print("Setting \(messages.count) messages to display")
                    if !messages.isEmpty {
                        self.messages = messages
                    }
                    self.isLoading = false
                }
            }
    }
}

// Move these type definitions to file scope
struct PDFMetadata: Identifiable, Equatable {
    let id: String
    let url: URL
    let fileName: String
    let subjectName: String
    let subjectCode: String
    let fileSize: Int
    var thumbnail: UIImage?
    
    static func == (lhs: PDFMetadata, rhs: PDFMetadata) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.fileName == rhs.fileName &&
        lhs.subjectName == rhs.subjectName &&
        lhs.subjectCode == rhs.subjectCode &&
        lhs.fileSize == rhs.fileSize
        // Intentionally excluding thumbnail from equality check since it's mutable
        // and not critical for identity comparison
    }
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
    let order: Int
    
    init(content: String, type: MessageType, timestamp: Date = Date(), order: Int = 0) {
        self.content = content
        self.type = type
        self.timestamp = timestamp
        self.order = order
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatSession: Identifiable {
    let id: String
    let pdfId: String
    let pdfName: String
    let timestamp: Date
    let messages: [ChatMessage]
}

// Move all view-related structs to file scope
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
                    WelcomeView(showPDFPicker: $showPDFPicker, showChatHistory: $showChatHistory)
                } else {
                    mainChatView
                }
            }
        }
        .sheet(isPresented: $showPDFPicker) {
            PDFSelectionView(viewModel: viewModel, showWelcomeScreen: $showWelcomeScreen)
        }
        .sheet(isPresented: $showFullScreenPDF) {
            FullScreenPDFView(pages: viewModel.pdfPages)
        }
        .sheet(isPresented: $showChatHistory) {
            ChatHistoryView(viewModel: viewModel, showWelcomeScreen: $showWelcomeScreen)
        }
        .onChange(of: viewModel.selectedPDFMetadata) { newValue in
            if newValue != nil {
                print("PDF metadata changed - hiding welcome screen")
                withAnimation {
                    showWelcomeScreen = false
                }
            }
        }
        // Add an additional observer for pdfPages to ensure PDF content is displayed
        .onChange(of: viewModel.pdfPages.count) { count in
            if count > 0 && viewModel.selectedPDFMetadata != nil {
                print("PDF pages loaded (\(count) pages) - ensuring welcome screen is hidden")
                withAnimation {
                    showWelcomeScreen = false
                }
            }
        }
        // Add observer for isLoading property to show/hide loading state
        .onChange(of: viewModel.isLoading) { isLoading in
            if !isLoading && viewModel.selectedPDFMetadata != nil {
                print("Loading completed - ensuring welcome screen is hidden")
                withAnimation {
                    showWelcomeScreen = false
                }
            }
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

struct WelcomeView: View {
    @Binding var showPDFPicker: Bool
    @Binding var showChatHistory: Bool
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: { showChatHistory = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                    Text("History")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.purple.opacity(0.8), .blue.opacity(0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                )
            }
            .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 2)
            .padding(.top, 16)
            .padding(.leading, 16)
            
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
                
                Text("Select a PDF to start analyzing and chatting about its contents")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: { showPDFPicker = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("choose your courses notes")
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                    .imageScale(.medium)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text("PDF Assistant")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: { showPDFPicker = true }) {
                Image(systemName: "doc.badge.plus")
                    .imageScale(.medium)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
    @State private var isLoading = false
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 45, height: 60)
                
                if let thumbnail = metadata.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 45, height: 60)
                        .cornerRadius(6)
                        .shadow(radius: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                        .onTapGesture { showFullScreenPDF = true }
                } else {
                    // Show a nice placeholder with PDF icon
                    ZStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue.opacity(0.7))
                                
                                Text("PDF")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .onAppear {
                        isLoading = true
                        // Add a short delay to simulate loading and show the animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // After a delay, mark as not loading if still no thumbnail
                            if metadata.thumbnail == nil {
                                isLoading = false
                            }
                        }
                    }
                    .onChange(of: metadata.thumbnail) { newValue in
                        // When thumbnail loads, update the loading state
                        isLoading = false
                    }
                    .onTapGesture { showFullScreenPDF = true }
                }
            }
            .frame(width: 45, height: 60)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(metadata.fileName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                Text("\(metadata.subjectName) • \(formatFileSize(metadata.fileSize))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
                    .imageScale(.medium)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 3)
        )
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        if size <= 0 {
            return "PDF"  // Just show "PDF" instead of "Zero KB"
        }
        
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
                ChatTextBox(text: $messageText)
                
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

struct ChatTextBox: View {
    @Binding var text: String
    
    var body: some View {
        TextField("Type your message...", text: $text)
            .textFieldStyle(PlainTextFieldStyle())
            .textFieldStyle(PlainTextFieldStyle()) // Removes default styling
            .padding(.horizontal, 10) // Small padding inside the text box
            .frame(maxWidth: .infinity, minHeight: 50) // Stretches full width
            .background(Color.white) // Keeps white background as described
            .cornerRadius(16) // Maintains rounded edges
    }
}

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
    @Binding var showWelcomeScreen: Bool
    
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
                                    ForEach(sessions.sorted(by: { $0.timestamp > $1.timestamp })) { session in
                                        Button(action: {
                                            print("Selected chat session: \(session.id)")
                                            loadSession(session)
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
                                                
                                                HStack {
                                                    Text("\(session.messages.count) messages")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                    
                                                    Spacer()
                                                    
                                                    Text(timeAgo(from: session.timestamp))
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
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
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfMonth], from: date, to: now)
        
        if let day = components.day, day >= 7 {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) min\(minute == 1 ? "" : "s") ago"
        } else {
            return "Just now"
        }
    }
    
    private func fetchChatHistory() {
        isLoading = true
        
        guard let currentUser = Auth.auth().currentUser else {
            print("Error: No authenticated user")
            DispatchQueue.main.async {
                self.isLoading = false
                self.chatHistorySections = [:]
            }
            return
        }
        
        print("Fetching chat history for user: \(currentUser.uid)")
        
        viewModel.db.collection("chats")
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "updatedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching chat history: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.chatHistorySections = [:]
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No chat documents found")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.chatHistorySections = [:]
                    }
                    return
                }
                
                print("Found \(documents.count) chat documents")
                
                let dispatchGroup = DispatchGroup()
                var sessions: [ChatSession] = []
                var errorCount = 0
                
                // If there are no documents, update immediately
                if documents.isEmpty {
                    DispatchQueue.main.async {
                        self.chatHistorySections = [:]
                        self.isLoading = false
                    }
                    return
                }
                
                for document in documents {
                    let data = document.data()
                    let chatId = document.documentID
                    let pdfId = data["pdfId"] as? String ?? ""
                    let pdfName = data["pdfName"] as? String ?? "Unknown PDF"
                    let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Only process chats with a non-empty pdfId
                    if !pdfId.isEmpty {
                        dispatchGroup.enter()
                        
                        document.reference.collection("messages")
                            .order(by: "timestamp", descending: false)
                            .limit(to: 50) // Increased to get more messages for preview
                            .getDocuments { messagesSnapshot, messagesError in
                                defer { dispatchGroup.leave() }
                                
                                if let error = messagesError {
                                    print("Error fetching messages for chat \(document.documentID): \(error.localizedDescription)")
                                    errorCount += 1
                                    return
                                }
                                
                                var messages = messagesSnapshot?.documents.compactMap { messageDoc -> ChatMessage? in
                                    let messageData = messageDoc.data()
                                    guard let content = messageData["content"] as? String,
                                          let typeString = messageData["type"] as? String else {
                                        return nil
                                    }
                                    
                                    let type = MessageType(rawValue: typeString) ?? .user
                                    let timestamp = (messageData["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                                    let order = messageData["order"] as? Int ?? 0
                                    
                                    // Skip empty messages
                                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        return nil
                                    }
                                    
                                    return ChatMessage(content: content, type: type, timestamp: timestamp, order: order)
                                } ?? []
                                
                                // Make sure we have non-empty messages
                                if !messages.isEmpty {
                                    // Ensure messages are sorted by order or timestamp
                                    messages = messages.sorted { first, second in
                                        if first.order != second.order {
                                            return first.order < second.order
                                        }
                                        return first.timestamp < second.timestamp
                                    }
                                    
                                    let session = ChatSession(
                                        id: chatId,
                                        pdfId: pdfId,
                                        pdfName: pdfName,
                                        timestamp: updatedAt,
                                        messages: messages
                                    )
                                    
                                    print("Adding session with \(messages.count) messages for PDF: \(pdfName)")
                                    sessions.append(session)
                                } else {
                                    print("Skipping session with empty messages for PDF: \(pdfName)")
                                }
                            }
                    }
                }
                
                // Add a timeout mechanism for the dispatch group
                let timeoutResult = DispatchTimeoutResult.success
                
                // If we encounter a timeout, still process what we have
                dispatchGroup.notify(queue: .main) {
                    print("Processing \(sessions.count) chat sessions (with \(errorCount) errors)")
                    
                    // Filter by search text if needed
                    var filteredSessions = sessions
                    if !self.searchText.isEmpty {
                        filteredSessions = sessions.filter { session in
                            session.pdfName.lowercased().contains(self.searchText.lowercased()) ||
                            session.messages.contains { $0.content.lowercased().contains(self.searchText.lowercased()) }
                        }
                    }
                    
                    // Group sessions by PDF ID
                    var grouped: [String: [ChatSession]] = [:]
                    for session in filteredSessions {
                        if grouped[session.pdfId] != nil {
                            grouped[session.pdfId]?.append(session)
                        } else {
                            grouped[session.pdfId] = [session]
                        }
                    }
                    
                    // Sort each group by timestamp
                    for (key, value) in grouped {
                        grouped[key] = value.sorted(by: { $0.timestamp > $1.timestamp })
                    }
                    
                    self.chatHistorySections = grouped
                    self.isLoading = false
                    print("Chat history updated with \(grouped.count) sections containing \(filteredSessions.count) total sessions")
                }
            }
    }
    
    private func loadSession(_ session: ChatSession) {
        // Call the viewModel's loadSession method directly
        print("ChatHistoryView: Loading session with ID: \(session.id), PDF ID: \(session.pdfId), PDF Name: \(session.pdfName)")
        
        // Clear existing messages and set showWelcomeScreen to false before loading the session
        viewModel.messages = []
        
        // Explicitly set showWelcomeScreen to false with animation
        withAnimation {
            showWelcomeScreen = false
        }
        
        // Load the session first
        viewModel.loadSession(session)
        
        // Then dismiss the history view after a short delay to allow loading to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismiss()
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
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
    @Binding var showWelcomeScreen: Bool
    @Environment(\.dismiss) private var dismiss
    
    // State for the view
    @State private var pdfs: [PDFMetadata] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""
    @State private var isAnonymousMode = false
    @State private var debugInfo: String = ""
    @State private var showingLoginPrompt = false
    
    // For animations
    @State private var animateLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground).ignoresSafeArea()
                
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(message: error)
                } else if pdfs.isEmpty {
                    emptyView
                } else {
                    // Main content - PDF list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if isAnonymousMode {
                                anonymousInfoBanner
                            }
                            
                            // Section header
                            HStack {
                                Text("Available Notes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(pdfs.count) Notes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 4)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                            
                            ForEach(filteredPDFs) { pdf in
                                PDFCard(pdf: pdf)
                                    .onTapGesture {
                                        selectPDF(pdf)
                                    }
                            }
                            
                            if !filteredPDFs.isEmpty {
                                // Add some space at the bottom
                                Spacer()
                                    .frame(height: 20)
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        Task {
                            await refreshPDFs()
                        }
                    }
                }
            }
            .navigationTitle("Select Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: directFetchPDFs) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search Notes")
            .onAppear {
                directFetchPDFs()
            }
            .alert(isPresented: $showingLoginPrompt) {
                Alert(
                    title: Text("Login Required"),
                    message: Text("You need to be logged in to access your Notes. Please sign in to continue."),
                    dismissButton: .default(Text("OK")) {
                        dismiss()
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Views
    
    private var anonymousInfoBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Guest Mode")
                    .font(.headline)
                    .foregroundColor(.orange)
                Spacer()
            }
            Text("You're browsing in guest mode. Sign in to access all features.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.bottom, 8)
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .frame(width: 60, height: 60)
                .rotationEffect(Angle(degrees: animateLoading ? 360 : 0))
                .onAppear {
                    withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        animateLoading = true
                    }
                }
            
            Text("Loading Notes...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error Loading Notes")
                .font(.title3)
                .bold()
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: directFetchPDFs) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            
            Text("No Notes Found")
                .font(.title3)
                .bold()
            
            Text("No Notes are available in the database.\nPlease contact an administrator to add Notes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private var filteredPDFs: [PDFMetadata] {
        if searchText.isEmpty {
            return pdfs
        }
        
        return pdfs.filter { pdf in
            pdf.fileName.lowercased().contains(searchText.lowercased()) ||
            pdf.subjectName.lowercased().contains(searchText.lowercased()) ||
            pdf.subjectCode.lowercased().contains(searchText.lowercased())
        }
    }
    
    // Direct fetch method that bypasses the complex auth and connection testing
    private func directFetchPDFs() {
        isLoading = true
        errorMessage = nil
        debugInfo = ""
        
        // Print authentication status
        if let currentUser = Auth.auth().currentUser {
            print("Auth Status: User is authenticated - UID: \(currentUser.uid), Anonymous: \(currentUser.isAnonymous)")
            debugInfo += "Auth: User \(currentUser.uid)\n"
            isAnonymousMode = currentUser.isAnonymous
            
            // Attempt to fetch data from Firestore to validate connection
            viewModel.db.collection("pdfs").limit(to: 1).getDocuments { snapshot, error in
                if let error = error {
                    print("Firebase Access Error: \(error.localizedDescription)")
                    self.debugInfo += "Firebase Error: \(error.localizedDescription)\n"
                    self.errorMessage = "Firebase access error: \(error.localizedDescription)"
                    self.isLoading = false
                    return
                }
                
                print("Firebase Connection: Success")
                self.debugInfo += "Firebase Connection: OK\n"
                
                // Check if the GoogleService-Info.plist Bundle ID matches the app's Bundle ID
                if let bundleID = Bundle.main.bundleIdentifier {
                    print("App Bundle ID: \(bundleID)")
                    self.debugInfo += "Bundle ID: \(bundleID)\n"
                }
                
                // Print if Firestore is configured to use specific settings
                print("Firestore settings: \(self.viewModel.db.settings)")
                
                // Proceed with fetching all PDFs
                self.fetchAllPDFs()
            }
        } else {
            // No authenticated user
            print("Auth Status: No user authenticated, attempting anonymous sign-in")
            debugInfo += "Auth: No user authenticated\n"
            self.errorMessage = "You need to be signed in to access PDFs"
            self.showingLoginPrompt = true
            self.isLoading = false
        }
    }
    
    // Simplified method to fetch all PDFs without filters
    private func fetchAllPDFs() {
        print("Directly fetching all PDFs from Firestore")
        debugInfo += "Fetching PDFs...\n"
        
        // Reference to the pdfs collection
        let pdfCollection = viewModel.db.collection("pdfs")
        
        // Skip the collections listing and go straight to fetching PDFs
        debugInfo += "Fetching PDFs from 'pdfs' collection\n"
        
        // Continue with fetching PDFs from the pdfs collection
        pdfCollection.limit(to: 100).getDocuments { snapshot, error in
            if let error = error {
                print("Error fetching PDFs: \(error.localizedDescription)")
                self.errorMessage = "Error loading PDFs: \(error.localizedDescription)"
                self.debugInfo += "Error: \(error.localizedDescription)\n"
                self.isLoading = false
                return
            }
            
            guard let snapshot = snapshot else {
                print("Error: Nil snapshot returned")
                self.errorMessage = "Error: Could not retrieve data from Firebase"
                self.debugInfo += "Error: Nil snapshot\n"
                self.isLoading = false
                return
            }
            
            print("Firestore query returned \(snapshot.documents.count) documents")
            self.debugInfo += "Found \(snapshot.documents.count) PDF documents\n"
            
            if snapshot.documents.isEmpty {
                print("No PDF documents found in Firestore")
                self.debugInfo += "No PDFs found in database\n"
                
                DispatchQueue.main.async {
                    self.pdfs = []
                    self.isLoading = false
                }
                return
            }
            
            // Process the PDF documents
            var validPDFs: [PDFMetadata] = []
            var skippedDocs = 0
            
            for document in snapshot.documents {
                let data = document.data()
                print("Processing document: \(document.documentID)")
                self.debugInfo += "Processing: \(document.documentID)\n"
                
                // Debug: Print all fields
                let fields = data.keys.joined(separator: ", ")
                print("Fields in document: \(fields)")
                self.debugInfo += "Fields: \(fields)\n"
                
                // Try to get the fileName - required field
                guard let fileName = data["fileName"] as? String else {
                    print("Missing fileName in document: \(document.documentID)")
                    self.debugInfo += "Skipped: Missing fileName\n"
                    skippedDocs += 1
                    continue
                }
                
                // Look specifically for downloadURL field which is what Firebase uses
                var pdfUrl: URL? = nil
                if let urlString = data["downloadURL"] as? String {
                    print("Found downloadURL: \(urlString)")
                    self.debugInfo += "URL found: \(urlString.prefix(30))...\n"
                    
                    // Fix for URL encoding issues
                    // First try direct URL creation
                    pdfUrl = URL(string: urlString)
                    
                    // If that fails, try cleaning up the URL
                    if pdfUrl == nil {
                        print("Attempting URL encoding fix...")
                        
                        // Remove any existing percent encoding and re-encode properly
                        if let decodedString = urlString.removingPercentEncoding {
                            // Create a URL-safe version by encoding problematic characters
                            let allowedCharacterSet = CharacterSet.urlQueryAllowed
                            if let encodedString = decodedString.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                                pdfUrl = URL(string: encodedString)
                                print("URL after encoding fix: \(encodedString)")
                                self.debugInfo += "URL fixed with encoding\n"
                            }
                        }
                        
                        // If still nil, try a different approach - encode only certain parts
                        if pdfUrl == nil {
                            // Extract components and encode only the path and query
                            if let components = URLComponents(string: urlString) {
                                pdfUrl = components.url
                                print("URL created using URLComponents")
                                self.debugInfo += "URL fixed with components\n"
                            } else {
                                print("Failed to create URL from string: \(urlString)")
                                self.debugInfo += "Invalid URL format\n"
                            }
                        }
                    }
                } else {
                    // Fallback to other possible URL field names
                    if let urlString = data["url"] as? String, let url = URL(string: urlString) {
                        print("Found url field instead: \(urlString)")
                        pdfUrl = url
                    } else if let urlString = data["pdfUrl"] as? String, let url = URL(string: urlString) {
                        print("Found pdfUrl field instead: \(urlString)")
                        pdfUrl = url
                    } else if let urlString = data["fileUrl"] as? String, let url = URL(string: urlString) {
                        print("Found fileUrl field instead: \(urlString)")
                        pdfUrl = url
                    }
                }
                
                guard let url = pdfUrl else {
                    print("Missing valid URL in document: \(document.documentID)")
                    if let downloadURLValue = data["downloadURL"] {
                        print("downloadURL exists but has invalid value: \(downloadURLValue)")
                        self.debugInfo += "Invalid downloadURL: \(downloadURLValue)\n"
                    } else {
                        print("downloadURL field is missing")
                        self.debugInfo += "Missing downloadURL field\n"
                    }
                    self.debugInfo += "Skipped: Missing URL for \(fileName)\n"
                    skippedDocs += 1
                    continue
                }
                
                // Get optional fields with defaults
                let subjectName = data["subjectName"] as? String ?? "General"
                let subjectCode = data["subjectCode"] as? String ?? "GEN101"
                
                // Get fileSize if available
                let fileSize: Int
                if let size = data["fileSize"] as? Int {
                    fileSize = size
                } else if let size = data["fileSize"] as? Double {
                    fileSize = Int(size)
                } else {
                    fileSize = 0
                }
                
                // Create the PDF metadata
                let metadata = PDFMetadata(
                    id: document.documentID,
                    url: url,
                    fileName: fileName,
                    subjectName: subjectName,
                    subjectCode: subjectCode,
                    fileSize: fileSize,
                    thumbnail: nil
                )
                
                validPDFs.append(metadata)
                print("Added PDF: \(fileName) with URL: \(url)")
                self.debugInfo += "Added: \(fileName)\n"
            }
            
            if skippedDocs > 0 {
                print("Skipped \(skippedDocs) invalid documents")
                self.debugInfo += "Skipped \(skippedDocs) invalid documents\n"
            }
            
            DispatchQueue.main.async {
                self.pdfs = validPDFs
                
                if validPDFs.isEmpty {
                    print("No valid PDFs found")
                    self.debugInfo += "No valid PDFs found after processing\n"
                } else {
                    print("Successfully loaded \(validPDFs.count) PDFs")
                    self.debugInfo += "Successfully loaded \(validPDFs.count) PDFs\n"
                    
                    // Load thumbnails for the PDFs
                    for (index, pdf) in self.pdfs.enumerated() {
                        self.loadThumbnail(for: pdf, at: index)
                    }
                }
                
                self.isLoading = false
            }
        }
    }
    
    private func loadThumbnail(for pdf: PDFMetadata, at index: Int) {
        // First check the cache
        if let cachedThumbnail = ThumbnailCache.shared.getThumbnail(for: pdf.id) {
            print("Using cached thumbnail for: \(pdf.fileName)")
            DispatchQueue.main.async {
                if index < self.pdfs.count {
                    var updatedPDF = self.pdfs[index]
                    updatedPDF.thumbnail = cachedThumbnail
                    self.pdfs[index] = updatedPDF
                }
            }
            return
        }
        
        // Mark thumbnail as loading
        DispatchQueue.main.async {
            if index < self.pdfs.count {
                var updatedPDF = self.pdfs[index]
                // No need to set a loading state here, the UI will handle it
                self.pdfs[index] = updatedPDF
            }
        }
        
        // No cached thumbnail, download the PDF
        print("Downloading PDF for thumbnail: \(pdf.fileName)")
        
        URLSession.shared.dataTask(with: pdf.url) { data, response, error in
            if let error = error {
                print("Error downloading PDF: \(error.localizedDescription)")
                return
            }
            
            guard let data = data, !data.isEmpty else {
                print("Received empty data for PDF: \(pdf.fileName)")
                return
            }
            
            // Save to temporary file
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
            
            do {
                try data.write(to: tempURL)
                
                // Generate high-quality thumbnail from the PDF
                if let document = PDFDocument(url: tempURL), let page = document.page(at: 0) {
                    // Get the actual page size for better aspect ratio calculation
                    let pageRect = page.bounds(for: .cropBox)
                    let aspectRatio = pageRect.width / pageRect.height
                    
                    // Size that maintains aspect ratio but provides good quality
                    let height: CGFloat = 800
                    let width = height * aspectRatio
                    let size = CGSize(width: width, height: height)
                    
                    // Use mediaBox for better full-page coverage
                    let thumbnailBox = PDFDisplayBox.mediaBox
                    
                    // Get high-quality thumbnail
                    let highQualThumb = page.thumbnail(of: size, for: thumbnailBox)
                    
                    // Create final thumbnail with proper rendering
                    UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
                    if let context = UIGraphicsGetCurrentContext() {
                        context.setFillColor(UIColor.white.cgColor)
                        context.fill(CGRect(origin: .zero, size: size))
                        highQualThumb.draw(in: CGRect(origin: .zero, size: size))
                        
                        if let finalImage = UIGraphicsGetImageFromCurrentImageContext() {
                            // Cache and update UI
                            ThumbnailCache.shared.storeThumbnail(finalImage, for: pdf.id)
                            
                            DispatchQueue.main.async {
                                if index < self.pdfs.count {
                                    var updatedPDF = self.pdfs[index]
                                    updatedPDF.thumbnail = finalImage
                                    self.pdfs[index] = updatedPDF
                                    print("Successfully set thumbnail for \(pdf.fileName)")
                                }
                            }
                        }
                    }
                    UIGraphicsEndImageContext()
                } else {
                    print("Failed to create PDF document or get first page for \(pdf.fileName)")
                }
                
                // Clean up
                try? FileManager.default.removeItem(at: tempURL)
            } catch {
                print("Error creating thumbnail: \(error.localizedDescription)")
            }
        }.resume()
    }
    
    private func selectPDF(_ pdf: PDFMetadata) {
        print("Selected PDF: \(pdf.fileName)")
        viewModel.selectPDFFromList(pdf)
        showWelcomeScreen = false
        dismiss()
    }
    
    // Add an async refresh function for the pull-to-refresh functionality
    private func refreshPDFs() async {
        // Run the direct fetch in a background thread
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.directFetchPDFs()
                continuation.resume()
            }
        }
    }
}

// MARK: - PDF Card View
struct PDFCard: View {
    let pdf: PDFMetadata
    @State private var isImageLoading = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Enhanced Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 70, height: 90)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                if let thumbnail = pdf.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 70, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
                        )
                } else {
                    // Show a nice placeholder with PDF icon
                    ZStack {
                        if isImageLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.blue.opacity(0.7))
                                
                                Text("PDF")
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                        }
                    }
                    .onAppear {
                        isImageLoading = true
                        // Add a short delay to simulate loading and show the animation
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // After a delay, mark as not loading if still no thumbnail
                            if pdf.thumbnail == nil {
                                isImageLoading = false
                            }
                        }
                    }
                    .onChange(of: pdf.thumbnail) { newValue in
                        // When thumbnail loads, update the loading state
                        isImageLoading = false
                    }
                }
            }
            .frame(width: 70, height: 90)
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(pdf.fileName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(pdf.subjectName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(pdf.subjectCode)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(formatFileSize(pdf.fileSize))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // Select icon
            Image(systemName: "chevron.right")
                .foregroundColor(.blue)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 15)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle()) // Make entire card tappable
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Thumbnail Cache
class ThumbnailCache {
    static let shared = ThumbnailCache()
    
    private var memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100  // Max number of images
        return cache
    }()
    
    private let fileManager = FileManager.default
    private lazy var diskCacheURL: URL = {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDirectory = cachesDirectory.appendingPathComponent("PDFThumbnails", isDirectory: true)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        return cacheDirectory
    }()
    
    func storeThumbnail(_ thumbnail: UIImage, for id: String) {
        // Store in memory cache
        memoryCache.setObject(thumbnail, forKey: id as NSString)
        
        // Store on disk
        let fileURL = diskCacheURL.appendingPathComponent("\(id).jpg")
        if let data = thumbnail.jpegData(compressionQuality: 0.8) {
            try? data.write(to: fileURL)
        }
    }
    
    func getThumbnail(for id: String) -> UIImage? {
        // First check memory cache
        if let cachedImage = memoryCache.object(forKey: id as NSString) {
            return cachedImage
        }
        
        // Then check disk cache
        let fileURL = diskCacheURL.appendingPathComponent("\(id).jpg")
        if fileManager.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            // Add back to memory cache for faster access next time
            memoryCache.setObject(image, forKey: id as NSString)
            return image
        }
        
        return nil
    }
    
    func clearCache() {
        memoryCache.removeAllObjects()
        
        // Clean disk cache
        try? fileManager.removeItem(at: diskCacheURL)
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
}

// Move preview provider to file scope
struct AdvancedChatView_Previews: PreviewProvider {
    static var previews: some View {
        AdvancedChatView()
    }
}
extension DispatchQueue {
    static func ensureMainThread(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

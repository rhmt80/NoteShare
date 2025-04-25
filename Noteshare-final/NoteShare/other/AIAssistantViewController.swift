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
    @Published var selectedPDF: URL? { didSet { if !contentIsReady { extractPDFPages() } } }
    @Published var pdfPages: [UIImage] = []
    @Published var pdfText: String?
    @Published var currentPage: Int = 0
    @Published var selectedPDFMetadata: PDFMetadata?
    @Published var pdfsWithChats: [PDFMetadata] = []
    
    // Flag to indicate content is already processed (bypassing extraction)
    var contentIsReady: Bool = false
    
    // Flag to indicate if this instance was launched from the tab bar
    var isTabBarInstance: Bool = false
    
    // New properties for direct PDF document handling
    var pdfDocument: PDFDocument? { didSet { if !contentIsReady { handleDirectPDFDocument() } } }
    var originalPDFDocument: PDFDocument? // Used to maintain a strong reference
    
    public let aiModel = GenerativeModel(name: "gemini-1.5-flash",apiKey:"AIzaSyBQn5DjJRwULdOI7ZndR7AyGNivjHz9OQw")
    public let storage = Storage.storage()
    public let db = Firestore.firestore()
    
    init(isTabBarInstance: Bool = false) {
        self.isTabBarInstance = isTabBarInstance
        
        // Set up notification listener for direct PDF passing
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePDFDocumentPassedDirectly(_:)),
            name: NSNotification.Name("PDFDocumentPassedDirectly"),
            object: nil
        )
        
        // Add an initial welcome message
        DispatchQueue.main.async {
            if self.messages.isEmpty {
                let initialMessage = ChatMessage(
                    content: "Hello! I'm here to help you with your document. What questions do you have?",
                    type: .ai,
                    order: 0
                )
                self.messages.append(initialMessage)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Method to handle PDF document directly passed from PDFViewerViewController
    private func handleDirectPDFDocument() {
        guard let document = pdfDocument else { return }
        
        print("Direct PDF document received with \(document.pageCount) pages")
        isLoading = true
        
        // Extract text immediately from the provided document
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let extractedText = self.extractTextFromPDF(document)
            let textWasExtracted = !extractedText.isEmpty && !extractedText.contains("No text could be extracted")
            
            // If standard extraction failed, try OCR
            DispatchQueue.main.async {
                if !textWasExtracted {
                    print("Standard extraction failed, trying OCR")
                    let ocrText = self.attemptOCRForImageBasedPDF(document)
                    if !ocrText.isEmpty {
                        self.pdfText = ocrText
                        print("OCR extraction successful: \(ocrText.count) characters")
                        self.updateInitialMessage(true)
                    } else {
                        self.updateInitialMessage(false)
                    }
                } else {
                    self.pdfText = extractedText
                    self.updateInitialMessage(true)
                }
                
                // Also extract pages for display
                self.extractPDFPagesFromDocument(document)
                self.isLoading = false
            }
        }
    }
    
    // Handler for the notification when a PDF document is passed directly
    @objc func handlePDFDocumentPassedDirectly(_ notification: Notification) {
        // Skip processing for tab bar instances
        if isTabBarInstance {
            print("Tab bar instance ignoring PDF document notification")
            return
        }
        
        print("PDF document passed directly notification received")
        if let document = notification.object as? PDFDocument {
            // Store a strong reference to prevent deallocation
            self.originalPDFDocument = document
            self.pdfDocument = document
            
            // Mark content as ready to prevent duplicate extraction
            self.contentIsReady = true
            
            // Get metadata from userInfo if available
            if let userInfo = notification.userInfo {
                if let metadata = userInfo["metadata"] as? PDFMetadata {
                    self.selectedPDFMetadata = metadata
                    print("PDF metadata received: \(metadata.fileName)")
                }
                
                if let text = userInfo["text"] as? String, !text.isEmpty {
                    print("PDF text received directly: \(text.count) characters")
                    self.pdfText = text
                    self.updateInitialMessage(true)
                }
                
                if let pages = userInfo["pages"] as? [UIImage], !pages.isEmpty {
                    print("Received \(pages.count) pre-extracted page images")
                    self.pdfPages = pages
                }
            }
        } else {
            print("Notification received but no PDF document found in the object")
        }
    }
    
    // Update the initial AI message based on PDF content availability
    private func updateInitialMessage(_ hasContent: Bool) {
        DispatchQueue.main.async {
            // Remove existing AI messages if any
            if !self.messages.isEmpty, self.messages[0].type == .ai {
                self.messages.removeAll(where: { $0.type == .ai && $0.order == 0 })
            }
            
            let initialMessage: ChatMessage
            if hasContent {
                initialMessage = ChatMessage(
                    content: "I have access to your PDF document. How can I help you with this material?",
                    type: .ai,
                    order: 0
                )
            } else {
                initialMessage = ChatMessage(
                    content: "I'm having trouble accessing the PDF content. I'll try to help with what I can, but my ability may be limited without the text.",
                    type: .ai,
                    order: 0
                )
            }
            self.messages.insert(initialMessage, at: 0)
        }
    }
    
    // Extract PDF pages from the document directly
    private func extractPDFPagesFromDocument(_ document: PDFDocument) {
        var images: [UIImage] = []
        for i in 0..<document.pageCount {
            if let page = document.page(at: i) {
                let pageRect = page.bounds(for: .mediaBox)
                let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                let image = renderer.image { context in
                    UIColor.white.set()
                    context.fill(CGRect(origin: .zero, size: pageRect.size))
                    
                    context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                    context.cgContext.scaleBy(x: 1, y: -1)
                    
                    page.draw(with: .mediaBox, to: context.cgContext)
                }
                images.append(image)
            }
        }
        
        DispatchQueue.main.async {
            self.pdfPages = images
            print("Extracted \(images.count) page images from PDF document")
        }
    }
    
    // Helper function to extract text from PDF - enhanced version with more detailed logging
    private func extractTextFromPDF(_ pdfDocument: PDFDocument) -> String {
        var text = ""
        let pageCount = pdfDocument.pageCount
        
        print("==== EXTRACT TEXT START ====")
        print("Extracting text from PDF with \(pageCount) pages")
        
        // Use a more intensive approach to text extraction
        for i in 0..<pageCount {
            guard let page = pdfDocument.page(at: i) else {
                print("Failed to get page \(i)")
                continue
            }
            
            print("Processing page \(i+1) of \(pageCount)")
            
            // Try multiple methods to extract text
            if let pageText = page.string, !pageText.isEmpty {
                // Method 1: Direct string extraction
                text += "--- Page \(i+1) ---\n"
                text += pageText
                text += "\n\n"
                print("SUCCESS: Extracted \(pageText.count) characters from page \(i+1) using direct method")
                // Log a sample of the extracted text
                if pageText.count > 0 {
                    let sampleLength = min(pageText.count, 100)
                    print("SAMPLE: \"\(pageText.prefix(sampleLength))...\"")
                }
            } else {
                // Method 2: Using PDFKit's attribute dictionary if direct method fails
                print("Direct string extraction failed, trying attributedString method")
                let pageBounds = page.bounds(for: .mediaBox)
                if let attributedText = page.attributedString, attributedText.length > 0 {
                    text += "--- Page \(i+1) ---\n"
                    text += attributedText.string
                    text += "\n\n"
                    print("SUCCESS: Extracted \(attributedText.string.count) characters from page \(i+1) using attributed string")
                    // Log a sample of the extracted text
                    if attributedText.string.count > 0 {
                        let sampleLength = min(attributedText.string.count, 100)
                        print("SAMPLE: \"\(attributedText.string.prefix(sampleLength))...\"")
                    }
                } else {
                    print("ERROR: No text found on page \(i+1) - both extraction methods failed")
                    text += "--- Page \(i+1) [No text detected] ---\n\n"
                }
            }
        }
        
        // Set the pdfText property immediately
        if !text.isEmpty {
            self.pdfText = text
            print("SUCCESS: PDF text extracted successfully: \(text.count) characters total across \(pageCount) pages")
            // Log a sample of the final text
            let sampleLength = min(text.count, 200)
            print("FINAL TEXT SAMPLE: \"\(text.prefix(sampleLength))...\"")
        } else {
            self.pdfText = "No text could be extracted from this PDF. It may be scanned or image-based."
            print("ERROR: No text could be extracted from PDF - all extraction methods failed")
        }
        
        print("==== EXTRACT TEXT END ====")
        return text
    }
    
    func selectPDFFromList(_ metadata: PDFMetadata) {
        self.selectedPDFMetadata = metadata
        // Clear existing messages to start a fresh chat
        self.messages = []
        
        print("Selected PDF metadata: \(metadata.fileName) from URL: \(metadata.url)")
        
        // Create a proper URL from the string URL in metadata
        if let pdfUrl = metadata.url?.absoluteString, let url = URL(string: pdfUrl) {
            downloadPDF(from: url)
        } else {
            print("ERROR: Invalid URL in PDF metadata: \(String(describing: metadata.url))")
            self.pdfText = "Error: The PDF URL is invalid and could not be loaded."
            isLoading = false
        }
    }
    
    // Improved PDF download with URL refresh capabilities
    public func downloadPDF(from url: URL) {
        isLoading = true
        print("Downloading PDF from URL: \(url.absoluteString)")
        
        // Extract the PDF path from the URL for potential refresh
        let pdfPath = extractPDFPathFromURL(url.absoluteString)
        
        // Create a URL request with a timeout
        var request = URLRequest(url: url)
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
                    // Set an error message for the user
                    self.pdfText = "Error downloading PDF: \(error.localizedDescription)"
                }
                return
            }
            
            // Check HTTP response status
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode != 200 {
                print("Invalid response: \(response?.description ?? "unknown") - Status: \(httpResponse.statusCode)")
                
                // If we get a 400 error (likely expired token), try to refresh the URL
                if httpResponse.statusCode == 400 && !pdfPath.isEmpty {
                    self.refreshFirebaseURL(for: pdfPath) { [weak self] result in
                        guard let self = self else { return }
                        
                        switch result {
                        case .success(let newURL):
                            print("URL refreshed successfully, retrying with new URL: \(newURL)")
                            // Retry download with new URL if we have a valid URL
                            if let newValidURL = URL(string: newURL) {
                                DispatchQueue.main.async {
                                    self.downloadPDF(from: newValidURL)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    self.pdfText = "Error: Invalid URL after refresh"
                                }
                            }
                            
                        case .failure(let refreshError):
                            print("Failed to refresh URL: \(refreshError.localizedDescription)")
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.pdfText = "Error: Firebase URL has expired and refresh failed"
                            }
                        }
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.pdfText = "Error: Server returned status code \(httpResponse.statusCode)"
                }
                return
            }
            
            guard let tempFileURL = tempFileURL else {
                print("Error: No temporary file URL received after download")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.pdfText = "Error: Download failed (no temporary file)"
                }
                return
            }
            
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let uniqueFilename = UUID().uuidString + ".pdf"
                let localURL = documentsPath.appendingPathComponent(uniqueFilename)
                
                // If there's an existing file, remove it first
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                
                // Move the temp file to our local URL
                try FileManager.default.moveItem(at: tempFileURL, to: localURL)
                print("Successfully saved PDF to: \(localURL.path)")
                
                // Check if file is a valid PDF
                guard let document = PDFDocument(url: localURL) else {
                    print("Error: Invalid PDF file at \(localURL.path)")
                    try? FileManager.default.removeItem(at: localURL)
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.pdfText = "Error: The downloaded file is not a valid PDF"
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    print("Setting selectedPDF to: \(localURL.path)")
                    self.selectedPDF = localURL
                    
                    // Extract text immediately
                    let extractedText = self.extractTextFromPDF(document)
                    
                    // If standard extraction failed, try OCR
                    if extractedText.isEmpty || extractedText.contains("No text could be extracted") {
                        print("Standard extraction failed, trying OCR")
                        let ocrText = self.attemptOCRForImageBasedPDF(document)
                        if !ocrText.isEmpty {
                            self.pdfText = ocrText
                            print("OCR extraction successful: \(ocrText.count) characters")
                        }
                    }
                    
                    self.isLoading = false
                }
            } catch {
                print("Error saving PDF: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.pdfText = "Error saving PDF: \(error.localizedDescription)"
                }
            }
        }
        
        task.resume()
    }
    
    // Extract the PDF path from a Firebase Storage URL
    private func extractPDFPathFromURL(_ urlString: String) -> String {
        guard let url = URL(string: urlString),
              url.absoluteString.contains("firebasestorage.googleapis.com") else {
            return ""
        }
        
        // Extract pdfs/USER_ID/FILE_ID.pdf from the URL path
        if let pathComponent = url.path.components(separatedBy: "/o/").last?.removingPercentEncoding,
           pathComponent.starts(with: "pdfs/") {
            // Remove any query parameters
            let cleanPath = pathComponent.components(separatedBy: "?").first ?? pathComponent
            return cleanPath
        }
        
        return ""
    }
    
    // Refresh a Firebase Storage URL to get a new download token
    private func refreshFirebaseURL(for pdfPath: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let currentUser = Auth.auth().currentUser else {
            completion(.failure(NSError(domain: "Firebase", code: 401,
                                      userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }
        
        print("Refreshing Firebase URL for path: \(pdfPath)")
        
        // Get a fresh download URL from Firebase Storage
        let storageRef = Storage.storage().reference().child(pdfPath)
        storageRef.downloadURL { url, error in
            if let error = error {
                print("Failed to refresh download URL: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let refreshedURL = url else {
                completion(.failure(NSError(domain: "Firebase", code: 404,
                                          userInfo: [NSLocalizedDescriptionKey: "Could not get fresh download URL"])))
                return
            }
            
            print("Successfully refreshed download URL: \(refreshedURL.absoluteString)")
            completion(.success(refreshedURL.absoluteString))
        }
    }
    
    private func createPromptWithContext(_ pdfText: String?, message: String) -> String {
            var context = "PDF Context:\n"
            if let metadata = selectedPDFMetadata {
                context += "Title: \(metadata.fileName)\n"
                context += "Subject: \(metadata.subjectName) (\(metadata.subjectCode))\n\n"
            }
            context += "\(pdfText ?? "")\n\n"
            return context + "User Question: \(message)\n\nPlease provide a helpful and concise response based on the PDF context and do not use any bold text."
        }
    
    // Create a more comprehensive fallback prompt when PDF content is unavailable
    private func createFallbackPrompt(message: String) -> String {
        var context = ""
        
        // Add metadata if available
        if let metadata = selectedPDFMetadata {
            context += "Note: I'm trying to answer a question about a PDF titled '\(metadata.fileName)' for subject '\(metadata.subjectName)' (\(metadata.subjectCode)), but I couldn't access the PDF text content. "
            
            // Provide subject-specific fallback information
            if metadata.subjectName.lowercased().contains("operating") || metadata.fileName.lowercased().contains("page replacement") {
                context += "\n\nWhile I don't have access to the specific PDF, I can provide general information about page replacement algorithms in operating systems:\n\n"
                context += "Page replacement algorithms are used in virtual memory systems to decide which memory pages to swap out when a page fault occurs and new pages need to be brought into memory. Common page replacement algorithms include:\n\n"
                context += "1. FIFO (First-In-First-Out): Replaces the oldest page in memory\n"
                context += "2. LRU (Least Recently Used): Replaces the page that hasn't been used for the longest time\n"
                context += "3. LFU (Least Frequently Used): Replaces the page with the lowest usage count\n"
                context += "4. Optimal/OPT: Replaces the page that won't be used for the longest time in the future (theoretical algorithm)\n"
                context += "5. Clock/Second-Chance: A more efficient approximation of LRU using a circular buffer\n"
                context += "6. Random: Randomly selects a page to replace\n\n"
                context += "These algorithms are evaluated based on page fault rate, implementation complexity, and memory overhead.\n\n"
            }
        } else {
            context += "Note: I'm trying to answer a question, but I couldn't access the PDF text content. "
        }
        
        // Add specific error info if the pdfText contains an error message
        if let pdfText = self.pdfText, pdfText.starts(with: "Error:") {
            context += pdfText + " "
        } else {
            context += "The PDF file may be inaccessible due to a download error or permission issue. "
        }
        
        context += "Please provide a helpful response based on the user's question.\n\n"
        context += "User Question: \(message)\n\n"
        
        // Add additional guidance for the AI
        context += "Instructions:\n"
        context += "1. Acknowledge that you don't have access to the specific PDF.\n"
        context += "2. If the question is about a general topic that you can answer based on your knowledge, provide a helpful response.\n"
        context += "3. If the question requires the specific PDF content, explain that you can't access it and suggest alternatives.\n"
        context += "4. Be honest about limitations while remaining helpful.\n"
        
        return context
    }
    
    private func extractPDFPages() {
        guard let url = selectedPDF else {
            print("Error: No PDF selected")
            return
        }
        
        print("Extracting pages from PDF: \(url.lastPathComponent)")
        
        DispatchQueue.main.async {
            self.pdfPages.removeAll()
        }
        
        // First verify the file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            print("Error: PDF file does not exist at path: \(url.path)")
            DispatchQueue.main.async {
                self.isLoading = false
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
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
            
            // Extract pages and collect them
            var thumbnails: [UIImage] = []
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) {
                    let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 300), for: .cropBox)
                    thumbnails.append(thumbnail)
                }
            }
            
            // Extract text from the PDF
            let extractedText = self.extractTextFromPDF(document)
            print("Extracted \(extractedText.count) characters of text from PDF")
            
            // Update all published properties on the main thread
            DispatchQueue.main.async {
                self.pdfPages = thumbnails
                
                // Set the first page as the thumbnail for the selected PDF metadata
                if !thumbnails.isEmpty && self.selectedPDFMetadata != nil {
                    var updatedMetadata = self.selectedPDFMetadata!
                    updatedMetadata.thumbnail = thumbnails[0]
                    self.selectedPDFMetadata = updatedMetadata
                    print("Set first page as thumbnail for selected PDF")
                }
                
                print("Finished processing PDF: \(document.pageCount) pages extracted, \(thumbnails.count) thumbnails created")
            }
        }
    }
    
    private func saveChatToFirestore(messages newMessages: [ChatMessage]) {
        guard let currentUser = Auth.auth().currentUser,
              let pdfMetadata = selectedPDFMetadata else {
            print("ERROR: Missing user or PDF metadata - cannot save chat")
            if Auth.auth().currentUser == nil {
                print("DEBUG: User is not authenticated")
            }
            if selectedPDFMetadata == nil {
                print("DEBUG: No PDF metadata available")
            }
            return
        }
        
        print("DEBUG: User authenticated with ID: \(currentUser.uid)")
        let chatId = "\(currentUser.uid)_\(pdfMetadata.id)"
        print("SAVING chat with ID: \(chatId) - Contains \(newMessages.count) messages")
        
        // Create safer PDF text fallback
        let pdfTextToSave: String
        if let availableText = self.pdfText, !availableText.isEmpty {
            pdfTextToSave = availableText
            print("Using available PDF text: \(availableText.count) characters")
        } else {
            pdfTextToSave = "[PDF text not available - using empty placeholder]"
            print("WARNING: PDF text is missing, using empty placeholder")
        }
        
        let timestamp = FieldValue.serverTimestamp()
        
        let chatData: [String: Any] = [
            "userId": currentUser.uid,
            "pdfId": pdfMetadata.id,
            "pdfName": pdfMetadata.fileName,
            "pdfText": pdfTextToSave,
            "pdfUrl": pdfMetadata.url?.absoluteString ?? "",
            "subjectName": pdfMetadata.subjectName,
            "subjectCode": pdfMetadata.subjectCode,
            "messageCount": newMessages.count,
            "lastMessage": newMessages.last?.content ?? "",
            "createdAt": timestamp,
            "updatedAt": timestamp
        ]
        
        print("DEBUG: Saving chat document with \(newMessages.count) messages")
        
        // Simplify the approach: Always update or create the main chat document first
        let chatRef = db.collection("chats").document(chatId)
        
        // Create or update the main chat document
        chatRef.setData(chatData, merge: true) { error in
            if let error = error {
                print("ERROR: Failed to save chat document: \(error.localizedDescription)")
                
                if let nsError = error as NSError? {
                    print("ERROR: Firebase error details - code: \(nsError.code), domain: \(nsError.domain)")
                    
                    // Check for common Firebase errors
                    if nsError.code == 7 {
                        print("ERROR: Permission denied - check Firebase security rules")
                    } else if nsError.code == 3 {
                        print("ERROR: Document too large - PDF text may be too big")
                    }
                }
                return
            }
            
            print("SUCCESS: Updated chat document. Now saving messages...")
            
            // Now handle the messages collection - using a simple approach
            // Delete existing messages and add all messages again to ensure consistency
            self.recreateMessagesCollection(chatId: chatId, messages: newMessages)
        }
    }
    
    private func recreateMessagesCollection(chatId: String, messages: [ChatMessage]) {
        let messagesRef = db.collection("chats").document(chatId).collection("messages")
        let currentUser = Auth.auth().currentUser!
        
        // First, delete all existing messages (if any)
        print("DEBUG: Getting existing messages to delete them...")
        messagesRef.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("ERROR: Failed to get existing messages: \(error.localizedDescription)")
                // Continue with adding new messages even if we failed to delete old ones
                self.addAllMessages(messagesRef: messagesRef, messages: messages, userId: currentUser.uid)
                return
            }
            
            // If we have existing documents, delete them
            if let documents = snapshot?.documents, !documents.isEmpty {
                print("DEBUG: Deleting \(documents.count) existing messages...")
                
                let batch = self.db.batch()
                for document in documents {
                    batch.deleteDocument(document.reference)
                }
                
                batch.commit { error in
                    if let error = error {
                        print("ERROR: Failed to delete old messages: \(error.localizedDescription)")
                } else {
                        print("SUCCESS: Deleted old messages. Adding \(messages.count) new messages...")
                    }
                    
                    // Add all new messages
                    self.addAllMessages(messagesRef: messagesRef, messages: messages, userId: currentUser.uid)
                }
            } else {
                // No existing messages, just add the new ones
                print("DEBUG: No existing messages to delete. Adding \(messages.count) new messages...")
                self.addAllMessages(messagesRef: messagesRef, messages: messages, userId: currentUser.uid)
            }
        }
    }
    
    private func addAllMessages(messagesRef: CollectionReference, messages: [ChatMessage], userId: String) {
        // Use a batch to add all messages at once
        let batch = db.batch()
        
        // Make sure we have a valid user ID
        let safeUserId = userId.isEmpty ? "anonymous_user" : userId
        
        // Add each message to the batch
        for (index, message) in messages.enumerated() {
            let order = index // Use the index to ensure proper order
            let documentId = "msg_\(order)_\(message.id.uuidString)" // Use predictable IDs with order as prefix
            let messageRef = messagesRef.document(documentId)
            
            // Ensure critical fields match the index requirements from firestore.indexes.json
                    let messageData: [String: Any] = [
                        "content": message.content,
                        "type": message.type.rawValue,
                        "timestamp": message.timestamp,
                "userId": safeUserId, // Always include userId field
                "order": order,
                "created_at": FieldValue.serverTimestamp()
            ]
            
            batch.setData(messageData, forDocument: messageRef)
            
            print("DEBUG: Adding message \(index+1)/\(messages.count) with order=\(order), userId=\(safeUserId)")
        }
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                print("ERROR: Failed to save messages: \(error.localizedDescription)")
                
                if let nsError = error as NSError? {
                    print("ERROR: Firestore error code: \(nsError.code), domain: \(nsError.domain)")
                }
            } else {
                print("SUCCESS: Successfully saved all \(messages.count) messages to Firestore!")
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
        print("Loading chat messages for PDF ID: \(pdfId), Chat ID: \(chatId)")
        
        // Get messages from the subcollection - use a simpler query to avoid index requirements
        db.collection("chats").document(chatId)
            .collection("messages")
            // Removed whereField to simplify query
            .order(by: "order", descending: false)  // Only sort by order field, no composite index needed
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                
                if let error = error {
                    print("Error loading messages: \(error.localizedDescription)")
                    
                    // Try an even simpler query if the first one fails
                    self.fallbackLoadMessages(chatId: chatId)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found in messages collection")
                    return
                }
                
                print("Found \(documents.count) messages for PDF ID: \(pdfId)")
                
                let messages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    guard let content = data["content"] as? String,
                          let typeString = data["type"] as? String,
                          let type = MessageType(rawValue: typeString) else {
                        print("Failed to parse message: \(data)")
                        return nil
                    }
                    
                    // Get timestamp (fallback to current date if not available)
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // Get order (fallback to document ID extraction)
                    let order: Int
                    if let orderNum = data["order"] as? Int {
                        order = orderNum
                    } else {
                        // Try to extract order from document ID (format: msg_0_uuid)
                        let docId = document.documentID
                        if docId.hasPrefix("msg_"),
                           let underscoreIndex = docId.firstIndex(of: "_"),
                           let secondUnderscoreIndex = docId[underscoreIndex..<docId.endIndex].dropFirst().firstIndex(of: "_"),
                           let orderValue = Int(docId[docId.index(after: underscoreIndex)..<secondUnderscoreIndex]) {
                            order = orderValue
                        } else {
                            // Fallback to random order
                            order = Int.random(in: 0..<1000)
                        }
                    }
                    
                    return ChatMessage(content: content, type: type, timestamp: timestamp, order: order)
                }
                
                // Sort messages by order
                let sortedMessages = messages.sorted { $0.order < $1.order }
                
                DispatchQueue.main.async {
                    self.messages = sortedMessages
                    print("Successfully loaded \(sortedMessages.count) messages for chat")
                    
                    // Verify message order
                    for (index, message) in sortedMessages.enumerated() {
                        print("Message \(index): Order \(message.order), Type \(message.type.rawValue)")
                    }
                }
            }
    }
    
    // Fallback method with an even simpler query if the first one fails
    private func fallbackLoadMessages(chatId: String) {
        print("Attempting fallback message loading for chat: \(chatId)")
        
        db.collection("chats").document(chatId)
            .collection("messages")
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Fallback also failed: \(error.localizedDescription)")
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No documents found in fallback query")
                    return
                }
                
                print("Fallback found \(documents.count) messages")
                
                // Process messages similarly to the main method
                let messages = documents.compactMap { document -> ChatMessage? in
                    let data = document.data()
                    guard let content = data["content"] as? String,
                          let typeString = data["type"] as? String,
                          let type = MessageType(rawValue: typeString) else {
                        return nil
                    }
                    
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let order = data["order"] as? Int ?? 0
                    
                    return ChatMessage(content: content, type: type, timestamp: timestamp, order: order)
                }
                
                // Sort manually after fetching
                let sortedMessages = messages.sorted {
                    if $0.order != $1.order {
                        return $0.order < $1.order
                    }
                    return $0.timestamp < $1.timestamp
                }
                
                DispatchQueue.main.async {
                    if !sortedMessages.isEmpty {
                        self.messages = sortedMessages
                        print("Successfully loaded \(sortedMessages.count) messages using fallback")
                    }
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
                    privacy: data["privacy"] as? String ?? "Public",
                    uploadDate: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                    thumbnail: nil,
                    pageCount: data["pageCount"] as? Int,
                    thumbnailIsLoading: false,
                    uploaderName: data["uploaderName"] as? String ?? "Unknown",
                    college: data["college"] as? String ?? "Unknown"
                )
                
                fetchedPDFs.append(metadata)
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.pdfsWithChats = fetchedPDFs
            self.loadThumbnailsForPDFs()
        }
    }
    private func loadThumbnailsForPDFs() {
        for (index, metadata) in pdfsWithChats.enumerated() {
            if let url = metadata.url {
                downloadPDFThumbnail(from: url) { [weak self] thumbnail in
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
                    privacy: chatData["privacy"] as? String ?? "Public",
                    uploadDate: (chatData["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                    thumbnail: nil,
                    pageCount: chatData["pageCount"] as? Int,
                    thumbnailIsLoading: false,
                    uploaderName: chatData["uploaderName"] as? String ?? "Unknown",
                    college: chatData["college"] as? String ?? "Unknown"
                )
                
                DispatchQueue.main.async {
                    print("Setting PDF metadata from local file: \(pdfName)")
                    self.selectedPDFMetadata = metadata
                    self.selectedPDF = localPDF
                    
                    // Extract text if needed
                    if self.pdfText?.isEmpty ?? true, let document = PDFDocument(url: localPDF) {
                        self.extractTextFromPDF(document)
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
                        privacy: chatData["privacy"] as? String ?? "Public",
                        uploadDate: (chatData["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                        thumbnail: nil,
                        pageCount: chatData["pageCount"] as? Int,
                        thumbnailIsLoading: false,
                        uploaderName: chatData["uploaderName"] as? String ?? "Unknown",
                        college: chatData["college"] as? String ?? "Unknown"
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
                        privacy: data["privacy"] as? String ?? "Public",
                        uploadDate: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                        thumbnail: nil,
                        pageCount: data["pageCount"] as? Int,
                        thumbnailIsLoading: false,
                        uploaderName: data["uploaderName"] as? String ?? "Unknown",
                        college: data["college"] as? String ?? "Unknown"
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
                    privacy: "Public",
                    uploadDate: Date(),
                    thumbnail: nil,
                    pageCount: nil,
                    thumbnailIsLoading: false,
                    uploaderName: "Unknown",
                    college: "Unknown"
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
    
    // Add a test function to verify Firebase connection and permissions
    func testFirebaseConnection() {
        guard let currentUser = Auth.auth().currentUser else {
            print("DEBUG TEST: No authenticated user - cannot test Firebase")
            return
        }
        
        print("DEBUG TEST: Starting Firebase test with user: \(currentUser.uid)")
        print("DEBUG TEST: User is \(currentUser.isAnonymous ? "anonymous" : "authenticated")")
        
        // Create a test document in a special collection
        let testCollection = db.collection("test_chats")
        let testDocument = testCollection.document("test_\(currentUser.uid)_\(Date().timeIntervalSince1970)")
        
        // Create test data
        let testData: [String: Any] = [
            "userId": currentUser.uid,
            "testMessage": "This is a test message",
            "timestamp": FieldValue.serverTimestamp(),
            "deviceInfo": UIDevice.current.systemName + " " + UIDevice.current.systemVersion
        ]
        
        // Write test data
        print("DEBUG TEST: Writing test data to Firebase...")
        testDocument.setData(testData) { error in
            if let error = error {
                print("DEBUG TEST: Failed to write test data: \(error.localizedDescription)")
                if let nsError = error as NSError? {
                    print("DEBUG TEST: Error code: \(nsError.code), domain: \(nsError.domain)")
                    
                    if nsError.code == 7 {
                        print("DEBUG TEST: Permission denied - check Firebase security rules")
                    } else if nsError.code == 2 {
                        print("DEBUG TEST: Network error - check internet connection")
                    }
                }
                return
            }
            
            print("DEBUG TEST: Successfully wrote test data to: \(testDocument.path)")
            
            // Now try to read the data back
            print("DEBUG TEST: Reading test data from Firebase...")
            testDocument.getDocument { document, error in
                if let error = error {
                    print("DEBUG TEST: Failed to read test data: \(error.localizedDescription)")
                    return
                }
                
                if let document = document, document.exists, let data = document.data() {
                    print("DEBUG TEST: Successfully read test data")
                    print("DEBUG TEST: Data: \(data)")
                    
                    // Now try to write a subcollection item
                    let messageRef = testDocument.collection("messages").document()
                    let messageData: [String: Any] = [
                        "content": "Test chat message",
                        "timestamp": FieldValue.serverTimestamp(),
                        "userId": currentUser.uid
                    ]
                    
                    print("DEBUG TEST: Writing test message to subcollection...")
                    messageRef.setData(messageData) { error in
                        if let error = error {
                            print("DEBUG TEST: Failed to write test message: \(error.localizedDescription)")
                            return
                        }
                        
                        print("DEBUG TEST: Successfully wrote test message to: \(messageRef.path)")
                        
                        // Now try to read the subcollection
                        testDocument.collection("messages").getDocuments { snapshot, error in
                            if let error = error {
                                print("DEBUG TEST: Failed to read test messages: \(error.localizedDescription)")
                                return
                            }
                            
                            if let documents = snapshot?.documents {
                                print("DEBUG TEST: Successfully read \(documents.count) test messages")
                                print("DEBUG TEST: All Firebase tests PASSED!")
                            } else {
                                print("DEBUG TEST: No test messages found")
                            }
                        }
                    }
                } else {
                    print("DEBUG TEST: Test document not found or empty")
                }
            }
        }
    }
    
    // Helper method to try OCR as a last resort for image-based PDFs
    private func attemptOCRForImageBasedPDF(_ pdfDocument: PDFDocument) -> String {
        print("==== OCR ATTEMPT START ====")
        print("Attempting OCR for image-based PDF with \(pdfDocument.pageCount) pages")
        
        var extractedText = ""
        let group = DispatchGroup()
        let lock = NSLock()
        
        // Process each page with OCR
        for i in 0..<min(pdfDocument.pageCount, 10) { // Limit to first 10 pages to avoid long processing
            guard let page = pdfDocument.page(at: i) else { continue }
            
            // Get page as image
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let pageImage = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(CGRect(origin: .zero, size: pageRect.size))
                
                // Fixed: CGContext is not optional, so we can't use guard let
                let cgContext = ctx.cgContext
                cgContext.translateBy(x: 0, y: pageRect.size.height)
                cgContext.scaleBy(x: 1, y: -1)
                
                page.draw(with: .mediaBox, to: cgContext)
            }
            
            group.enter()
            
            // Use Vision framework for OCR
            guard let cgImage = pageImage.cgImage else {
                group.leave()
                continue
            }
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { request, error in
                defer { group.leave() }
                
                if let error = error {
                    print("OCR error on page \(i+1): \(error.localizedDescription)")
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                
                let pageText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                lock.lock()
                extractedText += "--- Page \(i+1) (OCR) ---\n"
                extractedText += pageText
                extractedText += "\n\n"
                lock.unlock()
                
                print("OCR extracted \(pageText.count) characters from page \(i+1)")
                if pageText.count > 0 {
                    let sample = pageText.prefix(min(pageText.count, 100))
                    print("OCR SAMPLE: \"\(sample)...\"")
                }
            }
            
            // Configure the request to use accurate mode
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("Failed to perform OCR: \(error.localizedDescription)")
                group.leave()
            }
        }
        
        // Wait for all OCR tasks to complete
        let _ = group.wait(timeout: .now() + 30.0)
        
        print("==== OCR ATTEMPT END ====")
        if extractedText.isEmpty {
            print("OCR failed to extract any text")
            return ""
        } else {
            print("OCR extracted \(extractedText.count) characters total")
            return extractedText
        }
    }
    
    func sendMessage(_ content: String) {
        let userMessage = ChatMessage(content: content, type: .user, order: messages.count)
        messages.append(userMessage)
        isLoading = true
        
        print("==== SEND MESSAGE START ====")
        print("User message: \"\(content)\"")
        
        // Ensure we have PDF text with enhanced extraction attempts
        var hasPdfTextSuccess = false
        
        // Try to extract text if it's missing
        if pdfText == nil || pdfText?.isEmpty == true || pdfText?.contains("No text could be extracted") == true {
            print("PDF text missing or empty, attempting extraction")
            
            if let selectedPDF = selectedPDF, let document = PDFDocument(url: selectedPDF) {
                print("PDF URL: \(selectedPDF.absoluteString)")
                print("Attempting text extraction from document")
                let extractedText = extractTextFromPDF(document)
                
                if !extractedText.isEmpty && !extractedText.contains("No text could be extracted") {
                    hasPdfTextSuccess = true
                    print("Successfully extracted text: \(extractedText.count) characters")
                } else {
                    print("Text extraction failed or returned empty result")
                    
                    // Force another attempt with different settings
                    if let document = PDFDocument(url: selectedPDF) {
                        print("Making second extraction attempt with different settings")
                        // Try a different approach for extraction if needed
                        var alternativeText = ""
                        for i in 0..<document.pageCount {
                            if let page = document.page(at: i) {
                                let pageText = page.string ?? ""
                                alternativeText += pageText + "\n\n"
                            }
                        }
                        
                        if !alternativeText.isEmpty {
                            self.pdfText = alternativeText
                            hasPdfTextSuccess = true
                            print("Second attempt extracted: \(alternativeText.count) characters")
                            // Log a sample of the alternative text
                            let sampleLength = min(alternativeText.count, 100)
                            print("ALT TEXT SAMPLE: \"\(alternativeText.prefix(sampleLength))...\"")
                        } else {
                            // As a last resort, try OCR
                            print("Regular extraction methods failed, attempting OCR as last resort")
                            let ocrText = attemptOCRForImageBasedPDF(document)
                            if !ocrText.isEmpty {
                                self.pdfText = ocrText
                                hasPdfTextSuccess = true
                                print("OCR extraction successful: \(ocrText.count) characters")
                            } else {
                                print("All extraction methods failed including OCR")
                            }
                        }
                    }
                }
            } else if let metadata = selectedPDFMetadata {
                print("No PDF available locally. Attempting to re-download PDF from: \(String(describing: metadata.url))")
                // Force-extract text from PDF again by re-downloading
                if let url = metadata.url {
                    downloadPDF(from: url)
                }
                
                // Wait a moment for download to complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    guard let self = self else { return }
                    
                    if let selectedPDF = self.selectedPDF, let document = PDFDocument(url: selectedPDF) {
                        let extractedText = self.extractTextFromPDF(document)
                        print("Re-extraction after download: \(extractedText.count) characters")
                        
                        // If standard extraction failed, try OCR
                        if extractedText.isEmpty || extractedText.contains("No text could be extracted") {
                            print("Standard extraction after download failed, trying OCR")
                            let ocrText = self.attemptOCRForImageBasedPDF(document)
                            if !ocrText.isEmpty {
                                self.pdfText = ocrText
                                print("OCR after download successful: \(ocrText.count) characters")
                            }
                        }
                    }
                }
            } else {
                print("ERROR: No PDF file or metadata available for extraction")
            }
        } else {
            hasPdfTextSuccess = true
            print("Using existing PDF text: \(pdfText?.count ?? 0) characters")
        }
        
        Task {
            do {
                // Prepare context with the PDF content
                let context: String
                if hasPdfTextSuccess {
                    context = createPromptWithContext(pdfText, message: content)
                    print("Created context with PDF content: \(context.count) characters")
                } else {
                    context = createFallbackPrompt(message: content)
                    print("Created fallback context: \(context.count) characters")
                }
                
                // Log subset of context for debugging
                let previewLength = min(context.count, 200)
                print("Context preview: \(context.prefix(previewLength))...")
                
                // API call - add more debugging
                print("Sending context to AI model (length: \(context.count))")
                let response = try await aiModel.generateContent(context)
                
                await MainActor.run {
                    let aiMessage = ChatMessage(content: response.text ?? "No response", type: .ai, order: messages.count)
                    messages.append(aiMessage)
                    
                    print("Received AI response: \(aiMessage.content.prefix(50))...")
                    print("Total messages in chat: \(self.messages.count)")
                    print("==== SEND MESSAGE END ====")
                    
                    if let metadata = selectedPDFMetadata {
                        print("Saving chat history to Firebase with \(self.messages.count) messages")
                        saveChatToFirestore(messages: self.messages)
                    } else {
                        print("Cannot save chat - no PDF metadata available")
                    }
                    
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Error getting AI response: \(error.localizedDescription)")
                    let errorMessage = ChatMessage(content: "Error: \(error.localizedDescription)", type: .error, order: messages.count)
                    messages.append(errorMessage)
                    isLoading = false
                    print("==== SEND MESSAGE END WITH ERROR ====")
                }
            }
        }
    }
    
    // Convenience method to download from string URL
    func downloadPDF(from urlString: String) {
        print("String URL download requested: \(urlString)")
        guard let url = URL(string: urlString) else {
            print("ERROR: Invalid URL string: \(urlString)")
            self.pdfText = "Error: The PDF URL is invalid and could not be loaded."
            isLoading = false
            return
        }
        
        downloadPDF(from: url)
    }
}

// Move these type definitions to file scope
struct PDFMetadata: Identifiable, Equatable {
    let id: String
    let url: URL?
    let fileName: String
    let subjectName: String
    let subjectCode: String
    let fileSize: Int
    let privacy: String
    let uploadDate: Date
    var thumbnail: UIImage?
    var pageCount: Int?
    var thumbnailIsLoading = false
    let uploaderName: String
    let college: String
    
    init(id: String,
         url: URL? = nil,
         fileName: String,
         subjectName: String,
         subjectCode: String = "",
         fileSize: Int = 0,
         privacy: String = "public",
         uploadDate: Date = Date(),
         thumbnail: UIImage? = nil,
         pageCount: Int? = nil,
         thumbnailIsLoading: Bool = false,
         uploaderName: String = "Unknown",
         college: String = "") {
        
        self.id = id
        self.url = url
        self.fileName = fileName
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.fileSize = fileSize
        self.privacy = privacy
        self.uploadDate = uploadDate
        self.thumbnail = thumbnail
        self.pageCount = pageCount
        self.thumbnailIsLoading = thumbnailIsLoading
        self.uploaderName = uploaderName
        self.college = college
    }
    
    init(id: String, fileName: String, subjectName: String, subjectCode: String, fileSize: Int, pageCount: Int?, uploadTimestamp: Date, uploaderName: String, college: String) {
        self.id = id
        self.url = nil
        self.fileName = fileName
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.fileSize = fileSize
        self.privacy = "public"
        self.uploadDate = uploadTimestamp
        self.pageCount = pageCount
        self.uploaderName = uploaderName
        self.college = college
    }
    
    static func == (lhs: PDFMetadata, rhs: PDFMetadata) -> Bool {
        lhs.id == rhs.id &&
        lhs.url == rhs.url &&
        lhs.fileName == rhs.fileName &&
        lhs.subjectName == rhs.subjectName &&
        lhs.subjectCode == rhs.subjectCode &&
        lhs.fileSize == rhs.fileSize &&
        lhs.privacy == rhs.privacy &&
        lhs.uploadDate == rhs.uploadDate
        // Intentionally excluding thumbnail, pageCount, and thumbnailIsLoading from equality check since they're mutable
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
    @ObservedObject private var viewModel: AIPageViewController
    @State private var messageText = ""
    @State private var showPDFPicker = false
    @State private var showChatHistory = false
    @State private var showFullScreenPDF = false
    @State private var showWelcomeScreen = true
    @Environment(\.presentationMode) private var presentationMode
    @Namespace private var bottomID
    
    // Initialize with a provided view model (for PDF viewer)
    init(viewModel: AIPageViewController) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
    }
    
    // Default initializer for when no viewModel is provided (for tab bar)
    init() {
        // Create a new instance marked as tab bar instance that won't be affected by PDF viewer
        let tabBarViewModel = AIPageViewController(isTabBarInstance: true)
        self._viewModel = ObservedObject(wrappedValue: tabBarViewModel)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                if showWelcomeScreen && viewModel.selectedPDFMetadata == nil {
                    WelcomeView(showPDFPicker: $showPDFPicker, showChatHistory: $showChatHistory)
                } else {
                    mainChatView
                }
                
                // Remove the floating close button
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
                
                Text("Welcome to NoteBuddy")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
                
                Text("Select your courses notes to start using NoteBuddy")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: { showPDFPicker = true }) {
                    HStack {
                        Image(systemName: "doc.badge.plus")
                        Text("Choose your Courses Notes")
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
            
            Text("NoteBuddy")
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
            print("ERROR: No authenticated user when attempting to fetch chat history")
            DispatchQueue.main.async {
                self.isLoading = false
                self.chatHistorySections = [:]
            }
            return
        }
        
        print("DEBUG: Fetching chat history for user: \(currentUser.uid)")
        print("DEBUG: User authentication state: isAnonymous=\(currentUser.isAnonymous), email=\(currentUser.email ?? "none")")
        
        // Check Firestore connection
        let testRef = viewModel.db.collection("chats").limit(to: 1)
        print("DEBUG: Testing Firestore connection before fetching chats...")
        
        testRef.getDocuments { (testSnapshot, testError) in
            if let testError = testError {
                print("ERROR: Firestore connection test failed: \(testError.localizedDescription)")
            } else {
                print("DEBUG: Firestore connection successful")
            }
            
            // Now proceed with the actual query
            print("DEBUG: Querying Firestore for chats with userId=\(currentUser.uid)")
        
        viewModel.db.collection("chats")
            .whereField("userId", isEqualTo: currentUser.uid)
            .order(by: "updatedAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                        print("ERROR: Failed to fetch chat history: \(error.localizedDescription)")
                        if let firestoreError = error as NSError? {
                            print("ERROR: Firestore error details - code: \(firestoreError.code), domain: \(firestoreError.domain)")
                            if firestoreError.code == 9 || firestoreError.code == 8 {
                                print("ERROR: This may be a permission issue or missing index")
                            }
                        }
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.chatHistorySections = [:]
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                        print("ERROR: No chat documents found (nil snapshot)")
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.chatHistorySections = [:]
                    }
                    return
                }
                
                    print("DEBUG: Found \(documents.count) chat documents for user: \(currentUser.uid)")
                    
                    if documents.isEmpty {
                        print("DEBUG: Chat documents array is empty - no chats found")
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.chatHistorySections = [:]
                        }
                        return
                    }
                
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
                        
                        // Detailed debug information about loaded chat history
                        for (pdfId, sessions) in grouped {
                            print("DEBUG: PDF ID: \(pdfId) has \(sessions.count) chat sessions")
                            for (index, session) in sessions.enumerated() {
                                print("DEBUG:   Session \(index+1): ID \(session.id), Messages: \(session.messages.count)")
                                if !session.messages.isEmpty {
                                    print("DEBUG:     First message: \(session.messages.first?.content.prefix(30) ?? "none") ...")
                                    print("DEBUG:     Last message: \(session.messages.last?.content.prefix(30) ?? "none") ...")
                                } else {
                                    print("DEBUG:     No messages in this session")
                                }
                            }
                        }
                        
                        if grouped.isEmpty {
                            print("DEBUG: No chat history was found to display")
                        }
                    }
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
    @State private var pdfs: [CategoryPDFMetadata] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var searchText = ""
    @State private var isAnonymousMode = false
    @State private var debugInfo: String = ""
    @State private var showingLoginPrompt = false
    
    // For animations
    @State private var animateLoading = false
    
    // Define a struct to hold the PDF metadata and its category
    struct CategoryPDFMetadata: Identifiable {
        var pdf: PDFMetadata
        let category: PDFCategory
        
        var id: String {
            return pdf.id
        }
    }
    
    enum PDFCategory {
        case favorite
        case uploaded
        case both
        
        var icon: String {
            switch self {
            case .favorite:
                return "heart.fill"
            case .uploaded:
                return "square.and.arrow.up.fill"
            case .both:
                return "star.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .favorite:
                return .red
            case .uploaded:
                return .blue
            case .both:
                return .purple
            }
        }
    }
    
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
                                Text("Your Notes")
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
                            
                            ForEach(filteredPDFs) { categoryPdf in
                                PDFCategoryCard(categoryPdf: categoryPdf)
                                    .onTapGesture {
                                        selectPDF(categoryPdf.pdf)
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
                    Button(action: {
                        Task {
                            await refreshPDFs()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search Notes")
            .onAppear {
                fetchAllNotes()
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
            
            Button(action: {
                Task {
                    await refreshPDFs()
                }
            }) {
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
            
            Text("You don't have any favorite or uploaded notes yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private var filteredPDFs: [CategoryPDFMetadata] {
        if searchText.isEmpty {
            return pdfs
        }
        
        return pdfs.filter { item in
            let pdf = item.pdf
            return pdf.fileName.lowercased().contains(searchText.lowercased()) ||
                   pdf.subjectName.lowercased().contains(searchText.lowercased()) ||
                   pdf.subjectCode.lowercased().contains(searchText.lowercased())
        }
    }
    
    private func fetchAllNotes() {
        isLoading = true
        errorMessage = nil
        
        guard let currentUser = Auth.auth().currentUser else {
            self.errorMessage = "You need to be signed in to access PDFs"
            self.showingLoginPrompt = true
            self.isLoading = false
            return
        }
        
        let userId = currentUser.uid
        isAnonymousMode = currentUser.isAnonymous
        
        // Create dispatch group to track both fetch operations
        let group = DispatchGroup()
        
        // Store results
        var favoriteIds = Set<String>()
        var uploadedPDFs = [PDFMetadata]()
        var allPDFs = [CategoryPDFMetadata]()
        
        // Fetch favorite note IDs
        group.enter()
        viewModel.db.collection("userFavorites")
            .document(userId)
            .collection("favorites")
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching favorites: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    favoriteIds = Set(documents.map { $0.documentID })
                    print("Found \(favoriteIds.count) favorite note IDs")
                }
            }
        
        // Fetch uploaded notes
        group.enter()
        viewModel.db.collection("pdfs")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching uploaded notes: \(error)")
                    return
                }
                
                if let documents = snapshot?.documents {
                    print("Found \(documents.count) uploaded notes")
                    
                    for document in documents {
                        let data = document.data()
                        let pdfId = document.documentID
                        
                        // Validate required fields and create metadata
                        if let fileName = data["fileName"] as? String,
                           let urlString = data["downloadURL"] as? String,
                           let url = URL(string: urlString) {
                            
                            let subjectName = data["subjectName"] as? String ?? "General"
                            let subjectCode = data["subjectCode"] as? String ?? "GEN101"
                            let fileSize = data["fileSize"] as? Int ?? 0
                            
                            let metadata = PDFMetadata(
                                id: pdfId,
                                url: url,
                                fileName: fileName,
                                subjectName: subjectName,
                                subjectCode: subjectCode,
                                fileSize: fileSize,
                                privacy: data["privacy"] as? String ?? "Public",
                                uploadDate: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                                thumbnail: nil,
                                pageCount: data["pageCount"] as? Int,
                                thumbnailIsLoading: false,
                                uploaderName: data["uploaderName"] as? String ?? "Unknown",
                                college: data["college"] as? String ?? "Unknown"
                            )
                            
                            uploadedPDFs.append(metadata)
                        }
                    }
                }
            }
        
        // Process results when both operations complete
        group.notify(queue: .main) {
            // Create a Set to track processed PDF IDs
            var processedIds = Set<String>()
            
            // First process uploaded PDFs
            for pdf in uploadedPDFs {
                let isFavorite = favoriteIds.contains(pdf.id)
                let category: PDFCategory = isFavorite ? .both : .uploaded
                allPDFs.append(CategoryPDFMetadata(pdf: pdf, category: category))
                processedIds.insert(pdf.id)
            }
            
            // Fetch any favorites that weren't in the uploaded list
            let remainingFavorites = favoriteIds.filter { !processedIds.contains($0) }
            
            if !remainingFavorites.isEmpty {
                self.fetchRemainingFavorites(favoriteIds: Array(remainingFavorites)) { favoritePDFs in
                    for pdf in favoritePDFs {
                        allPDFs.append(CategoryPDFMetadata(pdf: pdf, category: .favorite))
                    }
                    
                    self.pdfs = allPDFs
                    self.isLoading = false
                    
                    // Load thumbnails for the PDFs
                    for (index, item) in self.pdfs.enumerated() {
                        self.loadThumbnail(for: item.pdf, at: index)
                    }
                }
            } else {
                self.pdfs = allPDFs
                self.isLoading = false
                
                // Load thumbnails for the PDFs
                for (index, item) in self.pdfs.enumerated() {
                    self.loadThumbnail(for: item.pdf, at: index)
                }
            }
        }
    }
    
    private func fetchRemainingFavorites(favoriteIds: [String], completion: @escaping ([PDFMetadata]) -> Void) {
        let group = DispatchGroup()
        var favoritePDFs = [PDFMetadata]()
        
        for pdfId in favoriteIds {
            group.enter()
            
            viewModel.db.collection("pdfs").document(pdfId).getDocument { snapshot, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error fetching PDF \(pdfId): \(error)")
                    return
                }
                
                guard let document = snapshot, document.exists, let data = document.data() else {
                    print("PDF document \(pdfId) not found or empty")
                    return
                }
                
                // Extract PDF data
                if let fileName = data["fileName"] as? String,
                   let urlString = data["downloadURL"] as? String,
                   let url = URL(string: urlString) {
                    
                    let subjectName = data["subjectName"] as? String ?? "General"
                    let subjectCode = data["subjectCode"] as? String ?? "GEN101"
                    let fileSize = data["fileSize"] as? Int ?? 0
                    
                    let metadata = PDFMetadata(
                        id: pdfId,
                        url: url,
                        fileName: fileName,
                        subjectName: subjectName,
                        subjectCode: subjectCode,
                        fileSize: fileSize,
                        privacy: data["privacy"] as? String ?? "Public",
                        uploadDate: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                        thumbnail: nil,
                        pageCount: data["pageCount"] as? Int,
                        thumbnailIsLoading: false,
                        uploaderName: data["uploaderName"] as? String ?? "Unknown",
                        college: data["college"] as? String ?? "Unknown"
                    )
                    
                    favoritePDFs.append(metadata)
                }
            }
        }
        
        group.notify(queue: .main) {
            completion(favoritePDFs)
        }
    }
    
    private func loadThumbnail(for pdf: PDFMetadata, at index: Int) {
        // First check the cache
        if let cachedThumbnail = ThumbnailCache.shared.getThumbnail(for: pdf.id) {
            print("Using cached thumbnail for: \(pdf.fileName)")
            DispatchQueue.main.async {
                if index < self.pdfs.count {
                    var updatedItem = self.pdfs[index]
                    var updatedPDF = updatedItem.pdf
                    updatedPDF.thumbnail = cachedThumbnail
                    updatedItem.pdf = updatedPDF
                    self.pdfs[index] = updatedItem
                }
            }
            return
        }
        
        // No cached thumbnail, download the PDF
        print("Downloading PDF for thumbnail: \(pdf.fileName)")
        
        if let url = pdf.url {
            URLSession.shared.dataTask(with: url) { data, response, error in
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
                                    // Find the PDF in the array by ID
                                    if let idx = self.pdfs.firstIndex(where: { $0.id == pdf.id }) {
                                        var updatedItem = self.pdfs[idx]
                                        var updatedPDF = updatedItem.pdf
                                        updatedPDF.thumbnail = finalImage
                                        updatedItem.pdf = updatedPDF
                                        self.pdfs[idx] = updatedItem
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
    }
    
    private func selectPDF(_ pdf: PDFMetadata) {
        print("Selected PDF: \(pdf.fileName)")
        viewModel.selectPDFFromList(pdf)
        showWelcomeScreen = false
        dismiss()
    }
    
    // Add an async refresh function for the pull-to-refresh functionality
    private func refreshPDFs() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.fetchAllNotes()
                continuation.resume()
            }
        }
    }
}

// MARK: - PDF Category Card View
struct PDFCategoryCard: View {
    let categoryPdf: PDFSelectionView.CategoryPDFMetadata
    @State private var isImageLoading = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Enhanced Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 70, height: 90)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                if let thumbnail = categoryPdf.pdf.thumbnail {
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
                            if categoryPdf.pdf.thumbnail == nil {
                                isImageLoading = false
                            }
                        }
                    }
                    .onChange(of: categoryPdf.pdf.thumbnail) { newValue in
                        // When thumbnail loads, update the loading state
                        isImageLoading = false
                    }
                }
            }
            .frame(width: 70, height: 90)
            .overlay(
                ZStack {
                    Circle()
                        .fill(categoryPdf.category.color)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: categoryPdf.category.icon)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
                .offset(x: -5, y: -5),
                alignment: .topTrailing
            )
            
            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(categoryPdf.pdf.fileName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(categoryPdf.pdf.subjectName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack {
                    Text(categoryPdf.pdf.subjectCode)
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        // Show category badge text
                        if categoryPdf.category == .both {
                            Text("Favorite & Uploaded")
                                .font(.caption)
                                .foregroundColor(categoryPdf.category.color)
                        } else if categoryPdf.category == .favorite {
                            Text("Favorite")
                                .font(.caption)
                                .foregroundColor(categoryPdf.category.color)
                        } else {
                            Text("Uploaded")
                                .font(.caption)
                                .foregroundColor(categoryPdf.category.color)
                        }
                    }
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

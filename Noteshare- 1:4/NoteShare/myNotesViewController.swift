import UIKit
import AuthenticationServices
import VisionKit
import FirebaseStorage
import FirebaseFirestore
import PDFKit
import FirebaseAuth

struct SavedFireNote {
    let id: String
    var title: String
    let author: String
    let pdfUrl: String?
    var coverImage: UIImage?
    var isFavorite: Bool
    var pageCount: Int
    var subjectName: String?
    var subjectCode: String?
    let fileSize: String
    let dateAdded: Date
    let college: String?
    let university: String?
    let userId: String // Add userId property
    
    init(id: String, title: String, author: String, pdfUrl: String?, coverImage: UIImage? = nil,
         isFavorite: Bool = false, pageCount: Int = 0, subjectName: String? = nil,
         subjectCode: String? = nil, fileSize: String = "Unknown", dateAdded: Date = Date(),
         college: String? = nil, university: String? = nil, userId: String) {
        self.id = id
        self.title = title
        self.author = author
        self.pdfUrl = pdfUrl
        self.coverImage = coverImage
        self.isFavorite = isFavorite
        self.pageCount = pageCount
        self.subjectName = subjectName
        self.subjectCode = subjectCode
        self.fileSize = fileSize
        self.dateAdded = dateAdded
        self.college = college
        self.university = university
        self.userId = userId
    }
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "fileName": title,
            "category": author,
            "collegeName": college ?? "Unknown",
            "downloadURL": pdfUrl ?? "",
            "uploadDate": dateAdded,
            "pageCount": pageCount,
            "fileSize": fileSize,
            "userId": userId, // Use the actual userId
            "isFavorite": isFavorite,
            "subjectCode": subjectCode ?? "",
            "subjectName": subjectName ?? "",
            "privacy": "public"
        ]
    }
}

class PDFCache {
    static let shared = PDFCache()
    
    private let userDefaults = UserDefaults.standard
    private let imageCache = NSCache<NSString, UIImage>()
    private let metadataExpiryTime: TimeInterval = 5 * 60 // 5 minutes
    
    private init() {
        // Configure cache limits
        imageCache.countLimit = 100
        imageCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    // MARK: - Image Caching
    
    func getCachedImage(for key: String) -> UIImage? {
        return imageCache.object(forKey: key as NSString)
    }
    
    func cacheImage(_ image: UIImage, for key: String) {
        imageCache.setObject(image, forKey: key as NSString)
    }
    
    // MARK: - Metadata Caching
    
    func cacheNotes(curated: [SavedFireNote], favorites: [SavedFireNote]) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let timestamp = Date().timeIntervalSince1970
        
        // Cache curated notes
        let curatedData = curated.map { note -> [String: Any] in
            var data = note.dictionary
            data["cacheTimestamp"] = timestamp
            return data
        }
        
        // Cache favorite notes
        let favoritesData = favorites.map { note -> [String: Any] in
            var data = note.dictionary
            data["cacheTimestamp"] = timestamp
            return data
        }
        
        userDefaults.set(curatedData, forKey: "cached_curated_notes_\(userId)")
        userDefaults.set(favoritesData, forKey: "cached_favorite_notes_\(userId)")
        userDefaults.set(timestamp, forKey: "notes_cache_timestamp_\(userId)")
    }
    
    func getCachedNotes() -> (curated: [SavedFireNote], favorites: [SavedFireNote], isFresh: Bool) {
        guard let userId = Auth.auth().currentUser?.uid else { return ([], [], false) }
        
        // Check if cache is fresh
        let lastUpdated = userDefaults.double(forKey: "notes_cache_timestamp_\(userId)")
        let isFresh = Date().timeIntervalSince1970 - lastUpdated < metadataExpiryTime
        
        // Load cached curated notes
        var curatedNotes: [SavedFireNote] = []
        if let curatedData = userDefaults.array(forKey: "cached_curated_notes_\(userId)") as? [[String: Any]] {
            curatedNotes = curatedData.compactMap { self.createNoteFromDictionary($0) }
        }
        
        // Load cached favorite notes
        var favoriteNotes: [SavedFireNote] = []
        if let favoritesData = userDefaults.array(forKey: "cached_favorite_notes_\(userId)") as? [[String: Any]] {
            favoriteNotes = favoritesData.compactMap { self.createNoteFromDictionary($0) }
        }
        
        return (curatedNotes, favoriteNotes, isFresh)
    }
    
    private func createNoteFromDictionary(_ data: [String: Any]) -> SavedFireNote? {
        guard
            let id = data["id"] as? String,
            let title = data["fileName"] as? String,
            let author = data["category"] as? String,
            let pdfUrl = data["downloadURL"] as? String,
            let fileSize = data["fileSize"] as? String,
            let userId = data["userId"] as? String
        else {
            return nil
        }
        
        // Get image from cache
        let coverImage = getCachedImage(for: pdfUrl)
        
        // Convert date if available
        let dateAdded: Date
        if let timestamp = data["uploadDate"] as? Timestamp {
            dateAdded = timestamp.dateValue()
        } else if let timestamp = data["uploadDate"] as? TimeInterval {
            dateAdded = Date(timeIntervalSince1970: timestamp)
        } else {
            dateAdded = Date()
        }
        
        return SavedFireNote(
            id: id,
            title: title,
            author: author,
            pdfUrl: pdfUrl,
            coverImage: coverImage,
            isFavorite: data["isFavorite"] as? Bool ?? false,
            pageCount: data["pageCount"] as? Int ?? 0,
            subjectName: data["subjectName"] as? String,
            subjectCode: data["subjectCode"] as? String,
            fileSize: fileSize,
            dateAdded: dateAdded,
            college: data["collegeName"] as? String,
            university: data["universityName"] as? String,
            userId: userId  // Add the userId from the method parameter
        )
    }
    
    // MARK: - PDF File Caching
    
    func cachePDFPath(for noteId: String, fileURL: URL) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var cachedPaths = userDefaults.dictionary(forKey: "cached_pdf_paths_\(userId)") as? [String: String] ?? [:]
        cachedPaths[noteId] = fileURL.path
        userDefaults.set(cachedPaths, forKey: "cached_pdf_paths_\(userId)")
    }
    
    func getCachedPDFPath(for noteId: String) -> URL? {
        guard let userId = Auth.auth().currentUser?.uid else { return nil }
        
        if let cachedPaths = userDefaults.dictionary(forKey: "cached_pdf_paths_\(userId)") as? [String: String],
           let path = cachedPaths[noteId] {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        
        return nil
    }
    
    // MARK: - Clear Cache
    
    func clearCache() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        imageCache.removeAllObjects()
        userDefaults.removeObject(forKey: "cached_curated_notes_\(userId)")
        userDefaults.removeObject(forKey: "cached_favorite_notes_\(userId)")
        userDefaults.removeObject(forKey: "notes_cache_timestamp_\(userId)")
        
        // Delete cached PDFs
        if let cachedPaths = userDefaults.dictionary(forKey: "cached_pdf_paths_\(userId)") as? [String: String] {
            for path in cachedPaths.values {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: path))
            }
        }
        
        userDefaults.removeObject(forKey: "cached_pdf_paths_\(userId)")
    }
}

class FirebaseService1 {
    static let shared = FirebaseService1()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private var notesListener: ListenerRegistration?
    
    // Fetch notes for a specific user
    func observeNotes(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
            // Add this flag to prevent multiple leaves
            var hasLeft = false
            
            self.notesListener = db.collection("pdfs")
                .whereField("userId", isEqualTo: userId)
                .addSnapshotListener { (snapshot, error) in
                    if let error = error {
                        print("Error observing notes: \(error.localizedDescription)")
                        // Only leave once
                        if !hasLeft {
                            completion([])
                            hasLeft = true
                        }
                        return
                    }

                    guard let documents = snapshot?.documents else {
                        // Only leave once
                        if !hasLeft {
                            completion([])
                            hasLeft = true
                        }
                        return
                    }

                    var notes: [SavedFireNote] = []
                    let group = DispatchGroup()

                    for document in documents {
                        group.enter()
                        let data = document.data()
                        let pdfUrl = data["downloadURL"] as? String ?? ""
                        let noteId = document.documentID

                        self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                            let fileSize = self.formatFileSize(metadata?.size ?? 0)

                            self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                                let note = SavedFireNote(
                                    id: noteId,
                                    title: data["fileName"] as? String ?? "Untitled",
                                    author: data["category"] as? String ?? "Unknown Author",
                                    pdfUrl: pdfUrl,
                                    coverImage: image,
                                    isFavorite: false,
                                    pageCount: pageCount,
                                    subjectName: data["subjectName"] as? String,
                                    subjectCode: data["subjectCode"] as? String,
                                    fileSize: fileSize,
                                    dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                                    college: data["collegeName"] as? String,
                                    university: data["universityName"] as? String,
                                    userId: userId  // Add the userId from the method parameter
                                )
                                notes.append(note)
                                group.leave()
                            }
                        }
                    }

                    group.notify(queue: .main) {
                        // Only deliver result once per call to prevent multiple leaves in the caller
                        if !hasLeft {
                            completion(notes.sorted { $0.dateAdded > $1.dateAdded })
                            hasLeft = true
                        }
                    }
                }
        }

    
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
     func getStorageReference(from urlString: String) -> StorageReference? {
        guard !urlString.isEmpty else {
            print("Warning: Empty URL string provided to getStorageReference")
            return nil
        }
        
        do {
            if urlString.starts(with: "gs://") {
                return storage.reference(forURL: urlString)
            }
            
            if urlString.contains("firebasestorage.googleapis.com") {
                return storage.reference(forURL: urlString)
            }
            
            if urlString.starts(with: "/") {
                return storage.reference().child(urlString)
            }
            
            return storage.reference().child(urlString)
        } catch {
            print("Error creating storage reference for URL: \(urlString), error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func fetchPDFCoverImage(from urlString: String, completion: @escaping (UIImage?, Int) -> Void) {
        guard !urlString.isEmpty else {
            print("Empty PDF URL provided")
            completion(nil, 0)
            return
        }

        guard let storageRef = getStorageReference(from: urlString) else {
            print("Invalid storage reference for URL: \(urlString)")
            completion(nil, 0)
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")

        storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Error downloading PDF for cover from \(urlString): \(error.localizedDescription)")
                completion(nil, 0)
                return
            }

            guard let pdfURL = url, FileManager.default.fileExists(atPath: pdfURL.path) else {
                print("Failed to download PDF to \(localURL.path)")
                completion(nil, 0)
                return
            }

            guard let pdfDocument = PDFDocument(url: pdfURL) else {
                print("Failed to create PDFDocument from \(pdfURL.path)")
                completion(nil, 0)
                return
            }

            let pageCount = pdfDocument.pageCount
            guard pageCount > 0, let pdfPage = pdfDocument.page(at: 0) else {
                print("No pages found in PDF at \(pdfURL.path)")
                completion(nil, pageCount)
                return
            }

            let pageRect = pdfPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                pdfPage.draw(with: .mediaBox, to: context.cgContext)
            }

            do {
                try FileManager.default.removeItem(at: pdfURL)
            } catch {
                print("Failed to delete temp file: \(error)")
            }

            completion(image, pageCount)
        }
    }
    
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !urlString.isEmpty else {
            let error = NSError(domain: "PDFDownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty PDF URL"])
            print("Download failed: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        guard let storageRef = getStorageReference(from: urlString) else {
            let error = NSError(domain: "PDFDownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid storage reference URL: \(urlString)"])
            print("Download failed: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        let fileName = UUID().uuidString + ".pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent(fileName)

        if FileManager.default.fileExists(atPath: localURL.path) {
            do {
                try FileManager.default.removeItem(at: localURL)
                print("Removed existing file at \(localURL.path)")
            } catch {
                print("Failed to remove existing file: \(error)")
                completion(.failure(error))
                return
            }
        }

        print("Starting download from \(urlString) to \(localURL.path)")
        let downloadTask = storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                // Enhanced error logging
                if let nsError = error as NSError? {
                    let errorCode = nsError.code
                    let errorDesc = nsError.localizedDescription
                    let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
                    print("Download error for \(urlString): Code \(errorCode) - \(errorDesc)")
                    if let underlyingDesc = underlyingError?.localizedDescription {
                        print("Underlying error: \(underlyingDesc)")
                    }
                } else {
                    print("Download error for \(urlString): \(error.localizedDescription)")
                }
                completion(.failure(error))
                return
            }

            guard let url = url else {
                let error = NSError(domain: "PDFDownloadError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded file URL is nil"])
                print("Download failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            if FileManager.default.fileExists(atPath: url.path) {
                if let pdfDocument = PDFDocument(url: url) {
                    print("PDF loaded successfully with \(pdfDocument.pageCount) pages at \(url.path)")
                    completion(.success(url))
                } else {
                    let error = NSError(domain: "PDFDownloadError", code: -4, userInfo: [NSLocalizedDescriptionKey: "Invalid PDF at \(url.path)"])
                    print("Download failed: \(error.localizedDescription)")
                    completion(.failure(error))
                }
            } else {
                let error = NSError(domain: "PDFDownloadError", code: -5, userInfo: [NSLocalizedDescriptionKey: "File not found at \(url.path) after download"])
                print("Download failed: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }

        downloadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress?.completedUnitCount ?? 0) /
                Double(snapshot.progress?.totalUnitCount ?? 1)
            print("Download progress for \(urlString): \(percentComplete)%")
        }
    }
    
    
    //    fav
    // Ensure fetchFavoriteNotes works correctly
    func fetchFavoriteNotes(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
        self.db.collection("userFavorites")
            .document(userId)
            .collection("favorites")
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error fetching favorite note IDs: \(error.localizedDescription)")
                    completion([])
                    return
                }

                guard let favoriteDocs = snapshot?.documents, !favoriteDocs.isEmpty else {
                    print("No favorite notes found for user \(userId)")
                    completion([])
                    return
                }

                let favoriteIds = favoriteDocs.map { $0.documentID }
                let group = DispatchGroup()
                var favoriteNotes: [SavedFireNote] = []

                for noteId in favoriteIds {
                    group.enter()
                    self.db.collection("pdfs").document(noteId).getDocument { (document, error) in
                        if let error = error {
                            print("Error fetching note \(noteId): \(error)")
                            group.leave()
                            return
                        }

                        guard let data = document?.data(), document?.exists ?? false else {
                            print("Note \(noteId) not found")
                            group.leave()
                            return
                        }

                        let pdfUrl = data["downloadURL"] as? String ?? ""
                        self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                            if let error = error { print("Metadata error for \(pdfUrl): \(error)") }
                            let fileSize = self.formatFileSize(metadata?.size ?? 0)

                            self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                                let note = SavedFireNote(
                                    id: noteId,
                                    title: data["fileName"] as? String ?? "Untitled",
                                    author: data["category"] as? String ?? "Unknown Author",
                                    pdfUrl: pdfUrl,
                                    coverImage: image,
                                    isFavorite: true,
                                    pageCount: pageCount,
                                    subjectName: data["subjectName"] as? String,
                                    subjectCode: data["subjectCode"] as? String,
                                    fileSize: fileSize,
                                    dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                                    college: data["collegeName"] as? String,
                                    university: data["universityName"] as? String,
                                    userId: userId  // Add the userId from the method parameter
                                )
                                favoriteNotes.append(note)
                                group.leave()
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    print("Fetched \(favoriteNotes.count) favorite notes for user \(userId)")
                    completion(favoriteNotes.sorted { $0.dateAdded > $1.dateAdded })
                }
            }
    }
    
    // Fetch favorite note IDs for the user
        private func fetchUserFavorites(userId: String, completion: @escaping ([String]) -> Void) {
            db.collection("userFavorites")
                .document(userId)
                .collection("favorites")
                .whereField("isFavorite", isEqualTo: true)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching favorites: \(error)")
                        completion([])
                        return
                    }
                    let favoriteIds = snapshot?.documents.map { $0.documentID } ?? []
                    completion(favoriteIds)
                }
        }
    
    
    // Update favorite status
    func updateFavoriteStatus(for noteId: String, isFavorite: Bool, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }
        
        let favoriteRef = db.collection("userFavorites").document(userId).collection("favorites").document(noteId)
        
        if isFavorite {
            favoriteRef.setData([
                "isFavorite": true,
                "timestamp": Timestamp(date: Date())
            ]) { error in
                completion(error)
            }
        } else {
            favoriteRef.delete { error in
                completion(error)
            }
        }
    }
}
    // fav end


import PDFKit
import UIKit

class NoteCollectionViewCell1: UICollectionViewCell {
    var noteId: String?
    
    private let containerView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemBackground
            view.layer.cornerRadius = 8
            view.clipsToBounds = false
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
    
    private let bookBackgroundView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 6
        view.clipsToBounds = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
 
    
    private let spineEffectLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.black.withAlphaComponent(0.3).cgColor,
            UIColor.black.withAlphaComponent(0.1).cgColor,
            UIColor.clear.cgColor
        ]
        layer.startPoint = CGPoint(x: 0, y: 0.5)
        layer.endPoint = CGPoint(x: 1, y: 0.5)
        return layer
    }()
    
    private let topEdgeShadowLayer: CALayer = {
        let layer = CALayer()
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
        layer.masksToBounds = false
        return layer
    }()
    
    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.locations = [0.7, 1.0]
        return layer
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .bold) // Increased font size and made bold
        label.textColor = .white
        label.numberOfLines = 3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subjectLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .semibold) // Adjusted font size and made semibold
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 3
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let userNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 2
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    var isFavorite: Bool = false {
        didSet {
            updateFavoriteButtonImage()
        }
    }
    
    var favoriteButtonTapped: (() -> Void)?
    
    // Closure to notify the parent view controller of a long press
    var onLongPress: ((SavedFireNote) -> Void)?

    

    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5 // Default 0.5 seconds
        self.addGestureRecognizer(longPressGesture)
    }

    // Add a property for the haptic feedback generator
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let note = note else { return }
        
        print("Long press detected on note: \(note.id)") // Debug line
        
        // Trigger haptic feedback
        impactFeedbackGenerator.prepare()
        impactFeedbackGenerator.impactOccurred()
        
        onLongPress?(note)
    }
    
    
    private let colors: [UIColor] = [
        UIColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0), // Red
        UIColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1.0), // Blue
        UIColor(red: 0.3, green: 0.7, blue: 0.3, alpha: 1.0), // Green
        UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0)  // Orange
    ]
    
    private var currentColor: UIColor? // Store the current color to prevent flickering
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupLongPressGesture()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
            contentView.addSubview(containerView)
            containerView.addSubview(bookBackgroundView) // Directly add bookBackgroundView
            bookBackgroundView.layer.addSublayer(gradientLayer)
            bookBackgroundView.layer.addSublayer(spineEffectLayer)
            bookBackgroundView.addSubview(titleLabel)
            bookBackgroundView.addSubview(subjectLabel)
            bookBackgroundView.addSubview(userNameLabel)
            bookBackgroundView.addSubview(favoriteButton)
            bookBackgroundView.layer.addSublayer(topEdgeShadowLayer)
            
            setupConstraints()
            favoriteButton.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
            
            // Remove or comment out these lines to eliminate the cell's border
            // layer.borderColor = UIColor.white.cgColor
            // layer.borderWidth = 1.0
            layer.cornerRadius = 8.0
            layer.masksToBounds = true

            // Keep shadow for refined look
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.shadowOffset = CGSize(width: 0, height: 2)
            layer.shadowRadius = 4
            layer.masksToBounds = false
        }
    
    private func setupConstraints() {
            NSLayoutConstraint.activate([
                // Container View
                containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
                containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
                containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
                containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
                
                // Book Background View (updated to anchor to containerView directly)
                bookBackgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
                bookBackgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                bookBackgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                bookBackgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                
                // Title Label
                titleLabel.topAnchor.constraint(equalTo: bookBackgroundView.topAnchor, constant: 16),
                titleLabel.leadingAnchor.constraint(equalTo: bookBackgroundView.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: bookBackgroundView.trailingAnchor, constant: -12),
                
                // Subject Label
                subjectLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                subjectLabel.leadingAnchor.constraint(equalTo: bookBackgroundView.leadingAnchor, constant: 12),
                subjectLabel.trailingAnchor.constraint(equalTo: bookBackgroundView.trailingAnchor, constant: -12),
                
                // User Name Label
                userNameLabel.bottomAnchor.constraint(equalTo: bookBackgroundView.bottomAnchor, constant: -16),
                userNameLabel.leadingAnchor.constraint(equalTo: bookBackgroundView.leadingAnchor, constant: 12),
                userNameLabel.trailingAnchor.constraint(equalTo: bookBackgroundView.trailingAnchor, constant: -12),
                
                // Favorite Button
                favoriteButton.topAnchor.constraint(equalTo: bookBackgroundView.topAnchor, constant: 8),
                favoriteButton.trailingAnchor.constraint(equalTo: bookBackgroundView.trailingAnchor, constant: -8),
                favoriteButton.widthAnchor.constraint(equalToConstant: 24),
                favoriteButton.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 10
            layer.shadowOpacity = 0.1
            layer.masksToBounds = false
            
            gradientLayer.frame = bookBackgroundView.bounds
            spineEffectLayer.frame = CGRect(x: 0, y: 0, width: 12, height: bookBackgroundView.bounds.height)
            topEdgeShadowLayer.frame = CGRect(x: 0, y: 0, width: bookBackgroundView.bounds.width, height: 2)
        }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        subjectLabel.text = nil
        userNameLabel.text = nil
        noteId = nil
        isFavorite = false
        bookBackgroundView.backgroundColor = nil
//        gradientLayer.colors = nil
//        currentColor = nil // Reset the current color
    }
    
    public func updateFavoriteButtonImage() {
        let image = isFavorite ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        favoriteButton.setImage(image, for: .normal)
        favoriteButton.tintColor = isFavorite ? .systemRed : .systemGray
    }
    
    @objc private func favoriteButtonPressed() {
        isFavorite.toggle()
        updateFavoriteButtonImage()
        
        guard let noteId = noteId else { return }
        
        UIView.animate(withDuration: 0.1, animations: {
            self.favoriteButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        }, completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.favoriteButton.transform = .identity
            }
        })
        
        NotificationCenter.default.post(
            name: NSNotification.Name("FavoriteStatusChanged"),
            object: nil,
            userInfo: ["noteId": noteId, "isFavorite": isFavorite]
        )
        
        FirebaseService1.shared.updateFavoriteStatus(for: noteId, isFavorite: isFavorite) { error in
            if let error = error {
                print("Error updating favorite status: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    self.isFavorite.toggle()
                    self.updateFavoriteButtonImage()
                    
                    NotificationCenter.default.post(
                        name: NSNotification.Name("FavoriteStatusChanged"),
                        object: nil,
                        userInfo: ["noteId": noteId, "isFavorite": !self.isFavorite]
                    )
                }
            }
        }
    }
    
    private func fetchUserName(userId: String, completion: @escaping (String) -> Void) {
            let db = Firestore.firestore()
            db.collection("users").document(userId).getDocument { (document, error) in
                if let document = document, document.exists, let name = document.data()?["name"] as? String {
                    completion(name)
                } else {
                    completion("Unknown User")
                }
            }
        }
    
    private func setGradientForColor(_ color: UIColor) {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            
            let darkerColor = UIColor(red: max(red - 0.2, 0),
                                     green: max(green - 0.2, 0),
                                     blue: max(blue - 0.2, 0),
                                     alpha: alpha)
            
            gradientLayer.colors = [
                UIColor.clear.cgColor,
                darkerColor.withAlphaComponent(0.5).cgColor
            ]
        }
    
    private var note: SavedFireNote?

    func configure(with note: SavedFireNote) {
            self.note = note
            noteId = note.id
            
            // Set text immediately to avoid flickering
            titleLabel.text = note.title
            if let subjectInfo = note.subjectName, !subjectInfo.isEmpty {
                subjectLabel.text = subjectInfo
            } else if let subjectCode = note.subjectCode, !subjectCode.isEmpty {
                subjectLabel.text = subjectCode
            } else {
                subjectLabel.text = "No Subject"
            }
            
            // Set username synchronously if cached, otherwise placeholder
            userNameLabel.text = "By Loading..." // Placeholder
            fetchUserName(userId: note.userId) { [weak self] userName in
                DispatchQueue.main.async {
                    // Only update if this cell is still displaying the same note
                    if self?.noteId == note.id {
                        self?.userNameLabel.text = "By \(userName)"
                    }
                }
            }
            
            // Set color only if it’s different or not set
            let colorIndex = abs(note.id.hashValue % colors.count)
            let selectedColor = colors[colorIndex]
            if currentColor != selectedColor {
                currentColor = selectedColor
                bookBackgroundView.backgroundColor = selectedColor
                setGradientForColor(selectedColor)
            }
            
            isFavorite = note.isFavorite
            updateFavoriteButtonImage()
            
            // Update shadow (no change needed here)
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOffset = CGSize(width: 0, height: 3)
            layer.shadowRadius = 10
            layer.shadowOpacity = 0.1
            layer.masksToBounds = false
            
            // Remove animation to prevent flickering during scroll
            // alpha = 0
            // UIView.animate(withDuration: 0.3) {
            //     self.alpha = 1
            // }
        }
}

class PDFCollectionViewCell: UICollectionViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        
        [coverImageView, titleLabel, authorLabel, descriptionLabel].forEach {
            containerView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.5),
            
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            descriptionLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Ensure descriptionLabel doesn't expand uncontrollably
            descriptionLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            
            // Allow some flexibility while ensuring it doesn't overflow
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }

       
    func configure(with note: Note) {
        titleLabel.text = note.title
        authorLabel.text = "By \(note.author)"
        descriptionLabel.text = note.description
        coverImageView.image = note.coverImage
    }
}


class SavedViewController: UIViewController, UIScrollViewDelegate, UITableViewDelegate, UITableViewDataSource, VNDocumentCameraViewControllerDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let note = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = note.title
        content.secondaryText = "\(note.subjectName ?? note.author) • Pages: \(note.pageCount) • \(note.fileSize)"
        content.image = note.coverImage ?? UIImage(systemName: "doc.fill")
        content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
        content.imageProperties.cornerRadius = 4
        
        cell.contentConfiguration = content
        return cell
    }
    
    // MARK: - Previously Read Notes Storage
    struct PreviouslyReadNote {
        let id: String
        let title: String
        let pdfUrl: String
        let lastOpened: Date
    }

    // MARK: - Properties
    private var curatedNotes: [SavedFireNote] = []
    private var favoriteNotes: [SavedFireNote] = []
    private var allNotes: [SavedFireNote] = []
    private var searchResults: [SavedFireNote] = []
    
    private var curatedPlaceholderView: PlaceholderView?
    private var favoritePlaceholderView: PlaceholderView?
    
    // Cache for PDF thumbnails
    private let imageCache = NSCache<NSString, UIImage>()
    
    // Firestore listeners
    private var notesListener: ListenerRegistration?
    
    // Loading state
    private var isLoading = false
    
    // Keep existing code, but add a refresh control
    private let refreshControl = UIRefreshControl()
    // Track if we're doing a background refresh
    private var isBackgroundRefreshing = false
    
    // Reference to Firestore
    private let db = Firestore.firestore()
    
    // MARK: - UI Elements
    private let uploadNotesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upload Notes", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium) // Reduced from 16 to 14
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        // Add icon
        let icon = UIImage(systemName: "arrow.up.doc")?.withTintColor(.systemPurple, renderingMode: .alwaysOriginal)
        button.setImage(icon, for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        // Increased width by adjusting left and right contentEdgeInsets from 15 to 25
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 25, bottom: 14, right: 25)
        
        return button
    }()

    private let scanDocumentButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Scan Document", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium) // Reduced from 16 to 14
        button.setTitleColor(.black, for: .normal)
        button.backgroundColor = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1.0)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Shadow
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        
        // Add icon
        let icon = UIImage(systemName: "doc.viewfinder")?.withTintColor(.systemPurple, renderingMode: .alwaysOriginal)
        button.setImage(icon, for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        // Increased width by adjusting left and right contentEdgeInsets from 15 to 25
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 25, bottom: 14, right: 25)
        
        return button
    }()
    private let favoriteNotesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Favourites", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        button.setTitleColor(.label, for: .normal)
        button.semanticContentAttribute = .forceLeftToRight
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let seeAllFavoritesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("See All", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    lazy var favoriteNotesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 280)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 5, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "FavoriteNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let curatedNotesButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Uploaded Notes", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        button.setTitleColor(.label, for: .normal)
        button.semanticContentAttribute = .forceLeftToRight
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let seeAllUploadedButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("See All", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    lazy var curatedNotesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 280)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 5, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "CuratedNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Add search results table view (though it won't be used since search bar is removed)
    private lazy var searchResultsTableView: UITableView = {
        let tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        tableView.backgroundColor = .systemBackground
        return tableView
    }()
    
    // MARK: - Previously Read Notes Storage
    private func savePreviouslyReadNote(_ note: PreviouslyReadNote) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        var history = loadPreviouslyReadNotes()
        
        history.removeAll { $0.id == note.id }
        history.append(note)
        history.sort { $0.lastOpened > $1.lastOpened }
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        
        let historyData = history.map { [
            "id": $0.id,
            "title": $0.title,
            "pdfUrl": $0.pdfUrl,
            "lastOpened": $0.lastOpened.timeIntervalSince1970
        ]}
        UserDefaults.standard.set(historyData, forKey: "previouslyReadNotes_\(userId)")
        
        NotificationCenter.default.post(name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
    }

    private func loadPreviouslyReadNotes() -> [PreviouslyReadNote] {
        guard let userId = Auth.auth().currentUser?.uid else { return [] }
        guard let historyData = UserDefaults.standard.array(forKey: "previouslyReadNotes_\(userId)") as? [[String: Any]] else {
            return []
        }
        
        return historyData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let pdfUrl = dict["pdfUrl"] as? String,
                  let lastOpenedTimestamp = dict["lastOpened"] as? TimeInterval else { return nil }
            
            return PreviouslyReadNote(id: id, title: title, pdfUrl: pdfUrl, lastOpened: Date(timeIntervalSince1970: lastOpenedTimestamp))
        }
    }
    
    private func updateAllNotes() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let combinedNotes = (self.curatedNotes + self.favoriteNotes)
                .sorted { $0.dateAdded > $1.dateAdded }
                .removingDuplicates(by: \.id)
            
            DispatchQueue.main.async {
                self.allNotes = combinedNotes
                self.searchResults = self.allNotes
            }
        }
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        setupPlaceholders()
        updatePlaceholderVisibility()
        
        setupDelegates()
        configureNavigationBar()
        setupRefreshControl()
        
        updateCollectionViewLayouts()
        
        setupNotifications()
        
        loadDataFromCache()
        
        checkAndRefreshData()
        
        scrollView.delegate = self
        searchResultsTableView.delegate = self
        searchResultsTableView.dataSource = self
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handleFavoriteStatusChange),
                                              name: NSNotification.Name("FavoriteStatusChanged"),
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handlePreviouslyReadNotesUpdated),
                                              name: NSNotification.Name("PreviouslyReadNotesUpdated"),
                                              object: nil)
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handlePDFUploadSuccess),
                                              name: NSNotification.Name("PDFUploadedSuccessfully"),
                                              object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
        
        if !curatedNotes.isEmpty || !favoriteNotes.isEmpty {
            refreshDataInBackground()
        } else {
            loadDataFromCache()
            checkAndRefreshData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        notesListener?.remove()
    }
    
    // MARK: - Data Loading
    private func loadDataFromCache() {
        let cachedData = PDFCache.shared.getCachedNotes()
        
        if !cachedData.curated.isEmpty || !cachedData.favorites.isEmpty {
            self.curatedNotes = cachedData.curated
            self.favoriteNotes = cachedData.favorites
            self.updateAllNotes()
            self.curatedNotesCollectionView.reloadData()
            self.favoriteNotesCollectionView.reloadData()
            self.updatePlaceholderVisibility()
        }
    }
    
    private func checkAndRefreshData() {
        let cachedData = PDFCache.shared.getCachedNotes()
        
        if !cachedData.isFresh {
            loadData(forceRefresh: false)
        }
    }
    
    private func loadData(forceRefresh: Bool = false) {
        if isLoading && !forceRefresh {
            return
        }
        
        isLoading = true
        
        if curatedNotes.isEmpty {
            updatePlaceholderVisibility()
        }
        
        guard let userId = Auth.auth().currentUser?.uid else {
            isLoading = false
            updatePlaceholderVisibility()
            return
        }
        
        if !forceRefresh {
            let (cachedCuratedNotes, cachedFavoriteNotes, isFresh) = PDFCache.shared.getCachedNotes()
            
            if !cachedCuratedNotes.isEmpty || !cachedFavoriteNotes.isEmpty {
                self.curatedNotes = cachedCuratedNotes
                self.favoriteNotes = cachedFavoriteNotes
                
                updateUIWithLoadedData()
                
                if !isFresh {
                    isBackgroundRefreshing = true
                    refreshDataFromFirebase(userId: userId)
                } else {
                    isLoading = false
                    generateMissingThumbnailsAndMetadata()
                }
                return
            }
        }
        
        refreshDataFromFirebase(userId: userId)
    }
    
    private func refreshDataFromFirebase(userId: String) {
        let group = DispatchGroup()
        
        var loadedCuratedNotes: [SavedFireNote] = []
            var loadedFavoriteNotes: [SavedFireNote] = []
            var loadError: Error?
            
            group.enter() // Fixed: Changed from group.enter1.enter() to group.enter()
            self.fetchCuratedNotesMetadata(userId: userId) { notes in
                loadedCuratedNotes = notes
                group.leave()
            }
        
        group.enter()
        self.fetchFavoriteNotesMetadata(userId: userId) { notes in
            loadedFavoriteNotes = notes
            group.leave()
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if let error = loadError {
                print("Error loading notes: \(error.localizedDescription)")
            }
            
            self.curatedNotes = loadedCuratedNotes
            self.favoriteNotes = loadedFavoriteNotes
            
            PDFCache.shared.cacheNotes(curated: self.curatedNotes, favorites: self.favoriteNotes)
            
            self.updateUIWithLoadedData()
            
            self.isLoading = false
            self.isBackgroundRefreshing = false
            
            self.generateMissingThumbnailsAndMetadata()
        }
    }
    
    private func generateMissingThumbnailsAndMetadata() {
        let processingQueue = DispatchQueue(label: "com.noteshare.thumbnailprocessing", qos: .utility, attributes: .concurrent)
        
        let notesToProcess = curatedNotes + favoriteNotes
        
        for (index, note) in notesToProcess.enumerated() {
            if note.coverImage != nil && note.pageCount > 0 {
                continue
            }
            
            processingQueue.async { [weak self] in
                guard let self = self else { return }
                
                if let metadata = self.extractMetadataFromLocalPDF(for: note) {
                    DispatchQueue.main.async {
                        self.updateNoteMetadataInAllCollections(
                            noteId: note.id,
                            pageCount: metadata.pageCount,
                            thumbnail: metadata.thumbnail
                        )
                    }
                    return
                }
                
                guard let url = URL(string: note.pdfUrl ?? "") else { return }
                
                var request = URLRequest(url: url)
                request.setValue("bytes=0-200000", forHTTPHeaderField: "Range")
                
                let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                    guard let self = self, let data = data, error == nil else { return }
                    
                    if let pdfDocument = PDFDocument(data: data) {
                        let pageCount = pdfDocument.pageCount
                        var thumbnail: UIImage? = nil
                        
                        if let page = pdfDocument.page(at: 0) {
                            thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                            
                            if let thumbnail = thumbnail {
                                PDFCache.shared.cacheImage(thumbnail, for: note.pdfUrl ?? "")
                            }
                        }
                        
                        if pageCount > 0 {
                            self.db.collection("pdfs").document(note.id).updateData([
                                "pageCount": pageCount
                            ]) { error in
                                if let error = error {
                                    print("Error updating page count: \(error)")
                                }
                            }
                        }
                        
                        DispatchQueue.main.async {
                            self.updateNoteMetadataInAllCollections(
                                noteId: note.id,
                                pageCount: pageCount,
                                thumbnail: thumbnail
                            )
                        }
                    }
                }
                
                task.resume()
            }
        }
    }
    
    private func updateNoteMetadataInAllCollections(noteId: String, pageCount: Int, thumbnail: UIImage?) {
        for i in 0..<curatedNotes.count {
            if curatedNotes[i].id == noteId {
                if pageCount > 0 {
                    curatedNotes[i].pageCount = pageCount
                }
                if let thumbnail = thumbnail {
                    curatedNotes[i].coverImage = thumbnail
                }
            }
        }
        
        for i in 0..<favoriteNotes.count {
            if favoriteNotes[i].id == noteId {
                if pageCount > 0 {
                    favoriteNotes[i].pageCount = pageCount
                }
                if let thumbnail = thumbnail {
                    favoriteNotes[i].coverImage = thumbnail
                }
            }
        }
        
        for i in 0..<searchResults.count {
            if searchResults[i].id == noteId {
                if pageCount > 0 {
                    searchResults[i].pageCount = pageCount
                }
                if let thumbnail = thumbnail {
                    searchResults[i].coverImage = thumbnail
                }
            }
        }
        
        for i in 0..<allNotes.count {
            if allNotes[i].id == noteId {
                if pageCount > 0 {
                    allNotes[i].pageCount = pageCount
                }
                if let thumbnail = thumbnail {
                    allNotes[i].coverImage = thumbnail
                }
            }
        }
        
        curatedNotesCollectionView.reloadData()
        favoriteNotesCollectionView.reloadData()
        
        if !searchResults.isEmpty {
            searchResultsTableView.reloadData()
        }
    }
    
    private func fetchUserFavorites(userId: String, completion: @escaping ([String]) -> Void) {
        db.collection("userFavorites")
            .document(userId)
            .collection("favorites")
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching favorites: \(error)")
                    completion([])
                    return
                }
                let favoriteIds = snapshot?.documents.map { $0.documentID } ?? []
                completion(favoriteIds)
            }
    }
    
    private func fetchCuratedNotesMetadata(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
        db.collection("pdfs")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error observing notes: \(error.localizedDescription)")
                    
                    if !self.isBackgroundRefreshing {
                        DispatchQueue.main.async {
                            let errorMsg = error.localizedDescription
                            if errorMsg.contains("requires an index") {
                                self.showAlert(title: "Database Setup Required",
                                          message: "Your Firebase database needs an index to be set up. Please create the index using the Firebase console or contact the app developer.")
                            } else {
                                self.showAlert(title: "Error Loading Notes", message: errorMsg)
                            }
                        }
                    }
                    
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                self.fetchUserFavorites(userId: userId) { favoriteIds in
                    let notesGroup = DispatchGroup()
                    var notes: [SavedFireNote] = []
                    
                    for document in documents {
                        let data = document.data()
                        let pdfUrl = data["downloadURL"] as? String ?? ""
                        let noteId = document.documentID
                        let noteUserId = data["userId"] as? String ?? "" // Extract userId from document
                        
                        notesGroup.enter()
                        
                        let coverImage = PDFCache.shared.getCachedImage(for: pdfUrl)
                        
                        let uploadDate = (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date()
                        
                        var pageCount = data["pageCount"] as? Int ?? 0
                        
                        var note = SavedFireNote(
                            id: noteId,
                            title: data["fileName"] as? String ?? "Untitled",
                            author: data["category"] as? String ?? "Unknown Author",
                            pdfUrl: pdfUrl,
                            coverImage: coverImage,
                            isFavorite: favoriteIds.contains(noteId),
                            pageCount: pageCount,
                            subjectName: data["subjectName"] as? String,
                            subjectCode: data["subjectCode"] as? String,
                            fileSize: data["fileSize"] as? String ?? "Unknown",
                            dateAdded: uploadDate,
                            college: data["collegeName"] as? String,
                            university: data["universityName"] as? String,
                            userId: noteUserId // Pass the userId
                        )
                        
                        if pageCount == 0 {
                            if let metadata = self.extractMetadataFromLocalPDF(for: note) {
                                note.pageCount = metadata.pageCount
                                note.coverImage = metadata.thumbnail ?? note.coverImage
                                notes.append(note)
                                notesGroup.leave()
                            } else {
                                DispatchQueue.global(qos: .utility).async {
                                    if let url = URL(string: pdfUrl),
                                       let data = try? Data(contentsOf: url, options: [.alwaysMapped, .dataReadingMapped]),
                                       let pdfDocument = PDFDocument(data: data) {
                                        
                                        note.pageCount = pdfDocument.pageCount
                                        
                                        if note.coverImage == nil, let page = pdfDocument.page(at: 0) {
                                            note.coverImage = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                                            if let coverImage = note.coverImage {
                                                PDFCache.shared.cacheImage(coverImage, for: pdfUrl)
                                            }
                                        }
                                        
                                        self.db.collection("pdfs").document(noteId).updateData([
                                            "pageCount": note.pageCount
                                        ]) { _ in }
                                    }
                                    
                                    notes.append(note)
                                    notesGroup.leave()
                                }
                            }
                        } else {
                            notes.append(note)
                            notesGroup.leave()
                        }
                    }
                    
                    notesGroup.notify(queue: .main) {
                        let sortedNotes = notes.sorted { $0.dateAdded > $1.dateAdded }
                        
                        completion(sortedNotes)
                        
                        self.loadThumbnailsForVisibleNotes()
                        
                        self.loadThumbnailsInBackground(for: sortedNotes)
                    }
                }
            }
    }
    
    private func fetchFavoriteNotesMetadata(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
        self.db.collection("userFavorites")
            .document(userId)
            .collection("favorites")
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else {
                    completion([])
                    return
                }
                
                if let error = error {
                    print("Error fetching favorite note IDs: \(error.localizedDescription)")
                    
                    if !self.isBackgroundRefreshing {
                        DispatchQueue.main.async {
                            self.showAlert(title: "Error Loading Favorites", message: error.localizedDescription)
                        }
                    }
                    
                    completion([])
                    return
                }
                
                guard let favoriteDocs = snapshot?.documents, !favoriteDocs.isEmpty else {
                    print("No favorite notes found for user \(userId)")
                    completion([])
                    return
                }
                
                let favoriteIds = favoriteDocs.map { $0.documentID }
                var favoriteNotes: [SavedFireNote] = []
                let group = DispatchGroup()
                
                if favoriteIds.isEmpty {
                    completion([])
                    return
                }
                
                // Flag to ensure completion is called only once
                var hasCompleted = false
                
                let timeoutWorkItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    print("Favorite notes loading timed out")
                    DispatchQueue.main.async {
                        if !hasCompleted {
                            hasCompleted = true
                            completion(favoriteNotes.sorted { $0.dateAdded > $1.dateAdded })
                        }
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeoutWorkItem)
                
                for noteId in favoriteIds {
                    group.enter()
                    self.db.collection("pdfs").document(noteId).getDocument { [weak self] (document, error) in
                        guard let self = self else {
                            group.leave()
                            return
                        }
                        
                        if let error = error {
                            print("Error fetching note \(noteId): \(error)")
                            group.leave()
                            return
                        }

                        guard let data = document?.data(), document?.exists ?? false else {
                            print("Note \(noteId) not found")
                            group.leave()
                            return
                        }

                        let pdfUrl = data["downloadURL"] as? String ?? ""
                        let noteUserId = data["userId"] as? String ?? "" // Extract userId from document
                        let coverImage = PDFCache.shared.getCachedImage(for: pdfUrl)
                        let uploadDate = (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date()
                        
                        var pageCount = data["pageCount"] as? Int ?? 0
                        
                        if pageCount > 0 {
                            let note = SavedFireNote(
                                id: noteId,
                                title: data["fileName"] as? String ?? "Untitled",
                                author: data["category"] as? String ?? "Unknown Author",
                                pdfUrl: pdfUrl,
                                coverImage: coverImage,
                                isFavorite: true,
                                pageCount: pageCount,
                                subjectName: data["subjectName"] as? String,
                                subjectCode: data["subjectCode"] as? String,
                                fileSize: data["fileSize"] as? String ?? "Unknown",
                                dateAdded: uploadDate,
                                college: data["collegeName"] as? String,
                                university: data["universityName"] as? String,
                                userId: noteUserId // Pass the userId
                            )
                            favoriteNotes.append(note)
                            group.leave()
                        } else {
                            DispatchQueue.global(qos: .utility).async {
                                if let url = URL(string: pdfUrl),
                                   let data = try? Data(contentsOf: url, options: [.alwaysMapped, .dataReadingMapped]),
                                   let pdfDocument = PDFDocument(data: data) {
                                    
                                    pageCount = pdfDocument.pageCount
                                    
                                    var updatedCoverImage = coverImage
                                    if coverImage == nil, let page = pdfDocument.page(at: 0) {
                                        updatedCoverImage = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                                        if let updatedCoverImage = updatedCoverImage {
                                            PDFCache.shared.cacheImage(updatedCoverImage, for: pdfUrl)
                                        }
                                    }
                                    
                                    self.db.collection("pdfs").document(noteId).updateData([
                                        "pageCount": pageCount
                                    ]) { _ in }
                                    
                                    let note = SavedFireNote(
                                        id: noteId,
                                        title: document?.get("fileName") as? String ?? "Untitled",
                                        author: document?.get("category") as? String ?? "Unknown Author",
                                        pdfUrl: pdfUrl,
                                        coverImage: updatedCoverImage,
                                        isFavorite: true,
                                        pageCount: pageCount,
                                        subjectName: document?.get("subjectName") as? String,
                                        subjectCode: document?.get("subjectCode") as? String,
                                        fileSize: document?.get("fileSize") as? String ?? "Unknown",
                                        dateAdded: uploadDate,
                                        college: document?.get("collegeName") as? String,
                                        university: document?.get("universityName") as? String,
                                        userId: noteUserId // Pass the userId
                                    )
                                    favoriteNotes.append(note)
                                } else {
                                    let note = SavedFireNote(
                                        id: noteId,
                                        title: document?.get("fileName") as? String ?? "Untitled",
                                        author: document?.get("category") as? String ?? "Unknown Author",
                                        pdfUrl: pdfUrl,
                                        coverImage: coverImage,
                                        isFavorite: true,
                                        pageCount: 0,
                                        subjectName: document?.get("subjectName") as? String,
                                        subjectCode: document?.get("subjectCode") as? String,
                                        fileSize: document?.get("fileSize") as? String ?? "Unknown",
                                        dateAdded: uploadDate,
                                        college: document?.get("collegeName") as? String,
                                        university: document?.get("universityName") as? String,
                                        userId: noteUserId // Pass the userId
                                    )
                                    favoriteNotes.append(note)
                                }
                                group.leave()
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    timeoutWorkItem.cancel()
                    
                    if !hasCompleted {
                        hasCompleted = true
                        let sortedNotes = favoriteNotes.sorted { $0.dateAdded > $1.dateAdded }
                        completion(sortedNotes)
                        
                        self.loadThumbnailsForVisibleNotes()
                        self.loadThumbnailsInBackground(for: sortedNotes)
                    }
                }
            }
    }
    
    private func loadThumbnailsForVisibleNotes() {
        let visibleCuratedCells = curatedNotesCollectionView.visibleCells.compactMap { $0 as? NoteCollectionViewCell1 }
        let visibleFavoriteCells = favoriteNotesCollectionView.visibleCells.compactMap { $0 as? NoteCollectionViewCell1 }
        
        for cell in (visibleCuratedCells + visibleFavoriteCells) {
            if let noteId = cell.noteId,
               let note = (curatedNotes + favoriteNotes).first(where: { $0.id == noteId }),
               note.coverImage == nil {
                self.loadThumbnailForNote(note) { updatedNote in
                    if let index = self.curatedNotes.firstIndex(where: { $0.id == noteId }) {
                        self.curatedNotes[index].coverImage = updatedNote.coverImage
                    }
                    if let index = self.favoriteNotes.firstIndex(where: { $0.id == noteId }) {
                        self.favoriteNotes[index].coverImage = updatedNote.coverImage
                    }
                    
                    DispatchQueue.main.async {
                        cell.configure(with: updatedNote)
                    }
                }
            }
        }
    }
    
    private func loadThumbnailsInBackground(for notes: [SavedFireNote]) {
        let loadQueue = DispatchQueue(label: "com.noteshare.thumbnailLoading", qos: .utility, attributes: .concurrent)
        
        let notesWithoutThumbnails = notes.filter { $0.coverImage == nil }
        let batchSize = 5
        
        for i in stride(from: 0, to: notesWithoutThumbnails.count, by: batchSize) {
            let endIndex = min(i + batchSize, notesWithoutThumbnails.count)
            let batch = Array(notesWithoutThumbnails[i..<endIndex])
            
            loadQueue.async { [weak self] in
                for note in batch {
                    if PDFCache.shared.getCachedImage(for: note.pdfUrl ?? "") != nil {
                        continue
                    }
                    
                    self?.loadThumbnailForNote(note) { updatedNote in
                        DispatchQueue.main.async {
                            guard let self = self else { return }
                            
                            if let index = self.curatedNotes.firstIndex(where: { $0.id == updatedNote.id }) {
                                self.curatedNotes[index].coverImage = updatedNote.coverImage
                                
                                for cell in self.curatedNotesCollectionView.visibleCells {
                                    if let noteCell = cell as? NoteCollectionViewCell1, noteCell.noteId == updatedNote.id {
                                        noteCell.configure(with: self.curatedNotes[index])
                                    }
                                }
                            }
                            
                            if let index = self.favoriteNotes.firstIndex(where: { $0.id == updatedNote.id }) {
                                self.favoriteNotes[index].coverImage = updatedNote.coverImage
                                
                                for cell in self.favoriteNotesCollectionView.visibleCells {
                                    if let noteCell = cell as? NoteCollectionViewCell1, noteCell.noteId == updatedNote.id {
                                        noteCell.configure(with: self.favoriteNotes[index])
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func loadThumbnailForNote(_ note: SavedFireNote, completion: @escaping (SavedFireNote) -> Void) {
        guard let storageRef = FirebaseService1.shared.getStorageReference(from: note.pdfUrl ?? "") else {
            completion(note)
            return
        }
        
        if let cachedImage = PDFCache.shared.getCachedImage(for: note.pdfUrl ?? "") {
            var updatedNote = note
            updatedNote.coverImage = cachedImage
            completion(updatedNote)
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
        
        storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Error downloading PDF for cover from \(note.pdfUrl ?? ""): \(error.localizedDescription)")
                completion(note)
                return
            }

            guard let pdfURL = url, FileManager.default.fileExists(atPath: pdfURL.path) else {
                print("Failed to download PDF to \(localURL.path)")
                completion(note)
                return
            }

            guard let pdfDocument = PDFDocument(url: pdfURL) else {
                print("Failed to create PDFDocument from \(pdfURL.path)")
                completion(note)
                return
            }

            let pageCount = pdfDocument.pageCount
            guard pageCount > 0, let pdfPage = pdfDocument.page(at: 0) else {
                print("No pages found in PDF at \(pdfURL.path)")
                var updatedNote = note
                updatedNote.pageCount = pageCount
                completion(updatedNote)
                return
            }

            let pageRect = pdfPage.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { context in
                UIColor.white.set()
                context.fill(pageRect)
                context.cgContext.translateBy(x: 0.0, y: pageRect.size.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)
                pdfPage.draw(with: .mediaBox, to: context.cgContext)
            }
            
            PDFCache.shared.cacheImage(image, for: note.pdfUrl ?? "")

            do {
                try FileManager.default.removeItem(at: pdfURL)
            } catch {
                print("Failed to delete temp file: \(error)")
            }
            
            var updatedNote = note
            updatedNote.coverImage = image
            updatedNote.pageCount = pageCount
            completion(updatedNote)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add new buttons
        view.addSubview(uploadNotesButton)
        view.addSubview(scanDocumentButton)
        
        // Add scroll view for content
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add scrollable content
        [favoriteNotesButton, seeAllFavoritesButton, favoriteNotesCollectionView,
         curatedNotesButton, seeAllUploadedButton, curatedNotesCollectionView].forEach {
            contentView.addSubview($0)
        }
        
        // Add search results table view (though it won't be used)
        view.addSubview(searchResultsTableView)
        curatedNotesCollectionView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // New buttons
            uploadNotesButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            uploadNotesButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            scanDocumentButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            scanDocumentButton.leadingAnchor.constraint(equalTo: uploadNotesButton.trailingAnchor, constant: 16),
            scanDocumentButton.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),
            
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: uploadNotesButton.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Favorite Notes Section
            favoriteNotesButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            favoriteNotesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            seeAllFavoritesButton.centerYAnchor.constraint(equalTo: favoriteNotesButton.centerYAnchor),
            seeAllFavoritesButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            favoriteNotesCollectionView.topAnchor.constraint(equalTo: favoriteNotesButton.bottomAnchor, constant: 12),
            favoriteNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            favoriteNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            favoriteNotesCollectionView.heightAnchor.constraint(equalToConstant: 265), // Adjusted for new cell height
            
            // Curated Notes Section
            curatedNotesButton.topAnchor.constraint(equalTo: favoriteNotesCollectionView.bottomAnchor, constant: 24),
            curatedNotesButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            seeAllUploadedButton.centerYAnchor.constraint(equalTo: curatedNotesButton.centerYAnchor),
            seeAllUploadedButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            curatedNotesCollectionView.topAnchor.constraint(equalTo: curatedNotesButton.bottomAnchor, constant: 12),
            curatedNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            curatedNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            curatedNotesCollectionView.heightAnchor.constraint(equalToConstant: 265),
            curatedNotesCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            searchResultsTableView.topAnchor.constraint(equalTo: uploadNotesButton.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchResultsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: curatedNotesCollectionView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: curatedNotesCollectionView.centerYAnchor)
        ])
        
        // Add targets for buttons
        favoriteNotesButton.addTarget(self, action: #selector(viewFavoritesTapped), for: .touchUpInside)
        curatedNotesButton.addTarget(self, action: #selector(viewUploadedTapped), for: .touchUpInside)
        seeAllFavoritesButton.addTarget(self, action: #selector(viewFavoritesTapped), for: .touchUpInside)
        seeAllUploadedButton.addTarget(self, action: #selector(viewUploadedTapped), for: .touchUpInside)
        uploadNotesButton.addTarget(self, action: #selector(addNoteTapped), for: .touchUpInside)
        scanDocumentButton.addTarget(self, action: #selector(moreOptionsTapped), for: .touchUpInside)
    }
    
    private func setupRefreshControl() {
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        scrollView.refreshControl = refreshControl
    }
    
    @objc private func refreshData() {
        loadData(forceRefresh: true)
    }
    
    private func setupPlaceholders() {
        favoritePlaceholderView = PlaceholderView(
            image: UIImage(systemName: "heart.circle"),
            title: "No Favorites Yet",
            message: "Mark notes as favorites to see them here.",
            buttonTitle: "Upload Notes",
            action: { [weak self] in
                self?.addNoteTapped()
            }
        )
        favoritePlaceholderView?.backgroundColor = .systemBackground
        favoritePlaceholderView?.alpha = 1.0
        favoriteNotesCollectionView.backgroundView = favoritePlaceholderView
        
        curatedPlaceholderView = PlaceholderView(
            image: UIImage(systemName: "doc.text"),
            title: "No Uploaded Notes",
            message: "Get Started, Scan and upload your notes!",
            buttonTitle: "Scan Now",
            action: { [weak self] in
                self?.moreOptionsTapped()
            }
        )
        curatedPlaceholderView?.backgroundColor = .systemBackground
        curatedPlaceholderView?.alpha = 1.0
        curatedNotesCollectionView.backgroundView = curatedPlaceholderView
        
        let addBorder = { (view: UIView) in
            view.layer.borderWidth = 0
            view.layer.borderColor = UIColor.systemGray5.cgColor
            view.layer.cornerRadius = 16
            view.clipsToBounds = true
        }
        
        addBorder(favoritePlaceholderView!)
        addBorder(curatedPlaceholderView!)
        
        DispatchQueue.main.async { [weak self] in
            self?.updatePlaceholderVisibility()
        }
    }
    
    private func updateCollectionViewLayouts() {
        let favoriteLayout = UICollectionViewFlowLayout()
        favoriteLayout.scrollDirection = .horizontal
        
        let cellWidth: CGFloat = 150
        let cellHeight: CGFloat = 225
        
        favoriteLayout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        favoriteLayout.minimumInteritemSpacing = 16
        favoriteLayout.minimumLineSpacing = 16
        favoriteLayout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        favoriteNotesCollectionView.collectionViewLayout = favoriteLayout
        
        let curatedLayout = UICollectionViewFlowLayout()
        curatedLayout.scrollDirection = .horizontal
        curatedLayout.itemSize = CGSize(width: cellWidth, height: cellHeight)
        curatedLayout.minimumInteritemSpacing = 16
        curatedLayout.minimumLineSpacing = 16
        curatedLayout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        curatedNotesCollectionView.collectionViewLayout = curatedLayout
        
        favoriteNotesCollectionView.performBatchUpdates(nil, completion: nil)
        curatedNotesCollectionView.performBatchUpdates(nil, completion: nil)
    }

    private func updatePlaceholderVisibility() {
        DispatchQueue.main.async {
            if self.favoriteNotes.isEmpty {
                if self.favoritePlaceholderView == nil {
                    self.favoritePlaceholderView = PlaceholderView(
                        image: UIImage(systemName: "heart.circle"),
                        title: "No Favorites Yet",
                        message: "Mark notes as favorites to see them here.",
                        buttonTitle: "Upload a Note",
                        action: { [weak self] in
                            self?.addNoteTapped()
                        }
                    )
                    self.favoriteNotesCollectionView.backgroundView = self.favoritePlaceholderView
                }
                
                self.favoritePlaceholderView?.alpha = 1.0
                self.favoritePlaceholderView?.isHidden = false
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.favoritePlaceholderView?.alpha = 0.0
                } completion: { _ in
                    self.favoritePlaceholderView?.isHidden = true
                }
            }
            
            if self.curatedNotes.isEmpty {
                if self.curatedPlaceholderView == nil {
                    self.curatedPlaceholderView = PlaceholderView(
                        image: UIImage(systemName: "doc.text"),
                        title: "No Uploaded Notes",
                        message: self.isLoading ? "Loading your notes..." : "Upload or scan a document to get started.",
                        buttonTitle: "Scan Now",
                        action: { [weak self] in
                            self?.moreOptionsTapped()
                        }
                    )
                    self.curatedNotesCollectionView.backgroundView = self.curatedPlaceholderView
                } else {
                    if self.isLoading {
                        self.curatedPlaceholderView?.updateMessage("Loading your notes...")
                    }
                }
                
                self.curatedPlaceholderView?.alpha = 1.0
                self.curatedPlaceholderView?.isHidden = false
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.curatedPlaceholderView?.alpha = 0.0
                } completion: { _ in
                    self.curatedPlaceholderView?.isHidden = true
                }
            }
        }
    }
    
    // MARK: - Action Methods
    @objc private func viewFavoritesTapped() {
        let favoritesVC = FavoriteNotesViewController()
        favoritesVC.configure(with: favoriteNotes)
        favoritesVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(favoritesVC, animated: true)
    }

    @objc private func viewUploadedTapped() {
        let uploadedVC = UploadedNotesViewController()
        uploadedVC.configure(with: curatedNotes)
        uploadedVC.hidesBottomBarWhenPushed = true
        navigationController?.pushViewController(uploadedVC, animated: true)
    }

    @objc private func moreOptionsTapped() {
        openDocumentScanner()
    }

    private func openDocumentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(title: "Error", message: "Document scanning is not supported on this device.")
            return
        }

        let documentScanner = VNDocumentCameraViewController()
        documentScanner.delegate = self
        present(documentScanner, animated: true, completion: nil)
    }
    
    @objc private func addNoteTapped() {
        let uploadVC = UploadModalViewController()
        uploadVC.modalPresentationStyle = .pageSheet
        if let sheet = uploadVC.sheetPresentationController {
            sheet.detents = [.custom { context in
                return context.maximumDetentValue * 0.75
            }]
            sheet.prefersGrabberVisible = true
        }
        present(uploadVC, animated: true)
    }

    // MARK: - Background Refresh
    private func refreshDataInBackground() {
        if isLoading || isBackgroundRefreshing {
            return
        }
        
        isBackgroundRefreshing = true
        loadData(forceRefresh: true)
    }

    private func showLoadingAlert(completion: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: "Loading PDF...", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        alert.view.addSubview(indicator)
        
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: alert.view.centerYAnchor, constant: 20)
        ])
        
        present(alert, animated: true, completion: completion)
    }

    private func dismissLoadingAlert(completion: @escaping () -> Void) {
        dismiss(animated: true, completion: completion)
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func handleFavoriteStatusChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let noteId = userInfo["noteId"] as? String,
              let isFavorite = userInfo["isFavorite"] as? Bool else {
            loadData(forceRefresh: true)
            return
        }
        
        print("Updating favorite status for noteId: \(noteId) to \(isFavorite)")
        
        let updateNoteInCollection = { (notes: inout [SavedFireNote]) -> Bool in
            var updated = false
            for i in 0..<notes.count {
                if notes[i].id == noteId {
                    notes[i].isFavorite = isFavorite
                    updated = true
                }
            }
            return updated
        }
        
        let curatedUpdated = updateNoteInCollection(&curatedNotes)
        
        if isFavorite {
            if !favoriteNotes.contains(where: { $0.id == noteId }) {
                if let note = curatedNotes.first(where: { $0.id == noteId }) {
                    var favoriteNote = note
                    favoriteNote.isFavorite = true
                    favoriteNotes.append(favoriteNote)
                    favoriteNotes.sort { $0.dateAdded > $1.dateAdded }
                }
            }
        } else {
            favoriteNotes.removeAll(where: { $0.id == noteId })
        }
        
        let updateVisibleCells = { (collectionView: UICollectionView) in
            for cell in collectionView.visibleCells {
                if let noteCell = cell as? NoteCollectionViewCell1, noteCell.noteId == noteId {
                    noteCell.isFavorite = isFavorite
                    noteCell.updateFavoriteButtonImage()
                }
            }
        }
        
        updateVisibleCells(curatedNotesCollectionView)
        updateVisibleCells(favoriteNotesCollectionView)
        
        if isFavorite || !isFavorite {
            favoriteNotesCollectionView.reloadData()
        }
        
        if curatedUpdated {
            curatedNotesCollectionView.reloadData()
        }
        
        updatePlaceholderVisibility()
        
        updateAllNotes()
        
        if !searchResults.isEmpty {
            for i in 0..<searchResults.count {
                if searchResults[i].id == noteId {
                    searchResults[i].isFavorite = isFavorite
                }
            }
            searchResultsTableView.reloadData()
        }
    }
    
    @objc private func handlePreviouslyReadNotesUpdated() {
        // No need to refresh everything for this
    }

    @objc private func handlePDFUploadSuccess() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            self.notesListener?.remove()
            self.notesListener = nil
            
            self.isLoading = false
            self.isBackgroundRefreshing = false
            
            self.loadData(forceRefresh: true)
        }
    }

    // MARK: - Setup Methods
    private func setupDelegates() {
        print("setup")
        curatedNotesCollectionView.dataSource = self
        curatedNotesCollectionView.delegate = self
        curatedNotesCollectionView.allowsSelection = true
        favoriteNotesCollectionView.dataSource = self
        favoriteNotesCollectionView.delegate = self
    }
    
    private func configureNavigationBar() {
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func savePDFMetadataToFirestore(downloadURL: String, userID: String, documentId: String) {
        let db = Firestore.firestore()
        let pdfMetadata: [String: Any] = [
            "downloadURL": downloadURL,
            "userId": userID,
            "fileName": "Scanned Document",
            "category": "Scanned",
            "collegeName": "Unknown",
            "isFavorite": false,
            "dateAdded": Timestamp(date: Date())
        ]

        db.collection("pdfs").document(documentId).setData(pdfMetadata) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to save PDF metadata: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "PDF uploaded and saved successfully!")
                self.loadData(forceRefresh: true)
            }
        }
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print("Document scanner failed with error: \(error.localizedDescription)")
        controller.dismiss(animated: true, completion: nil)
    }

    private func loadPDFMetadataIfNeeded(for note: SavedFireNote, at indexPath: IndexPath, in collectionView: UICollectionView) {
        if note.pageCount > 0 {
            return
        }
        
        guard let _ = collectionView.cellForItem(at: indexPath) as? NoteCollectionViewCell1 else {
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let cachedPDFURL = PDFCache.shared.getCachedPDFPath(for: note.id),
               let pdfDocument = PDFDocument(url: cachedPDFURL) {
                
                self.updateNoteWithPDFMetadata(pdfDocument: pdfDocument, note: note, indexPath: indexPath, collectionView: collectionView)
                return
            }
            
            guard let url = URL(string: note.pdfUrl ?? "") else { return }
            
            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil,
                      let pdfDocument = PDFDocument(data: data) else {
                    return
                }
                
                self.updateNoteWithPDFMetadata(pdfDocument: pdfDocument, note: note, indexPath: indexPath, collectionView: collectionView)
            }
            task.resume()
        }
    }

    private func updateNoteWithPDFMetadata(pdfDocument: PDFDocument, note: SavedFireNote, indexPath: IndexPath, collectionView: UICollectionView) {
        let pageCount = pdfDocument.pageCount
        
        // Keep fileSize for potential use elsewhere, but we won't display it in the cell
        let fileSize = note.fileSize != "Unknown" ? note.fileSize : "\(Int.random(in: 1...10)) MB"
        
        // Update pageCount in Firestore if it's missing
        if pageCount > 0 && note.pageCount == 0 {
            self.db.collection("pdfs").document(note.id).updateData([
                "pageCount": pageCount
            ]) { error in
                if let error = error {
                    print("Error updating page count: \(error)")
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update pageCount in the SavedFireNote objects
            let updateNoteInCollection = { (notes: inout [SavedFireNote]) -> Bool in
                var updated = false
                for i in 0..<notes.count {
                    if notes[i].id == note.id {
                        notes[i].pageCount = pageCount
                        updated = true
                    }
                }
                return updated
            }
            
            let curatedUpdated = updateNoteInCollection(&self.curatedNotes)
            let favoritesUpdated = updateNoteInCollection(&self.favoriteNotes)
            let searchUpdated = updateNoteInCollection(&self.searchResults)
            updateNoteInCollection(&self.allNotes)
            
            // Remove UI updates for page count and details text
            // if let cell = collectionView.cellForItem(at: indexPath) as? NoteCollectionViewCell1 {
            //     let pageText = pageCount > 0 ? "\(pageCount) Pages" : "0 Pages"
            //     cell.updatePageCount(pageCount)
            //     cell.updateDetailsText("\(pageText) • \(fileSize)")
            // }
            
            // Reload collection views if necessary
            if curatedUpdated {
                self.curatedNotesCollectionView.reloadItems(at: [indexPath])
            }
            
            if favoritesUpdated {
                self.favoriteNotesCollectionView.reloadItems(at: [indexPath])
            }
            
            if searchUpdated {
                self.searchResultsTableView.reloadData()
            }
        }
    }

    private func extractMetadataFromLocalPDF(for note: SavedFireNote) -> (pageCount: Int, thumbnail: UIImage?)? {
        if let cachedPDFURL = PDFCache.shared.getCachedPDFPath(for: note.id),
           let pdfDocument = PDFDocument(url: cachedPDFURL) {
            
            let pageCount = pdfDocument.pageCount
            
            var thumbnail = note.coverImage
            if thumbnail == nil, let page = pdfDocument.page(at: 0) {
                thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                if let thumbnail = thumbnail {
                    PDFCache.shared.cacheImage(thumbnail, for: note.pdfUrl ?? "")
                }
            }
            
            if pageCount > 0 && note.pageCount == 0 {
                self.db.collection("pdfs").document(note.id).updateData([
                    "pageCount": pageCount
                ]) { error in
                    if let error = error {
                        print("Error updating page count: \(error)")
                    }
                }
            }
            
            return (pageCount, thumbnail)
        }
        
        return nil
    }
    
    private func showActionSheet(for note: SavedFireNote, fromCell cell: NoteCollectionViewCell1) {
        // Only show edit/delete options for curated notes (uploaded by the user)
        guard curatedNotes.contains(where: { $0.id == note.id }) else { return }
        
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        // Edit Title
        let editTitleAction = UIAlertAction(title: "Edit Title", style: .default) { [weak self] _ in
            self?.showEditAlert(for: note, field: "Title") { newValue in
                self?.updateNoteMetadata(noteId: note.id, field: "fileName", value: newValue)
            }
        }
        actionSheet.addAction(editTitleAction)
        
        // Edit Subject Name
        let editSubjectNameAction = UIAlertAction(title: "Edit Subject Name", style: .default) { [weak self] _ in
            self?.showEditAlert(for: note, field: "Subject Name") { newValue in
                self?.updateNoteMetadata(noteId: note.id, field: "subjectName", value: newValue)
            }
        }
        actionSheet.addAction(editSubjectNameAction)
        
        // Edit Subject Code
        let editSubjectCodeAction = UIAlertAction(title: "Edit Subject Code", style: .default) { [weak self] _ in
            self?.showEditAlert(for: note, field: "Subject Code") { newValue in
                self?.updateNoteMetadata(noteId: note.id, field: "subjectCode", value: newValue)
            }
        }
        actionSheet.addAction(editSubjectCodeAction)
        
        // Delete
        let deleteAction = UIAlertAction(title: "Delete Now", style: .destructive) { [weak self] _ in
            self?.confirmDelete(note: note)
        }
        actionSheet.addAction(deleteAction)
        
        // Cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        actionSheet.addAction(cancelAction)
        
        // Present the action sheet
        if let popoverController = actionSheet.popoverPresentationController {
            popoverController.sourceView = cell
            popoverController.sourceRect = cell.bounds
        }
        present(actionSheet, animated: true, completion: nil)
    }

    private func showEditAlert(for note: SavedFireNote, field: String, completion: @escaping (String) -> Void) {
        let alert = UIAlertController(title: "Edit \(field)", message: "Enter the new \(field.lowercased()) for this note.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            switch field {
            case "Title":
                textField.text = note.title
            case "Subject Name":
                textField.text = note.subjectName ?? ""
            case "Subject Code":
                textField.text = note.subjectCode ?? ""
            default:
                textField.text = ""
            }
            textField.placeholder = "Enter \(field.lowercased())"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            guard let newValue = alert.textFields?.first?.text, !newValue.isEmpty else { return }
            completion(newValue)
        }
        alert.addAction(saveAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }

    private func updateNoteMetadata(noteId: String, field: String, value: String) {
        // Update Firestore
        db.collection("pdfs").document(noteId).updateData([field: value]) { error in
            if let error = error {
                print("Error updating \(field): \(error)")
                self.showAlert(title: "Error", message: "Failed to update \(field): \(error.localizedDescription)")
                return
            }
            
            // Update local data
            if let index = self.curatedNotes.firstIndex(where: { $0.id == noteId }) {
                var updatedNote = self.curatedNotes[index]
                switch field {
                case "fileName":
                    updatedNote.title = value
                case "subjectName":
                    updatedNote.subjectName = value
                case "subjectCode":
                    updatedNote.subjectCode = value
                default:
                    break
                }
                self.curatedNotes[index] = updatedNote
                self.curatedNotesCollectionView.reloadItems(at: [IndexPath(item: index, section: 0)])
            }
            
            // Update allNotes and searchResults if necessary
            if let index = self.allNotes.firstIndex(where: { $0.id == noteId }) {
                var updatedNote = self.allNotes[index]
                switch field {
                case "fileName":
                    updatedNote.title = value
                case "subjectName":
                    updatedNote.subjectName = value
                case "subjectCode":
                    updatedNote.subjectCode = value
                default:
                    break
                }
                self.allNotes[index] = updatedNote
            }
            
            if let index = self.searchResults.firstIndex(where: { $0.id == noteId }) {
                var updatedNote = self.searchResults[index]
                switch field {
                case "fileName":
                    updatedNote.title = value
                case "subjectName":
                    updatedNote.subjectName = value
                case "subjectCode":
                    updatedNote.subjectCode = value
                default:
                    break
                }
                self.searchResults[index] = updatedNote
                self.searchResultsTableView.reloadData()
            }
        }
    }

    private func confirmDelete(note: SavedFireNote) {
        let alert = UIAlertController(title: "Delete Note", message: "Are you sure you want to delete \"\(note.title)\"? This action cannot be undone.", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteNote(note: note)
        }
        alert.addAction(deleteAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }

    private func deleteNote(note: SavedFireNote) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        // Delete from Firestore
        db.collection("pdfs").document(note.id).delete { [weak self] error in
            if let error = error {
                print("Error deleting note: \(error)")
                self?.showAlert(title: "Error", message: "Failed to delete note: \(error.localizedDescription)")
                return
            }
            
            // Delete from Storage
            if let pdfUrl = note.pdfUrl, !pdfUrl.isEmpty,
               let storageRef = FirebaseService1.shared.getStorageReference(from: pdfUrl) {
                storageRef.delete { error in
                    if let error = error {
                        print("Error deleting PDF from storage: \(error)")
                    }
                }
            }
            
            // Remove from local collections
            self?.curatedNotes.removeAll(where: { $0.id == note.id })
            self?.allNotes.removeAll(where: { $0.id == note.id })
            self?.searchResults.removeAll(where: { $0.id == note.id })
            
            // Remove from favorites if it exists there
            self?.favoriteNotes.removeAll(where: { $0.id == note.id })
            FirebaseService1.shared.updateFavoriteStatus(for: note.id, isFavorite: false) { error in
                if let error = error {
                    print("Error removing favorite status: \(error)")
                }
            }
            
            // Remove from cache
            PDFCache.shared.clearCache()
            
            // Update UI
            self?.curatedNotesCollectionView.reloadData()
            self?.favoriteNotesCollectionView.reloadData()
            self?.searchResultsTableView.reloadData()
            self?.updatePlaceholderVisibility()
        }
    }

    private func updateUIWithLoadedData() {
        DispatchQueue.main.async {
            self.curatedNotesCollectionView.reloadData()
            self.favoriteNotesCollectionView.reloadData()
            
            self.updatePlaceholderVisibility()
            
            if self.refreshControl.isRefreshing {
                self.refreshControl.endRefreshing()
            }
            
            self.activityIndicator.stopAnimating()
            
            self.updateAllNotes()
        }
    }
}

extension Array {
    func removingDuplicates<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        return filter { element in
            let key = element[keyPath: keyPath]
            return seen.insert(key).inserted
        }
    }
}

extension SavedViewController {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // No keyboard to dismiss since search bar is removed
    }
}

extension SavedViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == favoriteNotesCollectionView {
            return favoriteNotes.count
        } else {
            return curatedNotes.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let note: SavedFireNote
        let identifier: String
        
        if collectionView == favoriteNotesCollectionView {
            note = favoriteNotes[indexPath.item]
            identifier = "FavoriteNoteCell"
        } else {
            note = curatedNotes[indexPath.item]
            identifier = "CuratedNoteCell"
        }
        
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as? NoteCollectionViewCell1 else {
            return UICollectionViewCell()
        }
        
        cell.configure(with: note)
        
        // Set up long-press handler
        cell.onLongPress = { [weak self] note in
            print("Long press closure triggered for note: \(note.id)") // Debug line
            self?.showActionSheet(for: note, fromCell: cell)
        }
        
        loadPDFMetadataIfNeeded(for: note, at: indexPath, in: collectionView)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedNote: SavedFireNote
        
        if collectionView == favoriteNotesCollectionView {
            selectedNote = favoriteNotes[indexPath.item]
        } else {
            selectedNote = curatedNotes[indexPath.item]
        }
        
        self.showLoadingAlert {
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: selectedNote.id) {
                self.dismissLoadingAlert {
                    let pdfVC = PDFViewerViewController(documentId: selectedNote.id)
                    let nav = UINavigationController(rootViewController: pdfVC)
                    nav.modalPresentationStyle = .fullScreen
                    self.present(nav, animated: true)
                    
                    let previouslyReadNote = PreviouslyReadNote(
                        id: selectedNote.id,
                        title: selectedNote.title,
                        pdfUrl: selectedNote.pdfUrl ?? "",
                        lastOpened: Date()
                    )
                    self.savePreviouslyReadNote(previouslyReadNote)
                }
                return
            }
            
            FirebaseService1.shared.downloadPDF(from: selectedNote.pdfUrl ?? "") { [weak self] result in
                DispatchQueue.main.async {
                    self?.dismissLoadingAlert {
                        switch result {
                        case .success(let url):
                            PDFCache.shared.cachePDFPath(for: selectedNote.id, fileURL: url)
                            
                            let pdfVC = PDFViewerViewController(documentId: selectedNote.id)
                            let nav = UINavigationController(rootViewController: pdfVC)
                            nav.modalPresentationStyle = .fullScreen
                            self?.present(nav, animated: true)
                            
                            let previouslyReadNote = PreviouslyReadNote(
                                id: selectedNote.id,
                                title: selectedNote.title,
                                pdfUrl: selectedNote.pdfUrl ?? "",
                                lastOpened: Date()
                            )
                            self?.savePreviouslyReadNote(previouslyReadNote)
                            
                        case .failure(let error):
                            self?.showAlert(title: "Error", message: "Could not load PDF: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let noteCell = cell as? NoteCollectionViewCell1,
              let noteId = noteCell.noteId else { return }
        
        let note: SavedFireNote?
        if collectionView == favoriteNotesCollectionView {
            note = favoriteNotes.first(where: { $0.id == noteId })
        } else {
            note = curatedNotes.first(where: { $0.id == noteId })
        }
        
        guard let note = note, note.coverImage == nil else { return }
        
        loadThumbnailForNote(note) { updatedNote in
            if let index = self.curatedNotes.firstIndex(where: { $0.id == noteId }) {
                self.curatedNotes[index].coverImage = updatedNote.coverImage
            }
            if let index = self.favoriteNotes.firstIndex(where: { $0.id == noteId }) {
                self.favoriteNotes[index].coverImage = updatedNote.coverImage
            }
            
            DispatchQueue.main.async {
                if let visibleCell = collectionView.cellForItem(at: indexPath) as? NoteCollectionViewCell1 {
                    visibleCell.configure(with: updatedNote)
                }
            }
        }
    }
}

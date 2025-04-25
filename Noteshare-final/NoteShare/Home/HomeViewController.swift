import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import PDFKit
import Kingfisher
import Cache

struct FireNote: Codable {
    let id: String
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let pdfUrl: String
    let dateAdded: Date
    var pageCount: Int
    var fileSize: String
    var isFavorite: Bool
    let category: String
    let subjectCode: String
    let subjectName: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, author, pdfUrl, dateAdded, pageCount, fileSize, isFavorite, category, subjectCode, subjectName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        author = try container.decode(String.self, forKey: .author)
        pdfUrl = try container.decode(String.self, forKey: .pdfUrl)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        pageCount = try container.decode(Int.self, forKey: .pageCount)
        fileSize = try container.decode(String.self, forKey: .fileSize)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        category = try container.decode(String.self, forKey: .category)
        subjectCode = try container.decode(String.self, forKey: .subjectCode)
        subjectName = try container.decode(String.self, forKey: .subjectName)
        coverImage = nil // We'll set this separately
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(author, forKey: .author)
        try container.encode(pdfUrl, forKey: .pdfUrl)
        try container.encode(dateAdded, forKey: .dateAdded)
        try container.encode(pageCount, forKey: .pageCount)
        try container.encode(fileSize, forKey: .fileSize)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(category, forKey: .category)
        try container.encode(subjectCode, forKey: .subjectCode)
        try container.encode(subjectName, forKey: .subjectName)
    }
    
    init(id: String, title: String, description: String, author: String, coverImage: UIImage?, pdfUrl: String, dateAdded: Date, pageCount: Int, fileSize: String, isFavorite: Bool, category: String, subjectCode: String, subjectName: String) {
        self.id = id
        self.title = title
        self.description = description
        self.author = author
        self.coverImage = coverImage
        self.pdfUrl = pdfUrl
        self.dateAdded = dateAdded
        self.pageCount = pageCount
        self.fileSize = fileSize
        self.isFavorite = isFavorite
        self.category = category
        self.subjectCode = subjectCode
        self.subjectName = subjectName
    }
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "title": title,
            "description": description,
            "author": author,
            "pdfUrl": pdfUrl,
            "dateAdded": dateAdded,
            "pageCount": pageCount,
            "fileSize": fileSize,
            "isFavorite": isFavorite,
            "category": category,
            "subjectCode": subjectCode,
            "subjectName": subjectName
        ]
    }
}

// MARK: - Cache Configuration
struct CacheConfig {
    static let maxDiskSize: UInt = 500 * 1024 * 1024 // 500MB
    static let maxMemorySize: UInt = 100 * 1024 * 1024 // 100MB
    static let maxAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    static let maxCount: Int = 100 // Maximum number of items in memory cache
}

// MARK: - Cache Manager
class CacheManager {
    static let shared = CacheManager()
    
    private let imageCache = ImageCache.default
    private let pdfCache = NSCache<NSString, NSData>()
    private let dataCache = NSCache<NSString, NSData>()
    
    private init() {
        // Configure Kingfisher image cache
        imageCache.memoryStorage.config.totalCostLimit = Int(CacheConfig.maxMemorySize)
        imageCache.diskStorage.config.sizeLimit = CacheConfig.maxDiskSize
        
        // Configure NSCache
        pdfCache.countLimit = CacheConfig.maxCount
        pdfCache.totalCostLimit = Int(CacheConfig.maxMemorySize)
        
        dataCache.countLimit = CacheConfig.maxCount
        dataCache.totalCostLimit = Int(CacheConfig.maxMemorySize)
    }
    
    // MARK: - PDF Caching with Compression
    func cachePDF(url: URL, data: Data) throws {
        let key = url.absoluteString as NSString
        // Compress data before caching
        if let compressedData = try? (data as NSData).compressed(using: .lzfse) {
            pdfCache.setObject(compressedData, forKey: key)
            
            // Also save to disk
            let fileManager = FileManager.default
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileURL = cacheDirectory.appendingPathComponent("pdf_cache").appendingPathComponent(key as String)
            
            // Create directory if it doesn't exist
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try compressedData.write(to: fileURL)
        }
    }
    
    func getCachedPDF(url: URL) -> Data? {
        let key = url.absoluteString as NSString
        
        // Try memory cache first
        if let compressedData = pdfCache.object(forKey: key) {
            return try? compressedData.decompressed(using: .lzfse) as Data
        }
        
        // Try disk cache
        let fileManager = FileManager.default
        do {
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = cacheDirectory.appendingPathComponent("pdf_cache").appendingPathComponent(key as String)
            
            if fileManager.fileExists(atPath: fileURL.path),
               let compressedData = NSData(contentsOf: fileURL) {
                // Store in memory cache for future use
                pdfCache.setObject(compressedData, forKey: key)
                return try? compressedData.decompressed(using: .lzfse) as Data
            }
        } catch {
            print("Error reading cached PDF: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Image Caching with Kingfisher
    func cacheImage(_ image: UIImage, for key: String) {
        // Cache using Kingfisher with default options
        imageCache.store(image, forKey: key)
        
        // Force write to disk
        imageCache.store(image, forKey: key, toDisk: true) { _ in
            print("Image for key \(key) successfully cached to disk")
        }
    }
    
    func getCachedImage(for key: String) -> UIImage? {
        // Try Kingfisher memory cache first
        if let memoryImage = imageCache.retrieveImageInMemoryCache(forKey: key) {
            return memoryImage
        }
        
        // Try Kingfisher disk cache
        if let imageData = try? imageCache.diskStorage.value(forKey: key),
           let diskImage = UIImage(data: imageData) {
            // Add to memory cache for faster future access
            imageCache.store(diskImage, forKey: key, toDisk: false)
            return diskImage
        }
        
        return nil
    }
    
    // MARK: - Data Caching with JSON
    func cacheData<T: Codable>(_ data: T, for key: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let encodedData = try? encoder.encode(data),
           let compressedData = try? (encodedData as NSData).compressed(using: .lzfse) {
            dataCache.setObject(compressedData, forKey: key as NSString)
            
            // Save to disk as well
            let fileManager = FileManager.default
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let fileURL = cacheDirectory.appendingPathComponent("data_cache").appendingPathComponent(key)
            
            // Create directory if it doesn't exist
            try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try compressedData.write(to: fileURL)
        }
    }
    
    func getCachedData<T: Codable>(for key: String) -> T? {
        // Try memory cache first
        if let compressedData = dataCache.object(forKey: key as NSString),
           let decompressedData = try? compressedData.decompressed(using: .lzfse) as Data {
            return try? JSONDecoder().decode(T.self, from: decompressedData)
        }
        
        // Try disk cache
        let fileManager = FileManager.default
        do {
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let fileURL = cacheDirectory.appendingPathComponent("data_cache").appendingPathComponent(key)
            
            if fileManager.fileExists(atPath: fileURL.path),
               let compressedData = NSData(contentsOf: fileURL),
               let decompressedData = try? compressedData.decompressed(using: .lzfse) as Data {
                // Store in memory cache for future use
                dataCache.setObject(compressedData, forKey: key as NSString)
                return try? JSONDecoder().decode(T.self, from: decompressedData)
            }
        } catch {
            print("Error reading cached data: \(error)")
        }
        
        return nil
    }
    
    // MARK: - Cache Management
    func clearCache() {
        pdfCache.removeAllObjects()
        dataCache.removeAllObjects()
        imageCache.clearMemoryCache()
        imageCache.clearDiskCache()
        
        // Clear disk caches
        let fileManager = FileManager.default
        do {
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            try fileManager.removeItem(at: cacheDirectory.appendingPathComponent("pdf_cache"))
            try fileManager.removeItem(at: cacheDirectory.appendingPathComponent("data_cache"))
        } catch {
            print("Error clearing disk cache: \(error)")
        }
    }
    
    // MARK: - Cache Statistics
    func getCacheStats() -> (diskSize: Int64, memorySize: Int64, itemCount: Int) {
        var diskSize: Int64 = 0
        var itemCount: Int = 0
        
        // Calculate disk cache size
        let fileManager = FileManager.default
        do {
            let cacheDirectory = try fileManager.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let pdfCacheURL = cacheDirectory.appendingPathComponent("pdf_cache")
            let dataCacheURL = cacheDirectory.appendingPathComponent("data_cache")
            
            if fileManager.fileExists(atPath: pdfCacheURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: pdfCacheURL.path)
                if let size = attributes[.size] as? NSNumber {
                    diskSize += size.int64Value
                }
            }
            
            if fileManager.fileExists(atPath: dataCacheURL.path) {
                let attributes = try fileManager.attributesOfItem(atPath: dataCacheURL.path)
                if let size = attributes[.size] as? NSNumber {
                    diskSize += size.int64Value
                }
            }
        } catch {
            print("Error calculating disk cache size: \(error)")
        }
        
        // Estimated memory size (not exact)
        let memorySize: Int64 = Int64(pdfCache.totalCostLimit + dataCache.totalCostLimit)
        itemCount = pdfCache.totalCostLimit / (1024 * 1024) // Rough estimation
        
        return (diskSize, memorySize, itemCount)
    }
}

class FirebaseService {
    static let shared = FirebaseService()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // Cache for notes to avoid redundant fetches
    private var notesCache: [FireNote] = []
    private var groupedNotesCache: [String: [String: [FireNote]]] = [:]
    private var _userFavoritesCache: [String] = []
    private var lastNotesFetchTime: Date?
    private var lastFavoritesFetchTime: Date?
    private var pdfCoverImageCache = NSCache<NSString, UIImage>()
    private var userDataCache: (interests: [String], college: String)?
    private var lastUserDataFetchTime: Date?
    
    // Cache invalidation time (5 minutes)
    private let cacheInvalidationTime: TimeInterval = 300

    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Public getter/setter for userFavoritesCache
    var userFavoritesCache: [String] {
        get { return _userFavoritesCache }
        set { _userFavoritesCache = newValue }
    }
    
    // Fetch all notes with caching
    func fetchNotes(completion: @escaping ([FireNote], [String: [String: [FireNote]]]) -> Void) {
        // Check if cache is valid
        if !notesCache.isEmpty && groupedNotesCache.count > 0,
           let lastFetch = lastNotesFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInvalidationTime {
            print("Using cached notes data - \(notesCache.count) notes")
            completion(notesCache, groupedNotesCache)
            return
        }
        
        db.collection("pdfs")
            .whereField("privacy", isEqualTo: "public") // Filter for public PDFs only
            .getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching notes: \(error.localizedDescription)")
                    completion([], [:])
                    return
                }

                var notes: [FireNote] = []
                var groupedNotes: [String: [String: [FireNote]]] = [:]
                let group = DispatchGroup()

                snapshot?.documents.forEach { document in
                    group.enter()
                    let data = document.data()
                    let pdfUrl = data["downloadURL"] as? String ?? ""
                    let collegeName = data["collegeName"] as? String ?? "Unknown College"
                    let subjectCode = data["subjectCode"] as? String ?? "Unknown Subject"

                    // Check if we have the cover image in cache
                    let cacheKey = NSString(string: pdfUrl)
                    if let cachedImage = self.pdfCoverImageCache.object(forKey: cacheKey) {
                        // Use cached image
                        let fileSize = self.formatFileSize(0) // We don't have size info in cache
                        let note = FireNote(
                            id: document.documentID,
                            title: data["fileName"] as? String ?? "Untitled",
                            description: data["category"] as? String ?? "",
                            author: collegeName,
                            coverImage: cachedImage,
                            pdfUrl: pdfUrl,
                            dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                            pageCount: 0, // We don't have page count in cache
                            fileSize: fileSize,
                            isFavorite: false,
                            category: data["category"] as? String ?? "",
                            subjectCode: subjectCode,
                            subjectName: data["subjectName"] as? String ?? ""
                        )
                        notes.append(note)
                        if groupedNotes[collegeName] == nil { groupedNotes[collegeName] = [:] }
                        if groupedNotes[collegeName]?[subjectCode] != nil {
                            groupedNotes[collegeName]?[subjectCode]?.append(note)
                        } else {
                            groupedNotes[collegeName]?[subjectCode] = [note]
                        }
                        group.leave()
                    } else {
                        // Fetch metadata and cover image
                    self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                        if let error = error { print("Metadata error for \(pdfUrl): \(error)") }
                        let fileSize = self.formatFileSize(metadata?.size ?? 0)

                        self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                                // Cache the image
                                if let image = image {
                                    self.pdfCoverImageCache.setObject(image, forKey: cacheKey)
                                }
                                
                            let note = FireNote(
                                id: document.documentID,
                                title: data["fileName"] as? String ?? "Untitled",
                                description: data["category"] as? String ?? "",
                                author: collegeName,
                                coverImage: image,
                                pdfUrl: pdfUrl,
                                    dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                                pageCount: pageCount,
                                fileSize: fileSize,
                                isFavorite: false,
                                category: data["category"] as? String ?? "",
                                subjectCode: subjectCode,
                                subjectName: data["subjectName"] as? String ?? ""
                            )
                            notes.append(note)
                            if groupedNotes[collegeName] == nil { groupedNotes[collegeName] = [:] }
                            if groupedNotes[collegeName]?[subjectCode] != nil {
                                groupedNotes[collegeName]?[subjectCode]?.append(note)
                            } else {
                                groupedNotes[collegeName]?[subjectCode] = [note]
                            }
                            group.leave()
                            }
                        }
                    }
                }

                group.notify(queue: .main) {
                    self.fetchUserFavorites(completion: { favoriteNoteIds in
                        let updatedNotes = notes.map { note in
                            var updatedNote = note
                            updatedNote.isFavorite = favoriteNoteIds.contains(note.id)
                            return updatedNote
                        }
                        print("Fetched \(updatedNotes.count) notes")
                        
                        // Update cache
                        self.notesCache = updatedNotes.sorted { $0.dateAdded > $1.dateAdded }
                        self.groupedNotesCache = groupedNotes
                        self.lastNotesFetchTime = Date()
                        
                        completion(self.notesCache, self.groupedNotesCache)
                    })
                }
            }
    }
    
    // Fetch the current user's favorite note IDs with caching
    func fetchUserFavorites(completion: @escaping ([String]) -> Void) {
        guard let userId = currentUserId else {
            completion([])
            return
        }
        
        // Check if cache is valid
        if !_userFavoritesCache.isEmpty,
           let lastFetch = lastFavoritesFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheInvalidationTime {
            print("Using cached favorites data - \(_userFavoritesCache.count) favorites")
            completion(_userFavoritesCache)
            return
        }
        
        db.collection("userFavorites").document(userId).collection("favorites")
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching favorites: \(error)")
                    completion([])
                    return
                }
                let favoriteIds = snapshot?.documents.map { $0.documentID } ?? []
                
                // Update cache
                self._userFavoritesCache = favoriteIds
                self.lastFavoritesFetchTime = Date()
                
                completion(favoriteIds)
            }
    }
    
    // Fetch user data with caching
        func fetchUserData(completion: @escaping ([String], String) -> Void) {
        // Check if cache is valid
//        if let cachedData = userDataCache,
//           let lastFetch = lastUserDataFetchTime,
//           Date().timeIntervalSince(lastFetch) < cacheInvalidationTime {
//            print("Using cached user data")
//            completion(cachedData.interests, cachedData.college)
//            return
//        }
        
            guard let userId = currentUserId else {
                completion([], "")
                return
            }
            
            let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] document, error in
            guard let self = self else { return }
            
                if let error = error {
                    print("Error fetching user data: \(error)")
                    completion([], "")
                    return
                }
                
                guard let document = document, document.exists else {
                    completion([], "")
                    return
                }
                
                let data = document.data() ?? [:]
                let interests = data["interests"] as? [String] ?? []
                let college = data["college"] as? String ?? ""
            
            // Update cache
            self.userDataCache = (interests: interests, college: college)
            self.lastUserDataFetchTime = Date()
                
                completion(interests, college)
            }
        }
    
    // Fetch recommended notes with caching
    func fetchRecommendedNotes(islastday:Bool,completion: @escaping ([FireNote]) -> Void) {
        fetchUserData { [weak self] interests, college in
            guard let self = self else { return }
            
            let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60) // 24 hours ago
            
            // First attempt: Fetch recent notes based on user interests or college
            var query = db.collection("pdfs")
                .whereField("privacy", isEqualTo: "public")
                .order(by: "uploadDate", descending: true)
            
            // Add filters based on user data if available
            if !interests.isEmpty {
                query = query.whereField("category", in: interests)
            } else if !college.isEmpty {
                query = query.whereField("collegeName", isEqualTo: college)
            }
            if(islastday){
                query = query.whereField("uploadDate", isGreaterThan: Timestamp(date: oneDayAgo))
            }
            
            // Try fetching recent notes first
            query
                .limit(to: 5)
                .getDocuments { snapshot, error in
                    if let error = error {
                        print("Error fetching recommended notes: \(error.localizedDescription)")
                        // Fallback to broader query
                        self.fetchFallbackRecommendedNotes(completion: completion)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("No recent notes found within 24 hours. Falling back to broader query.")
                        self.fetchFallbackRecommendedNotes(completion: completion)
                        return
                    }
                    
                    var recommendedNotes: [FireNote] = []
                    let group = DispatchGroup()
                    if(documents.count < 5 && islastday){
                        self.fetchRecommendedNotes(islastday: false, completion: completion)
                        return
                    }
                    
                    documents.forEach { document in
                        group.enter()
                        let data = document.data()
                        let pdfUrl = data["downloadURL"] as? String ?? ""
                        let collegeName = data["collegeName"] as? String ?? "Unknown College"
                        
                        self.fetchPDFCoverImage(from: pdfUrl) { image, pageCount in
                            let note = FireNote(
                                id: document.documentID,
                                title: data["fileName"] as? String ?? "Untitled",
                                description: data["category"] as? String ?? "",
                                author: collegeName,
                                coverImage: image,
                                pdfUrl: pdfUrl,
                                dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                                pageCount: pageCount,
                                fileSize: self.formatFileSize(0), // Fetch size lazily if needed
                                isFavorite: false,
                                category: data["category"] as? String ?? "",
                                subjectCode: data["subjectCode"] as? String ?? "",
                                subjectName: data["subjectName"] as? String ?? ""
                            )
                            recommendedNotes.append(note)
                            group.leave()
                        }
                    }
                    
                    group.notify(queue: .main) {
                        self.fetchUserFavorites { favoriteIds in
                            let updatedNotes = recommendedNotes.map { note in
                                var updatedNote = note
                                updatedNote.isFavorite = favoriteIds.contains(note.id)
                                return updatedNote
                            }
                            print("Fetched \(updatedNotes.count) recommended notes")
                            completion(updatedNotes.sorted { $0.dateAdded > $1.dateAdded })
                        }
                    }
                }
        }
    }

    // Fallback method to fetch broader set of notes if recent ones aren't available
    private func fetchFallbackRecommendedNotes(completion: @escaping ([FireNote]) -> Void) {
        let query = db.collection("pdfs")
            .whereField("privacy", isEqualTo: "public")
            .order(by: "uploadDate", descending: true)
            .limit(to: 5)
        
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching fallback recommended notes: \(error.localizedDescription)")
                completion([])
                return
            }
            
            var recommendedNotes: [FireNote] = []
            let group = DispatchGroup()
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                let pdfUrl = data["downloadURL"] as? String ?? ""
                let collegeName = data["collegeName"] as? String ?? "Unknown College"
                
                self.fetchPDFCoverImage(from: pdfUrl) { image, pageCount in
                    let note = FireNote(
                        id: document.documentID, // Fixed: Use document.documentID
                        title: data["fileName"] as? String ?? "Untitled",
                        description: data["category"] as? String ?? "",
                        author: collegeName,
                        coverImage: image,
                        pdfUrl: pdfUrl,
                        dateAdded: (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date(),
                        pageCount: pageCount,
                        fileSize: self.formatFileSize(0),
                        isFavorite: false,
                        category: data["category"] as? String ?? "",
                        subjectCode: data["subjectCode"] as? String ?? "",
                        subjectName: data["subjectName"] as? String ?? ""
                    )
                    recommendedNotes.append(note)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.fetchUserFavorites { favoriteIds in
                    let updatedNotes = recommendedNotes.map { note in
                        var updatedNote = note
                        updatedNote.isFavorite = favoriteIds.contains(note.id)
                        return updatedNote
                    }
                    print("Fetched \(updatedNotes.count) fallback recommended notes")
                    completion(updatedNotes.sorted { $0.dateAdded > $1.dateAdded })
                }
            }
        }
    }
    
    // Download PDF from Firebase Storage with caching
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard !urlString.isEmpty else {
            let error = NSError(domain: "PDFDownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty PDF URL"])
            print("Download failed: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        let hashedFilename = urlString.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        let fileName = hashedFilename + ".pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent(fileName)

        // Check cache first
        guard let pdfUrl = URL(string: urlString) else {
            let error = NSError(domain: "PDFDownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid PDF URL format"])
            completion(.failure(error))
            return
        }

        if let cachedData = CacheManager.shared.getCachedPDF(url: pdfUrl) {
            try? cachedData.write(to: localURL)
            completion(.success(localURL))
            return
        }
        
        // Check if file exists in documents directory
        if FileManager.default.fileExists(atPath: localURL.path) {
            completion(.success(localURL))
            return
        }
        
        guard let storageRef = getStorageReference(from: urlString) else {
            let error = NSError(domain: "PDFDownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid storage reference URL: \(urlString)"])
            print("Download failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
        }

        let downloadTask = storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let url = url else {
                let error = NSError(domain: "PDFDownloadError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded file URL is nil"])
                print("Download failed: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Cache the downloaded PDF
            if let pdfData = try? Data(contentsOf: url) {
                try? CacheManager.shared.cachePDF(url: pdfUrl, data: pdfData)
            }
            
                    completion(.success(url))
        }
    }
    
    // Clear caches (can be called when user logs out or when memory warning is received)
    func clearCaches() {
        notesCache = []
        groupedNotesCache = [:]
        _userFavoritesCache = []
        lastNotesFetchTime = nil
        lastFavoritesFetchTime = nil
        pdfCoverImageCache.removeAllObjects()
        userDataCache = nil
        lastUserDataFetchTime = nil
    }
    
    // Helper methods
    func getStorageReference(from urlString: String) -> StorageReference? {
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
    }
    
    func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func fetchPDFCoverImage(from urlString: String, completion: @escaping (UIImage?, Int) -> Void) {
        guard !urlString.isEmpty else {
            print("Empty PDF URL provided")
            completion(nil, 0)
            return
        }
        
        // Check if image is in cache
        let cacheKey = NSString(string: urlString)
        if let cachedImage = pdfCoverImageCache.object(forKey: cacheKey) {
            completion(cachedImage, 0) // We don't store page count in the cache
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

            // Get the PDF page bounds
            let pageRect = pdfPage.bounds(for: .mediaBox)
            
            // Use a fixed aspect ratio for all thumbnails (letter size: 8.5x11)
            let targetWidth: CGFloat = 500 // Higher resolution for better quality
            let targetHeight = targetWidth * (11.0/8.5) // Maintain aspect ratio
            
            // Create a renderer with the target size
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetWidth, height: targetHeight))
            
            let image = renderer.image { context in
                // Fill background with white
                UIColor.white.set()
                context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
                
                // Calculate scaling to fit the PDF page into our target size while maintaining aspect ratio
                let pdfAspect = pageRect.width / pageRect.height
                let targetAspect = targetWidth / targetHeight
                
                var scaledWidth: CGFloat
                var scaledHeight: CGFloat
                
                if pdfAspect > targetAspect {
                    // PDF is wider than target, scale to fit width
                    scaledWidth = targetWidth
                    scaledHeight = targetWidth / pdfAspect
                } else {
                    // PDF is taller than target, scale to fit height
                    scaledHeight = targetHeight
                    scaledWidth = targetHeight * pdfAspect
                }
                
                // Center the PDF in the target rect
                let x = (targetWidth - scaledWidth) / 2
                let y = (targetHeight - scaledHeight) / 2
                
                // Create the rect for drawing
                let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
                
                // Save graphics state
                context.cgContext.saveGState()
                
                // Flip coordinates (PDFKit uses bottom-left origin)
                context.cgContext.translateBy(x: x, y: y + scaledHeight)
                context.cgContext.scaleBy(x: scaledWidth / pageRect.width, y: -scaledHeight / pageRect.height)
                
                // Draw the PDF page
                pdfPage.draw(with: .mediaBox, to: context.cgContext)
                
                // Restore graphics state
                context.cgContext.restoreGState()
            }
            
            // Cache the image
                self.pdfCoverImageCache.setObject(image, forKey: cacheKey)

            do {
                try FileManager.default.removeItem(at: pdfURL)
            } catch {
                print("Failed to delete temp file: \(error)")
            }

            completion(image, pageCount)
        }
    }
    
    // Update favorite status and invalidate cache
    func updateFavoriteStatus(for noteId: String, isFavorite: Bool, completion: @escaping (Error?) -> Void) {
        guard let userId = currentUserId else {
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

// previously read note struct
struct PreviouslyReadNote {
    let id: String
    let title: String
    let pdfUrl: String
    let lastOpened: Date
}

class NoteCollectionViewCell: UICollectionViewCell {
    var noteId: String?
    
    public let lastOpenedDateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let lastOpenedIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        imageView.image = UIImage(systemName: "clock", withConfiguration: config)
        imageView.tintColor = .secondaryLabel
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let documentIcon: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
        imageView.image = UIImage(systemName: "doc.text", withConfiguration: config)
        imageView.tintColor = .systemBlue.withAlphaComponent(0.8)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    public let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 0
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    public let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    public let subjectNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subjectCodeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    public let pagesLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let recommendedTag: UILabel = {
        let label = UILabel()
        label.text = "Recommended"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.backgroundColor = .systemBlue
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Properties
    var isFavorite: Bool = false {
        didSet {
            updateFavoriteButtonImage()
        }
    }
    
    var favoriteButtonTapped: (() -> Void)?
    
    // Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        
        // Important: Make sure button touches aren't blocked by cell selection
        self.contentView.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // UI Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        
        containerView.addSubview(coverImageView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(authorLabel)
        containerView.addSubview(subjectNameLabel)
        containerView.addSubview(pagesLabel)
        containerView.addSubview(favoriteButton)
        containerView.addSubview(recommendedTag)
        containerView.addSubview(lastOpenedDateLabel)
        // Don't add these yet, they'll be added when needed
        // containerView.addSubview(lastOpenedIcon)
        // containerView.addSubview(documentIcon)
        
        setupConstraints()
        favoriteButton.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
        
        // Make sure the favorite button is properly configured for touch events
        favoriteButton.isUserInteractionEnabled = true
        favoriteButton.layer.zPosition = 10 // Ensure it's on top of other views
    }
    
    private func setupConstraints() {
            NSLayoutConstraint.activate([
                // Container view constraints
                containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
                containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
                containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
                containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
                
                // Cover image view - REDUCE HEIGHT RATIO
                coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.55),
                
                // Title label
                titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
                titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                
                // Subject name label (college name) - moved to be right after title
                subjectNameLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
                subjectNameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                subjectNameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                
                // Author label
                authorLabel.topAnchor.constraint(equalTo: subjectNameLabel.bottomAnchor, constant: 3),
                authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -40),
                
                // Pages label - replaced file size
                pagesLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 3),
                pagesLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                pagesLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8),
                
                // Favorite button
                favoriteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
                favoriteButton.centerYAnchor.constraint(equalTo: pagesLabel.centerYAnchor),
                favoriteButton.widthAnchor.constraint(equalToConstant: 24),
                favoriteButton.heightAnchor.constraint(equalToConstant: 24),
                
                // Recommended tag
                recommendedTag.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
                recommendedTag.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
                recommendedTag.heightAnchor.constraint(equalToConstant: 22),
                recommendedTag.widthAnchor.constraint(equalToConstant: 100),
                
                // Last opened date label (for previously read notes)
                lastOpenedDateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
                lastOpenedDateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
                lastOpenedDateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Apply premium card-like shadow effect
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        
        // Add a subtle border
        containerView.layer.borderWidth = 0.5
        containerView.layer.borderColor = UIColor.systemGray5.cgColor
    }
        
        // Update UI for favorite button
        public func updateFavoriteButtonImage() {
            let image = isFavorite ? UIImage(systemName: "heart.circle") : UIImage(systemName: "heart.circle")
            favoriteButton.setImage(image, for: .normal)
            favoriteButton.tintColor = isFavorite ? .systemRed : .systemGray
        }
        
        // Favorite button pressed
        @objc private func favoriteButtonPressed() {
            isFavorite.toggle()
            updateFavoriteButtonImage()
            
            guard let noteId = noteId else { return }
            
            // Visual feedback - start slight animation
            UIView.animate(withDuration: 0.1, animations: {
                self.favoriteButton.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }, completion: { _ in
                UIView.animate(withDuration: 0.1) {
                    self.favoriteButton.transform = .identity
                }
            })
            
            // Get existing note details from the cell to preserve metadata
            let currentPageCount = Int((pagesLabel.text?.replacingOccurrences(of: " Pages", with: "") ?? "0")) ?? 0
            
            // Post notification directly to update other cells immediately
            NotificationCenter.default.post(
                name: NSNotification.Name("FavoriteStatusChanged"),
                object: nil,
                userInfo: [
                    "noteId": noteId,
                    "isFavorite": isFavorite,
                    "pageCount": currentPageCount
                ]
            )
            
            // Also call Firebase service to persist the change
            FirebaseService.shared.updateFavoriteStatus(for: noteId, isFavorite: isFavorite) { error in
                if let error = error {
                    print("Error updating favorite status: \(error.localizedDescription)")
                    
                    // If there was an error, revert the state and post a notification to update UI
                    DispatchQueue.main.async {
                        self.isFavorite.toggle()
                        self.updateFavoriteButtonImage()
                        
                        // Post notification to revert other cells too
                        NotificationCenter.default.post(
                            name: NSNotification.Name("FavoriteStatusChanged"),
                            object: nil,
                            userInfo: [
                                "noteId": noteId,
                                "isFavorite": !self.isFavorite,
                                "pageCount": currentPageCount
                            ]
                        )
                    }
                }
            }
        }
        
        override func prepareForReuse() {
            super.prepareForReuse()
            titleLabel.text = nil
            subjectNameLabel.text = nil
            lastOpenedDateLabel.text = nil
            authorLabel.text = nil
            pagesLabel.text = nil
            coverImageView.image = nil
            noteId = nil
            
            // Reset text alignment
            titleLabel.textAlignment = .left
            lastOpenedDateLabel.textAlignment = .left
            
            // Remove icons if they were added for previously read notes
            documentIcon.removeFromSuperview()
            lastOpenedIcon.removeFromSuperview()
            
            // Reset visibility
            titleLabel.isHidden = false
            subjectNameLabel.isHidden = false
            lastOpenedDateLabel.isHidden = true
            authorLabel.isHidden = false
            subjectCodeLabel.isHidden = true
            pagesLabel.text = nil
            favoriteButton.isHidden = false
            recommendedTag.isHidden = true
            coverImageView.isHidden = false
            
            // Reset appearance
            containerView.layer.borderWidth = 0.5
            containerView.layer.borderColor = UIColor.systemGray5.cgColor
        }
        
    func configureWithCaching(with note: FireNote) {
        noteId = note.id
        titleLabel.text = note.title.isEmpty ? "Loading..." : note.title
        authorLabel.text = note.author.isEmpty ? "Unknown" : note.author
        pagesLabel.text = note.pageCount > 0 ? "\(note.pageCount) Pages" : "Loading..."
        subjectNameLabel.text = note.category.isEmpty ? "Uncategorized" : note.category
        isFavorite = note.isFavorite
        
        // Show/hide labels as needed
        titleLabel.isHidden = false
        authorLabel.isHidden = false
        subjectNameLabel.isHidden = false
        pagesLabel.isHidden = false
        favoriteButton.isHidden = false
        lastOpenedDateLabel.isHidden = true
        
        // Configure the cover image view
        coverImageView.backgroundColor = UIColor.systemGray6
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = 0
        
        if let coverImage = note.coverImage {
            coverImageView.contentMode = .scaleAspectFill
            coverImageView.image = coverImage
            coverImageView.backgroundColor = .white
        } else {
            let cacheKey = "cover_\(note.id)"
            if let cachedImage = CacheManager.shared.getCachedImage(for: cacheKey) {
                coverImageView.contentMode = .scaleAspectFill
                coverImageView.image = cachedImage
                coverImageView.backgroundColor = .white
            } else {
                coverImageView.contentMode = .center
                coverImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
                let config = UIImage.SymbolConfiguration(pointSize: 45, weight: .regular)
                let placeholderImage = UIImage(systemName: "doc.richtext", withConfiguration: config)
                coverImageView.image = placeholderImage
                coverImageView.tintColor = .systemBlue.withAlphaComponent(0.8)
            }
        }
        
        updateFavoriteButtonImage()
    }

    func configureForPreviouslyRead(with previouslyReadNote: PreviouslyReadNote, fullNote: FireNote?) {
        noteId = previouslyReadNote.id
            titleLabel.text = previouslyReadNote.title
            lastOpenedDateLabel.text = formatDate(previouslyReadNote.lastOpened)
            
            // Hide cover image and show only text for previously read notes
            coverImageView.isHidden = true
            
            // Show/hide labels
            titleLabel.isHidden = false
            lastOpenedDateLabel.isHidden = false
            authorLabel.isHidden = true
            subjectNameLabel.isHidden = true
            subjectCodeLabel.isHidden = true
            pagesLabel.isHidden = true
            favoriteButton.isHidden = true
            recommendedTag.isHidden = true
            
            // Apply special style for previously read notes with Darker Mint Green color
            containerView.backgroundColor = UIColor(red: 225/255, green: 235/255, blue: 225/255, alpha: 1.0)
            containerView.layer.cornerRadius = 16
            containerView.layer.borderWidth = 1
            containerView.layer.borderColor = UIColor.systemGray5.cgColor
            
            // Left-align text with proper styling
            titleLabel.textAlignment = .left
            titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            lastOpenedDateLabel.textAlignment = .left
            lastOpenedDateLabel.font = .systemFont(ofSize: 13, weight: .regular)
            lastOpenedDateLabel.textColor = .secondaryLabel
            
            // Call special setup for previously read notes layout
            setupForPreviouslyRead()
    }
    
    private func setupForPreviouslyRead() {
        // Remove existing title constraints when used for previously read
        titleLabel.removeFromSuperview()
        lastOpenedDateLabel.removeFromSuperview()
        
        // Re-add with left-aligned positioning
        containerView.addSubview(documentIcon)
        containerView.addSubview(titleLabel)
        containerView.addSubview(lastOpenedIcon)
        containerView.addSubview(lastOpenedDateLabel)
        
        // Set up constraints for left-aligned layout with proper padding
            NSLayoutConstraint.activate([
            documentIcon.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            documentIcon.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            documentIcon.widthAnchor.constraint(equalToConstant: 28),
            documentIcon.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.leadingAnchor.constraint(equalTo: documentIcon.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: documentIcon.centerYAnchor),
            
            lastOpenedIcon.leadingAnchor.constraint(equalTo: documentIcon.leadingAnchor),
            lastOpenedIcon.topAnchor.constraint(equalTo: documentIcon.bottomAnchor, constant: 12),
            lastOpenedIcon.widthAnchor.constraint(equalToConstant: 14),
            lastOpenedIcon.heightAnchor.constraint(equalToConstant: 14),
            
            lastOpenedDateLabel.leadingAnchor.constraint(equalTo: lastOpenedIcon.trailingAnchor, constant: 6),
            lastOpenedDateLabel.centerYAnchor.constraint(equalTo: lastOpenedIcon.centerYAnchor),
            lastOpenedDateLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            lastOpenedDateLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -16)
        ])
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter.string(from: date)
        }
}

struct College {
    let name: String
    let logo: UIImage?
}

class CollegeCell: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor =   UIColor(red: 230/255, green: 215/255, blue: 235/255, alpha: 1.0)
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let collegeColors: [UIColor] = [ .systemBlue,
        UIColor(red: 220/255, green: 235/255, blue: 230/255, alpha: 1.0), // Darker Mint Green
        UIColor(red: 215/255, green: 230/255, blue: 245/255, alpha: 1.0), // Darker Grayish Blue
        UIColor(red: 230/255, green: 215/255, blue: 235/255, alpha: 1.0) // Darker Lavender
    ]
    
    private let logoImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gray
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
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
        containerView.addSubview(logoImageView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            logoImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            logoImageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 60),
            logoImageView.heightAnchor.constraint(equalToConstant: 60),
            
            nameLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])
    }
    
    func configure(with college: College, hasData: Bool) {
        logoImageView.image = college.logo
        nameLabel.text = college.name
        
        // Configure activity indicator based on whether data is available
        if hasData {
            activityIndicator.stopAnimating()
            activityIndicator.isHidden = true
        } else {
            activityIndicator.startAnimating()
            activityIndicator.isHidden = false
        }
    }
    
    func startLoading() {
        logoImageView.alpha = 0.5
        nameLabel.alpha = 0.5
        activityIndicator.startAnimating()
        activityIndicator.isHidden = false
    }
    
    func stopLoading() {
        logoImageView.alpha = 1.0
        nameLabel.alpha = 1.0
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        logoImageView.image = nil
        nameLabel.text = nil
        stopLoading()
    }
}
class HomeViewController: UIViewController, UICollectionViewDataSourcePrefetching {
    // MARK: - Properties
    private var notes: [FireNote] = []
    private var isShowingCollegeNotes = false
    private var isLoading = false
    private let collegeReuseIdentifier = "CollegeCell"
    private let noteReuseIdentifier = "NoteCell"
    private var recommendedNotes: [FireNote] = []
    private var collegeNotesCache: [String: [String: [FireNote]]] = [:] // Cache for college notes
    private var isPreloadingCollegeData = false
    private var prefetchOperations = [IndexPath: Operation]()
    private let imageProcessingQueue = OperationQueue()
    private var loadingBlurView: UIVisualEffectView?
    
    private let colleges: [College] = [
        College(name: "SRM", logo: UIImage(named: "srmist_logo")),
        College(name: "VIT", logo: UIImage(named: "vit_logo")),
        College(name: "KIIT", logo: UIImage(named: "kiit_new")),
        College(name: "Manipal", logo: UIImage(named: "manipal_new")),
        College(name: "LPU", logo: UIImage(named: "lpu_new")),
        College(name: "Amity", logo: UIImage(named: "amity_new"))
    ]
    
    // MARK: - UI Components
    // previously read note ui
    private var previouslyReadNotes: [PreviouslyReadNote] = []

    private let previouslyReadLabel: UILabel = {
        let label = UILabel()
        label.text = "Previously Read"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var previouslyReadCollectionView: UICollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .horizontal
            layout.itemSize = CGSize(width: 220, height: 100) // Adjusted width for better text display
            layout.minimumInteritemSpacing = 12
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
            
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.backgroundColor = .clear
            collectionView.showsHorizontalScrollIndicator = false
            collectionView.register(NoteCollectionViewCell.self, forCellWithReuseIdentifier: noteReuseIdentifier)
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            return collectionView
        }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.color = .systemBlue
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let loadingView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.1
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let loadingLabel: UILabel = {
        let label = UILabel()
        label.text = "Loading notes..."
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        return scroll
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.text = "Home"
        label.textAlignment = .left
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let profileButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 28)
        let image = UIImage(systemName: "person.crop.circle", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(profileButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let notesLabel: UILabel = {
        let label = UILabel()
        label.text = "Recommended Notes"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var notesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 170, height: 240) // Reduced size
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 5, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell.self, forCellWithReuseIdentifier: noteReuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let collegesLabel: UILabel = {
        let label = UILabel()
        label.text = "Explore College Notes"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // Add a placeholder view for when there are no previously read notes
        private let previouslyReadPlaceholderView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemGray6
            view.layer.cornerRadius = 12
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()

        private let placeholderLabel: UILabel = {
            let label = UILabel()
            label.text = "Start exploring notes!\nYour recently read notes will appear here."
            label.font = .systemFont(ofSize: 16, weight: .medium)
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
    
    private lazy var collegesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let availableWidth = UIScreen.main.bounds.width - 64
        let itemWidth = availableWidth / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth + 20)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.isScrollEnabled = false
        collectionView.register(CollegeCell.self, forCellWithReuseIdentifier: collegeReuseIdentifier) // Register here
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI() // Sets up UI and registers cells
        setupDelegates() // Sets up delegates without redundant registration
        configureCollectionViewLayouts()
        
        // Configure operation queue
        imageProcessingQueue.maxConcurrentOperationCount = 5
        
        // Load data after UI is fully set up
        fetchNotesWithImprovedPerformance()
        preloadCollegeData()
        
        // Load previously read notes and update UI
        previouslyReadNotes = loadPreviouslyReadNotes()
        updatePreviouslyReadUI()
        
        // Add observers
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFavoriteStatusChange(_:)),
            name: NSNotification.Name("FavoriteStatusChanged"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviouslyReadNotesUpdated),
            name: NSNotification.Name("PreviouslyReadNotesUpdated"),
            object: nil
        )
        
        // Add memory warning observer
        NotificationCenter.default.addObserver(self, selector: #selector(handleMemoryWarning), name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        
        // Ensure scrollView bounces at the top for refresh
        scrollView.alwaysBounceVertical = true
    }
    
    // Configure collection view layouts to match PDFListVC
    private func configureCollectionViewLayouts() {
        // Configure notes collection view
        if let layout = notesCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 170, height: 240)
            layout.minimumInteritemSpacing = 12
            layout.minimumLineSpacing = 12
            layout.sectionInset = UIEdgeInsets(top: 14, left: 14, bottom: 20, right: 14)
        }
        
        // Configure previously read collection view
        if let layout = previouslyReadCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 220, height: 100)
            layout.minimumInteritemSpacing = 12
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Check if recommended notes need a refresh (more than 24 hours since last fetch)
        if let lastFetch = UserDefaults.standard.object(forKey: "lastRecommendedNotesFetch") as? Date,
           Date().timeIntervalSince(lastFetch) > 24 * 60 * 60 { // More than 24 hours
            fetchNotesWithImprovedPerformance()
        }
        
        // Refresh user favorites to ensure favorite states are up-to-date
        fetchUserFavorites()
        
        // Refresh collegeNotesCache to ensure it has the latest favorite states
        if let cachedCollegeNotes: [String: [String: [FireNote]]] = CacheManager.shared.getCachedData(for: "collegeNotesCache") {
            // Update favorites in all cached college notes
            let favoriteIds = FirebaseService.shared.userFavoritesCache
            var updatedCollegeNotes = cachedCollegeNotes
            
            // Update all notes with current favorite status
            for (collegeName, subjects) in updatedCollegeNotes {
                for (subjectCode, notes) in subjects {
                    for i in 0..<notes.count {
                        let shouldBeFavorite = favoriteIds.contains(notes[i].id)
                        if updatedCollegeNotes[collegeName]?[subjectCode]?[i].isFavorite != shouldBeFavorite {
                            updatedCollegeNotes[collegeName]?[subjectCode]?[i].isFavorite = shouldBeFavorite
                        }
                    }
                }
            }
            
            // Update cache and save it
            self.collegeNotesCache = updatedCollegeNotes
            try? CacheManager.shared.cacheData(updatedCollegeNotes, for: "collegeNotesCache")
        } else {
            // If no cache exists, trigger a refresh
            preloadCollegeData()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Save any favorite state changes to cache
        try? CacheManager.shared.cacheData(recommendedNotes, for: "recommendedNotes")
    }
    
    private func fetchUserFavorites() {
        guard !isLoading else { return }
        
        FirebaseService.shared.fetchUserFavorites { [weak self] favoriteIds in
            guard let self = self else { return }
            
            // Update the isFavorite state on the cached notes
            var shouldReload = false
            for i in 0..<self.recommendedNotes.count {
                let shouldBeFavorite = favoriteIds.contains(self.recommendedNotes[i].id)
                if self.recommendedNotes[i].isFavorite != shouldBeFavorite {
                    self.recommendedNotes[i].isFavorite = shouldBeFavorite
                    shouldReload = true
                }
            }
            
            if shouldReload {
                DispatchQueue.main.async {
                    self.notesCollectionView.reloadData()
                }
            }
        }
    }
        override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        handleMemoryWarning()
    }
    
    @objc private func handleMemoryWarning() {
        // Clear memory caches when memory warning is received
        CacheManager.shared.clearCache()
        FirebaseService.shared.clearCaches()
        
        // Log cache statistics
        let stats = CacheManager.shared.getCacheStats()
        print("Cache cleared. Previous stats - Disk: \(stats.diskSize) bytes, Memory: \(stats.memorySize) bytes, Items: \(stats.itemCount)")
    }

    deinit {
        // Remove observers when the view controller is deallocated
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
    }

    private func updatePreviouslyReadUI() {
            if previouslyReadNotes.isEmpty {
                previouslyReadCollectionView.isHidden = true
                previouslyReadPlaceholderView.isHidden = false
            } else {
                previouslyReadCollectionView.isHidden = false
                previouslyReadPlaceholderView.isHidden = true
                previouslyReadCollectionView.reloadData()
                previouslyReadCollectionView.collectionViewLayout.invalidateLayout() // Force layout refresh
            }
        }

    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add header view
        view.addSubview(headerView)
        headerView.addSubview(headerLabel)
        headerView.addSubview(profileButton)
        
        // Add scroll view and content view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add UI components to the content view (loadingView is now a sibling)
        [notesLabel, notesCollectionView, previouslyReadLabel, previouslyReadCollectionView,
         previouslyReadPlaceholderView, collegesLabel, collegesCollectionView, loadingView].forEach {
            contentView.addSubview($0)
        }
        
        // Add placeholder label to placeholder view
        previouslyReadPlaceholderView.addSubview(placeholderLabel)
        
        // Add activity indicator and loading UI to loadingView
        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(loadingLabel)
        
        // Add pull-to-refresh to scrollView (moved from notesCollectionView)
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshRecommendedNotes), for: .valueChanged)
        scrollView.refreshControl = refreshControl
        
        // Constraints for header view
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerView.heightAnchor.constraint(equalToConstant: 40),
            
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            profileButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            profileButton.widthAnchor.constraint(equalToConstant: 40),
            profileButton.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        // Constraints for scroll view and content view
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])
        
        // Constraints for other UI components
        NSLayoutConstraint.activate([
            notesLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            notesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            notesCollectionView.topAnchor.constraint(equalTo: notesLabel.bottomAnchor, constant: 16),
            notesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            notesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            notesCollectionView.heightAnchor.constraint(equalToConstant: 240),
            
            previouslyReadLabel.topAnchor.constraint(equalTo: notesCollectionView.bottomAnchor, constant: 24),
            previouslyReadLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previouslyReadLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            previouslyReadCollectionView.topAnchor.constraint(equalTo: previouslyReadLabel.bottomAnchor, constant: 8),
            previouslyReadCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previouslyReadCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            previouslyReadCollectionView.heightAnchor.constraint(equalToConstant: 100),
            
            previouslyReadPlaceholderView.topAnchor.constraint(equalTo: previouslyReadLabel.bottomAnchor, constant: 8),
            previouslyReadPlaceholderView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previouslyReadPlaceholderView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previouslyReadPlaceholderView.heightAnchor.constraint(equalToConstant: 100),
            
            placeholderLabel.centerXAnchor.constraint(equalTo: previouslyReadPlaceholderView.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: previouslyReadPlaceholderView.centerYAnchor),
            placeholderLabel.leadingAnchor.constraint(greaterThanOrEqualTo: previouslyReadPlaceholderView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(lessThanOrEqualTo: previouslyReadPlaceholderView.trailingAnchor, constant: -16),
            
            collegesLabel.topAnchor.constraint(equalTo: previouslyReadCollectionView.bottomAnchor, constant: 24),
            collegesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            collegesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            collegesCollectionView.topAnchor.constraint(equalTo: collegesLabel.bottomAnchor, constant: 16),
            collegesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collegesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collegesCollectionView.heightAnchor.constraint(equalToConstant: 312),
            collegesCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            
            // Loading view constraints (positioned above notesCollectionView)
            loadingView.topAnchor.constraint(equalTo: notesLabel.bottomAnchor, constant: 8),
            loadingView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 160),
            loadingView.heightAnchor.constraint(equalToConstant: 80),
            loadingView.bottomAnchor.constraint(lessThanOrEqualTo: notesCollectionView.topAnchor, constant: -8),
            
            activityIndicator.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loadingView.topAnchor, constant: 16),
            
            loadingLabel.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
            loadingLabel.leadingAnchor.constraint(equalTo: loadingView.leadingAnchor, constant: 16),
            loadingLabel.trailingAnchor.constraint(equalTo: loadingView.trailingAnchor, constant: -16),
            loadingLabel.bottomAnchor.constraint(equalTo: loadingView.bottomAnchor, constant: -16)
        ])
    }
    
    @objc private func refreshRecommendedNotes() {
        fetchNotesWithImprovedPerformance()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.scrollView.refreshControl?.endRefreshing()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
    
    private func setupDelegates() {
        notesCollectionView.dataSource = self
        notesCollectionView.delegate = self
        previouslyReadCollectionView.dataSource = self
        previouslyReadCollectionView.delegate = self
        collegesCollectionView.dataSource = self
        collegesCollectionView.delegate = self
        
        // Add prefetching support
        if #available(iOS 13.0, *) {
            notesCollectionView.prefetchDataSource = self
            notesCollectionView.isPrefetchingEnabled = true
        }
    }
    
    // MARK: - Data Fetching with Improved Performance
    public func fetchNotesWithImprovedPerformance() {
        isLoading = true
        loadingView.isHidden = false
        activityIndicator.startAnimating()

        // Load cached notes immediately as a fallback
        if let cachedNotes: [FireNote] = CacheManager.shared.getCachedData(for: "recommendedNotes"), !cachedNotes.isEmpty {
            recommendedNotes = cachedNotes
            notesCollectionView.reloadData()
            print("Loaded \(cachedNotes.count) recommended notes from cache")
        } else {
            print("No valid cached recommended notes found")
        }

        FirebaseService.shared.fetchRecommendedNotes(islastday: true) { [weak self] recommendedNotes in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if recommendedNotes.isEmpty {
                    print("No recommended notes received from FirebaseService")
                } else {
                    print("Received \(recommendedNotes.count) recommended notes from FirebaseService")
                }
                
                self.recommendedNotes = recommendedNotes
                self.notesCollectionView.reloadData()
                self.activityIndicator.stopAnimating()
                self.loadingView.isHidden = true
                self.isLoading = false
                
                // Cache the fetched notes
                try? CacheManager.shared.cacheData(recommendedNotes, for: "recommendedNotes")
                
                // Prefetch images in the background
                self.prefetchImagesForNotes(recommendedNotes)
                
                // Save last fetch timestamp
                UserDefaults.standard.set(Date(), forKey: "lastRecommendedNotesFetch")
            }
        }
    }
    
    private func prefetchImagesForNotes(_ notes: [FireNote]) {
        // Process in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            
            for (index, note) in notes.enumerated() {
                if note.coverImage == nil {
                    let cacheKey = "cover_\(note.id)"
                    
                    // Skip if already in cache
                    if CacheManager.shared.getCachedImage(for: cacheKey) != nil {
                        continue
                    }
                    
                    // Create an operation for each image
                    let operation = BlockOperation { [weak self] in
                        guard let self = self else { return }
                        
                        FirebaseService.shared.fetchPDFCoverImage(from: note.pdfUrl) { image, pageCount in
                            guard let image = image else { return }
                            
                            // Cache the image
                            CacheManager.shared.cacheImage(image, for: cacheKey)
                            
                            // Update notes array with page count
                            if pageCount > 0 && self.recommendedNotes.indices.contains(index) {
                                DispatchQueue.main.async {
                                    if self.recommendedNotes[index].pageCount == 0 {
                                        self.recommendedNotes[index].pageCount = pageCount
                                    }
                                    
                                    // Find and update visible cell if needed
                                    if let cell = self.notesCollectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? NoteCollectionViewCell {
                                        cell.coverImageView.contentMode = .scaleAspectFill
                                        cell.coverImageView.backgroundColor = nil
                                        cell.pagesLabel.text = "\(pageCount)"
                                        cell.coverImageView.image = image
                                    }
                                }
                            }
                        }
                    }
                    
                    // Add to queue with priority based on index
                    operation.queuePriority = index < 5 ? .high : .normal
                    self.imageProcessingQueue.addOperation(operation)
                }
            }
        }
    }
    
    // MARK: - UICollectionViewDataSourcePrefetching
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // Only prefetch for notes collection
        guard collectionView == notesCollectionView else { return }
        
        for indexPath in indexPaths {
            // Make sure index is valid
            guard indexPath.item < recommendedNotes.count else { continue }
            
            let note = recommendedNotes[indexPath.item]
            let cacheKey = "cover_\(note.id)"
            
            // Skip if we already have the image
            if note.coverImage != nil || CacheManager.shared.getCachedImage(for: cacheKey) != nil {
                continue
            }
            
            // Create prefetch operation
            let operation = BlockOperation { [weak self] in
                guard let self = self else { return }
                
                FirebaseService.shared.fetchPDFCoverImage(from: note.pdfUrl) { image, pageCount in
                    guard let image = image else { return }
                    
                    // Cache the image
                    CacheManager.shared.cacheImage(image, for: cacheKey)
                    
                    // Update cell if visible
                    DispatchQueue.main.async {
                        if let cell = collectionView.cellForItem(at: indexPath) as? NoteCollectionViewCell {
                            cell.coverImageView.contentMode = .scaleAspectFill
                            cell.coverImageView.backgroundColor = nil
                            cell.coverImageView.image = image
                            cell.pagesLabel.text = "\(pageCount)"
                        }
                        
                        // Update data model
                        if self.recommendedNotes.indices.contains(indexPath.item) {
                            if self.recommendedNotes[indexPath.item].pageCount == 0 {
                                self.recommendedNotes[indexPath.item].pageCount = pageCount
                            }
                        }
                    }
                }
            }
            
            // Store and start operation
            prefetchOperations[indexPath] = operation
            imageProcessingQueue.addOperation(operation)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // Cancel operations for items no longer needed
        for indexPath in indexPaths {
            if let operation = prefetchOperations[indexPath], !operation.isFinished {
                operation.cancel()
                prefetchOperations.removeValue(forKey: indexPath)
            }
        }
    }
    
    private func preloadCollegeData() {
        // Check if cache is valid
        if let cachedCollegeNotes: [String: [String: [FireNote]]] = CacheManager.shared.getCachedData(for: "collegeNotesCache"),
           let lastCacheDate = UserDefaults.standard.object(forKey: "lastCollegeNotesCache") as? Date,
           Date().timeIntervalSince(lastCacheDate) < 24 * 60 * 60 { // Less than 24 hours
            self.collegeNotesCache = cachedCollegeNotes
            print("Using cached college notes data")
            DispatchQueue.main.async {
                self.collegesCollectionView.reloadData()
            }
            return
        }
        
        // Fetch fresh data if cache is invalid or missing
        isPreloadingCollegeData = true
        DispatchQueue.global(qos: .background).async { [weak self] in
            FirebaseService.shared.fetchNotes { [weak self] allNotes, groupedNotes in
                guard let self = self else { return }
                self.collegeNotesCache = groupedNotes
                try? CacheManager.shared.cacheData(groupedNotes, for: "collegeNotesCache")
                UserDefaults.standard.set(Date(), forKey: "lastCollegeNotesCache")
                
                DispatchQueue.main.async {
                    self.isPreloadingCollegeData = false
                    self.collegesCollectionView.reloadData()
                }
            }
        }
    }
    
    private func enhanceCollegeDataWithMetadata(groupedNotes: [String: [String: [FireNote]]]) {
        // Process each note to ensure metadata is properly fetched
        var enhancedGroupedNotes = groupedNotes
        let dispatchGroup = DispatchGroup()
        
        for (collegeName, subjects) in groupedNotes {
            for (subjectCode, notes) in subjects {
                for (noteIndex, note) in notes.enumerated() {
                    // If page count or file size is invalid, fetch it properly
                    if note.pageCount == 0 || note.fileSize == "0 KB" {
                        dispatchGroup.enter()
                        
                        // Re-fetch metadata
                        if let storageRef = FirebaseService.shared.getStorageReference(from: note.pdfUrl) {
                            storageRef.getMetadata { metadata, error in
                                let fileSize = FirebaseService.shared.formatFileSize(metadata?.size ?? 0)
                                
                                // Only fetch page count for notes that will be visible soon
                                if collegeName == "SRM" || collegeName == "VIT" {
                                    FirebaseService.shared.fetchPDFCoverImage(from: note.pdfUrl) { (image, pageCount) in
                                        // Update the note with correct metadata
                                        var updatedNote = note
                                        updatedNote.pageCount = pageCount
                                        if !fileSize.isEmpty && fileSize != "0 KB" {
                                            updatedNote.fileSize = fileSize
                                        }
                                        
                                        // Update the note in the dictionary
                                        enhancedGroupedNotes[collegeName]?[subjectCode]?[noteIndex] = updatedNote
                                        dispatchGroup.leave()
                                    }
                                } else {
                                    // For other colleges, just update file size
                                    var updatedNote = note
                                    if !fileSize.isEmpty && fileSize != "0 KB" {
                                        updatedNote.fileSize = fileSize
                                    }
                                    enhancedGroupedNotes[collegeName]?[subjectCode]?[noteIndex] = updatedNote
                                    dispatchGroup.leave()
                                }
                            }
                        } else {
                            dispatchGroup.leave()
                        }
                    }
                }
            }
        }
        
        // Update cache when complete
        dispatchGroup.notify(queue: .global()) { [weak self] in
            guard let self = self else { return }
            
            self.collegeNotesCache = enhancedGroupedNotes
            
            // Cache the college notes data with complete metadata
            try? CacheManager.shared.cacheData(enhancedGroupedNotes, for: "collegeNotesCache")
            
            DispatchQueue.main.async {
                self.isPreloadingCollegeData = false
                self.collegesCollectionView.reloadData()
            }
        }
    }
    
    // MARK: - Previously Read Notes Storage
    private func savePreviouslyReadNote(_ note: PreviouslyReadNote) {
            guard let userId = FirebaseService.shared.currentUserId else { return }
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
            "lastOpened": $0.lastOpened.timeIntervalSince1970 // Convert Date to TimeInterval
        ]}
        UserDefaults.standard.set(historyData, forKey: "previouslyReadNotes_\(userId)")
        
        NotificationCenter.default.post(name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
        }

        private func loadPreviouslyReadNotes() -> [PreviouslyReadNote] {
            guard let userId = FirebaseService.shared.currentUserId else { return [] }
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
    
    @objc private func profileButtonTapped() {
        let profileVC = ProfileViewController()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.pushViewController(profileVC, animated: true)
    }

    // Add these methods to handle notifications
    @objc private func handleFavoriteStatusChange(_ notification: Notification) {
        // Get noteId and favorite status from notification
        guard let userInfo = notification.userInfo,
              let noteId = userInfo["noteId"] as? String,
              let isFavorite = userInfo["isFavorite"] as? Bool else {
            // If we don't have specific info, reload all data
            fetchNotesWithImprovedPerformance()
            return
        }
        
        // Extract metadata if available
        let pageCount = userInfo["pageCount"] as? Int
        
        print("Updating favorite status for noteId: \(noteId) to \(isFavorite)")
        
        // Update recommended notes
        for i in 0..<recommendedNotes.count {
            if recommendedNotes[i].id == noteId {
                recommendedNotes[i].isFavorite = isFavorite
                // Preserve metadata if provided
                if let pageCount = pageCount, recommendedNotes[i].pageCount == 0 {
                    recommendedNotes[i].pageCount = pageCount
                }
            }
        }
        
        // Update notes cache
        for i in 0..<notes.count {
            if notes[i].id == noteId {
                notes[i].isFavorite = isFavorite
                // Preserve metadata if provided
                if let pageCount = pageCount, notes[i].pageCount == 0 {
                    notes[i].pageCount = pageCount
                }
            }
        }
        
        // Update collegeNotesCache - thoroughly check all notes
        var didUpdateCollegeCache = false
        for (collegeName, subjects) in collegeNotesCache {
            for (subjectCode, subjectNotes) in subjects {
                for i in 0..<subjectNotes.count {
                    if subjectNotes[i].id == noteId {
                        collegeNotesCache[collegeName]?[subjectCode]?[i].isFavorite = isFavorite
                        // Preserve metadata if provided
                        if let pageCount = pageCount, collegeNotesCache[collegeName]?[subjectCode]?[i].pageCount == 0 {
                            collegeNotesCache[collegeName]?[subjectCode]?[i].pageCount = pageCount
                        }
                        // Remove the fileSize check since it's no longer included in the notification
                        didUpdateCollegeCache = true
                    }
                }
            }
        }
        
        // Force update all visible cells with matching noteId
        let updateVisibleCells = { (collectionView: UICollectionView) in
            for cell in collectionView.visibleCells {
                if let noteCell = cell as? NoteCollectionViewCell, noteCell.noteId == noteId {
                    noteCell.isFavorite = isFavorite
                    noteCell.updateFavoriteButtonImage()
                }
            }
        }
        
        // Update all collection views that might contain notes
        updateVisibleCells(notesCollectionView)
        updateVisibleCells(previouslyReadCollectionView)
        
        // Also update FirebaseService cache
        if isFavorite {
            if !FirebaseService.shared.userFavoritesCache.contains(noteId) {
                FirebaseService.shared.userFavoritesCache.append(noteId)
            }
        } else {
            FirebaseService.shared.userFavoritesCache.removeAll { $0 == noteId }
        }
        
        // Save updated collegeNotesCache to persistent cache if it was changed
        if didUpdateCollegeCache {
            try? CacheManager.shared.cacheData(collegeNotesCache, for: "collegeNotesCache")
        }

        // Reload collection views to show the changes
        notesCollectionView.reloadData()
        previouslyReadCollectionView.reloadData()
        collegesCollectionView.reloadData() // Add this to refresh the college grid if needed
    }
    
    @objc private func handlePreviouslyReadNotesUpdated() {
        previouslyReadNotes = loadPreviouslyReadNotes()
        print("Updated previouslyReadNotes: \(previouslyReadNotes.map { "\($0.id): \($0.title), \($0.lastOpened)" })")
        updatePreviouslyReadUI()
    }
}


extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == notesCollectionView {
            return recommendedNotes.count
        } else if collectionView == previouslyReadCollectionView {
            return previouslyReadNotes.count
        } else {
            return colleges.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == notesCollectionView {
            // Use consistent sizing for recommendation section
            return CGSize(width: 170, height: 240)
        } else if collectionView == previouslyReadCollectionView {
            return CGSize(width: 220, height: 100)
        } else {
            // For colleges collection view
            let availableWidth = UIScreen.main.bounds.width - 64
            let itemWidth = availableWidth / 3
            return CGSize(width: itemWidth, height: itemWidth + 20)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == notesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: noteReuseIdentifier, for: indexPath) as! NoteCollectionViewCell
            let note = recommendedNotes[indexPath.item]
            cell.configureWithCaching(with: note)
            return cell
        } else if collectionView == previouslyReadCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: noteReuseIdentifier, for: indexPath) as! NoteCollectionViewCell
            let previouslyReadNote = previouslyReadNotes[indexPath.item]
            let fullNote = recommendedNotes.first(where: { $0.id == previouslyReadNote.id })
            cell.configureForPreviouslyRead(with: previouslyReadNote, fullNote: fullNote)
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collegeReuseIdentifier, for: indexPath) as! CollegeCell
            let college = colleges[indexPath.item]
            let hasData = collegeNotesCache[college.name] != nil
            cell.configure(with: college, hasData: hasData)
            return cell
        }
    }
}



extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    cell.transform = .identity
                }
            }
        }

        if collectionView == collegesCollectionView {
            let selectedCollege = colleges[indexPath.item]
            
            // Show activity indicator in the cell
            if let cell = collectionView.cellForItem(at: indexPath) as? CollegeCell {
                cell.startLoading()
            }
            
            collectionView.isUserInteractionEnabled = false // Disable taps during fetch

            // Check if we have cached data for this college
            if let collegeNotes = collegeNotesCache[selectedCollege.name] {
                // Use cached data
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    
                    if let cell = collectionView.cellForItem(at: indexPath) as? CollegeCell {
                        cell.stopLoading()
                    }
                    
                    collectionView.isUserInteractionEnabled = true
                    
                    // Update the cached notes with current favorite status
                    let favoriteIds = FirebaseService.shared.userFavoritesCache
                    var updatedCollegeNotes = collegeNotes
                    
                    // Update favorites in the collegeNotes before passing to NotesViewController
                    for (subjectCode, notes) in updatedCollegeNotes {
                        for i in 0..<notes.count {
                            // Check both favorite status and metadata
                            var noteNeedsUpdate = false
                            var updatedNote = notes[i]
                            
                            // Update favorite status
                            let shouldBeFavorite = favoriteIds.contains(notes[i].id)
                            if updatedCollegeNotes[subjectCode]?[i].isFavorite != shouldBeFavorite {
                                updatedNote.isFavorite = shouldBeFavorite
                                noteNeedsUpdate = true
                            }
                            
                            // If page count or file size is invalid, use what's available in the regular notes cache
                            if updatedNote.pageCount == 0 || updatedNote.fileSize == "0 KB" {
                                if let fullNote = self.notes.first(where: { $0.id == updatedNote.id }) {
                                    if updatedNote.pageCount == 0 && fullNote.pageCount > 0 {
                                        updatedNote.pageCount = fullNote.pageCount
                                        noteNeedsUpdate = true
                                    }
                                    if (updatedNote.fileSize == "0 KB" || updatedNote.fileSize.isEmpty) && !fullNote.fileSize.isEmpty {
                                        updatedNote.fileSize = fullNote.fileSize
                                        noteNeedsUpdate = true
                                    }
                                }
                            }
                            
                            // Update the note if needed
                            if noteNeedsUpdate {
                                updatedCollegeNotes[subjectCode]?[i] = updatedNote
                            }
                        }
                    }
                    
                    // Update the cache
                    self.collegeNotesCache[selectedCollege.name] = updatedCollegeNotes
                    try? CacheManager.shared.cacheData(self.collegeNotesCache, for: "collegeNotesCache")
                    
                    let notesVC = NotesViewController()
                    notesVC.configure(with: updatedCollegeNotes)
                    self.navigationController?.pushViewController(notesVC, animated: true)
                }
                return
            }
            
            // Fetch if not cached
            FirebaseService.shared.fetchNotes { [weak self] _, groupedNotes in
                guard let self = self else { return }
                
                // Update cache
                self.collegeNotesCache = groupedNotes
                
                // Cache for future use
                try? CacheManager.shared.cacheData(groupedNotes, for: "collegeNotesCache")
                
                DispatchQueue.main.async {
                    if let cell = collectionView.cellForItem(at: indexPath) as? CollegeCell {
                        cell.stopLoading()
                    }
                    
                    collectionView.isUserInteractionEnabled = true

                    if let collegeNotes = groupedNotes[selectedCollege.name] {
                        // Update with current favorite status
                        let favoriteIds = FirebaseService.shared.userFavoritesCache
                        var updatedCollegeNotes = collegeNotes
                        
                        // Update favorites in the collegeNotes before passing to NotesViewController
                        for (subjectCode, notes) in updatedCollegeNotes {
                            for i in 0..<notes.count {
                                // Check both favorite status and metadata
                                var noteNeedsUpdate = false
                                var updatedNote = notes[i]
                                
                                // Update favorite status
                                let shouldBeFavorite = favoriteIds.contains(notes[i].id)
                                if updatedNote.isFavorite != shouldBeFavorite {
                                    updatedNote.isFavorite = shouldBeFavorite
                                    noteNeedsUpdate = true
                                }
                                
                                // If page count or file size is invalid, use what's available in the regular notes cache
                                if updatedNote.pageCount == 0 || updatedNote.fileSize == "0 KB" {
                                    if let fullNote = self.notes.first(where: { $0.id == updatedNote.id }) {
                                        if updatedNote.pageCount == 0 && fullNote.pageCount > 0 {
                                            updatedNote.pageCount = fullNote.pageCount
                                            noteNeedsUpdate = true
                                        }
                                        if (updatedNote.fileSize == "0 KB" || updatedNote.fileSize.isEmpty) && !fullNote.fileSize.isEmpty {
                                            updatedNote.fileSize = fullNote.fileSize
                                            noteNeedsUpdate = true
                                        }
                                    }
                                }
                                
                                // Update the note if needed
                                if noteNeedsUpdate {
                                    updatedCollegeNotes[subjectCode]?[i] = updatedNote
                                }
                            }
                        }
                        
                        // Update the cache
                        self.collegeNotesCache[selectedCollege.name] = updatedCollegeNotes
                        try? CacheManager.shared.cacheData(self.collegeNotesCache, for: "collegeNotesCache")
                        
                        let notesVC = NotesViewController()
                        notesVC.configure(with: updatedCollegeNotes)
                        self.navigationController?.pushViewController(notesVC, animated: true)
                    } else {
                        self.showAlert(title: "No Notes", message: "No notes available for \(selectedCollege.name).")
                    }
                }
            }
            } else if collectionView == notesCollectionView {
                let selectedNote = recommendedNotes[indexPath.item]
            loadAndPresentPDF(note: selectedNote)
        } else if collectionView == previouslyReadCollectionView {
            let selectedNote = previouslyReadNotes[indexPath.item]
            
            // Try to find full note details
            let fullNote = notes.first { $0.id == selectedNote.id } ??
                           recommendedNotes.first { $0.id == selectedNote.id }
            
            if let fullNote = fullNote {
                loadAndPresentPDF(note: fullNote)
            } else {
                // Use previously read note data
                loadAndPresentPDF(pdfUrl: selectedNote.pdfUrl, title: selectedNote.title, noteId: selectedNote.id)
            }
        }
    }
    
    // Optimized method to load and present PDF
    private func loadAndPresentPDF(note: FireNote) {
        loadAndPresentPDF(pdfUrl: note.pdfUrl, title: note.title, noteId: note.id)
    }
    
    private func loadAndPresentPDF(pdfUrl: String, title: String, noteId: String) {
        // First check if we already have this PDF in cache
        guard let url = URL(string: pdfUrl) else {
            showAlert(title: "Error", message: "Invalid PDF URL")
            return
        }
        
        if let cachedData = CacheManager.shared.getCachedPDF(url: url) {
            // PDF is in cache, write to temp file and display
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(noteId).pdf")
            do {
                try cachedData.write(to: tempURL)
                self.presentPDFViewer(url: tempURL, title: title, noteId: noteId, pdfUrl: pdfUrl)
            } catch {
                // If writing fails, download normally
                downloadAndPresentPDF(pdfUrl: pdfUrl, title: title, noteId: noteId)
            }
            return
        }
        
        // Not in cache, download normally
        downloadAndPresentPDF(pdfUrl: pdfUrl, title: title, noteId: noteId)
    }
    
    private func downloadAndPresentPDF(pdfUrl: String, title: String, noteId: String) {
        showLoadingView {
            FirebaseService.shared.downloadPDF(from: pdfUrl) { [weak self] result in
                        DispatchQueue.main.async {
                    self?.hideLoadingView {
                                switch result {
                                case .success(let url):
                            self?.presentPDFViewer(url: url, title: title, noteId: noteId, pdfUrl: pdfUrl)
                                case .failure(let error):
                                    self?.showAlert(title: "Error", message: "Could not load PDF: \(error.localizedDescription)")
                                }
                            }
                        }
                    }
                }
            }
    
    private func presentPDFViewer(url: URL, title: String, noteId: String, pdfUrl: String) {
        // Use document ID-based constructor instead of URL-based one
        let pdfVC = PDFViewerViewController(documentId: noteId)
        let nav = UINavigationController(rootViewController: pdfVC)
        nav.modalPresentationStyle = .fullScreen
        self.present(nav, animated: true)
        
        // Update previously read notes
        let previouslyReadNote = PreviouslyReadNote(
            id: noteId,
            title: title,
            pdfUrl: pdfUrl,
            lastOpened: Date()
        )
        self.savePreviouslyReadNote(previouslyReadNote)
        self.previouslyReadNotes = self.loadPreviouslyReadNotes()
        self.previouslyReadCollectionView.reloadData()
    }
    
    // Helper methods for loading UI
    private func showLoadingView(completion: @escaping () -> Void) {
        // Create a custom loading view with a blur effect
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.alpha = 0
        
        // Use the existing loadingView for PDF loading
        loadingView.isHidden = false
        loadingView.alpha = 0
        loadingLabel.text = "Loading PDF..."
        activityIndicator.startAnimating()
        
        blurView.contentView.addSubview(loadingView)
        view.addSubview(blurView)
        
        NSLayoutConstraint.activate([
            loadingView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            loadingView.widthAnchor.constraint(equalToConstant: 200),
            loadingView.heightAnchor.constraint(equalToConstant: 120)
        ])
        
        // Animate the blur view in
        UIView.animate(withDuration: 0.3, animations: {
            blurView.alpha = 1
            self.loadingView.alpha = 1
        }, completion: { _ in
            completion()
        })
        
        // Store a reference to dismiss it later
        self.loadingBlurView = blurView
    }
    
    private func hideLoadingView(completion: @escaping () -> Void) {
        guard let blurView = self.loadingBlurView else {
            completion()
            return
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            blurView.alpha = 0
            self.loadingView.alpha = 0
        }, completion: { _ in
            blurView.removeFromSuperview()
            self.loadingBlurView = nil
            self.loadingView.isHidden = true
            self.activityIndicator.stopAnimating()
            completion()
        })
    }

    // Add this helper method if not already present
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

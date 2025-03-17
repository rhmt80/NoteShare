import UIKit
import VisionKit
import FirebaseStorage
import FirebaseFirestore
import PDFKit
import FirebaseAuth
struct SavedFireNote {
    let id: String
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let pdfUrl: String
    let dateAdded: Date
    let pageCount: Int
    let fileSize: String
    var userID : String
    var isFavorite: Bool
    var dictionary: [String: Any]{
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
            "userId" : userID
        ]
    }
}

class FirebaseService1 {
    static let shared = FirebaseService1()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    // Fetch notes for a specific user
    func observeNotes(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
        db.collection("pdfs")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener { (snapshot, error) in
                if let error = error {
                    print("Error observing notes: \(error.localizedDescription)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
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
                                description: data["category"] as? String ?? "",
                                author: data["collegeName"] as? String ?? "Unknown Author",
                                coverImage: image,
                                pdfUrl: pdfUrl,
                                dateAdded: (metadata?.timeCreated ?? Date()),
                                pageCount: pageCount,
                                fileSize: fileSize,
                                userID: userId,
                                isFavorite: false
                            )
                            notes.append(note)
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    completion(notes.sorted { $0.dateAdded > $1.dateAdded })
                }
            }
    }

    
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func getStorageReference(from urlString: String) -> StorageReference? {
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
                                        description: data["category"] as? String ?? "",
                                        author: data["collegeName"] as? String ?? "Unknown Author",
                                        coverImage: image,
                                        pdfUrl: pdfUrl,
                                        dateAdded: (metadata?.timeCreated ?? Date()),
                                        pageCount: pageCount,
                                        fileSize: fileSize,
                                        userID: data["userId"] as? String ?? userId,
                                        isFavorite: true
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
                if error == nil {
                    NotificationCenter.default.post(name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
                }
                completion(error)
            }
        } else {
            favoriteRef.delete { error in
                if error == nil {
                    NotificationCenter.default.post(name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
                }
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
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
        view.clipsToBounds = false // Allow shadow, but we'll constrain subviews
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray6
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2 // Allow up to 2 lines for long titles
        label.lineBreakMode = .byTruncatingTail // Truncate if still too long
        label.adjustsFontSizeToFitWidth = true // Dynamically adjust font size
        label.minimumScaleFactor = 0.75 // Minimum font scale
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let detailsStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let pagesLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let favoriteButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // UI Setup
    private func setupUI() {
        contentView.addSubview(containerView)
        
        [coverImageView, titleLabel, detailsStackView, favoriteButton].forEach {
            containerView.addSubview($0)
        }
        
        [pagesLabel, fileSizeLabel].forEach {
            detailsStackView.addArrangedSubview($0)
        }
        
        setupConstraints()
        favoriteButton.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Container view
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Cover image view
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            // Details stack view
            detailsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            detailsStackView.trailingAnchor.constraint(equalTo: favoriteButton.leadingAnchor, constant: -8), // Adjusted to respect favorite button
            
            // Favorite button
            favoriteButton.centerYAnchor.constraint(equalTo: detailsStackView.centerYAnchor),
            favoriteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 24),
            favoriteButton.heightAnchor.constraint(equalToConstant: 24),
            favoriteButton.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8) // Ensure it stays within bounds
        ])
    }
    
    // Update UI for favorite button
    private func updateFavoriteButtonImage() {
        let image = isFavorite ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        favoriteButton.setImage(image, for: .normal)
        favoriteButton.tintColor = isFavorite ? .systemBlue : .systemGray
    }
    
    // Favorite button pressed
    @objc private func favoriteButtonPressed() {
        isFavorite.toggle()
        updateFavoriteButtonImage()
        
        guard let noteId = noteId else { return }
        
        FirebaseService1.shared.updateFavoriteStatus(for: noteId, isFavorite: isFavorite) { error in
            if let error = error {
                print("Error updating favorite status: \(error.localizedDescription)")
                self.isFavorite.toggle()
                self.updateFavoriteButtonImage()
            }
        }
    }
    
    // Configure cell with SavedFireNote
    func configure(with note: SavedFireNote) {
        noteId = note.id
        titleLabel.text = note.title
        pagesLabel.text = "Pages: \(note.pageCount)"
        fileSizeLabel.text = note.fileSize
        coverImageView.image = note.coverImage ?? UIImage(systemName: "doc.fill")
        isFavorite = note.isFavorite
        
        // Add fade animation
        coverImageView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.coverImageView.alpha = 1
        }
        
        // Force layout update
        layoutIfNeeded()
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


class SavedViewController: UIViewController, UIScrollViewDelegate {
    // MARK: - Previously Read Notes Storage
    struct PreviouslyReadNote {
        let id: String
        let title: String
        let pdfUrl: String
        let lastOpened: Date
    }

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
                "lastOpened": $0.lastOpened.timeIntervalSince1970 // Convert Date to TimeInterval
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
    
    // MARK: - Properties
    
    private var curatedNotes: [SavedFireNote] = []
    private var isLoading = false
    private var favoriteNotes: [SavedFireNote] = []
    
//    fav section
    private let favoriteNotesLabel: UILabel = {
        let label = UILabel()
        label.text = "Favourites"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var favoriteNotesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 280)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 5, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "FavoriteNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private func fetchFavoriteNotes() {
            guard let userID = Auth.auth().currentUser?.uid else {
                showAlert(title: "Error", message: "User not authenticated")
                return
            }
            
            FirebaseService1.shared.fetchFavoriteNotes(userId: userID) { [weak self] notes in
                guard let self = self else { return }
                self.favoriteNotes = notes
                self.updateAllNotes()
                self.favoriteNotesCollectionView.reloadData()
            }
        }
       
    private func showAlert(title : String ,message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                present(alert, animated: true, completion: nil)
    }
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "My Notes"
//        label.backgroundColor = .systemBackground
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let addNoteButton: UIButton = {
        let button = UIButton(type: .system)
//        button.setImage(UIImage(systemName: "icloud.and.arrow.up"), for: .normal)
        
        button.setImage(UIImage(systemName: "document.badge.arrow.up"), for: .normal)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    

    private let scanButton: UIButton = {
        let button = UIButton(type: .system)
//        button.setImage(UIImage(systemName: "camera.viewfinder"), for: .normal)
        button.setImage(UIImage(systemName: "document.viewfinder.fill"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .prominent
        searchBar.placeholder = "Search"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let curatedNotesLabel: UILabel = {
        let label = UILabel()
        label.text = "Uploaded Notes"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var curatedNotesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 280)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 5, left: 16, bottom: 0, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
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
    
    @objc private func reloadFavoriteNotes() {
        print("🔄 Reloading favorite notes...")
        fetchFavoriteNotes()
    }
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)

    }
    
    private var allNotes: [SavedFireNote] = [] // Combined list of all notes
        private var searchResults: [SavedFireNote] = [] // Filtered search results
        
        // Add search results table view
        private lazy var searchResultsTableView: UITableView = {
            let tableView = UITableView()
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
            tableView.translatesAutoresizingMaskIntoConstraints = false
            tableView.isHidden = true
            tableView.backgroundColor = .systemBackground
            return tableView
        }()
    
    private func updateAllNotes() {
            allNotes = (curatedNotes + favoriteNotes).sorted { $0.dateAdded > $1.dateAdded }
                .removingDuplicates(by: \.id) // Remove duplicates based on id
            // Update searchResults only when not searching
            if searchBar.text?.isEmpty ?? true {
                searchResults = allNotes
            }
        }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
            super.viewDidLoad()
            setupUI()
            setupDelegates()
            configureNavigationBar()
            fetchCuratedNotes()
            fetchFavoriteNotes()
            searchBar.delegate = self
            scrollView.delegate = self
            
            // Add table view delegate and data source
            searchResultsTableView.delegate = self
            searchResultsTableView.dataSource = self
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
            tapGesture.cancelsTouchesInView = false
            view.addGestureRecognizer(tapGesture)
            
            NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChange), name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
            
            NotificationCenter.default.addObserver(self, selector: #selector(handlePreviouslyReadNotesUpdated), name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
            
            // Enable cancel button for search bar
//            searchBar.showsCancelButton = true
        }
    
    @objc private func handleFavoriteStatusChange() {
        // Refresh the notes when favorite status changes
        fetchCuratedNotes()
        fetchFavoriteNotes()
    }
    
    @objc private func handlePreviouslyReadNotesUpdated() {
        // Optionally refresh curated/favorite notes if they display previously read notes
        fetchCuratedNotes()
        fetchFavoriteNotes()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureNavigationBar()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: false)
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
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add fixed header elements directly to the view
        [titleLabel, addNoteButton, scanButton, searchBar].forEach {
            view.addSubview($0)
        }
        
        // Add scroll view for content
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add scrollable content to contentView
        [favoriteNotesLabel, favoriteNotesCollectionView,
         curatedNotesLabel, curatedNotesCollectionView].forEach {
            contentView.addSubview($0)
        }
        
        // Add search results table view to main view
        view.addSubview(searchResultsTableView)
        curatedNotesCollectionView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // Fixed Header Elements
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16), // Already consistent
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            addNoteButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addNoteButton.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -16),
            addNoteButton.widthAnchor.constraint(equalToConstant: 30),
            addNoteButton.heightAnchor.constraint(equalToConstant: 30),
            
            scanButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scanButton.widthAnchor.constraint(equalToConstant: 30),
            scanButton.heightAnchor.constraint(equalToConstant: 30),
            
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // ScrollView and other constraints remain unchanged
            scrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            favoriteNotesLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            favoriteNotesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            favoriteNotesCollectionView.topAnchor.constraint(equalTo: favoriteNotesLabel.bottomAnchor, constant: 16),
            favoriteNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            favoriteNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            favoriteNotesCollectionView.heightAnchor.constraint(equalToConstant: 280),
            
            curatedNotesLabel.topAnchor.constraint(equalTo: favoriteNotesCollectionView.bottomAnchor, constant: 24),
            curatedNotesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            curatedNotesCollectionView.topAnchor.constraint(equalTo: curatedNotesLabel.bottomAnchor, constant: 16),
            curatedNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            curatedNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            curatedNotesCollectionView.heightAnchor.constraint(equalToConstant: 280),
            curatedNotesCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            searchResultsTableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            searchResultsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchResultsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchResultsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: curatedNotesCollectionView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: curatedNotesCollectionView.centerYAnchor)
        ])
        
        // Add actions to buttons
        addNoteButton.addTarget(self, action: #selector(addNoteTapped), for: .touchUpInside)
        scanButton.addTarget(self, action: #selector(moreOptionsTapped), for: .touchUpInside)
    }
    
    private func fetchCuratedNotes() {
            guard let userID = Auth.auth().currentUser?.uid else {
                showAlert(title: "Error", message: "User not authenticated")
                return
            }
            
            FirebaseService1.shared.observeNotes(userId: userID) { [weak self] notes in
                guard let self = self else { return }
                self.curatedNotes = notes
                self.updateAllNotes()
                self.curatedNotesCollectionView.reloadData()
            }
        }

    
    // MARK: - Action Methods
    

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
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
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
}
// search bar functionality
extension SavedViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            searchResultsTableView.isHidden = true
            curatedNotesCollectionView.isHidden = false
            favoriteNotesCollectionView.isHidden = false
            favoriteNotesLabel.isHidden = false
            curatedNotesLabel.isHidden = false
            fetchCuratedNotes()
            fetchFavoriteNotes()
        } else {
            searchResults = allNotes.filter {
                $0.title.lowercased().contains(searchText.lowercased())
            }
            searchResultsTableView.isHidden = false
            curatedNotesCollectionView.isHidden = true
            favoriteNotesCollectionView.isHidden = true
            favoriteNotesLabel.isHidden = true
            curatedNotesLabel.isHidden = true
            searchResultsTableView.reloadData()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchResultsTableView.isHidden = true
        curatedNotesCollectionView.isHidden = false
        favoriteNotesCollectionView.isHidden = false
        favoriteNotesLabel.isHidden = false
        curatedNotesLabel.isHidden = false
        fetchCuratedNotes()
        fetchFavoriteNotes()
        searchBar.resignFirstResponder()
    }
}

// Table view delegate and data source
extension SavedViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let note = searchResults[indexPath.row]
        
        var content = cell.defaultContentConfiguration()
        content.text = note.title
        content.secondaryText = "Pages: \(note.pageCount) • \(note.fileSize) • \(note.isFavorite ? "Favorite" : "")"
        content.image = note.coverImage ?? UIImage(systemName: "doc.fill")
        content.imageProperties.maximumSize = CGSize(width: 40, height: 40)
        content.imageProperties.cornerRadius = 4
        
        cell.contentConfiguration = content
        cell.backgroundColor = .systemBackground
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedNote = searchResults[indexPath.row]
        
        showLoadingAlert {
            FirebaseService1.shared.downloadPDF(from: selectedNote.pdfUrl) { [weak self] result in
                DispatchQueue.main.async {
                    self?.dismissLoadingAlert {
                        switch result {
                        case .success(let url):
                            let pdfVC = PDFViewerViewController(pdfURL: url, title: selectedNote.title)
                            let nav = UINavigationController(rootViewController: pdfVC)
                            nav.modalPresentationStyle = .fullScreen
                            self?.present(nav, animated: true)
                            
                            let previouslyReadNote = PreviouslyReadNote(
                                id: selectedNote.id,
                                title: selectedNote.title,
                                pdfUrl: selectedNote.pdfUrl,
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
}

extension SavedViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        // Dismiss the scanner
        controller.dismiss(animated: true, completion: nil)

                // Convert scanned images to PDF
                let pdfDocument = PDFDocument()
                for pageIndex in 0..<scan.pageCount {
                    let scannedImage = scan.imageOfPage(at: pageIndex)
                    let pdfPage = PDFPage(image: scannedImage)
                    pdfDocument.insert(pdfPage!, at: pageIndex)
                }

                // Get PDF data
                guard let pdfData = pdfDocument.dataRepresentation() else {
                    showAlert(title: "Error", message: "Failed to create PDF from scanned images.")
                    return
                }

                // Present ScannedPDFUploadViewController with scanned PDF data
                let scannedPDFUploadVC = ScannedPDFUploadViewController(scannedPDFData: pdfData)
                present(scannedPDFUploadVC, animated: true, completion: nil)
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true, completion: nil)
    }

    private func uploadPDFToFirebase(pdfData: Data) {
        guard let userID = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not authenticated.")
            return
        }

        let storageRef = Storage.storage().reference()
        let pdfRef = storageRef.child("scanned_documents/\(UUID().uuidString).pdf")

        pdfRef.putData(pdfData, metadata: nil) { metadata, error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to upload PDF: \(error.localizedDescription)")
                return
            }

            // PDF uploaded successfully
            pdfRef.downloadURL { url, error in
                if let downloadURL = url {
                    print("PDF uploaded successfully! Download URL: \(downloadURL)")
                    self.savePDFMetadataToFirestore(downloadURL: downloadURL.absoluteString, userID: userID)
                } else {
                    self.showAlert(title: "Error", message: "Failed to get download URL.")
                }
            }
        }
    }

    private func savePDFMetadataToFirestore(downloadURL: String, userID: String) {
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

        db.collection("pdfs").addDocument(data: pdfMetadata) { error in
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to save PDF metadata: \(error.localizedDescription)")
            } else {
                self.showAlert(title: "Success", message: "PDF uploaded and saved successfully!")
                self.fetchCuratedNotes() // Refresh the notes list
            }
        }
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print("Document scanner failed with error: \(error.localizedDescription)")
        controller.dismiss(animated: true, completion: nil)
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
// Update scroll view delegate to dismiss keyboard
extension SavedViewController {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

// MARK: - UICollectionViewDataSource & UICollectionViewDelegate
extension SavedViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == curatedNotesCollectionView {
            return curatedNotes.count
        } else {
            return favoriteNotes.count
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == curatedNotesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CuratedNoteCell", for: indexPath) as! NoteCollectionViewCell1
            cell.configure(with: curatedNotes[indexPath.item])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FavoriteNoteCell", for: indexPath) as! NoteCollectionViewCell1
            cell.configure(with: favoriteNotes[indexPath.item])
            return cell
        }
    }
    
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedNote = collectionView == curatedNotesCollectionView ? curatedNotes[indexPath.item] : favoriteNotes[indexPath.item]
        print("Selected note with pdfUrl: \(selectedNote.pdfUrl)")
        showLoadingAlert {
            FirebaseService1.shared.downloadPDF(from: selectedNote.pdfUrl) { [weak self] result in
                DispatchQueue.main.async {
                    self?.dismissLoadingAlert {
                        switch result {
                        case .success(let url):
                            print("Opening PDF at \(url.path)")
                            let pdfVC = PDFViewerViewController(pdfURL: url, title: selectedNote.title)
                            let nav = UINavigationController(rootViewController: pdfVC)
                            nav.modalPresentationStyle = .fullScreen
                            self?.present(nav, animated: true)
                            
                            // Update previously read notes
                            let previouslyReadNote = PreviouslyReadNote(
                                id: selectedNote.id,
                                title: selectedNote.title,
                                pdfUrl: selectedNote.pdfUrl,
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
}

// MARK: - Preview Provider
#Preview {
    SavedViewController()
}


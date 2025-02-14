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
    
    func fetchNotes(userId:String , completion: @escaping ([SavedFireNote]) -> Void) {
        db.collection("pdfs").whereField("userId", isEqualTo: userId)
            .getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching notes: \(error)")
                completion([])
                return
            }
            
            var notes: [SavedFireNote] = []
            let group = DispatchGroup()
            
            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                let pdfUrl = data["downloadURL"] as? String ?? ""
                
                // Get metadata and cover image
                self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                    let fileSize = self.formatFileSize(metadata?.size ?? 0)
                    
                    self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                        let note = SavedFireNote(
                            id: document.documentID,
                            title: data["fileName"] as? String ?? "Untitled",
                            description: data["category"] as? String ?? "",
                            author: data["collegeName"] as? String ?? "Unknown Author",
                            coverImage: image,
                            pdfUrl: pdfUrl,
                            dateAdded: (metadata?.timeCreated ?? Date()),
                            pageCount: pageCount,
                            fileSize: fileSize,
                            userID: data["userId"] as? String ?? "",
                            isFavorite: data["isFavorite"] as? Bool ?? false
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
        guard let storageRef = getStorageReference(from: urlString) else {
            completion(nil, 0)
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let localURL = tempDir.appendingPathComponent(UUID().uuidString + ".pdf")
        
        storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Error downloading PDF for cover: \(error)")
                completion(nil, 0)
                return
            }
            
            guard let pdfDocument = PDFDocument(url: localURL) else {
                completion(nil, 0)
                return
            }
            
            let pageCount = pdfDocument.pageCount
            
            guard let pdfPage = pdfDocument.page(at: 0) else {
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
            
            try? FileManager.default.removeItem(at: localURL)
            
            completion(image, pageCount)
        }
    }
    
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let storageRef = getStorageReference(from: urlString) else {
            let error = NSError(domain: "PDFDownloadError",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Invalid storage reference URL"])
            completion(.failure(error))
            return
        }
        
        let fileName = UUID().uuidString + ".pdf"
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsPath.appendingPathComponent(fileName)
        
        // Ensure file doesn't already exist before download
        if FileManager.default.fileExists(atPath: localURL.path) {
            do {
                try FileManager.default.removeItem(at: localURL)
            } catch {
                completion(.failure(error))
                return
            }
        }
        
        let downloadTask = storageRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let url = url else {
                let error = NSError(domain: "PDFDownloadError",
                                    code: -2,
                                    userInfo: [NSLocalizedDescriptionKey: "Downloaded file URL is nil"])
                completion(.failure(error))
                return
            }
            
            // Verify that the file is a valid PDF
            if let pdfDocument = PDFDocument(url: url) {
                print("PDF document loaded successfully with \(pdfDocument.pageCount) pages")
                completion(.success(url))
            } else {
                let error = NSError(domain: "PDFDownloadError",
                                    code: -3,
                                    userInfo: [NSLocalizedDescriptionKey: "Downloaded file is not a valid PDF"])
                completion(.failure(error))
            }
        }
        
        downloadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress?.completedUnitCount ?? 0) /
            Double(snapshot.progress?.totalUnitCount ?? 1)
            print("Download is \(percentComplete)% complete")
        }
    }
//    fav
    func fetchFavoriteNotes(userId: String, completion: @escaping ([SavedFireNote]) -> Void) {
        db.collection("pdfs")
            .whereField("userId", isEqualTo: userId)  // Ensure correct filtering
            .whereField("isFavorite", isEqualTo: true)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("❌ Error fetching favorite notes: \(error)")
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("⚠️ No favorite notes found for userId: \(userId)")
                    completion([])
                    return
                }

                print("✅ Found \(documents.count) favorite notes.")

                var notes: [SavedFireNote] = []
                let group = DispatchGroup()

                for document in documents {
                    group.enter()
                    let data = document.data()
                    print("📄 Processing favorite note: \(data)") // Debug print

                    let pdfUrl = data["downloadURL"] as? String ?? ""
                    self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                        let fileSize = self.formatFileSize(metadata?.size ?? 0)

                        self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                            let note = SavedFireNote(
                                id: document.documentID,
                                title: data["fileName"] as? String ?? "Untitled",
                                description: data["category"] as? String ?? "",
                                author: data["collegeName"] as? String ?? "Unknown Author",
                                coverImage: image,
                                pdfUrl: pdfUrl,
                                dateAdded: (metadata?.timeCreated ?? Date()),
                                pageCount: pageCount,
                                fileSize: fileSize,
                                userID: data["userId"] as? String ?? "",
                                isFavorite: data["isFavorite"] as? Bool ?? false
                            )
                            notes.append(note)
                            group.leave()
                        }
                    }
                }

                group.notify(queue: .main) {
                    print("✅ Successfully loaded \(notes.count) favorite notes.")
                    completion(notes.sorted { $0.dateAdded > $1.dateAdded })
                }
            }
    }


    func updateFavoriteStatus(for noteId: String, isFavorite: Bool, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"]))
            return
        }

        let noteRef = db.collection("pdfs").document(noteId)
        noteRef.updateData(["isFavorite": isFavorite, "userId": userId]) { error in
            if error == nil {
                // Post notification when favorite status is updated
                NotificationCenter.default.post(name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
            }
            completion(error)
        }
    }
}

import UIKit
import PDFKit

class NoteCollectionViewCell1: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4
        view.layer.shadowOpacity = 0.1
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
    private var noteId: String = ""

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
    
    private var isFavorite: Bool = false {
        didSet {
            updateFavoriteButtonImage()
        }
    }
    
    var favoriteButtonTapped: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(containerView)
        
        [coverImageView, titleLabel, authorLabel, detailsStackView, favoriteButton].forEach {
            containerView.addSubview($0)
        }
        
        [pagesLabel, fileSizeLabel].forEach {
            detailsStackView.addArrangedSubview($0)
        }
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.6),
            
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            detailsStackView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            detailsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            detailsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            favoriteButton.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            favoriteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            favoriteButton.widthAnchor.constraint(equalToConstant: 32),
            favoriteButton.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        favoriteButton.addTarget(self, action: #selector(favoriteButtonPressed), for: .touchUpInside)
    }
    
    private func updateFavoriteButtonImage() {
        let imageName = isFavorite ? "heart.fill" : "heart"
        let image = UIImage(systemName: imageName)
        favoriteButton.setImage(image, for: .normal)
        favoriteButton.tintColor = isFavorite ? .systemRed : .systemGray
    }
    
    @objc private func favoriteButtonPressed() {
        isFavorite.toggle()
        updateFavoriteButtonImage()
        
        guard !noteId.isEmpty else { return }
        
        FirebaseService1.shared.updateFavoriteStatus(for: noteId, isFavorite: isFavorite) { error in
            if let error = error {
                print("Error updating favorite status: \(error.localizedDescription)")
            } else {
                print("Favorite status updated successfully")
                NotificationCenter.default.post(name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
            }
        }
    }
    func configure(with note: SavedFireNote) {
        noteId = note.id
        titleLabel.text = note.title
        authorLabel.text = "By \(note.author)"
        pagesLabel.text = "\(note.pageCount) pages"
        fileSizeLabel.text = note.fileSize
        coverImageView.image = note.coverImage ?? UIImage(systemName: "doc.fill")
        isFavorite = note.isFavorite
        
        // Add fade animation
        coverImageView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            self.coverImageView.alpha = 1
        }
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


class SavedViewController: UIViewController {
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
            self?.favoriteNotes = notes
            self?.favoriteNotesCollectionView.reloadData()
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
        label.backgroundColor = .systemBackground
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
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
        configureNavigationBar()
        fetchCuratedNotes()
        fetchFavoriteNotes()
        
//        keyboard dismiss
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
           view.addGestureRecognizer(tapGesture)
        
        // Add observer for favorite status changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChange), name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
    }
    @objc private func handleFavoriteStatusChange() {
        // Refresh the notes when favorite status changes
        fetchCuratedNotes()
        fetchFavoriteNotes()
    }

//    deinit {
//        // Remove observer when the view controller is deallocated
//        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
//    }

    
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

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        curatedNotesCollectionView.addSubview(activityIndicator)
        
        // Add all UI components to the contentView
        [titleLabel, addNoteButton, scanButton, searchBar,
         curatedNotesLabel, curatedNotesCollectionView,
         favoriteNotesLabel, favoriteNotesCollectionView].forEach {
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            // ScrollView constraints
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // ContentView constraints
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title Label
            titleLabel.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Add Note Button
            addNoteButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addNoteButton.trailingAnchor.constraint(equalTo: scanButton.leadingAnchor, constant: -16),
            
            // More Options Button
            scanButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            scanButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            
            // Favorites Section Label
            favoriteNotesLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 24),
            favoriteNotesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Favorites Collection View
            favoriteNotesCollectionView.topAnchor.constraint(equalTo: favoriteNotesLabel.bottomAnchor, constant: 16),
            favoriteNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            favoriteNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            favoriteNotesCollectionView.heightAnchor.constraint(equalToConstant: 280),
            
            // Saved Notes Section Label
            curatedNotesLabel.topAnchor.constraint(equalTo: favoriteNotesCollectionView.bottomAnchor, constant: 24),
            curatedNotesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            // Saved Notes Collection View
            curatedNotesCollectionView.topAnchor.constraint(equalTo: curatedNotesLabel.bottomAnchor, constant: 16),
            curatedNotesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            curatedNotesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            curatedNotesCollectionView.heightAnchor.constraint(equalToConstant: 280),
            curatedNotesCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            
            // Activity Indicator in the Collection View
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
        
        isLoading = true
        activityIndicator.startAnimating()
        
        FirebaseService1.shared.fetchNotes(userId: userID) { [weak self] notes in
            self?.curatedNotes = notes
            self?.curatedNotesCollectionView.reloadData()
            self?.activityIndicator.stopAnimating()
            self?.isLoading = false
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
        let selectedNote: SavedFireNote
        if collectionView == curatedNotesCollectionView {
            selectedNote = curatedNotes[indexPath.item]
        } else {
            selectedNote = favoriteNotes[indexPath.item]
        }

        let loadingAlert = UIAlertController(title: nil, message: "Loading PDF...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        
        present(loadingAlert, animated: true)
        
        FirebaseService1.shared.downloadPDF(from: selectedNote.pdfUrl) { [weak self] result in
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    switch result {
                    case .success(let url):
                        let pdfViewController = PDFViewerViewController(pdfURL: url, title: selectedNote.title)
                        let navController = UINavigationController(rootViewController: pdfViewController)
                        navController.modalPresentationStyle = .fullScreen
                        self?.present(navController, animated: true)
                    case .failure(let error):
                        let errorAlert = UIAlertController(
                            title: "Error",
                            message: "Could not load PDF: \(error.localizedDescription)",
                            preferredStyle: .alert
                        )
                        errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                        self?.present(errorAlert, animated: true)
                    }
                }
            }
        }
    }
}

// MARK: - Preview Provider
#Preview {
    SavedViewController()
}


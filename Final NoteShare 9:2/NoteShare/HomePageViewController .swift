
import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
import PDFKit

struct FireNote {
    let id: String
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let pdfUrl: String
    let dateAdded: Date
    let pageCount: Int
    let fileSize: String
    var isFavorite: Bool
    let category:String
    let subjectCode: String
    let subjectName: String
    
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
            "category":category,
            "subjectCode":subjectCode,
            "subjectName":subjectName
        ]
    }
}

class FirebaseService {
    static let shared = FirebaseService()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    
    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }
    
    
    
    func fetchNotes(completion: @escaping ([FireNote], [String: [String: [FireNote]]]) -> Void) {
        db.collection("pdfs").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching notes: \(error)")
                completion([], [:])
                return
            }

            var notes: [FireNote] = []
            var groupedNotes: [String: [String: [FireNote]]] = [:] // CollegeName -> SubjectCode -> Notes

            let group = DispatchGroup()

            snapshot?.documents.forEach { document in
                group.enter()
                let data = document.data()
                let pdfUrl = data["downloadURL"] as? String ?? ""
                let collegeName = data["collegeName"] as? String ?? "Unknown College"
                let subjectCode = data["subjectCode"] as? String ?? "Unknown Subject"

                self.getStorageReference(from: pdfUrl)?.getMetadata { metadata, error in
                    let fileSize = self.formatFileSize(metadata?.size ?? 0)

                    self.fetchPDFCoverImage(from: pdfUrl) { (image, pageCount) in
                        let note = FireNote(
                            id: document.documentID,
                            title: data["fileName"] as? String ?? "Untitled",
                            description: data["category"] as? String ?? "",
                            author: collegeName,
                            coverImage: image,
                            pdfUrl: pdfUrl,
                            dateAdded: (metadata?.timeCreated ?? Date()),
                            pageCount: pageCount,
                            fileSize: fileSize,
                            isFavorite: data["isFavorite"] as? Bool ?? false,
                            category: data["category"] as? String ?? "",
                            subjectCode: subjectCode,
                            subjectName: data["subjectName"] as? String ?? ""
                        )

                        if groupedNotes[collegeName] == nil {
                            groupedNotes[collegeName] = [:]
                        }
                        if groupedNotes[collegeName]?[subjectCode] != nil {
                            groupedNotes[collegeName]?[subjectCode]?.append(note)
                        } else {
                            groupedNotes[collegeName]?[subjectCode] = [note]
                        }

                        notes.append(note)
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                completion(notes.sorted { $0.dateAdded > $1.dateAdded }, groupedNotes)
            }
        }
    }

    
    
    
    
    
    
    func fetchUserData(completion: @escaping ([String], String) -> Void) {
        guard let userId = currentUserId else {
            completion([], "")
            return
        }
        
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { document, error in
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
            
            completion(interests, college)
        }
    }
    
    func fetchRecommendedNotes(completion: @escaping ([FireNote]) -> Void) {
        fetchUserData { [weak self] interests, college in
            guard let self = self else { return }
            
            self.fetchNotes { allNotes,arg  in
                var recommendedNotes = [FireNote]()
                let lowercasedCollege = college.lowercased()
                
                var interestMatches = [FireNote]()
                var collegeMatches = [FireNote]()
                
                if !interests.isEmpty {
                    interestMatches = allNotes.filter { note in
                        interests.contains { interest in
                            let lowerInterest = interest.lowercased()
                            return note.category.lowercased().contains(lowerInterest)
                                   
                        }
                    }
                }
                
                if !lowercasedCollege.isEmpty {
                    collegeMatches = allNotes.filter { note in
                        !interestMatches.contains(where: { $0.id == note.id }) &&
                        note.author.lowercased() == lowercasedCollege
                    }
                }
                
                interestMatches.sort { $0.dateAdded > $1.dateAdded }
                collegeMatches.sort { $0.dateAdded > $1.dateAdded }
                
                recommendedNotes = interestMatches  //+ collegeMatches
                
                if recommendedNotes.isEmpty {
                    print("recommendations empty")
                    recommendedNotes = Array(allNotes.prefix(5))
                } else {
                    recommendedNotes = Array(recommendedNotes.prefix(5))
                }
                
                print("Recommended notes breakdown:")
                print("Interest matches: \(interestMatches.count)")
                print("College matches: \(collegeMatches.count)")
                
                completion(recommendedNotes)
            }
        }
    }
    
    
    // Download PDF from Firebase Storage
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
                completion(.failure(error))
                return
            }
            
            guard let url = url else {
                let error = NSError(domain: "PDFDownloadError",
                                  code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to get local URL"])
                completion(.failure(error))
                return
            }
            
            completion(.success(url))
        }
        
        downloadTask.observe(.progress) { snapshot in
            let percentComplete = 100.0 * Double(snapshot.progress?.completedUnitCount ?? 0) /
                Double(snapshot.progress?.totalUnitCount ?? 1)
            print("Download is \(percentComplete)% complete")
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
}

class NoteCollectionViewCell: UICollectionViewCell {
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
    private var isFavorite: Bool = false {
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
        
        [coverImageView, titleLabel, authorLabel, detailsStackView, favoriteButton, recommendedTag].forEach {
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
            
            detailsStackView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant:-1),
            detailsStackView.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 8),
            detailsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            detailsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            
            favoriteButton.topAnchor.constraint(equalTo: detailsStackView.bottomAnchor, constant: 8),
            favoriteButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            favoriteButton.widthAnchor.constraint(equalToConstant: 24),
            favoriteButton.heightAnchor.constraint(equalToConstant: 24),
            
            recommendedTag.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            recommendedTag.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            recommendedTag.heightAnchor.constraint(equalToConstant: 20),
            recommendedTag.widthAnchor.constraint(equalToConstant: 100)
        ])
    }
    
    // Update UI for favorite button
    private func updateFavoriteButtonImage() {
        let image = isFavorite ? UIImage(systemName: "heart.fill") : UIImage(systemName: "heart")
        favoriteButton.setImage(image, for: .normal)
    }
    
    // Favorite button pressed
    @objc private func favoriteButtonPressed() {
        isFavorite.toggle()
        favoriteButtonTapped?()
    }
    
    // Configure cell with FireNote data
    func configure(with note: FireNote) {
        titleLabel.text = note.title
        authorLabel.text = note.author
        pagesLabel.text = "Pages: \(note.pageCount)"
        fileSizeLabel.text = note.fileSize
        
        coverImageView.image = note.coverImage
        isFavorite = note.isFavorite
        
        // Set recommended tag visibility based on certain conditions
        recommendedTag.isHidden = false // or implement logic for showing the tag
        
        // Hide the tag if it doesn't meet certain conditions
//         recommendedTag.isHidden = true
        
    }
}



struct College {
    let name: String
    let logo: UIImage?
}

class CollegeCell: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray5.cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
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
            nameLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -8)
        ])
    }
    
    func configure(with college: College) {
        logoImageView.image = college.logo
        nameLabel.text = college.name
    }
}

class HomeViewController: UIViewController {
    // MARK: - Properties
    private var notes: [FireNote] = []
    private var isShowingCollegeNotes = false
    private var isLoading = false
    private let collegeReuseIdentifier = "CollegeCell"
    private let noteReuseIdentifier = "NoteCell"
    private var recommendedNotes: [FireNote] = []
    
    private let colleges: [College] = [
        College(name: "SRM", logo: UIImage(named: "srmist_logo")),
        College(name: "VIT", logo: UIImage(named: "vit_logo")),
        College(name: "KIIT", logo: UIImage(named: "kiit_logo")),
        College(name: "Manipal", logo: UIImage(named: "manipal_logo")),
        College(name: "LPU", logo: UIImage(named: "lpu_logo")),
        College(name: "Amity", logo: UIImage(named: "amity_logo"))
    ]
    
    // MARK: - UI Components
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
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
        label.text = "Curated Notes for You"
        label.font = .systemFont(ofSize: 22, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var notesCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 200, height: 280)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
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
        collectionView.register(CollegeCell.self, forCellWithReuseIdentifier: collegeReuseIdentifier)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
        fetchNotes()
        
    }

    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(headerView)
        headerView.addSubview(headerLabel)
        headerView.addSubview(profileButton)
        notesCollectionView.addSubview(activityIndicator)
        
        [notesLabel, notesCollectionView, collegesLabel, collegesCollectionView].forEach {
            contentView.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            headerLabel.topAnchor.constraint(equalTo: headerView.topAnchor),
            headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            headerLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            
            profileButton.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            profileButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            profileButton.heightAnchor.constraint(equalToConstant: 40),
            profileButton.widthAnchor.constraint(equalToConstant: 40),
            
            notesLabel.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            notesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            notesCollectionView.topAnchor.constraint(equalTo: notesLabel.bottomAnchor, constant: 16),
            notesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            notesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            notesCollectionView.heightAnchor.constraint(equalToConstant: 280),
            
            collegesLabel.topAnchor.constraint(equalTo: notesCollectionView.bottomAnchor, constant: 24),
            collegesLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            collegesLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            collegesCollectionView.topAnchor.constraint(equalTo: collegesLabel.bottomAnchor, constant: 16),
            collegesCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collegesCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collegesCollectionView.heightAnchor.constraint(equalToConstant: 312),
            collegesCollectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            
            activityIndicator.centerXAnchor.constraint(equalTo: notesCollectionView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: notesCollectionView.centerYAnchor)
        ])
    }
    
    private func setupDelegates() {
        notesCollectionView.dataSource = self
        notesCollectionView.delegate = self
        collegesCollectionView.dataSource = self
        collegesCollectionView.delegate = self
    }
    
    private func fetchNotes() {
        isLoading = true
        activityIndicator.startAnimating()
        
        // Fetch all notes first
        FirebaseService.shared.fetchNotes { [weak self] fetchedNotes,arg in
            guard let self = self else { return }
            self.notes = fetchedNotes
            
            // Now fetch recommended notes
            FirebaseService.shared.fetchRecommendedNotes { recommendedNotes in
                self.recommendedNotes = recommendedNotes
                self.notesCollectionView.reloadData()
                self.activityIndicator.stopAnimating()
                self.isLoading = false
            }
        }
    }
    
    @objc private func profileButtonTapped() {
        let profileVC = ProfileViewController()
        navigationController?.setNavigationBarHidden(true, animated: false)
        navigationController?.pushViewController(profileVC, animated: true)
    }
}





extension HomeViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == notesCollectionView {
            return recommendedNotes.count // Use recommendedNotes instead of notes
        } else {
            return colleges.count
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == notesCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: noteReuseIdentifier, for: indexPath) as! NoteCollectionViewCell
            cell.configure(with: recommendedNotes[indexPath.item]) // Use recommendedNotes
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: collegeReuseIdentifier, for: indexPath) as! CollegeCell
            cell.configure(with: colleges[indexPath.item])
            return cell
        }
    }
}



extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == collegesCollectionView {
            let selectedCollege = colleges[indexPath.item]
            activityIndicator.startAnimating()

            FirebaseService.shared.fetchNotes { notesList, groupedNotes in
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    if let collegeNotes = groupedNotes[selectedCollege.name] {
                        let notesVC = NotesViewController()
                        notesVC.configure(with: collegeNotes)
                        self.navigationController?.pushViewController(notesVC, animated: true)
                    } else {
                        let alert = UIAlertController(title: "No Notes", message: "No notes available for \(selectedCollege.name).", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } else if collectionView == notesCollectionView {
            let selectedNote = recommendedNotes[indexPath.item]

            let loadingAlert = UIAlertController(title: nil, message: "Loading PDF...", preferredStyle: .alert)
            let loadingIndicator = UIActivityIndicatorView(style: .medium)
            loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
            loadingIndicator.startAnimating()
            loadingAlert.view.addSubview(loadingIndicator)
            
            present(loadingAlert, animated: true)

            FirebaseService.shared.downloadPDF(from: selectedNote.pdfUrl) { [weak self] result in
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
}

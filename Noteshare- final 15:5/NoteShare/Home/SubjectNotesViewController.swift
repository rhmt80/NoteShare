import UIKit
import FirebaseStorage
import FirebaseFirestore

// MARK: - SubjectNotesViewController
class SubjectNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {

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
            "lastOpened": $0.lastOpened.timeIntervalSince1970
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
    
    // MARK: - Properties
    private let subjectCode: String
    private var notes: [FireNote]
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 150, height: 225)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private var placeholderView: PlaceholderView1?
    
    init(subjectCode: String, notes: [FireNote]) {
        self.subjectCode = subjectCode
        self.notes = notes
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = subjectCode
        view.backgroundColor = .systemBackground
        setupUI()
        setupCollectionView()
        setupPlaceholder()
        updatePlaceholderVisibility()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChange(_:)), name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviouslyReadNotesUpdated), name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
        handleFavoriteStatusInitialSync()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        markSubjectAsVisited()
    }
    
    private func markSubjectAsVisited() {
        guard let userId = FirebaseService.shared.currentUserId else { return }
        var visitedSubjects: Set<String> = []
        if let visitedArray = UserDefaults.standard.array(forKey: "visitedSubjects_\(userId)") as? [String] {
            visitedSubjects = Set(visitedArray)
        }
        visitedSubjects.insert(subjectCode)
        UserDefaults.standard.set(Array(visitedSubjects), forKey: "visitedSubjects_\(userId)")
    }
    
    @objc private func handlePreviouslyReadNotesUpdated() {}
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 265)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupPlaceholder() {
        placeholderView = PlaceholderView1(
            image: UIImage(systemName: "doc.text"),
            title: "No Notes for \(subjectCode)",
            message: "There are no notes available for this subject yet.",
            buttonTitle: nil,
            action: nil
        )
        placeholderView?.backgroundColor = .systemBackground
        placeholderView?.alpha = 1.0
        collectionView.backgroundView = placeholderView
        
        placeholderView?.layer.borderWidth = 0
        placeholderView?.layer.borderColor = UIColor.systemGray5.cgColor
        placeholderView?.layer.cornerRadius = 16
        placeholderView?.clipsToBounds = true
    }
    
    private func updatePlaceholderVisibility() {
        DispatchQueue.main.async {
            if self.notes.isEmpty {
                self.placeholderView?.alpha = 1.0
                self.placeholderView?.isHidden = false
            } else {
                UIView.animate(withDuration: 0.3) {
                    self.placeholderView?.alpha = 0.0
                } completion: { _ in
                    self.placeholderView?.isHidden = true
                }
            }
        }
    }
    
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath) as! NoteCollectionViewCell1
        let note = notes[indexPath.row]
        
        // Map FireNote to SavedFireNote for cell configuration
        let savedFireNote = SavedFireNote(
            id: note.id,
            title: note.title,
            author: note.author,
            pdfUrl: note.pdfUrl, // Move 'pdfUrl' before 'subjectName'
            isFavorite: note.isFavorite,
            pageCount: note.pageCount,
            subjectName: note.subjectName,
            subjectCode: note.subjectCode,
            fileSize: note.fileSize,
            userId: ""
        )
        cell.configure(with: savedFireNote)
        
        // Handle favorite button tap
        cell.favoriteButtonTapped = { [weak self] in
            guard let self = self else { return }
            let newFavoriteStatus = !note.isFavorite
            self.notes[indexPath.row].isFavorite = newFavoriteStatus
            cell.isFavorite = newFavoriteStatus
            
            FirebaseService.shared.updateFavoriteStatus(for: note.id, isFavorite: newFavoriteStatus) { error in
                if let error = error {
                    print("Error updating favorite status: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.notes[indexPath.row].isFavorite = !newFavoriteStatus
                        cell.isFavorite = !newFavoriteStatus
                        collectionView.reloadItems(at: [indexPath])
                    }
                }
            }
        }
        
        // Fetch and update cover image (if needed)
        DispatchQueue.global(qos: .userInitiated).async {
            FirebaseService.shared.fetchPDFCoverImage(from: note.pdfUrl) { [weak self] (image, pageCount) in
                guard let self = self else { return }
                if let image = image {
                    let cacheKey = "cover_\(note.id)"
                    CacheManager.shared.cacheImage(image, for: cacheKey)
                    
                    var updatedNote = note
                    var needsUpdate = false
                    
                    if updatedNote.pageCount == 0 && pageCount > 0 {
                        updatedNote.pageCount = pageCount
                        needsUpdate = true
                    }
                    
                    if needsUpdate && indexPath.row < self.notes.count {
                        self.notes[indexPath.row] = updatedNote
                    }
                }
            }
            
            if let storageRef = FirebaseService.shared.getStorageReference(from: note.pdfUrl) {
                storageRef.getMetadata { [weak self] metadata, error in
                    guard let self = self, indexPath.row < self.notes.count else { return }
                    if let metadata = metadata {
                        let fileSize = FirebaseService.shared.formatFileSize(metadata.size)
                        if !fileSize.isEmpty && (note.fileSize == "0 KB" || note.fileSize.isEmpty) {
                            self.notes[indexPath.row].fileSize = fileSize
                        }
                    }
                }
            }
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        
        showLoadingView {
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: note.id) {
                self.hideLoadingView {
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                    
                    let previouslyReadNote = PreviouslyReadNote(
                        id: note.id,
                        title: note.title,
                        pdfUrl: note.pdfUrl,
                        lastOpened: Date()
                    )
                    self.savePreviouslyReadNote(previouslyReadNote)
                }
                return
            }
            
            self.downloadAndPresentPDF(note: note)
        }
    }
    
    private func downloadAndPresentPDF(note: FireNote) {
        FirebaseService.shared.downloadPDF(from: note.pdfUrl) { [weak self] result in
            guard let self = self else { return }
            self.hideLoadingView {
                switch result {
                case .success(let url):
                    PDFCache.shared.cachePDFPath(for: note.id, fileURL: url)
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                    
                    let previouslyReadNote = PreviouslyReadNote(
                        id: note.id,
                        title: note.title,
                        pdfUrl: note.pdfUrl,
                        lastOpened: Date()
                    )
                    self.savePreviouslyReadNote(previouslyReadNote)
                    
                case .failure(let error):
                    self.showAlert(title: "Error", message: "Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func showLoadingView(completion: @escaping () -> Void) {
        let loadingController = UIAlertController(title: nil, message: "Loading PDF...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingController.view.addSubview(loadingIndicator)
        present(loadingController, animated: true, completion: completion)
    }
    
    private func hideLoadingView(completion: @escaping () -> Void) {
        if let loadingController = presentedViewController as? UIAlertController,
           loadingController.message == "Loading PDF..." {
            loadingController.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
    @objc private func closePDF() {
        dismiss(animated: true)
    }
    
    @objc private func handleFavoriteStatusChange(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let noteId = userInfo["noteId"] as? String,
           let isFavorite = userInfo["isFavorite"] as? Bool {
            for i in 0..<notes.count {
                if notes[i].id == noteId {
                    notes[i].isFavorite = isFavorite
                    DispatchQueue.main.async {
                        let indexPath = IndexPath(item: i, section: 0)
                        self.collectionView.reloadItems(at: [indexPath])
                    }
                    return
                }
            }
        }
        
        FirebaseService.shared.fetchNotes { [weak self] allNotes, _ in
            guard let self = self else { return }
            self.notes = allNotes.filter { $0.subjectCode == self.subjectCode }
            DispatchQueue.main.async {
                self.collectionView.reloadData()
                self.updatePlaceholderVisibility()
            }
        }
    }
    
    @objc private func handleFavoriteStatusInitialSync() {
        FirebaseService.shared.fetchUserFavorites { [weak self] favoriteIds in
            guard let self = self else { return }
            var shouldReload = false
            for i in 0..<self.notes.count {
                let shouldBeFavorite = favoriteIds.contains(self.notes[i].id)
                if self.notes[i].isFavorite != shouldBeFavorite {
                    self.notes[i].isFavorite = shouldBeFavorite
                    shouldReload = true
                }
            }
            if shouldReload {
                DispatchQueue.main.async {
                    self.collectionView.reloadData()
                    self.updatePlaceholderVisibility()
                }
            }
        }
    }
}

// Placeholder stub
class PlaceholderView1: UIView {
    init(image: UIImage?, title: String, message: String, buttonTitle: String?, action: (() -> Void)?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

//new changed
import UIKit

class SubjectNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    // MARK: - Previously Read Notes Storage
    struct PreviouslyReadNote {
        let id: String
        let title: String
        let pdfUrl: String
        let lastOpened: Date
    }

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
    
    private let subjectCode: String
    private var notes: [FireNote] // Changed to var to allow updates
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        let sideInset: CGFloat = 14
        layout.sectionInset = UIEdgeInsets(top: 14, left: sideInset, bottom: 20, right: sideInset)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(NoteCollectionViewCell.self, forCellWithReuseIdentifier: "NoteCollectionViewCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        return collectionView
    }()
    
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
        setupCollectionView()
        
        // Add observer for favorite status changes
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChange(_:)), name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviouslyReadNotesUpdated), name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
        
        // Initial sync with current favorite status
        handleFavoriteStatusInitialSync()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure navigation bar is visible
        navigationController?.setNavigationBarHidden(false, animated: animated)
        
        // Mark this subject as visited (for UI updates when returning)
        markSubjectAsVisited()
    }
    
    private func markSubjectAsVisited() {
        guard let userId = FirebaseService.shared.currentUserId else { return }
        // Load current visited subjects
        var visitedSubjects: Set<String> = []
        if let visitedArray = UserDefaults.standard.array(forKey: "visitedSubjects_\(userId)") as? [String] {
            visitedSubjects = Set(visitedArray)
        }
        
        // Add current subject and save
        visitedSubjects.insert(subjectCode)
        UserDefaults.standard.set(Array(visitedSubjects), forKey: "visitedSubjects_\(userId)")
    }
    
    @objc private func handlePreviouslyReadNotesUpdated() {
        // No direct UI update needed unless SubjectNotes displays previously read notes
    }

    deinit {
        // Remove observer when the view controller is deallocated
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)

    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Ensure layout is properly configured
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            // Set the itemSize explicitly here to ensure consistent sizing
            flowLayout.itemSize = calculateItemSize()
        }
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // Extract item size calculation to a separate method for reuse
    private func calculateItemSize() -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let sideInset: CGFloat = 14
        let minimumSpacing: CGFloat = 12
        
        // Calculate width for exactly 2 items per row with equal spacing
        let availableWidth = screenWidth - (sideInset * 2) - minimumSpacing
        let cellWidth = floor(availableWidth / 2)
        let cellHeight = cellWidth * 1.3
        
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath) as! NoteCollectionViewCell
        let note = notes[indexPath.row]
        
        // Apply initial configuration with whatever data we have
        cell.configureWithCaching(with: note)
        cell.isFavorite = note.isFavorite
        
        // Always request the cover image to ensure it's updated
        DispatchQueue.global(qos: .userInitiated).async {
            FirebaseService.shared.fetchPDFCoverImage(from: note.pdfUrl) { [weak self] (image, pageCount) in
                guard let self = self else { return }
                
                // If we got an image, cache it explicitly
                if let image = image {
                    // Cache in CacheManager
                    let cacheKey = "cover_\(note.id)"
                    CacheManager.shared.cacheImage(image, for: cacheKey)
                    
                    // Update the note with correct metadata
                    var updatedNote = note
                    var needsUpdate = false
                    
                    if updatedNote.pageCount == 0 && pageCount > 0 {
                        updatedNote.pageCount = pageCount
                        needsUpdate = true
                    }
                    
                    if needsUpdate && indexPath.row < self.notes.count {
                        // Update the local notes array
                        self.notes[indexPath.row] = updatedNote
                    }
                    
                    // Update the cell on the main thread
                    DispatchQueue.main.async {
                        if collectionView.indexPath(for: cell) == indexPath {
                            // Cell is still visible and representing the same note
                            cell.coverImageView.contentMode = .scaleAspectFill
                            cell.coverImageView.backgroundColor = .white
                            cell.coverImageView.image = image
                            
                            if needsUpdate {
                                cell.pagesLabel.text = "\(pageCount) Pages"
                            }
                        }
                    }
                }
            }
            
            // Also check metadata
            if let storageRef = FirebaseService.shared.getStorageReference(from: note.pdfUrl) {
                storageRef.getMetadata { [weak self] metadata, error in
                    guard let self = self, indexPath.row < self.notes.count else { return }
                    
                    if let error = error {
                        print("Metadata error for \(note.pdfUrl): \(error)")
                        return
                    }
                    
                    // Get file size
                    let fileSize = FirebaseService.shared.formatFileSize(metadata?.size ?? 0)
                    
                    if !fileSize.isEmpty && fileSize != "0 KB" &&
                       (note.fileSize == "0 KB" || note.fileSize.isEmpty) {
                        // Update the note
                        var updatedNote = self.notes[indexPath.row]
                        updatedNote.fileSize = fileSize
                        self.notes[indexPath.row] = updatedNote
                    }
                }
            }
        }
        
        // Setup favorite button handler
        cell.favoriteButtonTapped = { [weak self] in
            guard let self = self else { return }
            
            let newFavoriteStatus = !note.isFavorite
            
            // Update local data first
            self.notes[indexPath.row].isFavorite = newFavoriteStatus
            cell.isFavorite = newFavoriteStatus
            
            // Update Firestore
            FirebaseService.shared.updateFavoriteStatus(for: note.id, isFavorite: newFavoriteStatus) { error in
                if let error = error {
                    print("Error updating favorite status: \(error.localizedDescription)")
                    // Revert on failure
                    DispatchQueue.main.async {
                        self.notes[indexPath.row].isFavorite = !newFavoriteStatus
                        cell.isFavorite = !newFavoriteStatus
                        collectionView.reloadItems(at: [indexPath])
                    }
                }
            }
        }
        
        return cell
    }
    
    // MARK: - UICollectionViewDelegate
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        
        // Show loading view
        self.showLoadingView {
            // Check if we already have this PDF in cache
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: note.id) {
                self.hideLoadingView {
                    // Open the PDF viewer with the cached path
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                    
                    // Update previously read notes
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
            
            // Also check URL-based cache
            if let url = URL(string: note.pdfUrl), let cachedData = CacheManager.shared.getCachedPDF(url: url) {
                self.hideLoadingView {
                    // Write cached data to temporary file
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(note.id).pdf")
                    do {
                        try cachedData.write(to: tempURL)
                        
                        // Cache for document ID for future use
                        PDFCache.shared.cachePDFPath(for: note.id, fileURL: tempURL)
                        
                        // Open the PDF viewer
                        let pdfVC = PDFViewerViewController(documentId: note.id)
                        let navController = UINavigationController(rootViewController: pdfVC)
                        pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                            barButtonSystemItem: .close,
                            target: self,
                            action: #selector(self.closePDF)
                        )
                        navController.modalPresentationStyle = .fullScreen
                        self.present(navController, animated: true)
                        
                        // Update previously read notes
                        let previouslyReadNote = PreviouslyReadNote(
                            id: note.id,
                            title: note.title,
                            pdfUrl: note.pdfUrl,
                            lastOpened: Date()
                        )
                        self.savePreviouslyReadNote(previouslyReadNote)
                    } catch {
                        // If writing fails, download normally
                        self.downloadAndPresentPDF(note: note)
                    }
                }
                return
            }
            
            // Not in cache, download and cache
            self.downloadAndPresentPDF(note: note)
        }
    }
    
    private func downloadAndPresentPDF(note: FireNote) {
        FirebaseService.shared.downloadPDF(from: note.pdfUrl) { [weak self] result in
            guard let self = self else { return }
            
            self.hideLoadingView {
                switch result {
                case .success(let url):
                    // Cache the downloaded PDF
                    PDFCache.shared.cachePDFPath(for: note.id, fileURL: url)
                    
                    // Also cache for URL-based access if possible
                    if let pdfUrl = URL(string: note.pdfUrl), let pdfData = try? Data(contentsOf: url) {
                        try? CacheManager.shared.cachePDF(url: pdfUrl, data: pdfData)
                    }
                    
                    // Present the PDF viewer
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                    
                    // Update previously read notes
                    let previouslyReadNote = PreviouslyReadNote(
                        id: note.id,
                        title: note.title,
                        pdfUrl: note.pdfUrl,
                        lastOpened: Date()
                    )
                    self.savePreviouslyReadNote(previouslyReadNote)
                    
                case .failure(let error):
                    self.showAlert(title: "Error", message: "Failed to download PDF: \(error.localizedDescription)")
                    print("Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLoadingView(completion: @escaping () -> Void) {
        // Create and configure loading view
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
        // Check if the notification has specific noteId and favorite status
        if let userInfo = notification.userInfo,
           let noteId = userInfo["noteId"] as? String,
           let isFavorite = userInfo["isFavorite"] as? Bool {
            // Just update the specific note rather than reloading everything
            for i in 0..<notes.count {
                if notes[i].id == noteId {
                    // Update favorite status
                    notes[i].isFavorite = isFavorite
                    
                    // Preserve metadata if provided
                    if let pageCount = userInfo["pageCount"] as? Int, notes[i].pageCount == 0 {
                        notes[i].pageCount = pageCount
                    }
                    if let fileSize = userInfo["fileSize"] as? String,
                       (notes[i].fileSize == "0 KB" || notes[i].fileSize.isEmpty) {
                        notes[i].fileSize = fileSize
                    }
                    
                    // Reload just this cell
                    DispatchQueue.main.async {
                        let indexPath = IndexPath(item: i, section: 0)
                        self.collectionView.reloadItems(at: [indexPath])
                    }
                    return
                }
            }
        }
        
        // If we didn't handle the specific case or there's no userInfo,
        // fall back to reloading all notes
        print("SubjectNotes: Received FavoriteStatusChanged notification")
        FirebaseService.shared.fetchNotes { [weak self] allNotes, _ in
            guard let self = self else { return }
            let filteredNotes = allNotes.filter { $0.subjectCode == self.subjectCode }
            print("SubjectNotes: Fetched \(filteredNotes.count) notes for subject \(self.subjectCode)")
            filteredNotes.forEach { note in
                print("Note \(note.id): isFavorite = \(note.isFavorite)")
            }
            
            // Ensure UI updates happen on the main thread
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.notes = filteredNotes
                self.collectionView.reloadData()
            }
        }
    }

    // Add a parameterless version for initial sync
    @objc private func handleFavoriteStatusInitialSync() {
        // Just fetch latest favorites status directly
        FirebaseService.shared.fetchUserFavorites { [weak self] favoriteIds in
            guard let self = self else { return }
            
            // Update the isFavorite state on notes
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
                }
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return calculateItemSize()
    }
}

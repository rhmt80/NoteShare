import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class FavoriteCollectionViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let subjectCode: String
    private var notes: [SavedFireNote]
    
    // Collection view setup similar to SavedViewController
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal // Match My Notes horizontal scrolling
        layout.itemSize = CGSize(width: 150, height: 225) // Match cell size from SavedViewController
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "FavoriteNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    // Placeholder view similar to SavedViewController
    private var placeholderView: PlaceholderView?
    
    init(subjectCode: String, notes: [SavedFireNote]) {
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
        setupNotifications()
    }
    
    private func setupUI() {
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 265) // Match height from SavedViewController
        ])
    }
    
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
    }
    
    private func setupPlaceholder() {
        placeholderView = PlaceholderView(
            image: UIImage(systemName: "doc.text"),
            title: "No Favorites for \(subjectCode)",
            message: "Favorite some notes for this subject to see them here.",
            buttonTitle: nil, // No button needed
            action: nil       // No action needed
        )
        placeholderView?.backgroundColor = .systemBackground
        placeholderView?.alpha = 1.0
        collectionView.backgroundView = placeholderView
        
        // Add border styling similar to SavedViewController
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
    
    // Setup notifications to refresh favorites
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFavoriteStatusChange),
            name: NSNotification.Name("FavoriteStatusChanged"),
            object: nil
        )
    }
    
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FavoriteNoteCell", for: indexPath) as! NoteCollectionViewCell1
        let note = notes[indexPath.row]
        cell.configure(with: note)
        
        // Handle favorite status changes (no edit/delete)
        cell.favoriteButtonTapped = { [weak self] in
            self?.updateFavoriteStatus(for: note)
        }
        
        // Disable long press gesture by not setting onLongPress
        cell.onLongPress = nil
        
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
                }
                return
            }
            
            self.downloadAndPresentPDF(note: note)
        }
    }
    
    // MARK: - Actions
    private func updateFavoriteStatus(for note: SavedFireNote) {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let newFavoriteStatus = !note.isFavorite
        
        FirebaseService1.shared.updateFavoriteStatus(for: note.id, isFavorite: newFavoriteStatus) { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Error", message: "Failed to update favorite status: \(error.localizedDescription)")
            } else {
                self?.fetchNotes()
            }
        }
    }
    
    private func fetchNotes() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        FirebaseService1.shared.fetchFavoriteNotes(userId: userId) { [weak self] favoriteNotes in
            guard let self = self else { return }
            // Filter favorites by subject code
            self.notes = favoriteNotes.filter { $0.subjectCode == self.subjectCode }
            self.collectionView.reloadData()
            self.updatePlaceholderVisibility()
        }
    }
    
    private func downloadAndPresentPDF(note: SavedFireNote) {
        guard let pdfUrl = note.pdfUrl, !pdfUrl.isEmpty else {
            self.hideLoadingView {
                self.showAlert(title: "Error", message: "PDF URL is missing")
            }
            return
        }
        
        FirebaseService1.shared.downloadPDF(from: pdfUrl) { [weak self] result in
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
                    
                case .failure(let error):
                    self.showAlert(title: "Error", message: "Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
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
    
    // Handle favorite status change to refresh the list
    @objc private func handleFavoriteStatusChange(_ notification: Notification) {
        fetchNotes()
    }
    
    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
    
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
    
    @objc private func closePDF() {
        dismiss(animated: true)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

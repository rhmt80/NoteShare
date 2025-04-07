import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class UploadedSubjectNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
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
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "UploadedNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    // Placeholder view similar to SavedViewController
    private var placeholderView: PlaceholderView?
    
    // Haptic feedback generator
    private let impactFeedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
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
            title: "No Notes for \(subjectCode)",
            message: "Upload notes for this subject to see them here.",
            buttonTitle: "Upload Now",
            action: { [weak self] in
                self?.addNoteTapped()
            }
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
    
    // Setup notifications to refresh data when notes are updated
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePDFUploadSuccess),
            name: NSNotification.Name("PDFUploadSuccess"),
            object: nil
        )
    }
    
    // MARK: - UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadedNoteCell", for: indexPath) as! NoteCollectionViewCell1
        let note = notes[indexPath.row]
        cell.configure(with: note)
        
        // Configure long press action from cell
        cell.onLongPress = { [weak self] note in
            self?.impactFeedbackGenerator.impactOccurred()
            self?.showEditNoteAlert(for: note.id)
        }
        
        // Handle favorite status changes
        cell.favoriteButtonTapped = { [weak self] in
            self?.updateFavoriteStatus(for: note)
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
                }
                return
            }
            
            self.downloadAndPresentPDF(note: note)
        }
    }
    
    // MARK: - Actions
    private func showEditNoteAlert(for noteId: String) {
        let note = notes.first { $0.id == noteId }
        guard let note = note else { return }
        
        let alert = UIAlertController(title: "Edit Note", message: "Update or delete note", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.showEditDetailsAlert(for: noteId, currentNote: note)
        })
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteNote(noteId: noteId)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showEditDetailsAlert(for noteId: String, currentNote: SavedFireNote) {
        let alert = UIAlertController(title: "Edit Note", message: "Update note details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = currentNote.title
            textField.placeholder = "Title"
        }
        alert.addTextField { textField in
            textField.text = currentNote.subjectName
            textField.placeholder = "Subject Name"
        }
        alert.addTextField { textField in
            textField.text = currentNote.subjectCode
            textField.placeholder = "Subject Code"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let titleField = alert.textFields?[0].text, !titleField.isEmpty,
                  let subjectNameField = alert.textFields?[1].text, !subjectNameField.isEmpty,
                  let subjectCodeField = alert.textFields?[2].text, !subjectCodeField.isEmpty else {
                self?.showAlert(title: "Error", message: "All fields must be filled.")
                return
            }
            self?.updateNoteDetails(noteId: noteId, title: titleField, subjectName: subjectNameField, subjectCode: subjectCodeField)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func deleteNote(noteId: String) {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not authenticated")
            return
        }
        
        guard let note = notes.first(where: { $0.id == noteId }) else {
            showAlert(title: "Error", message: "Note not found")
            return
        }
        
        db.collection("pdfs").document(noteId).delete { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to delete note: \(error.localizedDescription)")
                return
            }
            
            // Remove from favorites if present
            db.collection("userFavorites").document(userId)
                .collection("favorites").document(noteId).delete { error in
                    if let error = error {
                        print("Error deleting from favorites: \(error.localizedDescription)")
                    }
                }
            
            // Delete the file from storage
            if let pdfUrl = note.pdfUrl, !pdfUrl.isEmpty {
                storage.reference(forURL: pdfUrl).delete { error in
                    if let error = error {
                        self.showAlert(title: "Warning", message: "Note deleted from database but failed to delete file: \(error.localizedDescription)")
                    }
                    self.fetchNotes()
                }
            } else {
                self.fetchNotes()
            }
        }
    }
    
    private func updateNoteDetails(noteId: String, title: String, subjectName: String, subjectCode: String) {
        let db = Firestore.firestore()
        db.collection("pdfs").document(noteId).updateData([
            "fileName": title,
            "subjectName": subjectName,
            "subjectCode": subjectCode
        ]) { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Error", message: "Failed to update note: \(error.localizedDescription)")
            } else {
                self?.fetchNotes()
            }
        }
    }
    
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
        FirebaseService1.shared.observeNotes(userId: userId) { [weak self] allNotes in
            guard let self = self else { return }
            self.notes = allNotes.filter { $0.subjectCode == self.subjectCode }
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
    
    // Handle upload success to refresh notes
    @objc private func handlePDFUploadSuccess() {
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

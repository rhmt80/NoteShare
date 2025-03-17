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
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
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
        NotificationCenter.default.addObserver(self, selector: #selector(handleFavoriteStatusChange), name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreviouslyReadNotesUpdated), name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
        
        // Initial sync with current favorite status
        handleFavoriteStatusChange()
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
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "NoteCollectionViewCell", for: indexPath) as! NoteCollectionViewCell
        let note = notes[indexPath.row]
        cell.configure(with: note)
        
        // Ensure initial favorite state is set correctly
        cell.isFavorite = note.isFavorite
        
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
        FirebaseService.shared.downloadPDF(from: note.pdfUrl) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    let pdfVC = PDFViewerViewController(pdfURL: url, title: note.title)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self?.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self?.present(navController, animated: true)
                    
                    // Update previously read notes
                    let previouslyReadNote = PreviouslyReadNote(
                        id: note.id,
                        title: note.title,
                        pdfUrl: note.pdfUrl,
                        lastOpened: Date()
                    )
                    self?.savePreviouslyReadNote(previouslyReadNote)
                    print(previouslyReadNote)
                case .failure(let error):
                    print("Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 20) / 2
        return CGSize(width: width, height: 280) // Match HomeViewController height
    }
    
    @objc private func closePDF() {
        dismiss(animated: true)
    }
    
    @objc private func handleFavoriteStatusChange() {
        print("SubjectNotes: Received FavoriteStatusChanged notification")
        FirebaseService.shared.fetchNotes { [weak self] allNotes, _ in
            guard let self = self else { return }
            let filteredNotes = allNotes.filter { $0.subjectCode == self.subjectCode }
            print("SubjectNotes: Fetched \(filteredNotes.count) notes for subject \(self.subjectCode)")
            filteredNotes.forEach { note in
                print("Note \(note.id): isFavorite = \(note.isFavorite)")
            }
            self.notes = filteredNotes
            self.collectionView.reloadData()
        }
    }
}

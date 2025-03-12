//new changed
import UIKit

class SubjectNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
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
        
        // Initial sync with current favorite status
        handleFavoriteStatusChange()
    }
    
    deinit {
        // Remove observer when the view controller is deallocated
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("FavoriteStatusChanged"), object: nil)
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

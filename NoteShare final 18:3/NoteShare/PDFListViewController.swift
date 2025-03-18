import UIKit
import Foundation
import PDFKit
import MobileCoreServices
import FirebaseStorage
import FirebaseFirestore

// Forward declaration of FirebaseService for cross-file access
protocol PDFDownloader {
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void)
}

class PDFListViewController: UIViewController {
    // MARK: - Previously Read Notes Storage
    struct PreviouslyReadNote {
        let id: String
        let title: String
        let pdfUrl: String
        let lastOpened: Date
    }

    private func savePreviouslyReadNote(_ note: PreviouslyReadNote) {
        var history = loadPreviouslyReadNotes()
        
        history.removeAll { $0.id == note.id }
        history.append(note)
        history.sort { $0.lastOpened > $1.lastOpened }
        if history.count > 5 {
            history = Array(history.prefix(5))
        }
        
        let historyData = history.map { ["id": $0.id, "title": $0.title, "pdfUrl": $0.pdfUrl, "lastOpened": $0.lastOpened] }
        UserDefaults.standard.set(historyData, forKey: "previouslyReadNotes")
        
        NotificationCenter.default.post(name: NSNotification.Name("PreviouslyReadNotesUpdated"), object: nil)
    }

    private func loadPreviouslyReadNotes() -> [PreviouslyReadNote] {
        guard let historyData = UserDefaults.standard.array(forKey: "previouslyReadNotes") as? [[String: Any]] else {
            return []
        }
        
        return historyData.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let pdfUrl = dict["pdfUrl"] as? String,
                  let lastOpened = dict["lastOpened"] as? Date else {
                return nil
            }
            return PreviouslyReadNote(id: id, title: title, pdfUrl: pdfUrl, lastOpened: lastOpened)
        }
    }
    
    var onPDFSelected: ((URL, String, String, String, Int, UIImage?) -> Void)?
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Browse All Notes"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Find study materials for your courses"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.minimumInteritemSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 14, left: 14, bottom: 20, right: 14)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .onDrag
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search notes by title, subject, or code"
        searchBar.searchBarStyle = .minimal
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var pdfFiles: [(url: URL, fileName: String, subjectName: String, subjectCode: String, fileSize: Int, thumbnail: UIImage?)] = []
    private var filteredPDFFiles: [(url: URL, fileName: String, subjectName: String, subjectCode: String, fileSize: Int, thumbnail: UIImage?)] = []
    private let db = Firestore.firestore()
    private var viewBackgroundLayer: CAGradientLayer?
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.color = .systemBlue
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "No notes available"
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emptyStateView: UIView = {
        let view = UIView()
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let emptyStateImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .light)
        imageView.image = UIImage(systemName: "doc.text.magnifyingglass", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray3
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchPDFsFromFirebase()
        
        // Add tap gesture to dismiss keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Ensure loading container is hidden
        if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
            loadingContainer.isHidden = !loadingIndicator.isAnimating
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Add a subtle gradient background to the view
        if viewBackgroundLayer == nil {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = view.bounds
            gradientLayer.colors = [
                UIColor.systemBackground.cgColor,
                UIColor.systemGray6.cgColor
            ]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            
            view.layer.insertSublayer(gradientLayer, at: 0)
            viewBackgroundLayer = gradientLayer
        } else {
            viewBackgroundLayer?.frame = view.bounds
        }
        
        // Make sure loading container has correct frame and is explicitly hidden when not in use
        if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
            if !loadingIndicator.isAnimating {
                loadingContainer.isHidden = true
            }
            
            // Ensure any blur effect view has the correct corner radius
            if let blurView = loadingContainer.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView {
                blurView.layer.cornerRadius = 12
                blurView.clipsToBounds = true
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup empty state view
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        view.addSubview(emptyStateView)
        
        // Add header view that contains the title and subtitle
        view.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(subtitleLabel)
        
        // Setup search bar
        view.addSubview(searchBar)
        searchBar.delegate = self
        
        // Setup collection view
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(PDFCollectionViewCell1.self, forCellWithReuseIdentifier: "PDFCell")
        view.addSubview(collectionView)
        
        // Add a custom refresh control
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemBlue
        
        // Adding custom title text to the refresh control
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemBlue,
                         NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12)]
        refreshControl.attributedTitle = NSAttributedString(string: "Fetching Notes...", attributes: attributes)
        
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        // Add loading indicator with a transparent background container
        let loadingContainer = UIView()
        loadingContainer.backgroundColor = .clear // Changed to clear
        loadingContainer.clipsToBounds = true
        loadingContainer.layer.cornerRadius = 12
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.isHidden = true // Make sure it's hidden initially

        // Add blur effect to container instead of solid color
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 12
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(blurView)
        
        loadingContainer.addSubview(loadingIndicator)
        view.addSubview(loadingContainer)
        
        NSLayoutConstraint.activate([
            // Header view - reduced height
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Title with adjusted styling to stand out against gradient
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8),
            
            // Search bar
            searchBar.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            
            // Collection view - reduced top space
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Loading container
            loadingContainer.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            loadingContainer.widthAnchor.constraint(equalToConstant: 80),
            loadingContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Blur view fills container
            blurView.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            blurView.leftAnchor.constraint(equalTo: loadingContainer.leftAnchor),
            blurView.rightAnchor.constraint(equalTo: loadingContainer.rightAnchor),
            blurView.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),
            
            // Loading indicator centered in container
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor),
            
            // Empty state view
            emptyStateView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 200),
            emptyStateView.heightAnchor.constraint(equalToConstant: 160),
            
            // Empty state image view
            emptyStateImageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 70),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 70),
            
            // Empty state label
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 16),
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor)
        ])
        
        // Ensure title stands out against any background
        titleLabel.textColor = .label
    }
        
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func refreshData() {
        pdfFiles = []
        filteredPDFFiles = []
        collectionView.reloadData()
        
        // Since we're using pull-to-refresh, don't show the center loading indicator
        let useRefreshControl = true
        fetchPDFsFromFirebase(useRefreshControl: useRefreshControl)
    }
    
    private func fetchPDFsFromFirebase(useRefreshControl: Bool = false) {
        // Only show the center loading indicator if we're not using the refresh control
        if !useRefreshControl {
            // Make container visible when loading starts
            if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
                loadingContainer.isHidden = false
            }
            loadingIndicator.startAnimating()
        }
        
        emptyStateView.isHidden = true
        
        db.collection("pdfs").getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            // Always stop both loading indicators when done
            self.loadingIndicator.stopAnimating()
            
            // Explicitly hide the loading container
            if let loadingContainer = self.view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
                loadingContainer.isHidden = true
            }
            
            self.collectionView.refreshControl?.endRefreshing()
            
            if let error = error {
                print("Error getting documents: \(error)")
                self.showErrorAlert(message: "Failed to fetch notes: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                self.emptyStateView.isHidden = false
                return
            }
            
            let group = DispatchGroup()
            
            for document in documents {
                let data = document.data()
                
                guard let downloadURLString = data["downloadURL"] as? String,
                      let url = URL(string: downloadURLString),
                      let fileName = data["fileName"] as? String,
                      let subjectName = data["subjectName"] as? String,
                      let subjectCode = data["subjectCode"] as? String,
                      let fileSize = data["fileSize"] as? Int else {
                    continue
                }
                
                group.enter()
                self.generateThumbnail(for: url) { thumbnail in
                    let pdf = (url: url, fileName: fileName, subjectName: subjectName, subjectCode: subjectCode, fileSize: fileSize, thumbnail: thumbnail)
                    self.pdfFiles.append(pdf)
                    self.filteredPDFFiles.append(pdf)
                    group.leave()
                }
            }
            
            group.notify(queue: .main) {
                self.emptyStateView.isHidden = !self.pdfFiles.isEmpty
                self.filteredPDFFiles.sort { $0.fileName < $1.fileName } // Sort alphabetically
                self.collectionView.reloadData()
                
                // Add a subtle animation to the cells as they appear
                self.animateCollectionViewCells()
            }
        }
    }
    
    private func animateCollectionViewCells() {
        let cells = collectionView.visibleCells
        
        let originalTransform = CATransform3DIdentity
        var startTransform = CATransform3DTranslate(originalTransform, 0, 30, 0)
        startTransform.m34 = 1.0 / -800
        
        for (index, cell) in cells.enumerated() {
            cell.layer.transform = startTransform
            cell.alpha = 0
            
            UIView.animate(withDuration: 0.35, delay: Double(index) * 0.03, usingSpringWithDamping: 0.8,
                          initialSpringVelocity: 0.2, options: .curveEaseOut, animations: {
                cell.layer.transform = originalTransform
                cell.alpha = 1
            })
        }
    }
    
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?) -> Void) {
            DispatchQueue.global(qos: .userInitiated).async {
                if let document = PDFDocument(url: url),
                   let page = document.page(at: 0) {
                    let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                    DispatchQueue.main.async {
                        completion(thumbnail)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
        }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    private func showLoadingView(completion: @escaping () -> Void) {
        // Create a custom loading view with a blur effect for a more premium look
        let blurEffect = UIBlurEffect(style: .systemThinMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.alpha = 0
        
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.1
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .systemBlue
        activityIndicator.startAnimating()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        let loadingLabel = UILabel()
        loadingLabel.text = "Loading PDF..."
        loadingLabel.font = .systemFont(ofSize: 16, weight: .medium)
        loadingLabel.textAlignment = .center
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(activityIndicator)
        containerView.addSubview(loadingLabel)
        blurView.contentView.addSubview(containerView)
        view.addSubview(blurView)
        
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: blurView.contentView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 200),
            containerView.heightAnchor.constraint(equalToConstant: 120),
            
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
            
            loadingLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 16),
            loadingLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            loadingLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // Animate the blur view in
        UIView.animate(withDuration: 0.3, animations: {
            blurView.alpha = 1
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
        }, completion: { _ in
            blurView.removeFromSuperview()
            self.loadingBlurView = nil
            completion()
        })
    }
    
    private var loadingBlurView: UIVisualEffectView?
    
    private func handlePDFSelection(at indexPath: IndexPath) {
        let pdf = filteredPDFFiles[indexPath.row]
        
        // Show custom loading view
        showLoadingView {
            // First try direct URL access to avoid unnecessary download if URL is local
            if FileManager.default.fileExists(atPath: pdf.url.path),
               let pdfDocument = PDFDocument(url: pdf.url) {
                // PDF exists locally and is valid
                self.hideLoadingView {
                    self.displayPDF(localURL: pdf.url, fileName: pdf.fileName)
                }
                return
            }
            
            // Need to download PDF from Firebase
            self.downloadFromFirebase(url: pdf.url.absoluteString, fileName: pdf.fileName)
        }
    }
    
    private func downloadFromFirebase(url: String, fileName: String) {
        // Try to get the Firebase service dynamically
        let downloadService = getDownloadService()
        
        downloadService?.downloadPDF(from: url, completion: { [weak self] result in
            guard let self = self else { return }
            
            self.hideLoadingView {
                switch result {
                case .success(let localURL):
                    print("Successfully downloaded PDF to \(localURL.path)")
                    self.displayPDF(localURL: localURL, fileName: fileName)
                case .failure(let error):
                    print("Failed to download PDF: \(error.localizedDescription)")
                    self.showErrorAlert(message: "Could not open the PDF. \(error.localizedDescription)")
                }
            }
        })
    }
    
    private func displayPDF(localURL: URL, fileName: String) {
        let pdfViewerVC = PDFViewerViewController(pdfURL: localURL, title: fileName)
        let navController = UINavigationController(rootViewController: pdfViewerVC)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true)
        
        // Update previously read notes
        let previouslyReadNote = PreviouslyReadNote(
            id: fileName,
            title: fileName,
            pdfUrl: localURL.absoluteString,
            lastOpened: Date()
        )
        self.savePreviouslyReadNote(previouslyReadNote)
    }
    
    private func getDownloadService() -> PDFDownloader? {
        // Create our own downloader if we can't get one from elsewhere
        return PDFDownloaderService()
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension PDFListViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPDFFiles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PDFCell", for: indexPath) as! PDFCollectionViewCell1
        let pdf = filteredPDFFiles[indexPath.row]
        cell.configure(with: pdf)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 14 * 2 + 10
        let width = (collectionView.bounds.width - padding) / 2
        return CGSize(width: width, height: width * 1.3)
    }
    
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // Enhanced selection animation with 3D effect
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                // Add a subtle shadow change during selection
                cell.layer.shadowOpacity = 0.15
            }, completion: { _ in
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = CGAffineTransform.identity
                    cell.layer.shadowOpacity = 0.1
                }, completion: { _ in
                    // Continue with the original selection
                    self.handlePDFSelection(at: indexPath)
                })
            })
        } else {
            // If no cell is available, just handle the selection directly
            handlePDFSelection(at: indexPath)
        }
    }
}

// MARK: - Collection View Cell
class PDFCollectionViewCell1: UICollectionViewCell {
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray6
        imageView.layer.cornerRadius = 0
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
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
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pageCountBadge: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)
        view.layer.cornerRadius = 10
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pageCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pageIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "doc.text")
        imageView.tintColor = .white
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
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
        
        // Setup page count badge
        pageCountBadge.addSubview(pageIconImageView)
        pageCountBadge.addSubview(pageCountLabel)
        containerView.addSubview(pageCountBadge)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 3),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -3),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.62),
            
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            descriptionLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 3),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -10),
            
            // Page count badge constraints
            pageCountBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            pageCountBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            pageCountBadge.heightAnchor.constraint(equalToConstant: 22),
            
            // Page icon constraints
            pageIconImageView.leadingAnchor.constraint(equalTo: pageCountBadge.leadingAnchor, constant: 6),
            pageIconImageView.centerYAnchor.constraint(equalTo: pageCountBadge.centerYAnchor),
            pageIconImageView.widthAnchor.constraint(equalToConstant: 12),
            pageIconImageView.heightAnchor.constraint(equalToConstant: 12),
            
            // Page count label constraints
            pageCountLabel.leadingAnchor.constraint(equalTo: pageIconImageView.trailingAnchor, constant: 2),
            pageCountLabel.trailingAnchor.constraint(equalTo: pageCountBadge.trailingAnchor, constant: -6),
            pageCountLabel.centerYAnchor.constraint(equalTo: pageCountBadge.centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Apply more premium card-like shadow effect
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.1
        layer.masksToBounds = false
        
        // Add a subtle border
        containerView.layer.borderWidth = 0.5
        containerView.layer.borderColor = UIColor.systemGray5.cgColor
        
        // Add a subtle gradient overlay to the image for more premium look
        if coverImageView.image != nil && coverImageView.subviews.isEmpty {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = coverImageView.bounds
            gradientLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.15).cgColor
            ]
            gradientLayer.locations = [0.7, 1.0]
            
            let overlayView = UIView(frame: coverImageView.bounds)
            overlayView.backgroundColor = .clear
            overlayView.layer.addSublayer(gradientLayer)
            overlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            coverImageView.addSubview(overlayView)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        coverImageView.image = nil
        titleLabel.text = nil
        authorLabel.text = nil
        descriptionLabel.text = nil
        pageCountLabel.text = nil
        pageCountBadge.isHidden = true
    }
    
    func configure(with pdf: (url: URL, fileName: String, subjectName: String, subjectCode: String, fileSize: Int, thumbnail: UIImage?)) {
        titleLabel.text = pdf.fileName
        authorLabel.text = pdf.subjectName
        descriptionLabel.text = "\(pdf.subjectCode) • \(formatFileSize(pdf.fileSize))"
        
        if let thumbnail = pdf.thumbnail {
            coverImageView.contentMode = .scaleAspectFill
            coverImageView.image = thumbnail
        } else {
            // Use a more attractive PDF placeholder with gradient background
            coverImageView.contentMode = .center
            coverImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.08)
            let config = UIImage.SymbolConfiguration(pointSize: 45, weight: .regular)
            coverImageView.image = UIImage(systemName: "doc.richtext", withConfiguration: config)
            coverImageView.tintColor = .systemBlue.withAlphaComponent(0.8)
        }
        
        // Get page count from PDF document
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let document = PDFDocument(url: pdf.url) {
                let pageCount = document.pageCount
                DispatchQueue.main.async {
                    self.pageCountLabel.text = "\(pageCount)"
                    self.pageCountBadge.isHidden = false
                    
                    // Adjust width based on number of pages (more digits need more space)
                    let widthMultiplier = pageCount > 99 ? 3.0 : (pageCount > 9 ? 2.5 : 2.0)
                    let badgeWidth = 12 + (widthMultiplier * 10) // icon width + text space
                    NSLayoutConstraint.activate([
                        self.pageCountBadge.widthAnchor.constraint(equalToConstant: badgeWidth)
                    ])
                }
            } else {
                DispatchQueue.main.async {
                    self.pageCountBadge.isHidden = true
                }
            }
        }
    }
    
    private func formatFileSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}

// Implement a local PDF downloader service as a fallback
class PDFDownloaderService: NSObject, PDFDownloader {
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let url = URL(string: urlString) else {
            let error = NSError(domain: "PDFDownloadError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"])
            completion(.failure(error))
            return
        }
        
        // Create a local URL in the documents directory
        let fileName = UUID().uuidString + ".pdf"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsURL.appendingPathComponent(fileName)
        
        // Create a download task
        let session = URLSession.shared
        let downloadTask = session.downloadTask(with: url) { (tempURL, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let tempURL = tempURL else {
                let error = NSError(domain: "PDFDownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download failed: No temporary file URL"])
                completion(.failure(error))
                return
            }
            
            do {
                // Move the temporary file to our local URL
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                
                // Verify the PDF is valid
                if let _ = PDFDocument(url: localURL) {
                    completion(.success(localURL))
                } else {
                    // Downloaded file is not a valid PDF
                    try? FileManager.default.removeItem(at: localURL)
                    let error = NSError(domain: "PDFDownloadError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Downloaded file is not a valid PDF"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        downloadTask.resume()
    }
}

// MARK: - UISearchBar Delegate
extension PDFListViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterContent(with: searchText)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    private func filterContent(with searchText: String) {
        if searchText.isEmpty {
            filteredPDFFiles = pdfFiles
        } else {
            filteredPDFFiles = pdfFiles.filter {
                $0.fileName.lowercased().contains(searchText.lowercased()) ||
                $0.subjectName.lowercased().contains(searchText.lowercased()) ||
                $0.subjectCode.lowercased().contains(searchText.lowercased())
            }
        }
        collectionView.reloadData()
    }
}

#Preview {
    PDFListViewController()
}

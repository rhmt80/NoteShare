import UIKit
import Foundation
import PDFKit
import MobileCoreServices
import FirebaseStorage
import FirebaseFirestore
import CommonCrypto
import SwiftUI

protocol PDFDownloader {
    func downloadPDF(from urlString: String, completion: @escaping (Result<URL, Error>) -> Void)
}

private let imageCache = NSCache<NSString, UIImage>()

class PDFListViewController: UIViewController, UICollectionViewDataSourcePrefetching {
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
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search notes by title, subject, or code"
        searchBar.searchBarStyle = .minimal
        searchBar.backgroundColor = .systemBackground
        searchBar.tintColor = .systemBlue
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .onDrag
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .always
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }()
    
    private var pdfFiles: [PDFMetadata] = []
    private var filteredPDFFiles: [PDFMetadata] = []
    private var lastDocumentSnapshot: DocumentSnapshot?
    private let pageSize = 15
    private var isLoadingMore = false
    private var hasMoreData = true
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
        label.text = "No notes found"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .systemGray
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
        let config = UIImage.SymbolConfiguration(pointSize: 64, weight: .light)
        imageView.image = UIImage(systemName: "doc.text.magnifyingglass", withConfiguration: config)
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemGray2
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        fetchPDFsFromFirebase()
        
        if #available(iOS 13.0, *) {
            collectionView.isPrefetchingEnabled = true
            collectionView.prefetchDataSource = self
        }
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
            loadingContainer.isHidden = !loadingIndicator.isAnimating
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if viewBackgroundLayer == nil {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = view.bounds
            gradientLayer.colors = [
                UIColor.systemBackground.cgColor,
                UIColor.systemGray6.withAlphaComponent(0.6).cgColor
            ]
            gradientLayer.locations = [0.0, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            view.layer.insertSublayer(gradientLayer, at: 0)
            viewBackgroundLayer = gradientLayer
        } else {
            viewBackgroundLayer?.frame = view.bounds
        }
        
        if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
            if !loadingIndicator.isAnimating {
                loadingContainer.isHidden = true
            }
            if let blurView = loadingContainer.subviews.first(where: { $0 is UIVisualEffectView }) as? UIVisualEffectView {
                blurView.layer.cornerRadius = 16
                blurView.clipsToBounds = true
            }
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        view.addSubview(emptyStateView)
        
        view.addSubview(searchBar)
        searchBar.delegate = self
        
        collectionView.delegate = self
        collectionView.dataSource = self
        
        if #available(iOS 13.0, *) {
            collectionView.prefetchDataSource = self
            collectionView.isPrefetchingEnabled = true
        }
        
        collectionView.register(PDFCollectionViewCell1.self, forCellWithReuseIdentifier: "PDFCell")
        view.addSubview(collectionView)
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .systemBlue
        let attributes = [NSAttributedString.Key.foregroundColor: UIColor.systemBlue,
                         NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14, weight: .medium)]
        refreshControl.attributedTitle = NSAttributedString(string: "Fetching Notes...", attributes: attributes)
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
        
        let loadingContainer = UIView()
        loadingContainer.backgroundColor = .clear
        loadingContainer.clipsToBounds = true
        loadingContainer.layer.cornerRadius = 16
        loadingContainer.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.isHidden = true

        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.layer.cornerRadius = 16
        blurView.clipsToBounds = true
        blurView.translatesAutoresizingMaskIntoConstraints = false
        loadingContainer.addSubview(blurView)
        
        loadingContainer.addSubview(loadingIndicator)
        view.addSubview(loadingContainer)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            
            collectionView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 12),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            loadingContainer.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            loadingContainer.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            loadingContainer.widthAnchor.constraint(equalToConstant: 100),
            loadingContainer.heightAnchor.constraint(equalToConstant: 100),
            
            blurView.topAnchor.constraint(equalTo: loadingContainer.topAnchor),
            blurView.leftAnchor.constraint(equalTo: loadingContainer.leftAnchor),
            blurView.rightAnchor.constraint(equalTo: loadingContainer.rightAnchor),
            blurView.bottomAnchor.constraint(equalTo: loadingContainer.bottomAnchor),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor),
            
            emptyStateView.centerXAnchor.constraint(equalTo: collectionView.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: collectionView.centerYAnchor),
            emptyStateView.widthAnchor.constraint(equalToConstant: 220),
            emptyStateView.heightAnchor.constraint(equalToConstant: 180),
            
            emptyStateImageView.topAnchor.constraint(equalTo: emptyStateView.topAnchor),
            emptyStateImageView.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateImageView.widthAnchor.constraint(equalToConstant: 80),
            emptyStateImageView.heightAnchor.constraint(equalToConstant: 80),
            
            emptyStateLabel.topAnchor.constraint(equalTo: emptyStateImageView.bottomAnchor, constant: 20),
            emptyStateLabel.centerXAnchor.constraint(equalTo: emptyStateView.centerXAnchor),
            emptyStateLabel.leadingAnchor.constraint(equalTo: emptyStateView.leadingAnchor),
            emptyStateLabel.trailingAnchor.constraint(equalTo: emptyStateView.trailingAnchor)
        ])
    }
    
    @objc private func refreshData() {
        pdfFiles = []
        filteredPDFFiles = []
        collectionView.reloadData()
        fetchPDFsFromFirebase(useRefreshControl: true)
    }
    
    
    private func fetchPDFsFromFirebase(useRefreshControl: Bool = false) {
        if !useRefreshControl {
            if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
                loadingContainer.isHidden = false
            }
            loadingIndicator.startAnimating()
        }
        
        emptyStateView.isHidden = true
        
        if useRefreshControl || pdfFiles.isEmpty {
            lastDocumentSnapshot = nil
            hasMoreData = true
            pdfFiles = []
            filteredPDFFiles = []
            collectionView.reloadData()
        }
        
        guard !isLoadingMore && hasMoreData else {
            loadingIndicator.stopAnimating()
            if let loadingContainer = view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
                loadingContainer.isHidden = true
            }
            collectionView.refreshControl?.endRefreshing()
            return
        }
        
        isLoadingMore = true
        
        var query = db.collection("pdfs")
            .whereField("privacy", isEqualTo: "public")
            .order(by: "uploadDate", descending: true)
            .limit(to: pageSize)
        
        if let lastDocument = lastDocumentSnapshot {
            query = query.start(afterDocument: lastDocument)
        }
        
        query.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            self.loadingIndicator.stopAnimating()
            if let loadingContainer = self.view.subviews.first(where: { $0.subviews.contains(where: { $0 is UIActivityIndicatorView }) }) {
                loadingContainer.isHidden = true
            }
            self.collectionView.refreshControl?.endRefreshing()
            self.isLoadingMore = false
            
            if let error = error {
                print("Error getting documents: \(error)")
                self.showErrorAlert(message: "Failed to fetch notes: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                if self.pdfFiles.isEmpty {
                    self.emptyStateView.isHidden = false
                }
                self.hasMoreData = false
                return
            }
            
            self.lastDocumentSnapshot = documents.last
            self.hasMoreData = documents.count == self.pageSize
            
            for document in documents {
                let data = document.data()
                
                let privacy = (data["privacy"] as? String) ?? "public"
                
                guard let downloadURLString = data["downloadURL"] as? String,
                      let url = URL(string: downloadURLString),
                      let fileName = data["fileName"] as? String,
                      privacy == "public"
                else {
                    continue
                }
                
                let subjectName = (data["subjectName"] as? String) ?? "Unknown"
                let subjectCode = (data["subjectCode"] as? String) ?? "N/A"
                let fileSize = (data["fileSize"] as? Int) ?? 0
                let uploadDate = (data["uploadDate"] as? Timestamp)?.dateValue() ?? Date()
                
                let metadata = PDFMetadata(
                    id: document.documentID,
                    url: url,
                    fileName: fileName,
                    subjectName: subjectName,
                    subjectCode: subjectCode,
                    fileSize: fileSize,
                    privacy: privacy,
                    uploadDate: uploadDate,
                    uploaderName: (data["uploaderName"] as? String) ?? "Unknown",
                    college: (data["college"] as? String) ?? "Unknown"
                )
                
                self.pdfFiles.append(metadata)
                self.filteredPDFFiles.append(metadata)
            }
            
            self.filteredPDFFiles.sort { $0.uploadDate > $1.uploadDate }
            self.collectionView.reloadData()
            
            if !useRefreshControl && self.pdfFiles.count <= self.pageSize {
                self.animateCollectionViewCells()
            }
            
            self.emptyStateView.isHidden = !self.pdfFiles.isEmpty
        }
    }
    
    private func animateCollectionViewCells() {
            let cells = collectionView.visibleCells
            let originalTransform = CATransform3DIdentity
            var startTransform = CATransform3DTranslate(originalTransform, 0, 40, 0)
            startTransform.m34 = 1.0 / -1000
            
            for (index, cell) in cells.enumerated() {
                cell.layer.transform = startTransform
                cell.alpha = 0
                
                UIView.animate(withDuration: 0.4, delay: Double(index) * 0.04, usingSpringWithDamping: 0.85,
                              initialSpringVelocity: 0.3, options: .curveEaseOut, animations: {
                    cell.layer.transform = originalTransform
                    cell.alpha = 1
                })
            }
        }
    
    private func generateThumbnail(for url: URL, completion: @escaping (UIImage?, Int) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            if let document = PDFDocument(url: url),
               let page = document.page(at: 0) {
                let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                DispatchQueue.main.async {
                    completion(thumbnail, document.pageCount)
                }
            } else if url.isFileURL && FileManager.default.fileExists(atPath: url.path) {
                if let document = PDFDocument(url: url),
                   let page = document.page(at: 0) {
                    let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
                    DispatchQueue.main.async {
                        completion(thumbnail, document.pageCount)
                    }
                } else {
                    DispatchQueue.main.async {
                        completion(nil, 0)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    completion(nil, 0)
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
        
        UIView.animate(withDuration: 0.3, animations: {
            blurView.alpha = 1
        }, completion: { _ in
            completion()
        })
        
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
        let metadata = filteredPDFFiles[indexPath.item]
        let fileName = metadata.fileName
        let documentId = metadata.id
        
        showLoadingView {
            if !documentId.isEmpty, let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: documentId) {
                print("Found cached PDF in PDFCache with document ID: \(documentId)")
                self.hideLoadingView {
                    self.displayPDF(localURL: cachedPDFPath, fileName: fileName, documentId: documentId)
                }
                return
            }
            
            if let url = metadata.url,
               let cachedData = CacheManager.shared.getCachedPDF(url: url) {
                let urlString = url.absoluteString
                print("Found cached PDF in CacheManager for URL: \(urlString)")
                
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(documentId.isEmpty ? UUID().uuidString : documentId).pdf")
                do {
                    try cachedData.write(to: tempURL)
                    print("Successfully wrote cached PDF data to temporary file")
                    
                    if !documentId.isEmpty {
                        PDFCache.shared.cachePDFPath(for: documentId, fileURL: tempURL)
                    }
                    
                    self.hideLoadingView {
                        self.displayPDF(localURL: tempURL, fileName: fileName, documentId: documentId)
                    }
                    return
                } catch {
                    print("Error writing cached data to temporary file: \(error)")
                }
            }
            
            if let url = metadata.url, FileManager.default.fileExists(atPath: url.path),
               let pdfDocument = PDFDocument(url: url) {
                print("PDF exists as local file: \(url.path)")
                
                if !documentId.isEmpty {
                    PDFCache.shared.cachePDFPath(for: documentId, fileURL: url)
                }
                
                self.hideLoadingView {
                    self.displayPDF(localURL: url, fileName: fileName, documentId: documentId)
                }
                return
            }
            
            if let urlString = metadata.url?.absoluteString {
                print("PDF not found in any cache, downloading from: \(urlString)")
                self.downloadFromFirebase(url: urlString, fileName: fileName, documentId: documentId)
            } else {
                self.hideLoadingView {
                    self.showErrorAlert(message: "Could not access the PDF URL.")
                }
            }
        }
    }
    
    private func downloadFromFirebase(url: String, fileName: String, documentId: String = "") {
        let downloadService = getDownloadService()
        
        print("Downloading PDF from Firebase URL: \(url)")
        
        downloadService?.downloadPDF(from: url, completion: { [weak self] result in
            guard let self = self else { return }
            
            self.hideLoadingView {
                switch result {
                case .success(let localURL):
                    print("Successfully downloaded PDF to: \(localURL.path)")
                    if let document = PDFDocument(url: localURL) {
                        print("Downloaded valid PDF with \(document.pageCount) pages")
                    } else {
                        print("WARNING: Downloaded file is not a valid PDF")
                    }
                    
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let newFileName = "\(fileName)-\(url.md5).pdf"
                    let permanentURL = documentsPath.appendingPathComponent(newFileName)
                    
                    do {
                        if FileManager.default.fileExists(atPath: permanentURL.path) {
                            try FileManager.default.removeItem(at: permanentURL)
                        }
                        try FileManager.default.copyItem(at: localURL, to: permanentURL)
                        print("Saved PDF to permanent location: \(permanentURL.path)")
                        
                        if !documentId.isEmpty {
                            PDFCache.shared.cachePDFPath(for: documentId, fileURL: permanentURL)
                            print("Cached PDF with document ID: \(documentId)")
                        }
                        
                        if let pdfURL = URL(string: url), let pdfData = try? Data(contentsOf: permanentURL) {
                            try? CacheManager.shared.cachePDF(url: pdfURL, data: pdfData)
                            print("Cached PDF with URL: \(url)")
                        }
                        
                        self.displayPDF(localURL: permanentURL, fileName: fileName, documentId: documentId)
                    } catch {
                        print("Error saving PDF to cache: \(error.localizedDescription)")
                        self.displayPDF(localURL: localURL, fileName: fileName, documentId: documentId)
                    }
                    
                case .failure(let error):
                    print("Failed to download PDF: \(error.localizedDescription)")
                    self.showErrorAlert(message: "Could not open the PDF. \(error.localizedDescription)")
                }
            }
        })
    }
    
    private func displayPDF(localURL: URL, fileName: String, documentId: String = "") {
        print("Displaying PDF from: \(localURL.path)")
        
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("PDF file exists at path")
        } else {
            print("ERROR: PDF file does not exist at path")
            showErrorAlert(message: "Cannot find the PDF file at the specified location.")
            return
        }
        
        if let document = PDFDocument(url: localURL) {
            print("Valid PDF document with \(document.pageCount) pages")
        } else {
            print("ERROR: Could not create PDFDocument from URL")
            showErrorAlert(message: "The file exists but could not be opened as a PDF.")
            return
        }
        
        if !documentId.isEmpty {
            print("Opening PDF with document ID: \(documentId)")
            let pdfViewerVC = PDFViewerViewController(documentId: documentId)
            let navController = UINavigationController(rootViewController: pdfViewerVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
            
            let previouslyReadNote = PreviouslyReadNote(
                id: documentId,
                title: fileName,
                pdfUrl: localURL.absoluteString,
                lastOpened: Date()
            )
            self.savePreviouslyReadNote(previouslyReadNote)
            return
        }
        
        let fileName = localURL.lastPathComponent.removingPercentEncoding ?? localURL.lastPathComponent
        
        let validIdPattern = "^[a-zA-Z0-9]{20,28}$"
        if let regex = try? NSRegularExpression(pattern: validIdPattern),
           regex.numberOfMatches(in: fileName, range: NSRange(location: 0, length: fileName.count)) == 1 {
            
            let possibleDocumentId = fileName.replacingOccurrences(of: ".pdf", with: "")
            print("Opening PDF with possible Firebase ID: \(possibleDocumentId)")
            
            let pdfViewerVC = PDFViewerViewController(documentId: possibleDocumentId)
            let navController = UINavigationController(rootViewController: pdfViewerVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        } else {
            let pdfViewerVC = PDFViewerViewController(pdfURL: localURL, title: fileName)
            let navController = UINavigationController(rootViewController: pdfViewerVC)
            navController.modalPresentationStyle = .fullScreen
            self.present(navController, animated: true)
        }
        
        let previouslyReadNote = PreviouslyReadNote(
            id: fileName,
            title: fileName,
            pdfUrl: localURL.absoluteString,
            lastOpened: Date()
        )
        self.savePreviouslyReadNote(previouslyReadNote)
    }
    
    private func getDownloadService() -> PDFDownloader? {
        return PDFDownloaderService()
    }
    
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let itemsToProcess = min(indexPaths.count, 5)
        for i in 0..<itemsToProcess {
            let indexPath = indexPaths[i]
            if filteredPDFFiles.count > indexPath.item {
                loadThumbnailIfNeeded(for: indexPath)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // No-op since loading is asynchronous
    }
    
    private func loadThumbnailIfNeeded(for indexPath: IndexPath) {
        guard filteredPDFFiles.count > indexPath.item else { return }
        
        var metadata = filteredPDFFiles[indexPath.item]
        
        if metadata.thumbnail != nil || metadata.thumbnailIsLoading {
            return
        }
        
        var cacheKey: NSString?
        
        if let urlString = metadata.url?.absoluteString {
            cacheKey = NSString(string: urlString)
            if let cachedImage = imageCache.object(forKey: cacheKey!) {
                metadata.thumbnail = cachedImage
                filteredPDFFiles[indexPath.item] = metadata
                
                if let cell = collectionView.cellForItem(at: indexPath) as? PDFCollectionViewCell1 {
                    cell.configure(with: filteredPDFFiles[indexPath.item])
                }
                return
            }
        }
        
        metadata.thumbnailIsLoading = true
        filteredPDFFiles[indexPath.item] = metadata
        
        let capturedCacheKey = cacheKey
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            if let url = metadata.url {
                self?.generateThumbnail(for: url) { [weak self] (thumbnail: UIImage?, pageCount: Int) in
                    DispatchQueue.main.async {
                        guard let self = self, self.filteredPDFFiles.count > indexPath.item else { return }
                        
                        var updatedMetadata = self.filteredPDFFiles[indexPath.item]
                        updatedMetadata.thumbnail = thumbnail
                        updatedMetadata.pageCount = pageCount
                        updatedMetadata.thumbnailIsLoading = false
                        
                        if let thumbnail = thumbnail, let cacheKey = capturedCacheKey {
                            imageCache.setObject(thumbnail, forKey: cacheKey)
                        }
                        
                        self.filteredPDFFiles[indexPath.item] = updatedMetadata
                        
                        if let cell = self.collectionView.cellForItem(at: indexPath) as? PDFCollectionViewCell1 {
                            cell.configure(with: updatedMetadata)
                        }
                    }
                }
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let loadingBlurView = loadingBlurView {
            loadingBlurView.removeFromSuperview()
            self.loadingBlurView = nil
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        imageCache.removeAllObjects()
        
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        let visibleIds = visibleIndexPaths.compactMap {
            indexPath -> String? in
            guard filteredPDFFiles.count > indexPath.item else { return nil }
            return filteredPDFFiles[indexPath.item].id
        }
        
        for i in 0..<filteredPDFFiles.count {
            if visibleIndexPaths.contains(where: { $0.item == i }) {
                continue
            }
            
            var metadata = filteredPDFFiles[i]
            metadata.thumbnail = nil
            filteredPDFFiles[i] = metadata
        }
    }
}

// MARK: - UICollectionViewDelegate & UICollectionViewDataSource
extension PDFListViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredPDFFiles.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PDFCell", for: indexPath) as! PDFCollectionViewCell1
        
        guard filteredPDFFiles.count > indexPath.item else {
            return cell
        }
        
        let metadata = filteredPDFFiles[indexPath.item]
        cell.configure(with: metadata)
        loadThumbnailIfNeeded(for: indexPath)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 16 * 2 + 16
        let width = (collectionView.bounds.width - padding) / 2
        return CGSize(width: width, height: width * 1.4)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.15, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                cell.layer.shadowOpacity = 0.2
            }, completion: { _ in
                UIView.animate(withDuration: 0.12, animations: {
                    cell.transform = CGAffineTransform.identity
                    cell.layer.shadowOpacity = 0.15
                }, completion: { _ in
                    self.handlePDFSelection(at: indexPath)
                })
            })
        } else {
            handlePDFSelection(at: indexPath)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == collectionView else { return }
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height
        
        if offsetY > contentHeight - frameHeight * 1.8 && !isLoadingMore && hasMoreData {
            fetchPDFsFromFirebase()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        loadThumbnailIfNeeded(for: indexPath)
    }
}

// MARK: - Collection View Cell
class PDFCollectionViewCell1: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05) // Blue tint
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        imageView.layer.cornerRadius = 8
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.numberOfLines = 2
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let pageCountBadge: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let pageCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .semibold)
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
        
        pageCountBadge.addSubview(pageIconImageView)
        pageCountBadge.addSubview(pageCountLabel)
        containerView.addSubview(pageCountBadge)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            coverImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
            coverImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            coverImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            coverImageView.heightAnchor.constraint(equalTo: containerView.heightAnchor, multiplier: 0.65),
            
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            authorLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            authorLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            authorLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            
            descriptionLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: containerView.bottomAnchor, constant: -12),
            
            pageCountBadge.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            pageCountBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -12),
            pageCountBadge.heightAnchor.constraint(equalToConstant: 24),
            
            pageIconImageView.leadingAnchor.constraint(equalTo: pageCountBadge.leadingAnchor, constant: 8),
            pageIconImageView.centerYAnchor.constraint(equalTo: pageCountBadge.centerYAnchor),
            pageIconImageView.widthAnchor.constraint(equalToConstant: 14),
            pageIconImageView.heightAnchor.constraint(equalToConstant: 14),
            
            pageCountLabel.leadingAnchor.constraint(equalTo: pageIconImageView.trailingAnchor, constant: 4),
            pageCountLabel.trailingAnchor.constraint(equalTo: pageCountBadge.trailingAnchor, constant: -8), // Increased padding
            pageCountLabel.centerYAnchor.constraint(equalTo: pageCountBadge.centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        layer.shadowColor = UIColor.systemBlue.withAlphaComponent(0.3).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 8
        layer.shadowOpacity = 0.15
        layer.masksToBounds = false
        
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.1).cgColor
        
        if coverImageView.image != nil && coverImageView.subviews.isEmpty {
            let gradientLayer = CAGradientLayer()
            gradientLayer.frame = coverImageView.bounds
            gradientLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.2).cgColor
            ]
            gradientLayer.locations = [0.6, 1.0]
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
    
    func configure(with metadata: PDFMetadata) {
        titleLabel.text = metadata.fileName
        authorLabel.text = metadata.subjectName
        descriptionLabel.text = "\(metadata.subjectCode) • \(formatFileSize(metadata.fileSize))"
        
        if let thumbnail = metadata.thumbnail {
            coverImageView.contentMode = .scaleAspectFill
            coverImageView.image = thumbnail
        } else {
            coverImageView.contentMode = .center
            coverImageView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
            let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .medium)
            coverImageView.image = UIImage(systemName: "doc.richtext", withConfiguration: config)
            coverImageView.tintColor = .systemBlue.withAlphaComponent(0.7)
        }
        
        if let pageCount = metadata.pageCount {
            pageCountLabel.text = String(format: "%d", pageCount) // Changed from "%2d" to "%d" to allow natural width
            pageCountBadge.isHidden = false
            
            // Adjusted width multiplier to better accommodate 3-digit numbers
            let widthMultiplier: CGFloat
            switch pageCount {
            case 0...9:
                widthMultiplier = 2.4
            case 10...99:
                widthMultiplier = 2.8
            default: // 100 and above
                widthMultiplier = 3.4 // Increased to handle 3 digits
            }
            let badgeWidth = 24 + (widthMultiplier * 8) // Adjusted base width
            
            pageCountBadge.constraints.filter {
                $0.firstAttribute == .width && $0.secondItem == nil
            }.forEach { pageCountBadge.removeConstraint($0) }
            
            pageCountBadge.widthAnchor.constraint(equalToConstant: badgeWidth).isActive = true
        } else {
            pageCountBadge.isHidden = true
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
            print("Download failed: Invalid URL: \(urlString)")
            completion(.failure(error))
            return
        }
        
        print("PDFDownloaderService starting download from: \(urlString)")
        
        let fileName = UUID().uuidString + ".pdf"
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localURL = documentsURL.appendingPathComponent(fileName)
        
        let session = URLSession.shared
        let downloadTask = session.downloadTask(with: url) { (tempURL, response, error) in
            if let error = error {
                print("Download error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NSError(domain: "PDFDownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid HTTP response"])
                print("Invalid response: not an HTTP response")
                completion(.failure(error))
                return
            }
            
            print("HTTP response status code: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode >= 400 {
                let error = NSError(domain: "PDFDownloadError", code: httpResponse.statusCode,
                                    userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"])
                print("HTTP error status: \(httpResponse.statusCode)")
                completion(.failure(error))
                return
            }
            
            if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") {
                print("Content-Type: \(contentType)")
                if !contentType.contains("application/pdf") && !contentType.contains("octet-stream") && !contentType.contains("binary") {
                    print("Warning: Content-Type is not PDF: \(contentType)")
                }
            }
            
            guard let tempURL = tempURL else {
                let error = NSError(domain: "PDFDownloadError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Download failed: No temporary file URL"])
                print("No temporary URL received")
                completion(.failure(error))
                return
            }
            
            print("Downloaded to temporary location: \(tempURL.path)")
            
            do {
                let fileAttributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                if let fileSize = fileAttributes[.size] as? Int {
                    print("Downloaded file size: \(fileSize) bytes")
                    
                    if fileSize < 1024 {
                        if let data = try? Data(contentsOf: tempURL), let content = String(data: data, encoding: .utf8) {
                            print("Small file content: \(content)")
                            if content.contains("error") || content.contains("not found") {
                                let error = NSError(domain: "PDFDownloadError", code: -3,
                                                   userInfo: [NSLocalizedDescriptionKey: "Server returned error: \(content)"])
                                completion(.failure(error))
                                return
                            }
                        }
                    }
                }
                
                if FileManager.default.fileExists(atPath: localURL.path) {
                    try FileManager.default.removeItem(at: localURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: localURL)
                
                DispatchQueue.global(qos: .background).async {
                    if let pdfDocument = PDFDocument(url: localURL) {
                        print("Valid PDF document created with \(pdfDocument.pageCount) pages")
                        DispatchQueue.main.async {
                            completion(.success(localURL))
                        }
                    } else {
                        print("ERROR: Could not create PDFDocument from downloaded file")
                        let error = NSError(domain: "PDFDownloadError", code: -4,
                                          userInfo: [NSLocalizedDescriptionKey: "The downloaded file is not a valid PDF"])
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                        try? FileManager.default.removeItem(at: localURL)
                    }
                }
            } catch {
                print("Error moving downloaded file: \(error.localizedDescription)")
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

// Add MD5 extension for URL caching
extension String {
    var md5: String {
        let length = Int(CC_MD5_DIGEST_LENGTH)
        var digest = [UInt8](repeating: 0, count: length)
        
        if let data = self.data(using: .utf8) {
            _ = data.withUnsafeBytes { body -> UInt8 in
                CC_MD5(body.baseAddress, CC_LONG(data.count), &digest)
                return 0
            }
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    PDFListViewController()
}

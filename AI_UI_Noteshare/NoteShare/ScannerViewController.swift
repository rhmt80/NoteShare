import UIKit
import PDFKit
import VisionKit

class PDFScannerViewController: UIViewController {
    private var scannedDocuments: [ScannedDocument] = []
    
    private let backButton: UIButton = {
            let button = UIButton(type: .system)
            button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            button.tintColor = .systemBlue
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }()
    
    private let collectionView: UICollectionView = {
            let layout = UICollectionViewFlowLayout()
            layout.scrollDirection = .vertical
            layout.itemSize = CGSize(width: (UIScreen.main.bounds.width - 48) / 2, height: 250)
            layout.minimumInteritemSpacing = 16
            layout.minimumLineSpacing = 16
            layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            
            let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
            collectionView.backgroundColor = .clear
            collectionView.translatesAutoresizingMaskIntoConstraints = false
            return collectionView
        }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        loadSavedDocuments()
    }
    
    private func setupUI() {
        title = "PDF Scanner"
        view.backgroundColor = .systemBackground
        
        navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: "chevron.left"),
                style: .plain,
                target: self,
                action: #selector(navigateToFavorites)
            )
            
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "chevron.left"),
                    style: .plain,
                    target: self,
                    action: #selector(backButtonTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(startScanning)
        )
        
        view.addSubview(collectionView)
                
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ScannedDocumentCell.self, forCellWithReuseIdentifier: "ScannedDocumentCell")
    }
    @objc private func navigateToFavorites() {
        let favouriteVC = FavouriteViewController()
        
        if let navigationController = self.navigationController {
            var viewControllers = navigationController.viewControllers
            viewControllers.removeLast()
            viewControllers.append(favouriteVC)
            navigationController.setViewControllers(viewControllers, animated: true)
        } else {
            favouriteVC.modalPresentationStyle = .fullScreen
            present(favouriteVC, animated: true, completion: nil)
        }
    }
    
    @objc private func backButtonTapped() {
            navigationController?.popViewController(animated: true)
        }
    
    @objc private func startScanning() {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(title: "Not Supported", message: "Document scanning is not available on this device.")
            return
        }
        
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        present(scannerViewController, animated: true)
    }
    
    private func loadSavedDocuments() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: documentsPath,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )
            
            let pdfURLs = fileURLs.filter { $0.pathExtension.lowercased() == "pdf" }
            
            scannedDocuments = pdfURLs.compactMap { url in
                guard let pdfDocument = PDFDocument(url: url) else { return nil }
                
                let thumbnail = pdfDocument.page(at: 0)?.thumbnail(of: CGSize(width: 200, height: 200), for: .mediaBox) ?? UIImage()
                
                return ScannedDocument(
                    title: url.deletingPathExtension().lastPathComponent,
                    pdfUrl: url,
                    thumbnailImage: thumbnail,
                    numberOfPages: pdfDocument.pageCount
                )
            }
            
            scannedDocuments.sort { $0.dateCreated > $1.dateCreated }
            collectionView.reloadData()
            
        } catch {
            print("Error loading documents: \(error)")
        }
    }
    
    private func saveScannedDocument(from scan: VNDocumentCameraScan) {
        let pdfDocument = PDFDocument()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        
        for pageIndex in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: pageIndex)
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: pageIndex)
        }
        
        let fileName = "Scan_\(dateFormatter.string(from: Date())).pdf"
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let pdfUrl = documentsPath.appendingPathComponent(fileName)
        
        guard pdfDocument.write(to: pdfUrl) else {
            showAlert(title: "Error", message: "Failed to save the scanned document.")
            return
        }
        
        let thumbnail = scan.imageOfPage(at: 0)
        
        let document = ScannedDocument(
            title: fileName.replacingOccurrences(of: ".pdf", with: ""),
            pdfUrl: pdfUrl,
            thumbnailImage: thumbnail,
            numberOfPages: scan.pageCount
        )
        
        scannedDocuments.insert(document, at: 0)
        collectionView.reloadData()
    }
    
    fileprivate func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    fileprivate func   updatePDF(document: ScannedDocument, with newPages: [UIImage]) {
        guard let pdfDocument = PDFDocument(url: document.pdfUrl) else { return }
        
        
        for image in newPages {
            guard let newPage = PDFPage(image: image) else { continue }
            pdfDocument.insert(newPage, at: pdfDocument.pageCount)
        }
        
    
        pdfDocument.write(to: document.pdfUrl)
    
        loadSavedDocuments()
    }
}

extension PDFScannerViewController: VNDocumentCameraViewControllerDelegate {
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) {
            self.saveScannedDocument(from: scan)
        }
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) {
            self.showAlert(title: "Scanning Failed", message: error.localizedDescription)
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource & Delegate
extension PDFScannerViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return scannedDocuments.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ScannedDocumentCell", for: indexPath) as? ScannedDocumentCell else {
            return UICollectionViewCell()
        }
        
        let document = scannedDocuments[indexPath.item]
        cell.configure(with: document)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let document = scannedDocuments[indexPath.item]
        let pdfViewController = PDFViewController(document: document)
        navigationController?.pushViewController(pdfViewController, animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let document = scannedDocuments[indexPath.item]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addPages = UIAction(title: "Add Pages", image: UIImage(systemName: "plus.rectangle.on.rectangle")) { [weak self] _ in
                self?.startScanningToAddPages(to: document)
            }
            
            let viewPDF = UIAction(title: "View PDF", image: UIImage(systemName: "doc.text")) { [weak self] _ in
                let pdfViewController = PDFViewController(document: document)
                self?.navigationController?.pushViewController(pdfViewController, animated: true)
            }
            
            let share = UIAction(title: "Share", image: UIImage(systemName: "square.and.arrow.up")) { [weak self] _ in
                self?.shareDocument(document)
            }
            
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.deleteDocument(document)
            }
            
            return UIMenu(children: [addPages, viewPDF, share, delete])
        }
    }
    
    private func startScanningToAddPages(to document: ScannedDocument) {
        guard VNDocumentCameraViewController.isSupported else {
            showAlert(title: "Not Supported", message: "Document scanning is not available on this device.")
            return
        }
        
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = AddPagesDelegate(parentViewController: self, originalDocument: document)
        present(scannerViewController, animated: true)
    }
    
    private func shareDocument(_ document: ScannedDocument) {
        let activityViewController = UIActivityViewController(
            activityItems: [document.pdfUrl],
            applicationActivities: nil
        )
        
        present(activityViewController, animated: true)
    }
    
    private func deleteDocument(_ document: ScannedDocument) {
        do {
            try FileManager.default.removeItem(at: document.pdfUrl)
            loadSavedDocuments()
        } catch {
            showAlert(title: "Delete Failed", message: error.localizedDescription)
        }
    }
}

class AddPagesDelegate: NSObject, VNDocumentCameraViewControllerDelegate {
    private weak var parentViewController: PDFScannerViewController?
    private let originalDocument: ScannedDocument
    
    init(parentViewController: PDFScannerViewController, originalDocument: ScannedDocument) {
        self.parentViewController = parentViewController
        self.originalDocument = originalDocument
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self, let parentVC = parentViewController else { return }
            
            let newPages = (0..<scan.pageCount).map { scan.imageOfPage(at: $0) }
            parentVC.updatePDF(document: originalDocument, with: newPages)
        }
    }
    
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
    
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) { [weak self] in
            self?.parentViewController?.showAlert(title: "Scanning Failed", message: error.localizedDescription)
        }
    }
}

class ScannedDocumentCell: UICollectionViewCell {
        private let thumbnailImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = .systemGray6
            imageView.layer.cornerRadius = 8
            imageView.clipsToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            return imageView
        }()

        private let titleLabel: UILabel = {
            let label = UILabel()
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .label
            label.numberOfLines = 2
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()

        private let pageCountLabel: UILabel = {
            let label = UILabel()
            label.font = .systemFont(ofSize: 12, weight: .regular)
            label.textColor = .secondaryLabel
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
            backgroundColor = .systemBackground
            layer.cornerRadius = 12
            layer.borderWidth = 1
            layer.borderColor = UIColor.systemGray5.cgColor

            contentView.addSubview(thumbnailImageView)
            contentView.addSubview(titleLabel)
            contentView.addSubview(pageCountLabel)

            NSLayoutConstraint.activate([
                thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
                thumbnailImageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.6),

                titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 8),
                titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

                pageCountLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
                pageCountLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
                pageCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
            ])
        }

        func configure(with document: ScannedDocument) {
            thumbnailImageView.image = document.thumbnailImage
            titleLabel.text = document.title
            pageCountLabel.text = "\(document.numberOfPages) page\(document.numberOfPages == 1 ? "" : "s")"
        }
    }



class PDFViewController: UIViewController {
    private let document: ScannedDocument
        private let pdfView: PDFView = {
            let pdfView = PDFView()
            pdfView.autoScales = true
            pdfView.displayMode = .singlePage
            pdfView.displayDirection = .vertical
            pdfView.translatesAutoresizingMaskIntoConstraints = false
            return pdfView
    }()
        

    init(document: ScannedDocument) {
            self.document = document
            super.init(nibName: nil, bundle: nil)
        }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
            super.viewDidLoad()
            setupUI()
            setupNavigationBar()
            loadPDF()
    }

    private func setupUI() {
            view.backgroundColor = .systemBackground
            view.addSubview(pdfView)
            
            NSLayoutConstraint.activate([
                pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
    }

    private func setupNavigationBar() {
        title = document.title
        navigationItem.largeTitleDisplayMode = .never
        
        navigationItem.hidesBackButton = true
           navigationItem.leftBarButtonItem = UIBarButtonItem(
               image: UIImage(systemName: "chevron.left"),
               style: .plain,
               target: self,
               action: #selector(navigateToFavorites)
           )

        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareButtonTapped)
        )

        let thumbnailButton = UIBarButtonItem(
            image: UIImage(systemName: "square.grid.2x2"),
            style: .plain,
            target: self,
            action: #selector(thumbnailButtonTapped)
        )

        navigationItem.rightBarButtonItems = [shareButton, thumbnailButton]
    }
    
    @objc private func navigateToFavorites() {
        let favouriteVC = FavouriteViewController()
        
        if let navigationController = self.navigationController {
            var viewControllers = navigationController.viewControllers
            viewControllers.removeLast()  // Remove current view controller
            viewControllers.append(favouriteVC)  // Add FavouriteViewController
            navigationController.setViewControllers(viewControllers, animated: true)
        } else {
            favouriteVC.modalPresentationStyle = .fullScreen
            present(favouriteVC, animated: true, completion: nil)
        }
    }
    @objc private func backButtonTapped() {
            navigationController?.popViewController(animated: true)
        }
    
    

    private func loadPDF() {
        if let pdfDocument = PDFDocument(url: document.pdfUrl) {
            pdfView.document = pdfDocument
            pdfView.documentView?.isUserInteractionEnabled = true
            pdfView.usePageViewController(true, withViewOptions: nil)
        } else {
            showErrorAlert()
        }
    }

    @objc private func shareButtonTapped() {
        let activityViewController = UIActivityViewController(
            activityItems: [document.pdfUrl],
            applicationActivities: nil
        )

        if let popoverController = activityViewController.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?.first
        }

        present(activityViewController, animated: true)
    }

    @objc private func thumbnailButtonTapped() {
        let thumbnailViewController = PDFThumbnailViewController(pdfView: pdfView)
        let navigationController = UINavigationController(rootViewController: thumbnailViewController)

        if let sheet = navigationController.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }

        present(navigationController, animated: true)
    }

    private func showErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Unable to load the PDF document.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}



class PDFThumbnailViewController: UIViewController {
    private let pdfView: PDFView

    private let thumbnailView: PDFThumbnailView = {
        let view = PDFThumbnailView()
        view.thumbnailSize = CGSize(width: 80, height: 120)
        view.layoutMode = .horizontal
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(pdfView: PDFView) {
        self.pdfView = pdfView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        title = "Thumbnails"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
                    image: UIImage(systemName: "chevron.left"),
                    style: .plain,
                    target: self,
                    action: #selector(doneButtonTapped)
        )

        view.addSubview(thumbnailView)
        thumbnailView.pdfView = pdfView

        NSLayoutConstraint.activate([
            thumbnailView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            thumbnailView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            thumbnailView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(doneButtonTapped)
        )
    }

    @objc private func doneButtonTapped() {
        dismiss(animated: true)
    }
}

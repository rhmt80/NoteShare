import UIKit
import PDFKit
import FirebaseFirestore
import SwiftUI
import Firebase
import FirebaseCore

class PDFViewerViewController: UIViewController, UIScrollViewDelegate, PDFViewDelegate {
    // MARK: - Loading State Management
    private enum LoadingState {
        case notStarted, loading, loaded, failed
    }
    
    private var loadingState: LoadingState = .notStarted {
        didSet {
            updateLoadingIndicator()
        }
    }
    
    private func updateLoadingIndicator() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.loadingState {
            case .loading:
                if !self.activityIndicator.isAnimating {
                    self.activityIndicator.startAnimating()
                    if self.activityIndicator.superview == nil {
                        self.contentContainerView.addSubview(self.activityIndicator)
                        NSLayoutConstraint.activate([
                            self.activityIndicator.centerXAnchor.constraint(equalTo: self.contentContainerView.centerXAnchor),
                            self.activityIndicator.centerYAnchor.constraint(equalTo: self.contentContainerView.centerYAnchor)
                        ])
                    }
                    
                    // Add a failsafe timer to prevent eternal loading
                    DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
                        guard let self = self else { return }
                        if self.loadingState == .loading {
                            if self.isPDFActuallyDisplaying() {
                                self.loadingState = .loaded
                            } else {
                                self.loadingState = .failed
                            }
                        }
                    }
                }
            case .loaded, .failed, .notStarted:
                self.activityIndicator.stopAnimating()
            }
        }
    }
    
    // MARK: - Properties
    private var pdfView: PDFView = {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }()
    
    private let scrollView: UIScrollView = {
            let scrollView = UIScrollView()
            scrollView.backgroundColor = .systemGray6  // Changed from .white
            scrollView.showsVerticalScrollIndicator = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.bounces = true
            scrollView.alwaysBounceVertical = true
            return scrollView
        }()
    
    private let contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private var headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    
    private var shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var optionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let metadataView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    private let testKnowledgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.darkGray.withAlphaComponent(0.4).cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let testKnowledgeLabel: UILabel = {
        let label = UILabel()
        label.text = "Get AI Assistance"
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let doubtsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("NoteBuddy", for: .normal)
        let sparklesConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 0)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        button.tintColor = UIColor.systemPurple
        button.backgroundColor = .white
        button.layer.cornerRadius = 18
        button.clipsToBounds = true
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let courseContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let courseIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "folder.fill")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let courseNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .systemBlue
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let universityContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let universityIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "building.columns.fill")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let universityNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let dividerLine: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.darkGray
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    private let contentContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var pdfContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.layer.cornerRadius = 20
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Data Properties
    private var pdfURL: URL
    private var documentTitle: String
    private var courseName: String
    private var universityName: String
    private var uploader: String
    private var documentMetadata: [String: Any]?
    private var documentId: String?
    private let db = Firestore.firestore()
    
    // MARK: - Additional Properties
//    private var isMetadataCollapsed = false
//    private var metadataHeightConstraint: NSLayoutConstraint?
//    private let collapsedMetadataHeight: CGFloat = 60 // Just enough for the test knowledge container

    // Additional metadata labels
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let categoryIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "tag.fill")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let categoryContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let uploadDateLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let uploadDateIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "calendar")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let uploadDateContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let fileSizeIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "doc.fill")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let fileSizeContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let uploaderLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let uploaderIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.fill")
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    private let uploaderContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // Error handling properties
    private var isShowingErrorAlert = false
    private var lastErrorMessage: String?
    private var errorRetryCount = 0
    private var hasSuccessfullyLoadedPDF = false
    private var isAttemptingToLoadPDF = false // Track if we're actively loading to prevent premature errors
    
    // MARK: - Initialization
    init(pdfURL: URL, title: String = "Unknown", course: String = "Unknown", university: String = "Unknown", uploader: String = "Unknown", metadata: [String: Any]? = nil, documentId: String? = nil) {
        self.pdfURL = pdfURL
        self.documentTitle = title
        self.courseName = course
        self.universityName = university
        self.uploader = uploader
        self.documentMetadata = metadata
        self.documentId = documentId
        super.init(nibName: nil, bundle: nil)
    }
    
    // Convenience initializer for Firebase documents
    convenience init(documentId: String) {
        print("🚀 Initializing PDFViewerViewController with document ID: \(documentId)")
        print("🔍 Document ID Debug - Length: \(documentId.count), Value: \(documentId)")
        if documentId.isEmpty {
            print("⚠️ WARNING: Empty document ID was passed to initializer")
        }
        
        // Check if the ID looks like a valid Firestore ID
        let validIdPattern = "^[a-zA-Z0-9]+$"
        if let regex = try? NSRegularExpression(pattern: validIdPattern),
           regex.numberOfMatches(in: documentId, range: NSRange(location: 0, length: documentId.count)) == 0 {
            print("⚠️ WARNING: Document ID does not match expected Firestore ID pattern")
        }
        
        // Log the stack trace to see where this is being called from
        print("🔍 Call stack: \(Thread.callStackSymbols)")
        
        // Initialize with placeholder values that will be replaced with data from Firebase
        self.init(
            pdfURL: URL(fileURLWithPath: ""),
            title: "Loading...",
            course: "Loading...",
            university: "Loading...",
            uploader: "Loading...",
            documentId: documentId
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.05)
        
        // Configure views
        contentStackView.spacing = 0 // Remove spacing between elements
//        contentStackView.backgroundColor = .black // Set background to black
//        metadataView.backgroundColor = .black // Set metadata background to black
        
        // Set up the header
        headerView.backgroundColor = .clear
        
        // Set up PDF view
        pdfView.displayMode = .singlePageContinuous
        pdfView.autoScales = true
        pdfView.displayDirection = .vertical
        pdfView.usePageViewController(false)
        pdfView.backgroundColor = .black
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) // No page breaks
        pdfView.displaysPageBreaks = false // Hide page breaks
        pdfView.layer.cornerRadius = 20
        pdfView.layer.masksToBounds = true
        pdfView.clipsToBounds = true
        
        // Set default values for error handling
        isShowingErrorAlert = false
        hasSuccessfullyLoadedPDF = false
        loadingState = .notStarted
        
        view.backgroundColor = .black
        
        // Setup notification observer for PDF errors
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePDFKitError(_:)),
            name: NSNotification.Name.PDFDocumentDidUnlock,
            object: nil
        )
        
        // Setup observer for PDF page change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePageChange(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: nil
        )
        
        // Ensure Firebase is properly initialized
        print("🔥 Ensuring Firebase initialization")
        if FirebaseApp.app() == nil {
            print("🔥 Firebase app was nil, attempting to configure with default options")
            FirebaseApp.configure()
        }
        
        // Verify Firestore access with detailed error reporting
        print("🔥 Verifying Firestore access")
        let testRef = Firestore.firestore().collection("pdfs").limit(to: 1)
        testRef.getDocuments { snapshot, error in
            if let error = error {
                print("❌ Firestore connectivity test failed: \(error.localizedDescription)")
                
                // Check for permission-related errors
                if let nsError = error as NSError?, nsError.domain == "FIRFirestoreErrorDomain" {
                    if nsError.code == 7 { // PERMISSION_DENIED
                        print("🔐 Permission denied! Please check Firebase Security Rules.")
                    }
                }
            } else {
                print("✅ Firestore connectivity test passed. Document count: \(snapshot?.documents.count ?? 0)")
            }
        }
        
        // Initialize UI components
        setupUI()
        
        // Setup header view
        setupHeaderView()
        
        // Setup constraints
        setupConstraints()
        
        // Set backgrounds appropriately
        setAppropriateBackgrounds()
        
        // Ensure test knowledge container styling is applied
        applyTestKnowledgeContainerStyling()
        
        // Configure scrolling behavior for unified experience
        scrollView.delegate = self
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = true
        
        // Make sure to update the PDF position when scrolling
        scrollView.scrollsToTop = true
        
        // Hide the navigation bar for a fullscreen experience
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Initialize page indicator
        
        // Initialize metadata labels with default values
        titleLabel.text = documentTitle
        courseNameLabel.text = courseName
        universityNameLabel.text = universityName
        categoryLabel.text = "Not specified"
        uploadDateLabel.text = "Unknown date"
        fileSizeLabel.text = "Unknown size"
        uploaderLabel.text = uploader
        
        // Add page change notification observer
        NotificationCenter.default.addObserver(self,
                                              selector: #selector(handlePageChange(_:)),
                                              name: .PDFViewPageChanged,
                                              object: pdfView)
        
        // If document ID is provided, fetch document data from Firebase
        if let documentId = documentId, !documentId.isEmpty {
            print("📄 Document ID provided: \(documentId)")
            fetchDocumentDataFromFirebase(documentId: documentId)
        } else if let extractedId = extractDocumentIdFromURL(pdfURL) {
            // Try to extract document ID from URL if not explicitly provided
            print("📄 Document ID extracted from URL: \(extractedId)")
            self.documentId = extractedId
            fetchDocumentDataFromFirebase(documentId: extractedId)
        } else {
            print("⚠️ No document ID available, loading PDF without metadata")
            // Ensure PDF URL is valid
            if pdfURL.path.isEmpty {
                showErrorAlert(message: "No PDF URL provided")
                return
            }
            loadPDF()
        }
    }
    
    // Helper method to extract document ID from URL if possible
    private func extractDocumentIdFromURL(_ url: URL) -> String? {
        print("🔍 Attempting to extract document ID from URL: \(url.path)")
        
        // Check for Firebase Storage URL pattern
        // Example: .../pdfs/tZwfxaOUyDOE6R2WRWQkIqn1SZB2/...
        if url.path.contains("/pdfs/") {
            // Extract the segment after "/pdfs/"
            let components = url.path.components(separatedBy: "/pdfs/")
            if components.count > 1 {
                let afterPdfs = components[1]
                // Extract the first segment which might be the document ID or user ID
                if let firstSegment = afterPdfs.components(separatedBy: "/").first, !firstSegment.isEmpty {
                    print("📄 Possible document ID from URL path: \(firstSegment)")
                    return firstSegment
                }
            }
        }
        
        // Check if the base64-encoded filename contains a document ID
        // The URL appears to be base64 encoded, we can try to decode it
        let filename = url.lastPathComponent
        if filename.contains("==") || filename.contains("=") {
            if let decodedData = Data(base64Encoded: filename.replacingOccurrences(of: ".pdf", with: "")),
               let decodedString = String(data: decodedData, encoding: .utf8) {
                print("📄 Base64 decoded URL: \(decodedString)")
                
                // Try to extract a document ID from the decoded string
                // Look for patterns like /pdfs/{docId}/
                if decodedString.contains("/pdfs/") {
                    let components = decodedString.components(separatedBy: "/pdfs/")
                    if components.count > 1 {
                        let afterPdfs = components[1]
                        if let firstSegment = afterPdfs.components(separatedBy: "/").first, !firstSegment.isEmpty {
                            print("📄 Document ID from decoded URL: \(firstSegment)")
                            return firstSegment
                        }
                    }
                }
            }
        }
        
        print("⚠️ Could not extract document ID from URL")
        return nil
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Ensure proper z-index hierarchy
        view.bringSubviewToFront(headerView)
        
        // Configure scrollView frame
        let headerHeight = headerView.frame.height
        let availableHeight = view.bounds.height - headerHeight
        scrollView.frame = CGRect(x: 0, y: headerHeight, width: view.bounds.width, height: availableHeight)
        
        // Ensure contentStackView fills scrollView width
        contentStackView.frame.size.width = scrollView.bounds.width
        
        // Style header view
        headerView.layer.cornerRadius = 25
        headerView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        
        // Update PDF view layout if document exists
        if let document = pdfView.document {
            // Set backgrounds
            contentContainerView.backgroundColor = .black
            scrollView.backgroundColor = .black
            contentStackView.backgroundColor = .black
            
            // Configure PDF view
            pdfView.displayMode = .singlePageContinuous
            pdfView.displayDirection = .vertical
            pdfView.autoScales = true
            
            // Calculate and set proper scale
            if let firstPage = document.page(at: 0) {
                let pageSize = firstPage.bounds(for: .mediaBox)
                let availableWidth = pdfView.bounds.width - 20 // Account for padding
                let scaleFactor = availableWidth / pageSize.width
                pdfView.scaleFactor = scaleFactor
            }
            
            // Force layout updates
            pdfView.layoutDocumentView()
            pdfView.setNeedsDisplay()
            
            // Ensure page breaks are visible
            pdfView.displaysPageBreaks = true
            pdfView.pageBreakMargins = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
            
            // Disable internal scrolling
            if let pdfScrollView = findScrollView(in: pdfView) {
                pdfScrollView.isScrollEnabled = false
                pdfScrollView.bounces = false
            }
            
            // Update content size
            updateScrollViewContentSize()
            
            // Ensure everything is visible
            ensurePDFViewIsVisible()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure proper view hierarchy with header on top
        view.bringSubviewToFront(headerView)
        headerView.layer.zPosition = 100 // Ensure header is above all content
        
        // Force proper background color for container views
        scrollView.backgroundColor = .black
        contentStackView.backgroundColor = .black
        
        // Ensure test knowledge container styling is applied
        applyTestKnowledgeContainerStyling()
        
        // Load PDF when view appears
        loadPDF()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Make sure activity indicator is not running indefinitely when PDF is visible
        if isPDFActuallyDisplaying() {
            loadingState = .loaded
            hasSuccessfullyLoadedPDF = true
        }
        
        // Apply the test knowledge container styling again
        applyTestKnowledgeContainerStyling()
        
        // Refresh PDF rendering after view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.refreshPDFView()
            
            // Ensure proper scrolling setup
            if let pdfScrollView = self.findScrollView(in: self.pdfView) {
                pdfScrollView.isScrollEnabled = false
                pdfScrollView.bounces = false
            }
            
            // Force content size update for main scroll view
            self.updateScrollViewContentSize()
            self.scrollView.layoutIfNeeded()
            
            // Make sure everything is visible
            self.ensurePDFViewIsVisible()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Always stop the activity indicator when leaving the view
        loadingState = .notStarted
        
        // ... existing code ...
    }
    
    // Helper method to ensure consistent styling of test knowledge container
    private func applyTestKnowledgeContainerStyling() {
        testKnowledgeContainer.layer.cornerRadius = 20
        testKnowledgeContainer.layer.borderWidth = 1
        testKnowledgeContainer.layer.borderColor = UIColor.darkGray.withAlphaComponent(0.4).cgColor
        testKnowledgeContainer.backgroundColor = .black
        testKnowledgeContainer.clipsToBounds = true
        
        // Force layout update
        testKnowledgeContainer.setNeedsLayout()
        testKnowledgeContainer.layoutIfNeeded()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Set view background
        view.backgroundColor = .black
        
        // Setup header view with nav controls - fixed at the top
        view.addSubview(headerView)
        headerView.addSubview(backButton)
        headerView.addSubview(optionsButton)
        headerView.addSubview(shareButton)
        
        // Add content container below header
        view.addSubview(contentContainerView)
        contentContainerView.backgroundColor = .black
        
        // Configure scroll view to fill content container
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainerView.addSubview(scrollView)
        scrollView.backgroundColor = .black
        
        // Add content stack view to scroll view
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.distribution = .fill
        contentStackView.spacing = 0 // No spacing between elements
        contentStackView.backgroundColor = .black // Ensure background is black
        scrollView.addSubview(contentStackView)
        
        // Add metadata view to content stack view
        metadataView.translatesAutoresizingMaskIntoConstraints = false
        metadataView.backgroundColor = .black
        contentStackView.addArrangedSubview(metadataView)
        
        // Add the test knowledge container to the metadata view
        metadataView.addSubview(testKnowledgeContainer)
        
        // Add metadata subviews
        testKnowledgeContainer.addSubview(testKnowledgeLabel)
        testKnowledgeContainer.addSubview(doubtsButton)
        metadataView.addSubview(titleLabel)
        
        // Add divider line
        metadataView.addSubview(dividerLine)
        
        // Add course and university containers with their subviews
        metadataView.addSubview(courseContainer)
        courseContainer.addSubview(courseIconView)
        courseContainer.addSubview(courseNameLabel)
        
        metadataView.addSubview(universityContainer)
        universityContainer.addSubview(universityIconView)
        universityContainer.addSubview(universityNameLabel)
        
        // Add new metadata containers
        // Category container
        metadataView.addSubview(categoryContainer)
        categoryContainer.addSubview(categoryIconView)
        categoryContainer.addSubview(categoryLabel)
        
        // Upload date container
        metadataView.addSubview(uploadDateContainer)
        uploadDateContainer.addSubview(uploadDateIconView)
        uploadDateContainer.addSubview(uploadDateLabel)
        
        // File size container
        metadataView.addSubview(fileSizeContainer)
        fileSizeContainer.addSubview(fileSizeIconView)
        fileSizeContainer.addSubview(fileSizeLabel)
        
        // Uploader container
        metadataView.addSubview(uploaderContainer)
        uploaderContainer.addSubview(uploaderIconView)
        uploaderContainer.addSubview(uploaderLabel)
        
        
        // Note: pdfView will be added to contentStackView in loadPDF method
        
        // Setup activity indicator but don't add to view yet
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true
        activityIndicator.style = .large
        activityIndicator.color = .gray
        
        // Setup constraints for test knowledge container
        NSLayoutConstraint.activate([
            testKnowledgeContainer.topAnchor.constraint(equalTo: metadataView.topAnchor, constant: 20),
            testKnowledgeContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            testKnowledgeContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            testKnowledgeContainer.heightAnchor.constraint(equalToConstant: 60),
            
            testKnowledgeLabel.leadingAnchor.constraint(equalTo: testKnowledgeContainer.leadingAnchor, constant: 20),
            testKnowledgeLabel.centerYAnchor.constraint(equalTo: testKnowledgeContainer.centerYAnchor),
            
            doubtsButton.trailingAnchor.constraint(equalTo: testKnowledgeContainer.trailingAnchor, constant: -20),
            doubtsButton.centerYAnchor.constraint(equalTo: testKnowledgeContainer.centerYAnchor),
            doubtsButton.widthAnchor.constraint(equalToConstant: 120),
            doubtsButton.heightAnchor.constraint(equalToConstant: 36),
            
            // Add constraints for the divider line
            dividerLine.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            dividerLine.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            dividerLine.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            dividerLine.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // Setup constraints
        setupConstraints()
        setupActions()
    }
    
    private func setupHeaderView() {
        // Create header view with black background
        headerView = UIView()
        headerView.backgroundColor = .black
        headerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerView)
        
        // Back button
        backButton = UIButton(type: .system)
        backButton.tintColor = .white
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(backButton)
     
        
        // Share button
        shareButton = UIButton(type: .system)
        shareButton.tintColor = .white
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(shareButton)
        
        // Menu button
        optionsButton = UIButton(type: .system)
        optionsButton.tintColor = .white
        optionsButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        optionsButton.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)
        optionsButton.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(optionsButton)
        
        // Set constraints for header view
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 40),
            backButton.heightAnchor.constraint(equalToConstant: 40),
        
            shareButton.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -8),
            shareButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 40),
            shareButton.heightAnchor.constraint(equalToConstant: 40),
            
            optionsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            optionsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 40),
            optionsButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    private func setupConstraints() {
        // Setup scroll view constraints to fill the view below the header
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Setup content stack view constraints
        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        
        NSLayoutConstraint.activate([
            metadataView.heightAnchor.constraint(equalToConstant: 420),
            
            // Header View Constraints - Fixed at the top
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60),
            
            // Back Button Constraints
            backButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Share Button Constraints
            shareButton.trailingAnchor.constraint(equalTo: optionsButton.leadingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            shareButton.widthAnchor.constraint(equalToConstant: 30),
            shareButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Options Button Constraints
            optionsButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            optionsButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            optionsButton.widthAnchor.constraint(equalToConstant: 30),
            optionsButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Content Container View Constraints - Ensure it's below header
            contentContainerView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            contentContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            // Test knowledge container constraints
            testKnowledgeContainer.topAnchor.constraint(equalTo: metadataView.topAnchor, constant: 20),
                        testKnowledgeContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
                        testKnowledgeContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
                        testKnowledgeContainer.heightAnchor.constraint(equalToConstant: 60),
                        
                        testKnowledgeLabel.leadingAnchor.constraint(equalTo: testKnowledgeContainer.leadingAnchor, constant: 20),
                        testKnowledgeLabel.centerYAnchor.constraint(equalTo: testKnowledgeContainer.centerYAnchor),
                        
                        doubtsButton.trailingAnchor.constraint(equalTo: testKnowledgeContainer.trailingAnchor, constant: -20),
                        doubtsButton.centerYAnchor.constraint(equalTo: testKnowledgeContainer.centerYAnchor),
                        doubtsButton.widthAnchor.constraint(equalToConstant: 120),
                        doubtsButton.heightAnchor.constraint(equalToConstant: 36),
                        
                        titleLabel.topAnchor.constraint(equalTo: testKnowledgeContainer.bottomAnchor, constant: 24),
                        titleLabel.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
                        titleLabel.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
                        
                        dividerLine.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
                        dividerLine.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
                        dividerLine.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
                        dividerLine.heightAnchor.constraint(equalToConstant: 1),
            
            // Course Container Constraints
            courseContainer.topAnchor.constraint(equalTo: dividerLine.bottomAnchor, constant: 24),
            courseContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            courseContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            courseContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // Course Icon Constraints
            courseIconView.leadingAnchor.constraint(equalTo: courseContainer.leadingAnchor),
            courseIconView.centerYAnchor.constraint(equalTo: courseContainer.centerYAnchor),
            courseIconView.widthAnchor.constraint(equalToConstant: 28),
            courseIconView.heightAnchor.constraint(equalToConstant: 28),
            
            // Course Name Constraints
            courseNameLabel.leadingAnchor.constraint(equalTo: courseIconView.trailingAnchor, constant: 16),
            courseNameLabel.centerYAnchor.constraint(equalTo: courseContainer.centerYAnchor),
            
            // University Container Constraints
            universityContainer.topAnchor.constraint(equalTo: courseContainer.bottomAnchor, constant: 20),
            universityContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            universityContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            universityContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // University Icon Constraints
            universityIconView.leadingAnchor.constraint(equalTo: universityContainer.leadingAnchor),
            universityIconView.centerYAnchor.constraint(equalTo: universityContainer.centerYAnchor),
            universityIconView.widthAnchor.constraint(equalToConstant: 28),
            universityIconView.heightAnchor.constraint(equalToConstant: 28),
            
            // University Name Constraints
            universityNameLabel.leadingAnchor.constraint(equalTo: universityIconView.trailingAnchor, constant: 16),
            universityNameLabel.centerYAnchor.constraint(equalTo: universityContainer.centerYAnchor),
            universityNameLabel.trailingAnchor.constraint(equalTo: universityContainer.trailingAnchor, constant: -20),
            
            // Category Container Constraints
            categoryContainer.topAnchor.constraint(equalTo: universityContainer.bottomAnchor, constant: 20),
            categoryContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            categoryContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            categoryContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // Category Icon Constraints
            categoryIconView.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor),
            categoryIconView.centerYAnchor.constraint(equalTo: categoryContainer.centerYAnchor),
            categoryIconView.widthAnchor.constraint(equalToConstant: 28),
            categoryIconView.heightAnchor.constraint(equalToConstant: 28),
            
            // Category Label Constraints
            categoryLabel.leadingAnchor.constraint(equalTo: categoryIconView.trailingAnchor, constant: 16),
            categoryLabel.centerYAnchor.constraint(equalTo: categoryContainer.centerYAnchor),
            
            // Uploader Container Constraints
            uploaderContainer.topAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: 20),
            uploaderContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            uploaderContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            uploaderContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // Uploader Icon Constraints
            uploaderIconView.leadingAnchor.constraint(equalTo: uploaderContainer.leadingAnchor),
            uploaderIconView.centerYAnchor.constraint(equalTo: uploaderContainer.centerYAnchor),
            uploaderIconView.widthAnchor.constraint(equalToConstant: 28),
            uploaderIconView.heightAnchor.constraint(equalToConstant: 28),
            
            // Uploader Label Constraints
            uploaderLabel.leadingAnchor.constraint(equalTo: uploaderIconView.trailingAnchor, constant: 16),
            uploaderLabel.centerYAnchor.constraint(equalTo: uploaderContainer.centerYAnchor),
            
            // Upload Date Container Constraints
            uploadDateContainer.topAnchor.constraint(equalTo: uploaderContainer.bottomAnchor, constant: 20),
            uploadDateContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
            uploadDateContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
            uploadDateContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // Upload Date Icon Constraints
            uploadDateIconView.leadingAnchor.constraint(equalTo: uploadDateContainer.leadingAnchor),
            uploadDateIconView.centerYAnchor.constraint(equalTo: uploadDateContainer.centerYAnchor),
            uploadDateIconView.widthAnchor.constraint(equalToConstant: 28),
            uploadDateIconView.heightAnchor.constraint(equalToConstant: 28),
            
            // Upload Date Label Constraints
            uploadDateLabel.leadingAnchor.constraint(equalTo: uploadDateIconView.trailingAnchor, constant: 16),
            uploadDateLabel.centerYAnchor.constraint(equalTo: uploadDateContainer.centerYAnchor),
            
            // File Size Container Constraints
            fileSizeContainer.topAnchor.constraint(equalTo: uploadDateContainer.bottomAnchor, constant: 20),
                        fileSizeContainer.leadingAnchor.constraint(equalTo: metadataView.leadingAnchor, constant: 20),
                        fileSizeContainer.trailingAnchor.constraint(equalTo: metadataView.trailingAnchor, constant: -20),
                        fileSizeContainer.heightAnchor.constraint(equalToConstant: 32),
                        
                        fileSizeIconView.leadingAnchor.constraint(equalTo: fileSizeContainer.leadingAnchor),
                        fileSizeIconView.centerYAnchor.constraint(equalTo: fileSizeContainer.centerYAnchor),
                        fileSizeIconView.widthAnchor.constraint(equalToConstant: 28),
                        fileSizeIconView.heightAnchor.constraint(equalToConstant: 28),
                        
                        fileSizeLabel.leadingAnchor.constraint(equalTo: fileSizeIconView.trailingAnchor, constant: 16),
                        fileSizeLabel.centerYAnchor.constraint(equalTo: fileSizeContainer.centerYAnchor),
                        
                        // Removed infoButton constraints
            
            
        ])
        
        // Add tap gesture to collapse/expand metadata
        testKnowledgeContainer.isUserInteractionEnabled = true
    }
    
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        shareButton.addTarget(self, action: #selector(shareButtonTapped), for: .touchUpInside)
        optionsButton.addTarget(self, action: #selector(optionsButtonTapped), for: .touchUpInside)
        doubtsButton.addTarget(self, action: #selector(doubtsButtonTapped), for: .touchUpInside)
    }
    
    private func setupGestures() {
        // Add page change detection via notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePageChange(_:)),
            name: Notification.Name.PDFViewPageChanged,
            object: nil
        )
    }
    
    private func updateMetadata() {
        // Set the main document information
        titleLabel.text = documentTitle
        courseNameLabel.text = courseName
        universityNameLabel.text = universityName
        uploaderLabel.text = uploader
        
        // Format and set category
        if let category = documentMetadata?["category"] as? String, !category.isEmpty {
            categoryLabel.text = category
        } else {
            categoryLabel.text = "Not specified"
        }
        
        // Format and set upload date
        if let uploadTimestamp = documentMetadata?["uploadDate"] as? Timestamp {
            let date = uploadTimestamp.dateValue()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            uploadDateLabel.text = formatter.string(from: date)
        } else {
            uploadDateLabel.text = "Unknown date"
        }
        
        // Format and set file size
        if let fileSize = documentMetadata?["fileSize"] as? Int64 {
            if fileSize < 1024 {
                fileSizeLabel.text = "\(fileSize) B"
            } else if fileSize < 1024 * 1024 {
                let sizeInKB = Double(fileSize) / 1024.0
                fileSizeLabel.text = String(format: "%.0f KB", sizeInKB)
            } else {
                let sizeInMB = Double(fileSize) / (1024.0 * 1024.0)
                fileSizeLabel.text = String(format: "%.1f MB", sizeInMB)
            }
        } else {
            fileSizeLabel.text = "Unknown size"
        }
        
        // Ensure metadata is visible
        titleLabel.alpha = 1
        courseNameLabel.alpha = 1
        universityNameLabel.alpha = 1
        uploaderLabel.alpha = 1
        categoryLabel.alpha = 1
        uploadDateLabel.alpha = 1
        fileSizeLabel.alpha = 1
        
        // Force layout update
        metadataView.setNeedsLayout()
        metadataView.layoutIfNeeded()
    }
    
    // MARK: - PDF Loading
    private func loadPDF() {
        print("📄 Loading PDF from URL: \(pdfURL)")
        print("📄 URL path exists: \(FileManager.default.fileExists(atPath: pdfURL.path))")
        print("📄 Is file URL: \(pdfURL.isFileURL), scheme: \(pdfURL.scheme ?? "none")")
        
        // Validate the URL first
        if pdfURL.path.isEmpty {
            print("🚫 Empty PDF URL path")
            showErrorAlert(message: "No PDF URL provided")
            loadingState = .failed
            return
        }
        
        // Mark that we're attempting to load to prevent premature errors
        isAttemptingToLoadPDF = true
        
        // Update loading state - this will automatically show the indicator
        loadingState = .loading
        
        // Remove existing PDF views
        cleanupExistingPDFViews()
        
        // Configure the PDF container view
        pdfContainerView.backgroundColor = .black
        pdfContainerView.layer.cornerRadius = 20
        pdfContainerView.clipsToBounds = true
        
        // Reset pdfView with fresh settings
        pdfView = PDFKit.PDFView()
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        pdfView.displaysPageBreaks = false
        pdfView.pageBreakMargins = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        pdfView.usePageViewController(false)
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        pdfView.maxScaleFactor = 4.0
        pdfView.layer.cornerRadius = 15
        pdfView.clipsToBounds = true
        
        // Add pdfView to container view
        pdfContainerView.addSubview(pdfView)
        
        // Add pdfContainerView to stack view
        contentStackView.addArrangedSubview(pdfContainerView)
        
        // Set constraints for the pdfView to fill the container with minimal padding
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: pdfContainerView.topAnchor, constant: 5),
            pdfView.leadingAnchor.constraint(equalTo: pdfContainerView.leadingAnchor, constant: 5),
            pdfView.trailingAnchor.constraint(equalTo: pdfContainerView.trailingAnchor, constant: -5),
            pdfView.bottomAnchor.constraint(equalTo: pdfContainerView.bottomAnchor, constant: -5)
        ])
        
        // Important: Set an explicit height for the PDF container to make it visible
        let screenHeight = UIScreen.main.bounds.height
        let pdfContainerHeightConstraint = pdfContainerView.heightAnchor.constraint(equalToConstant: screenHeight * 0.7)
        pdfContainerHeightConstraint.isActive = true
        
        // First check if we have a document ID and if the PDF is in cache
        if let documentId = self.documentId, !documentId.isEmpty {
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: documentId) {
                print("📄 Found cached PDF at path: \(cachedPDFPath.path)")
                // Update the PDF URL to use the cached version
                self.pdfURL = cachedPDFPath
                
                // Load it directly from cache
                loadPDFFromLocalFile(cachedPDFPath)
                return
            }
        }
        
        // If the URL is a web URL, download it first
        if !pdfURL.isFileURL || !FileManager.default.fileExists(atPath: pdfURL.path) {
            // URL is either remote or a local file that doesn't exist
            print("📄 URL requires download - not a file URL or file doesn't exist: \(pdfURL)")
            
            // If this is a Firebase Storage URL, handle it directly
            if pdfURL.absoluteString.contains("firebasestorage.googleapis.com") || pdfURL.absoluteString.contains("storage.googleapis.com") {
                print("📄 Detected Firebase Storage URL, fetching directly")
                fetchPDFFromURL(pdfURL)
                return
            }
            
            // Try to extract document ID from URL if possible
            if let documentId = self.documentId, !documentId.isEmpty {
                print("📄 Have document ID: \(documentId), trying to get download URL from Firebase")
                
                // Try to construct a Firebase Storage URL from the document ID
                let potentialStorageUrl = "https://firebasestorage.googleapis.com/v0/b/noteshare-13.appspot.com/o/pdfs%2F\(documentId).pdf?alt=media"
                if let url = URL(string: potentialStorageUrl) {
                    print("📥 Attempting download from constructed URL: \(potentialStorageUrl)")
                    fetchPDFFromURL(url)
                    return
                }
            }
            
            // For other types of remote URLs
            print("📄 Attempting to download from URL: \(pdfURL)")
            fetchPDFFromURL(pdfURL)
            return
        }
        
        // Here we have a valid local file URL
        loadPDFFromLocalFile(pdfURL)
    }
    
    // New method to load PDF from a local file URL
    private func loadPDFFromLocalFile(_ fileURL: URL) {
        print("📄 Loading PDF from local file URL: \(fileURL.path)")
        
        // Load PDF document on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Create a fresh document from URL to ensure we're not using cached data
            print("📄 Creating PDFDocument from URL: \(fileURL)")
            let pdfDocument = PDFDocument(url: fileURL)
            
            DispatchQueue.main.async {
                if let document = pdfDocument {
                    print("✅ Successfully loaded PDF document with \(document.pageCount) pages")
                    
                    // Set the document
                    self.pdfView.document = document
                    
                    // Configure PDFView for optimal display
                    self.configurePDFViewForDocument(document)
                    
                    print("✅ PDF successfully loaded and configured")
                } else {
                    print("❌ Failed to create PDF document from file")
//                    self.handlePDFLoadingError("Could not load PDF document")
                }
            }
        }
    }
    
    // MARK: - PDF Network Loading
    private func fetchPDFFromURL(_ url: URL) {
        print("📥 Checking for PDF in cache before downloading from URL: \(url)")
        
        // First check if we have this PDF in cache based on document ID
        if let documentId = self.documentId, !documentId.isEmpty {
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: documentId) {
                print("📄 Found cached PDF at path: \(cachedPDFPath.path)")
                // Update the PDF URL to use the cached version
                self.pdfURL = cachedPDFPath
                
                // Load it directly from cache
                loadPDFFromLocalFile(cachedPDFPath)
                return
            }
        }
        
        // Also check CacheManager for URL-based cache
        if let cachedData = CacheManager.shared.getCachedPDF(url: url) {
            print("📄 Found cached PDF data for URL: \(url)")
            
            // Create a temporary file for the cached data
            let tempDirectory = FileManager.default.temporaryDirectory
            let tempFileName = "cached-\(UUID().uuidString).pdf"
            let tempFileURL = tempDirectory.appendingPathComponent(tempFileName)
            
            do {
                try cachedData.write(to: tempFileURL)
                print("✅ Successfully wrote cached PDF data to temporary file: \(tempFileURL.path)")
                
                // Load from the temporary file
                self.pdfURL = tempFileURL
                loadPDFFromLocalFile(tempFileURL)
                return
            } catch {
                print("❌ Error writing cached data to temporary file: \(error)")
                // If we can't write to temp file, continue with download
            }
        }
        
        print("📄 PDF not found in any cache, proceeding with download from: \(url)")
        
        // Update loading state
        loadingState = .loading
        
        // Check if this is a Firebase Storage URL
        var isFirebaseURL = false
        if url.absoluteString.contains("firebasestorage.googleapis.com") ||
           url.absoluteString.contains("storage.googleapis.com") {
            print("📄 Using Firebase Storage download process")
            isFirebaseURL = true
        }
        
        // Create a session with appropriate configuration
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        let session = URLSession(configuration: config)
        
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                
                        DispatchQueue.main.async {
                    self.loadingState = .failed
                    if (error as NSError).domain == NSURLErrorDomain {
                        // Only show alert for connection errors
                        self.handlePDFLoadingError("Failed to download PDF: \(error.localizedDescription)")
                    } else {
                        // Try loading from document ID if available
                        self.tryLoadingFromDocumentId()
                    }
                }
                return
            }
            
            // Validate HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("📄 HTTP Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode >= 400 {
                    DispatchQueue.main.async {
                        self.loadingState = .failed
                        if isFirebaseURL && httpResponse.statusCode == 404 {
                            print("❌ Firebase Storage file not found, trying alternative URL format")
                            self.tryAlternativeFirebaseURL()
                        } else {
                            self.handlePDFLoadingError("Failed to download PDF (HTTP \(httpResponse.statusCode))")
                        }
                    }
                    return
                }
            }
            
            // Check for valid data
            guard let data = data, data.count > 0 else {
                print("❌ No data received")
                
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("No PDF data received")
                }
            return
        }
        
            print("✅ Received PDF data: \(data.count) bytes")
            
            // Validate that the data is actually a PDF
            if !self.isPDFData(data) {
                print("❌ Data received is not a valid PDF")
                if let dataPreview = String(data: data.prefix(100), encoding: .utf8) {
                    print("📄 Data preview: \(dataPreview)")
                }
                
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    
                    // If we get HTML or text, it might be an error message from Firebase
                    if let errorText = String(data: data, encoding: .utf8),
                       (errorText.contains("<html") || errorText.contains("error")) {
                        print("🔥 Received error page from Firebase")
                        // Try alternative loading method
                        self.tryAlternativeFirebaseURL()
            } else {
                        self.handlePDFLoadingError("The file downloaded is not a valid PDF document")
                    }
                }
                return
            }
            
            // Create a permanent file for caching
            let cacheDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            let cacheFileName = UUID().uuidString + ".pdf"
            let cacheFileURL = cacheDirectory.appendingPathComponent(cacheFileName)
            
            do {
                try data.write(to: cacheFileURL)
                print("✅ PDF saved to cache file: \(cacheFileURL.path)")
                
                // Save to document ID cache if we have a document ID
                if let documentId = self.documentId, !documentId.isEmpty {
                    print("📄 Caching PDF for document ID: \(documentId)")
                    PDFCache.shared.cachePDFPath(for: documentId, fileURL: cacheFileURL)
                }
                
                // Also save to URL-based cache
                do {
                    try CacheManager.shared.cachePDF(url: url, data: data)
                    print("✅ PDF successfully saved to URL-based cache for future use")
                } catch {
                    print("❌ Failed to save PDF to URL-based cache: \(error)")
                }
                
                // Verify the written file
                if FileManager.default.fileExists(atPath: cacheFileURL.path) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: cacheFileURL.path)
                    print("📄 Saved file size: \(attributes[.size] ?? "unknown")")
                }
                
                // Create the PDF document directly from data
                let pdfDocument = PDFDocument(data: data)
                
                // Check if the document is valid
                guard let document = pdfDocument, document.pageCount > 0 else {
                    print("⚠️ PDF document creation failed with the downloaded data")
                    
                    DispatchQueue.main.async {
                        self.loadingState = .failed
                        self.handlePDFLoadingError("The PDF appears to be invalid or corrupted")
                    }
                    return
                }
                
                print("✅ Successfully created document with \(document.pageCount) pages from downloaded data")
            
            DispatchQueue.main.async {
                    // Update PDF URL for future reference
                    self.pdfURL = cacheFileURL
                    
                    // Clear existing document
                    self.pdfView.document = nil
                    
                    // Set the new document
                    self.pdfView.document = document
                    
                    // Configure PDFView for optimal display
                    self.configurePDFViewForDocument(document)
                    
                    // Update loading state to loaded
                    self.loadingState = .loaded
                    
                    print("✅ PDF successfully loaded from download and cached")
                }
            } catch {
                print("❌ Error processing PDF file: \(error.localizedDescription)")
                        DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("Error processing PDF: \(error.localizedDescription)")
                }
            }
        }
        
        task.resume()
    }
    
    // Configure PDFView optimally for the given document
    private func configurePDFViewForDocument(_ document: PDFDocument) {
        // Ensure we're on the main thread
        assert(Thread.isMainThread)
        
        // Keep loading state until configuration is complete
        loadingState = .loading
        
        // Configure PDF view settings
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.displaysPageBreaks = true
        pdfView.pageBreakMargins = UIEdgeInsets(top: 20, left: 0, bottom: 20, right: 0)
        
        // Disable internal scrolling
        if let scrollView = findScrollView(in: pdfView) {
            scrollView.isScrollEnabled = false
            scrollView.bounces = false
        }
        
        // Calculate proper scale to fit width
        guard let firstPage = document.page(at: 0) else { return }
        
        let pageSize = firstPage.bounds(for: .mediaBox)
        let availableWidth = pdfView.bounds.width - 20 // Account for padding
        let scaleFactor = availableWidth / pageSize.width
        pdfView.scaleFactor = scaleFactor
        
        // Calculate total height for all pages
        var totalPDFHeight: CGFloat = 0
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            let pageHeight = page.bounds(for: .mediaBox).height * scaleFactor
            totalPDFHeight += pageHeight
            
            // Add gap between pages
            if i < document.pageCount - 1 {
                totalPDFHeight += 20 // Standard gap between pages
            }
        }
        
        // Add padding to total height
        totalPDFHeight += 40 // 20pt top + 20pt bottom padding
        
        // Set minimum height to screen height or total PDF height, whichever is larger
        let screenHeight = UIScreen.main.bounds.height
        let desiredHeight = max(totalPDFHeight, screenHeight)
        
        // Remove any existing height constraints from the PDF container
        for view in contentStackView.arrangedSubviews where view != metadataView {
            view.constraints.forEach { constraint in
                if constraint.firstAttribute == .height {
                    view.removeConstraint(constraint)
                }
            }
            // Add new height constraint
            let heightConstraint = view.heightAnchor.constraint(equalToConstant: desiredHeight)
            heightConstraint.isActive = true
            break
        }
        
        // Force layout updates
        view.layoutIfNeeded()
        pdfView.layoutDocumentView()
        pdfView.setNeedsDisplay()
        
        // Update scroll view content size
        updateScrollViewContentSize()
        scrollView.layoutIfNeeded()
        
        // Go to first page
        pdfView.go(to: firstPage)
        
        // Now that everything is configured, mark as loaded
        loadingState = .loaded
        hasSuccessfullyLoadedPDF = true
        isAttemptingToLoadPDF = false
        
        // Final layout refresh after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.pdfView.layoutDocumentView()
            self.updateScrollViewContentSize()
            self.ensurePDFViewIsVisible()
        }
    }
    
    // Helper method to ignore data errors
    private func ignoreDataErrors() {
        // Set flag to prevent future error alerts
        hasSuccessfullyLoadedPDF = true
        
        // We'll use a timer to check for and suppress any Data errors that might come up
        var fireCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Increment our fire counter
            fireCount += 1
            
            // Only keep the timer running for a short while after PDF is loaded
            guard fireCount < 10 else {
                timer.invalidate()
                return
            }
            
            // If an error alert with "Data" is visible, dismiss it
            if let presentedVC = self.presentedViewController as? UIAlertController,
               presentedVC.title == "Error",
               let message = presentedVC.message,
               message.contains("Data") {
                
                print("🚫 Dismissing existing 'Data' error alert because PDF is visible")
                presentedVC.dismiss(animated: true)
            }
        }
    }
    
    // Try alternative Firebase URL format if the standard one fails
    private func tryAlternativeFirebaseURL() {
        guard let documentId = self.documentId, !documentId.isEmpty else {
            print("❌ No document ID available for alternative Firebase URL")
            return
        }
        
        print("🔄 Trying alternative Firebase URL format for document: \(documentId)")
        
        // Try format with document ID only
        let formatWithoutExtension = "https://firebasestorage.googleapis.com/v0/b/noteshare-13.appspot.com/o/pdfs%2F\(documentId)?alt=media"
        if let url = URL(string: formatWithoutExtension) {
            print("🔄 Attempting alternative URL: \(formatWithoutExtension)")
            fetchPDFFromURL(url)
            return
        }
        
        // Try format with .pdf extension
        let formatWithExtension = "https://firebasestorage.googleapis.com/v0/b/noteshare-13.appspot.com/o/pdfs%2F\(documentId).pdf?alt=media"
        if let url = URL(string: formatWithExtension) {
            print("🔄 Attempting alternative URL: \(formatWithExtension)")
            fetchPDFFromURL(url)
                    return
        }
    }
    
    // Try loading from document ID if it's available
    private func tryLoadingFromDocumentId() {
        print("📝 Trying to load with document ID if available")
        
        if let documentId = documentId, !documentId.isEmpty {
            print("📝 Document ID available: \(documentId)")
            
            // First check if we already have a PDF loaded
            if isPDFActuallyDisplaying() {
                print("📄 PDF is already visible, not trying again with document ID")
                loadingState = .loaded
                return
            }
            
            // Update meta-information about document
            if documentMetadata == nil || documentMetadata!.isEmpty {
                print("📝 Fetching document metadata using ID: \(documentId)")
                fetchDocumentDataFromFirebase(documentId: documentId)
            } else {
                print("📝 Already have document metadata")
                // Try different loading approach
                self.tryAlternativeLoadingMethod()
            }
            
            // Update loading state to appropriate state
            loadingState = .loading
                    } else {
            print("❌ No document ID available for alternative loading")
            
            // Try again with a different approach
            self.tryAlternativeLoadingMethod()
        }
    }
    
    // Helper method to clean up existing PDF views before adding new ones
    private func cleanupExistingPDFViews() {
        // If pdfView already has a superview, remove it first
        if pdfView.superview != nil {
            pdfView.document = nil  // Release document reference
            pdfView.removeFromSuperview()
        }
        
        // Remove any existing PDF container from contentStackView
        for view in contentStackView.arrangedSubviews where view != metadataView {
            contentStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
    }
    
    // Helper method to refresh PDF rendering
    private func refreshPDFView() {
        guard let _ = pdfView.document else {
            print("No document available to refresh, attempting to load PDF")
            loadPDF()  // If no document is loaded, try loading it
            return
        }
        
        print("Beginning PDF refresh...")
        
        // Force a full reload of the PDF to ensure it displays correctly
        let currentURL = pdfURL
        
        // Reset the PDFView document
        pdfView.document = nil
        
        // Load fresh document from URL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            guard let freshDocument = PDFDocument(url: currentURL) else {
                print("Failed to reload PDF document during refresh")
                return
            }
            
            DispatchQueue.main.async {
                // Set the fresh document
                self.pdfView.document = freshDocument
                
                // Reset display properties
                self.pdfView.autoScales = true
                self.pdfView.displayMode = .singlePageContinuous
                self.pdfView.displayDirection = .vertical
                self.pdfView.displaysPageBreaks = true
                self.pdfView.pageBreakMargins = UIEdgeInsets(top: 32, left: 0, bottom: 32, right: 0)
                self.pdfView.minScaleFactor = self.pdfView.scaleFactorForSizeToFit
                self.pdfView.maxScaleFactor = 4.0
                
                // Ensure PDFView's internal scrolling is disabled
                if let scrollView = self.findScrollView(in: self.pdfView) {
                    scrollView.isScrollEnabled = false
                    scrollView.bounces = false
                }
                
                // Calculate proper scale to fit width
                if let firstPage = freshDocument.page(at: 0) {
                    let pageSize = firstPage.bounds(for: .mediaBox)
                    let availableWidth = self.pdfView.bounds.width
                    let scaleFactor = availableWidth / pageSize.width
                    
                    // Set scale that fits the width of the page with slight padding
                    self.pdfView.scaleFactor = scaleFactor * 0.95
                    
                    // Go to the first page
                    self.pdfView.go(to: firstPage)
                    
                    // Calculate total height for PDF content with proper gaps
                    var totalPDFHeight: CGFloat = 0
                    for i in 0..<freshDocument.pageCount {
                        if let page = freshDocument.page(at: i) {
                            let pageHeight = page.bounds(for: .mediaBox).height * self.pdfView.scaleFactor
                            totalPDFHeight += pageHeight
                        }
                    }
                    
                    // Force immediate layout updates for the PDFView
                    self.pdfView.layoutDocumentView()
                    self.pdfView.setNeedsDisplay()
                    self.pdfView.layoutIfNeeded()
                    
                    // Update content size for main scroll view
                    self.updateScrollViewContentSize()
                    self.scrollView.layoutIfNeeded()
                    
                    // Make sure everything is visible and scrollable
                    self.ensurePDFViewIsVisible()
                    
                    // Set loading state to loaded
                    self.loadingState = .loaded
                    self.hasSuccessfullyLoadedPDF = true
                }
                
            }
        }
    }
    
    private func calculatePDFContentSize(document: PDFDocument) {
        var totalHeight: CGFloat = 0
        
        // Add metadata height
        totalHeight += metadataView.frame.height + 20 // Add some spacing
        
        // Calculate PDF content height
        if document.pageCount > 0 {
            var pdfContentHeight: CGFloat = 0
            
            for i in 0..<document.pageCount {
                if let page = document.page(at: i) {
                    let pageSize = page.bounds(for: .mediaBox)
                    pdfContentHeight += pageSize.height * CGFloat(pdfView.scaleFactor)
                }
            }
            
            // Add spacing between pages
            pdfContentHeight += CGFloat(document.pageCount - 1) * 10
            
            // Add padding
            pdfContentHeight += 40 // 20pt top + 20pt bottom
            
            totalHeight += pdfContentHeight
        }
        
        // Set scrollView content size
        let contentWidth = scrollView.frame.width
        scrollView.contentSize = CGSize(width: contentWidth, height: max(totalHeight, scrollView.frame.height + 1))
        print("Set content size to: \(scrollView.contentSize)")
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        // Try to dismiss if presented modally
        if self.presentingViewController != nil {
            self.dismiss(animated: true, completion: nil)
        }
        // Try to pop from navigation controller if in a navigation stack
        else if let navController = self.navigationController {
            navController.popViewController(animated: true)
        }
        // As a fallback, just dismiss anyway
        else {
            self.dismiss(animated: true, completion: nil)
        }
    }
    
    @objc private func shareButtonTapped() {
        let activityViewController = UIActivityViewController(
            activityItems: [pdfURL],
            applicationActivities: nil
        )
        present(activityViewController, animated: true)
    }
    
    @objc private func optionsButtonTapped() {
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        actionSheet.addAction(UIAlertAction(title: "Add to Favorites", style: .default, handler: { _ in
            // Handle favorite action
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Report", style: .destructive, handler: { _ in
            // Handle report action
        }))
        
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(actionSheet, animated: true)
    }
    

    
    @objc private func doubtsButtonTapped() {
        print("===== AI DOUBTS BUTTON TAPPED =====")
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .large)
        loadingIndicator.color = .systemBlue
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        loadingIndicator.startAnimating()
        
        // Create AI page view controller
        let aiPageVC = AIPageViewController()
        
        // Extract PDF content directly
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let pdf = self.pdfView.document else {
                DispatchQueue.main.async {
                    loadingIndicator.stopAnimating()
                    self?.showAlert(title: "Error", message: "Could not access the PDF document.")
                }
                return
            }
            
            // Extract text from all pages
            var extractedText = ""
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    if let pageText = page.string {
                        extractedText += pageText + "\n\n"
                    }
                }
            }
            
            // Extract images for all pages
            var pageImages: [UIImage] = []
            for i in 0..<pdf.pageCount {
                if let page = pdf.page(at: i) {
                    let pageRect = page.bounds(for: .mediaBox)
                    let renderer = UIGraphicsImageRenderer(size: pageRect.size)
                    let image = renderer.image { context in
                        UIColor.white.set()
                        context.fill(CGRect(origin: .zero, size: pageRect.size))
                        
                        context.cgContext.translateBy(x: 0, y: pageRect.size.height)
                        context.cgContext.scaleBy(x: 1, y: -1)
                        
                        page.draw(with: .mediaBox, to: context.cgContext)
                    }
                    pageImages.append(image)
                }
            }
            
            // Prepare metadata
            let metadata = PDFMetadata(
                id: UUID().uuidString,
                url: self.pdfURL,
                fileName: self.documentTitle,
                subjectName: self.courseName,
                fileSize: Int(self.documentMetadata?["fileSize"] as? Int64 ?? 0),
                uploadDate: Date(),
                pageCount: pdf.pageCount,
                uploaderName: self.uploader
            )
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                loadingIndicator.stopAnimating()
                
                // Send to AIPageViewController
                aiPageVC.selectedPDFMetadata = metadata
                aiPageVC.pdfText = extractedText
                aiPageVC.pdfPages = pageImages
                aiPageVC.contentIsReady = true
                
                // Store strong reference to PDF
                aiPageVC.originalPDFDocument = pdf
                
                // Notify that PDF document is ready
                NotificationCenter.default.post(
                    name: NSNotification.Name("PDFDocumentPassedDirectly"),
                    object: pdf,
                    userInfo: [
                        "metadata": metadata,
                        "text": extractedText,
                        "pages": pageImages
                    ]
                )
                
                // Create hosting controller
                let aiPageView = AdvancedChatView(viewModel: aiPageVC)
                let hostingController = UIHostingController(rootView: aiPageView)
                
                // Create navigation controller with custom back button
                let navController = UINavigationController(rootViewController: hostingController)
                navController.navigationBar.tintColor = .black
                
                // Add a custom close button to the navigation bar
                let closeButton = UIBarButtonItem(
                    image: UIImage(systemName: "xmark.circle.fill"),
                    style: .plain,
                    target: self,
                    action: #selector(self.dismissAIView)
                )
                closeButton.tintColor = .black
                hostingController.navigationItem.rightBarButtonItem = closeButton
                
                // Present the navigation controller
                self.present(navController, animated: true)
            }
        }
    }
    
    @objc private func dismissAIView() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func handlePageChange(_ notification: Notification) {
        if let pdfView = notification.object as? PDFView,
           let currentPage = pdfView.currentPage,
           let document = pdfView.document {
            let pageIndex = document.index(for: currentPage)

        }
    }
    
    // Helper method to show error alerts
    private func showErrorAlert(message: String) {
        // Ensure we're on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                self.showErrorAlert(message: message)
            }
            return
        }
        
        // Don't show error for "Data" issues if PDF is already displayed
        if message.contains("Data") && (isPDFActuallyDisplaying() || hasSuccessfullyLoadedPDF) {
            print("📄 Suppressing 'Data' error because PDF is already visible: \(message)")
            return
        }
        
        // If we're still in the process of loading, delay showing the error
        if isAttemptingToLoadPDF {
            print("⏳ Delaying error alert because we're still loading: \(message)")
            // Check again after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // Only show the error if the PDF is still not loaded after the delay
                if !self.isPDFActuallyDisplaying() && !self.hasSuccessfullyLoadedPDF && self.isAttemptingToLoadPDF {
                    // Try again for "Data" errors
                    if message.contains("Data") && self.documentId != nil {
                        print("🔄 Attempting to retry PDF loading after delay for Data error")
                        self.tryLoadingFromDocumentId()
                    } else {
                        // For other errors, show the alert but with a longer timeout
                        print("⚠️ PDF still not loaded after delay, showing error: \(message)")
                        self.isAttemptingToLoadPDF = false
                        self.showErrorAlert(message: message)
                    }
                } else {
                    print("✅ PDF loaded successfully during delay, suppressing error: \(message)")
                }
            }
            return
        }
        
        // Prevent showing multiple error alerts
        guard !isShowingErrorAlert else {
            print("⚠️ Not showing error alert because one is already displayed: \(message)")
            return
        }
        
        isShowingErrorAlert = true
        print("⚠️ Showing error alert: \(message)")
        
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.isShowingErrorAlert = false
            
            // Try to gracefully recover if possible
            if self.pdfView.document == nil && !self.hasSuccessfullyLoadedPDF {
                if message.contains("Data") && self.documentId != nil && !self.documentId!.isEmpty {
                    self.tryLoadingFromDocumentId()
                } else {
                    self.tryAlternativeLoadingMethod()
                }
            }
        })
        
        // Add retry option for network-related errors
        if message.contains("download") || message.contains("network") || message.contains("connection") {
            alert.addAction(UIAlertAction(title: "Retry", style: .default) { _ in
                self.isShowingErrorAlert = false
                self.refreshPDFView()
            })
        }
        
        present(alert, animated: true)
    }
    
    deinit {
        // Clean up PDF document references
        pdfView.document = nil
        
        // Remove any observers
        NotificationCenter.default.removeObserver(self)
        
        print("PDFViewerViewController deinitialized")
    }
    
    // Helper method to set backgrounds appropriately
    private func setAppropriateBackgrounds() {
        // Set black backgrounds for main container views
        view.backgroundColor = .black
        contentContainerView.backgroundColor = .black
        scrollView.backgroundColor = .black
        contentStackView.backgroundColor = .black
        metadataView.backgroundColor = .black
        headerView.backgroundColor = .black
        
        // Set appropriate background for test knowledge container
        applyTestKnowledgeContainerStyling()
        
        // Find the PDF container and ensure it has the correct background
        for view in contentStackView.arrangedSubviews where view != metadataView {
            // This is the PDF container - make it white
            view.backgroundColor = .white
            
            // Make the PDFView white as well
            for subview in view.subviews {
                if subview is PDFView {
                    subview.backgroundColor = .white
                }
            }
        }
    }
    
    // Add a utility method to find and disable scrollviews within PDFView
    private func findScrollView(in view: UIView) -> UIScrollView? {
        // Check if this view is a scrollview
        if let scrollView = view as? UIScrollView {
            return scrollView
        }
        
        // Check all subviews recursively
        for subview in view.subviews {
            if let scrollView = findScrollView(in: subview) {
                return scrollView
            }
        }
        
        return nil
    }
    
    // Helper method to update the scrollView's content size based on the current PDF
    private func updateScrollViewContentSize() {
        var totalHeight: CGFloat = 0
        
        // Add metadata view height
        totalHeight += metadataView.frame.height
        
        // Add spacing after metadata
        totalHeight += 16
        
        // Add PDF container height if it exists
        for view in contentStackView.arrangedSubviews where view != metadataView {
            totalHeight += view.frame.height
            break // We only need the first non-metadata view (PDF container)
        }
        
        // Ensure minimum content size is greater than scroll view height to enable scrolling
        totalHeight = max(totalHeight, scrollView.bounds.height + 1)
        
        // Set content size
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: totalHeight)
        
        // Ensure content size is updated immediately
        scrollView.layoutIfNeeded()
    }
    
    // Helper method to show alerts
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Firebase Data Fetching
    private func fetchDocumentDataFromFirebase(documentId: String) {
        print("📝 Fetching PDF document with ID: \(documentId)")
        
        // Set loading state
        loadingState = .loading
        
        // First check Firebase connection
        let testRef = db.collection("pdfs").limit(to: 1)
        testRef.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Firebase connection test failed: \(error.localizedDescription)")
                // Firebase is unavailable, use fallback approach
                self.handleFirebaseUnavailable(documentId: documentId)
                return
            }
            
            // Continue with normal fetching if Firebase is available
            self.tryFetchFromPdfsCollection(documentId: documentId)
        }
    }
    
    // Handle when Firebase is unavailable - extract data from local cache or use URL directly
    private func handleFirebaseUnavailable(documentId: String) {
        // If we have a direct URL, use it
        if !pdfURL.path.isEmpty {
            print("⚠️ Firebase unavailable, but we have a direct URL: \(pdfURL)")
        DispatchQueue.main.async {
            self.loadPDF()
            }
            return
        }
        
        // If all else fails, show error
        DispatchQueue.main.async {
            self.loadingState = .failed
            self.handlePDFLoadingError("Could not download PDF. Firebase is unavailable and no local copy exists.")
        }
    }
    
    // Method to try fetching from pdfs collection
    private func tryFetchFromPdfsCollection(documentId: String) {
        print("📂 Checking pdfs collection for document: \(documentId)")
        let docRef = self.db.collection("pdfs").document(documentId)
        
        docRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching from pdfs collection: \(error.localizedDescription)")
                
                // Try other collections if there's an error
                self.tryFetchFromNotesCollection(documentId: documentId)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Document not found in pdfs collection")
                
                // Try other collections if document doesn't exist
                self.tryFetchFromNotesCollection(documentId: documentId)
                return
            }
            
            guard let data = document.data() else {
                print("❌ Document exists but has no data")
                
                // Try other collections if document has no data
                self.tryFetchFromNotesCollection(documentId: documentId)
                return
            }
            
            print("✅ Document found in pdfs collection with \(data.count) fields: \(data.keys)")
            
            // Process the document data
            self.processDocumentData(data, fromCollection: "pdfs")
        }
    }
    
    // Method to try fetching from notes collection
    private func tryFetchFromNotesCollection(documentId: String) {
        print("📂 Checking notes collection for document: \(documentId)")
        let docRef = self.db.collection("notes").document(documentId)
        
        docRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching from notes collection: \(error.localizedDescription)")
                
                // Try other collections if there's an error
                self.tryFetchFromDocumentsCollection(documentId: documentId)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Document not found in notes collection")
                
                // Try other collections if document doesn't exist
                self.tryFetchFromDocumentsCollection(documentId: documentId)
                return
            }
            
            guard let data = document.data() else {
                print("❌ Document exists but has no data")
                
                // Try other collections if document has no data
                self.tryFetchFromDocumentsCollection(documentId: documentId)
                return
            }
            
            print("✅ Document found in notes collection with \(data.count) fields: \(data.keys)")
            
            // Process the document data
            self.processDocumentData(data, fromCollection: "notes")
        }
    }
    
    // Method to try fetching from documents collection
    private func tryFetchFromDocumentsCollection(documentId: String) {
        print("📂 Checking documents collection for document: \(documentId)")
        let docRef = self.db.collection("documents").document(documentId)
        
        docRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching from documents collection: \(error.localizedDescription)")
                
                // Try querying if direct document lookup fails
                self.searchForDocumentInCollections(documentId: documentId)
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ Document not found in documents collection")
                
                // Try querying if direct document lookup fails
                self.searchForDocumentInCollections(documentId: documentId)
                return
            }
            
            guard let data = document.data() else {
                print("❌ Document exists but has no data")
                
                // Try querying if direct document lookup fails
                self.searchForDocumentInCollections(documentId: documentId)
                return
            }
            
            print("✅ Document found in documents collection with \(data.count) fields: \(data.keys)")
            
            // Process the document data
            self.processDocumentData(data, fromCollection: "documents")
        }
    }
    
    // MARK: - Helper Methods for Firebase
    
    // Method to search for documents across collections using queries
    private func searchForDocumentInCollections(documentId: String) {
        print("🔍 Searching for document with queries in collections")
        
        // First try to search in pdfs collection
        let pdfsQuery = db.collection("pdfs")
            .whereField("id", isEqualTo: documentId)
            .limit(to: 1)
        
        pdfsQuery.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error searching for document: \(error.localizedDescription)")
                self.tryFindDocumentByUploaderId(documentId)
                return
            }
            
            if let snapshot = snapshot, !snapshot.documents.isEmpty, let data = snapshot.documents.first?.data() {
                print("✅ Document found via query with \(data.count) fields")
                self.processDocumentData(data, fromCollection: "pdfs")
                return
            }
            
            // Try second query with uid field
            self.tryFindDocumentByUploaderId(documentId)
        }
    }
    
    // Helper method to try finding document by uploaderId
    private func tryFindDocumentByUploaderId(_ potentialUserId: String) {
        print("🔍 Searching for documents with uploader/user ID: \(potentialUserId)")
        
        // This might be a user ID, try to fetch their uploads
        let uploaderQuery = db.collection("pdfs")
            .whereField("userId", isEqualTo: potentialUserId)
            .limit(to: 5)
        
        uploaderQuery.getDocuments { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error searching for documents by userId: \(error.localizedDescription)")
                self.fallbackToLocalPDFLoad()
                return
            }
            
            if let snapshot = snapshot, !snapshot.documents.isEmpty, let data = snapshot.documents.first?.data() {
                print("✅ Found document uploaded by user \(potentialUserId)")
                self.processDocumentData(data, fromCollection: "pdfs")
                return
            }
            
            // Try other user ID field variations as a last resort
            let otherFieldsQuery = db.collection("pdfs")
                .whereField("uploaderId", isEqualTo: potentialUserId)
                .limit(to: 1)
            
            otherFieldsQuery.getDocuments { [weak self] (snapshot, error) in
                guard let self = self else { return }
                
                if let snapshot = snapshot, !snapshot.documents.isEmpty, let data = snapshot.documents.first?.data() {
                    print("✅ Document found via uploaderId query")
                    self.processDocumentData(data, fromCollection: "pdfs")
                    return
                }
                
                // If all queries fail, try to load the PDF directly
                self.fallbackToLocalPDFLoad()
            }
        }
    }
    
    // Helper to fall back to local PDF loading
    private func fallbackToLocalPDFLoad() {
        print("📄 All attempts to get metadata failed, loading PDF locally")
        DispatchQueue.main.async {
            self.loadingState = .loaded
            
            // If we have a PDF URL, still load it even without metadata
            if !self.pdfURL.path.isEmpty && FileManager.default.fileExists(atPath: self.pdfURL.path) {
                print("📄 Loading PDF without metadata")
                self.loadPDF()
            } else {
                self.loadingState = .failed
                self.handlePDFLoadingError("Could not find document details in Firebase")
            }
        }
    }
    
    // Process document data once found in Firestore
    private func processDocumentData(_ data: [String: Any], fromCollection: String) {
        print("📝 Processing document data from collection: \(fromCollection)")
        
        // Store document metadata
        self.documentMetadata = data
        
        // Extract basic data - check multiple possible field names
        // Filename field
        if let fileName = data["fileName"] as? String {
            self.documentTitle = fileName
            print("📝 Found fileName: \(fileName)")
        } else if let title = data["title"] as? String {
            self.documentTitle = title
            print("📝 Found title: \(title)")
        } else if let name = data["name"] as? String {
            self.documentTitle = name
            print("📝 Found name: \(name)")
        } else {
            self.documentTitle = "PDF Document"
            print("❌ No fileName/title/name field found")
        }
        
        // Course/Subject field
        if let subjectName = data["subjectName"] as? String {
            self.courseName = subjectName
            print("📝 Found subjectName: \(subjectName)")
        } else if let subject = data["subject"] as? String {
            self.courseName = subject
            print("📝 Found subject: \(subject)")
        } else if let course = data["course"] as? String {
            self.courseName = course
            print("📝 Found course: \(course)")
        } else {
            self.courseName = "Unknown Subject"
            print("❌ No subjectName/subject/course field found")
        }
        
        // University/College field
        if let collegeName = data["collegeName"] as? String {
            self.universityName = collegeName
            print("📝 Found collegeName: \(collegeName)")
        } else if let college = data["college"] as? String {
            self.universityName = college
            print("📝 Found college: \(college)")
        } else if let university = data["university"] as? String {
            self.universityName = university
            print("📝 Found university: \(university)")
        } else {
            self.universityName = "Unknown College"
            print("❌ No collegeName/college/university field found")
        }
        
        print("📝 Extracted final values - title: \(self.documentTitle), course: \(self.courseName), college: \(self.universityName)")
        
        // Extract additional metadata
        var category = "Not specified"
        if let categoryValue = data["category"] as? String {
            category = categoryValue
            print("📝 Found category: \(category)")
        } else {
            print("❌ No category field found")
        }
        
        // Extract file size - handle different possible types
        var fileSize: Int64 = 0
        if let fileSizeNumber = data["fileSize"] as? NSNumber {
            fileSize = fileSizeNumber.int64Value
            print("📝 Found fileSize as NSNumber: \(fileSize)")
        } else if let fileSizeInt = data["fileSize"] as? Int {
            fileSize = Int64(fileSizeInt)
            print("📝 Found fileSize as Int: \(fileSize)")
        } else if let fileSizeInt64 = data["fileSize"] as? Int64 {
            fileSize = fileSizeInt64
            print("📝 Found fileSize as Int64: \(fileSize)")
        } else if let fileSizeString = data["fileSize"] as? String, let parsed = Int64(fileSizeString) {
            fileSize = parsed
            print("📝 Found fileSize as String: \(fileSize)")
        } else {
            print("❌ No valid fileSize field found")
        }
        
        let formattedFileSize = self.formatFileSize(fileSize)
        
        // Extract privacy setting
        let privacy = data["privacy"] as? String ?? "public"
        print("📝 Extracted privacy: \(privacy)")
        
        // Extract date - check multiple possible timestamp fields
        var uploadDateString = "Unknown date"
        var date: Date? = nil
        
        if let timestamp = data["uploadDate"] as? Timestamp {
            date = timestamp.dateValue()
            print("📝 Found uploadDate as Timestamp")
        } else if let timestamp = data["dateAdded"] as? Timestamp {
            date = timestamp.dateValue()
            print("📝 Found dateAdded as Timestamp")
        } else if let timestamp = data["date"] as? Timestamp {
            date = timestamp.dateValue()
            print("📝 Found date as Timestamp")
        } else if let dateDouble = data["uploadDate"] as? Double {
            date = Date(timeIntervalSince1970: dateDouble)
            print("📝 Found uploadDate as Double")
        } else if let dateDouble = data["dateAdded"] as? Double {
            date = Date(timeIntervalSince1970: dateDouble)
            print("📝 Found dateAdded as Double")
        } else if let dateString = data["uploadDate"] as? String {
            // Try to parse date string - various formats
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            if let parsedDate = dateFormatter.date(from: dateString) {
                date = parsedDate
                print("📝 Found uploadDate as ISO string format")
            }
        } else {
            print("❌ No valid date field found")
        }
        
        if let validDate = date {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            uploadDateString = dateFormatter.string(from: validDate)
            print("📝 Formatted date: \(uploadDateString)")
        }
        
        // Get user ID and fetch user details
        if let userId = data["userId"] as? String {
            print("👤 Found userId: \(userId), fetching user details")
            self.fetchUserDetails(userId: userId)
        } else if let userId = data["uploaderId"] as? String {
            print("👤 Found uploaderId: \(userId), fetching user details")
            self.fetchUserDetails(userId: userId)
        } else if let userId = data["uid"] as? String {
            print("👤 Found uid: \(userId), fetching user details")
            self.fetchUserDetails(userId: userId)
        } else {
            print("❌ No userId/uploaderId/uid found in document")
            self.uploader = "Unknown"
        }
        
        // Get and check download URL - try multiple possible fields
        var foundDownloadURL: URL? = nil
        var urlFieldName: String? = nil
        
        let urlFields = ["downloadURL", "url", "pdfUrl", "fileUrl", "downloadUrl", "download_url", "pdf_url", "file_url"]
        
        for field in urlFields {
            if let urlString = data[field] as? String, !urlString.isEmpty {
                if let url = URL(string: urlString) {
                    foundDownloadURL = url
                    urlFieldName = field
                    break
                } else {
                    print("❌ Found \(field) but couldn't convert to URL: \(urlString)")
                }
            }
        }
        
        // Update UI with fetched data first before downloading PDF
        DispatchQueue.main.async {
            self.titleLabel.text = self.documentTitle
            self.courseNameLabel.text = self.courseName
            self.universityNameLabel.text = self.universityName
            self.categoryLabel.text = category
            self.uploaderLabel.text = self.uploader
            self.uploadDateLabel.text = uploadDateString
            self.fileSizeLabel.text = formattedFileSize
            
            // Force layout update
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }
        
        if let downloadURL = foundDownloadURL, let fieldName = urlFieldName {
            print("📥 Found download URL in field '\(fieldName)': \(downloadURL)")
            self.fetchPDFFromURL(downloadURL)
        } else {
            print("❌ No valid download URL found in document among these fields: \(urlFields)")
            
            // Try to still use the local PDF if it exists
            if !self.pdfURL.path.isEmpty && FileManager.default.fileExists(atPath: self.pdfURL.path) {
                print("📄 Using local PDF file since no download URL found")
                self.loadPDF()
            } else {
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("PDF URL not found or invalid")
                }
            }
        }
    }
    
    // Helper method to format file size
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // Helper to validate PDF data
    private func isPDFData(_ data: Data) -> Bool {
        // PDF files start with "%PDF-" signature
        if data.count < 10 { // Increased minimum size check
            print("❌ PDF validation failed: data too small (\(data.count) bytes)")
            return false
        }
        
        // Primary check: look for the PDF signature
        let pdfSignature = "%PDF-"
        let signatureData = pdfSignature.data(using: .ascii)!
        
        if data.starts(with: signatureData) {
            print("✅ PDF signature detected")
            return true
        }
        
        // Check the first 1024 bytes for the signature (sometimes there's a BOM or other bytes before the signature)
        let searchRange = min(1024, data.count)
        let firstBytes = data.prefix(searchRange)
        
        if let signatureString = String(data: firstBytes, encoding: .ascii),
           signatureString.contains(pdfSignature) {
            print("✅ PDF signature found in first \(searchRange) bytes")
            return true
        }
        
        // Last resort: try to create a PDFDocument
        if let document = PDFDocument(data: data), document.pageCount > 0 {
            print("✅ PDFDocument creation successful despite missing signature")
            return true
        }
        
        // Log sample of data for debugging
        if let preview = String(data: data.prefix(50), encoding: .ascii) {
            print("❌ PDF validation failed: first bytes: \(preview)")
        } else {
            print("❌ PDF validation failed: data not readable as ASCII")
        }
        
        return false
    }
    
    // Fetch user details from Firebase
    private func fetchUserDetails(userId: String) {
        print("👤 Starting user fetch for userId: \(userId)")
        let userRef = db.collection("users").document(userId)
        print("👤 Using Firestore reference: \(userRef.path)")
        
        userRef.getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Error fetching user details: \(error.localizedDescription)")
                
                // Check specifically for permission errors
                if let nsError = error as NSError?,
                   nsError.domain == "FIRFirestoreErrorDomain",
                   nsError.code == 7 {
                    print("🔒 Permission denied accessing user details. This is expected in the simulator or if your Firebase security rules restrict user document access.")
                    self.uploader = "Unknown User"
                }
                return
            }
            
            guard let document = document, document.exists else {
                print("❌ User document not found for ID: \(userId)")
                self.uploader = "Unknown User"
                return
            }
            
            guard let data = document.data() else {
                print("❌ User document exists but data is empty for ID: \(userId)")
                self.uploader = "Unknown User"
                return
            }
            
            print("✅ Successfully retrieved user data with \(data.count) fields: \(data.keys)")
            
            // Check multiple name field variations
            if let userName = data["name"] as? String {
                self.uploader = userName
                print("👤 Found user.name: \(userName)")
            } else if let userName = data["userName"] as? String {
                self.uploader = userName
                print("👤 Found user.userName: \(userName)")
            } else if let firstName = data["firstName"] as? String {
                let lastName = data["lastName"] as? String ?? ""
                self.uploader = firstName + (lastName.isEmpty ? "" : " " + lastName)
                print("👤 Found user.firstName/lastName: \(self.uploader)")
            } else if let displayName = data["displayName"] as? String {
                self.uploader = displayName
                print("👤 Found user.displayName: \(displayName)")
            } else {
                print("❌ No valid name field found in user document")
                self.uploader = "Unknown User"
            }
            
            // Update college name if not already set
            if self.universityName == "Unknown College" {
                if let college = data["college"] as? String {
                    self.universityName = college
                    print("🏛 Updated college from user: \(college)")
                } else if let college = data["collegeName"] as? String {
                    self.universityName = college
                    print("🏛 Updated collegeName from user: \(college)")
                } else if let university = data["university"] as? String {
                    self.universityName = university
                    print("🏛 Updated university from user: \(university)")
                } else {
                    print("❌ No valid college/university field in user document")
                }
            }
            
            // Update course if not already set
            if self.courseName == "Unknown Subject" {
                if let course = data["course"] as? String {
                    self.courseName = course
                    print("📚 Updated course from user: \(course)")
                } else if let subject = data["subject"] as? String {
                    self.courseName = subject
                    print("📚 Updated subject from user: \(subject)")
                } else if let major = data["major"] as? String {
                    self.courseName = major
                    print("📚 Updated major from user: \(major)")
                } else {
                    print("❌ No valid course/subject field in user document")
                }
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.universityNameLabel.text = self.universityName
                self.courseNameLabel.text = self.courseName
                self.uploaderLabel.text = self.uploader
                
                // Force layout update
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }
    }
    
    // Add method to handle pdf loading errors
    private func handlePDFLoadingError(_ errorMessage: String) {
        // Set loading state to failed
        loadingState = .failed
        
        // If PDF is visible, ignore the error completely
        if isPDFActuallyDisplaying() || hasSuccessfullyLoadedPDF {
            print("📄 Ignoring error because PDF is already visible: \(errorMessage)")
            // If PDF is visible, we're actually in a loaded state despite the error
            loadingState = .loaded
            return
        }
        
        // If we're still attempting to load the PDF, delay error handling to give time for loading to complete
        if isAttemptingToLoadPDF {
            print("⏳ Delaying error handling because we're still loading: \(errorMessage)")
            // Delay error handling by 1 second to see if PDF loads successfully
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                
                // Check again if PDF is visible after the delay
                if self.isPDFActuallyDisplaying() || self.hasSuccessfullyLoadedPDF {
                    print("✅ PDF loaded successfully during delay, ignoring error: \(errorMessage)")
                    self.loadingState = .loaded
                    return
                }
                
                // Only proceed with error handling if we're still in loading state
                if self.isAttemptingToLoadPDF {
                    // We've waited enough, proceed with error handling
                    self.isAttemptingToLoadPDF = false
                    
                    // If error contains "Data" and we have a valid document ID, try direct loading
                    if errorMessage.contains("Data") && self.documentId != nil && !self.documentId!.isEmpty {
                        print("📄 Handling 'Data' error with direct loading attempt")
                        self.tryLoadingFromDocumentId()
                        return
                    }
                    
                    // Show error alert for other cases
                    self.showErrorAlert(message: errorMessage)
                }
            }
            return
        }
        
        // If error contains "Data" and we have a valid document ID, try direct loading
        if errorMessage.contains("Data") && documentId != nil && !documentId!.isEmpty {
            print("📄 Handling 'Data' error with direct loading attempt")
            tryLoadingFromDocumentId()
            return
        }
        
        // Show error alert for other cases
        showErrorAlert(message: errorMessage)
    }
    
    @objc private func handlePDFKitError(_ notification: Notification) {
        if let error = notification.userInfo?["PDFDocumentErrorDomain"] as? Error {
            print("🚨 PDFKit error intercepted: \(error.localizedDescription)")
            
            // If error contains "Data" but PDF is already displaying, suppress it
            if error.localizedDescription.contains("Data") && (isPDFActuallyDisplaying() || hasSuccessfullyLoadedPDF) {
                print("📄 Intercepted and suppressing 'Data' error because PDF is already visible")
                return
            }
        }
    }
    
    // Helper to determine if a pdf is actually loaded and displaying
    private func isPDFActuallyDisplaying() -> Bool {
        // Check if we have a document
        guard let document = pdfView.document, document.pageCount > 0 else {
            return false
        }
        
        // Check if we have a current page
        guard let _ = pdfView.currentPage else {
            return false
        }
        
        // Check if the PDFView has a valid frame
        if pdfView.frame.width <= 0 || pdfView.frame.height <= 0 {
            return false
        }
        
        return true
    }
    
    // Method to try alternative loading methods when standard approach fails
    private func tryAlternativeLoadingMethod() {
        
        // Check if URL exists
        if !pdfURL.isFileURL || !FileManager.default.fileExists(atPath: pdfURL.path) {
            fetchPDFFromURL(pdfURL)
            return
        }
        
        // Try to load the PDF with Data instead of URL
        do {
            let pdfData = try Data(contentsOf: pdfURL)

            
            // Verify it's a PDF
            if isPDFData(pdfData) {
                
                // Create document from data
                if let document = PDFDocument(data: pdfData), document.pageCount > 0 {
                    
                    // Set document to view on main thread
                    DispatchQueue.main.async {
                        self.pdfView.document = document
                        self.ensurePDFViewIsVisible()
                    }
                }
                else {
                    DispatchQueue.main.async {
//                        self.handlePDFLoadingError("Could not load PDF document")
                        return
                    }
                }
            } else {
                print("❌ Data is not a valid PDF")
                DispatchQueue.main.async {
//                    self.handlePDFLoadingError("The file is not a valid PDF")
                }
            }
        } catch {
            print("❌ Error reading PDF data: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.handlePDFLoadingError("Error loading PDF: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper method to trim excess white space from PDF display
    private func trimExcessWhiteSpace() {
        guard let document = pdfView.document, let firstPage = document.page(at: 0) else {
            return
        }
        
        // Force a layout to ensure we have accurate frame dimensions
        pdfView.layoutIfNeeded()
        
        // Get the box rectangle that contains the actual content (not the full page)
        let cropBox = firstPage.bounds(for: .cropBox)
        let mediaBox = firstPage.bounds(for: .mediaBox)
        
        // If the crop box is smaller than the media box, use it to determine margins
        if cropBox.width < mediaBox.width || cropBox.height < mediaBox.height {
            // Calculate padding to only show content area
            let scaleX = pdfView.bounds.width / mediaBox.width
            
            // Scale up to trim white borders
            pdfView.scaleFactor = scaleX * 1.08
            
            print("📄 Trimmed excess white space - scaled up by 8%")
        }
        
        // Force refresh
        pdfView.layoutDocumentView()
        pdfView.setNeedsDisplay()
    }
    
    private func downloadPDFFromURL(_ url: URL) {
        print("📥 Starting PDF download from URL: \(url)")
        
        // Set loading state
        loadingState = .loading
        
        // Create URL session with delegate to track progress
        let session = URLSession(configuration: .default)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Create a temporary file to download to
        let tempFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        
        // Start download task to file
        let downloadTask = session.downloadTask(with: request) { [weak self] (tempURL, response, error) in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                print("❌ Download error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("Failed to download PDF: \(error.localizedDescription)")
                }
                return
            }
            
            // Verify we have response and temp file URL
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let downloadedFileURL = tempURL else {
                print("❌ Invalid response or no file")
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("Failed to download PDF: Invalid response")
                }
                return
            }
            
            do {
                // Move downloaded file to our temp location
                if FileManager.default.fileExists(atPath: tempFileURL.path) {
                    try FileManager.default.removeItem(at: tempFileURL)
                }
                try FileManager.default.moveItem(at: downloadedFileURL, to: tempFileURL)
                
                // Try to create PDFDocument from the downloaded file
                guard let document = PDFDocument(url: tempFileURL) else {
                    print("❌ Invalid PDF file")
                    DispatchQueue.main.async {
                        self.loadingState = .failed
                        self.handlePDFLoadingError("The downloaded file is not a valid PDF")
                    }
                    return
                }
                
                // Verify document has pages
                guard document.pageCount > 0 else {
                    print("❌ PDF has no pages")
                    DispatchQueue.main.async {
                        self.loadingState = .failed
                        self.handlePDFLoadingError("The PDF appears to be empty")
                    }
                    return
                }
                
                // Pre-load all pages to ensure they're in memory
                var allPagesLoaded = true
                for i in 0..<document.pageCount {
                    guard let page = document.page(at: i) else {
                        allPagesLoaded = false
                        break
                    }
                    // Force page load by accessing its bounds
                    _ = page.bounds(for: .mediaBox)
                }
                
                guard allPagesLoaded else {
                    print("❌ Failed to load all pages")
                    DispatchQueue.main.async {
                        self.loadingState = .failed
                        self.handlePDFLoadingError("Failed to load all pages of the PDF")
                    }
                    return
                }
                
                print("✅ Successfully downloaded and verified PDF with \(document.pageCount) pages")
                
                // Now that everything is verified, update UI on main thread
                DispatchQueue.main.async {
                    // Update PDF URL for future reference
                    self.pdfURL = tempFileURL
                    
                    // Clear existing document
                    self.pdfView.document = nil
                    
                    // Set the new document
                    self.pdfView.document = document
                    
                    // Configure PDFView for optimal display
                    self.configurePDFViewForDocument(document)
                }
                
            } catch {
                print("❌ Error processing downloaded PDF: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.loadingState = .failed
                    self.handlePDFLoadingError("Error processing PDF: \(error.localizedDescription)")
                }
                
                // Clean up temp file if it exists
                try? FileManager.default.removeItem(at: tempFileURL)
            }
        }
        
        downloadTask.resume()
    }
}

// MARK: - UIScrollViewDelegate
extension PDFViewerViewController {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Make sure header view stays on top
        view.bringSubviewToFront(headerView)
        
        
        // Ensure the test knowledge container maintains its styling
        testKnowledgeContainer.layer.cornerRadius = 20
        testKnowledgeContainer.layer.borderWidth = 1
        testKnowledgeContainer.layer.borderColor = UIColor.darkGray.withAlphaComponent(0.4).cgColor
        testKnowledgeContainer.backgroundColor = UIColor.black
        
        // Update page indicator based on current scroll position
        
        // Ensure PDF content is always visible and properly displayed
        ensurePDFViewIsVisible()
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // Ensure PDF is fully visible
            ensurePDFViewIsVisible()
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Ensure PDF is fully visible after scrolling stops
        ensurePDFViewIsVisible()
    }
    
    // Helper method to ensure PDFView is properly displayed
    private func ensurePDFViewIsVisible() {
        // Update content size if needed
        updateScrollViewContentSize()
        
        // Make sure header is on top
        view.bringSubviewToFront(headerView)
        
        // Refresh PDF view if necessary
        if let document = pdfView.document, pdfView.currentPage == nil {
            if let firstPage = document.page(at: 0) {
                pdfView.go(to: firstPage)
            }
        }
        
        // Force layout and update of the PDF view
        pdfView.layoutDocumentView()
        pdfView.setNeedsDisplay()
        
        // Ensure PDFView's internal scrolling is properly configured
        if let pdfScrollView = findScrollView(in: pdfView) {
            pdfScrollView.isScrollEnabled = false
            pdfScrollView.bounces = false
        }
        
        // If PDF is visible, set a flag to prevent error messages
        if isPDFActuallyDisplaying() {
            hasSuccessfullyLoadedPDF = true
            loadingState = .loaded
            isAttemptingToLoadPDF = false
            
            // If there's an error alert showing and the PDF is actually visible, dismiss it
            if isShowingErrorAlert, let presentedVC = presentedViewController as? UIAlertController {
                print("🚫 Dismissing error alert because PDF is now visible")
                presentedVC.dismiss(animated: true) {
                    self.isShowingErrorAlert = false
                }
            }
        }
    }
}

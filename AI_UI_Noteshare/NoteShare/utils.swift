import UIKit
import PDFKit

class PDFViewerViewController: UIViewController {
    private let pdfView: PDFView = {
        let view = PDFKit.PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let summaryTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isEditable = false
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 8
        textView.contentInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.isHidden = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private let uploadButton: UIButton = {
        let button = UIButton(type: .system)
        let aiLogoConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        let normalImage = UIImage(systemName: "apple.intelligence", withConfiguration: aiLogoConfig)
        let selectedImage = UIImage(systemName: "apple.intelligence.fill", withConfiguration: aiLogoConfig)
        button.setImage(normalImage, for: .normal)
        button.setImage(selectedImage, for: .highlighted)
        button.tintColor = .white
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let pdfURL: URL
    private let documentTitle: String
    private var summary: String?
    
    init(pdfURL: URL, title: String = "PDF Document") {
        self.pdfURL = pdfURL
        self.documentTitle = title
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigation()
        loadPDF()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add PDF view and summary text view
        view.addSubview(pdfView)
        view.addSubview(summaryTextView)
        
        NSLayoutConstraint.activate([
            pdfView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
            summaryTextView.topAnchor.constraint(equalTo: pdfView.bottomAnchor, constant: 8),
            summaryTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            summaryTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        // Add activity indicator
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        // Add upload button
        view.addSubview(uploadButton)
        NSLayoutConstraint.activate([
            uploadButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            uploadButton.widthAnchor.constraint(equalToConstant: 44),
            uploadButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
    }
    
    private func setupNavigation() {
        title = documentTitle
        navigationController?.setNavigationBarHidden(false, animated: false)
        
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeButtonTapped)
        )
        navigationItem.leftBarButtonItem = closeButton
        
        let shareButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(shareButtonTapped)
        )
        navigationItem.rightBarButtonItem = shareButton
    }
    
    private func loadPDF() {
        activityIndicator.startAnimating()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let document = PDFDocument(url: self.pdfURL) {
                DispatchQueue.main.async {
                    self.pdfView.document = document
                    self.activityIndicator.stopAnimating()
                }
            } else {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showErrorAlert()
                }
            }
        }
    }
    
    @objc private func uploadButtonTapped() {
        activityIndicator.startAnimating()
        
        // Simulate API call for PDF summarization
        DispatchQueue.global().async { [weak self] in
            // Simulate processing time
            sleep(3)
            
            // Simulate getting summary from API
            let generatedSummary = "This is an AI-generated summary of the PDF document. It contains key points and main ideas extracted from the document using advanced natural language processing techniques."
            
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.activityIndicator.stopAnimating()
                self.summary = generatedSummary
                self.summaryTextView.text = generatedSummary
                self.summaryTextView.isHidden = false
                
                // Show success message
                self.showSuccessAlert()
            }
        }
    }
    
    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "Success",
            message: "PDF summary generated successfully!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Unable to load PDF document",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func shareButtonTapped() {
        var itemsToShare: [Any] = [pdfURL]
        
        // If summary exists, include it in sharing
        if let summary = summary {
            itemsToShare.append(summary)
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        present(activityViewController, animated: true)
    }
}

import UIKit
import PDFKit

// Custom label with padding
class PaddedLabel: UILabel {
    var padding = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
    
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
    
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + padding.left + padding.right,
                      height: size.height + padding.top + padding.bottom)
    }
}

class InformationViewController: UIViewController {
    
    // MARK: - Properties
    
    var titleText: String = "Information"
    var contentText: String = ""
    
    // MARK: - UI Components
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "chevron.left")
        button.setImage(image, for: .normal)
        button.setTitle("Back", for: .normal)
        button.tintColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        return button
    }()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 22, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = true
        scrollView.contentInsetAdjustmentBehavior = .automatic
        scrollView.backgroundColor = .white
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .white
        return view
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
        
        // Add a debug message to verify the view loaded
        print("InformationViewController loaded with title: \(titleText)")
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
        navigationController?.navigationBar.isHidden = true
        
        view.addSubview(backButton)
        view.addSubview(headerLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            headerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            headerLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    private func configureContent() {
        headerLabel.text = titleText
        
        // Parse and display content
        createSimpleTextDisplay()
    }
    
    private func createSimpleTextDisplay() {
        // Clean up any existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create a stack view to organize the content
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Split content by newlines to handle sections
        let sections = contentText.components(separatedBy: "\n\n")
        
        for section in sections {
            if section.isEmpty { continue }
            
            // Handle section titles (surrounded by ** **)
            if section.hasPrefix("**") && section.contains("**") {
                let titleLabel = createTitleLabel(section)
                stackView.addArrangedSubview(titleLabel)
            }
            // Handle bullet points
            else if section.contains("• ") {
                let bulletPoints = section.components(separatedBy: "\n")
                for point in bulletPoints {
                    if point.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                    let bulletLabel = createBulletPointLabel(point)
                    stackView.addArrangedSubview(bulletLabel)
                }
            }
            // Handle regular text
            else {
                let paragraphLabel = createParagraphLabel(section)
                stackView.addArrangedSubview(paragraphLabel)
            }
        }
        
        contentView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createTitleLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        
        // Remove ** markers
        let displayText = text.replacingOccurrences(of: "**", with: "")
        label.text = displayText
        
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textColor = .black
        return label
    }
    
    private func createBulletPointLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        
        // Keep the bullet point format
        label.text = text
        
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .darkGray
        return label
    }
    
    private func createParagraphLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        
        label.text = text
        
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .darkGray
        return label
    }
    
    // MARK: - Action Methods
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
}

#Preview {
    let previewVC = InformationViewController()
    previewVC.titleText = "Sample Title"
    previewVC.contentText = """
    **This is a Header**
    
    This is a paragraph with some text.
    
    • This is bullet point 1
    • This is bullet point 2
    
    **Another Section**
    
    Some more text here.
    """
    return previewVC
} 

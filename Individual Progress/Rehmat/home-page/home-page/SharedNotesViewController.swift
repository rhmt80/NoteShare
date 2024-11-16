import UIKit

class SharedNotesViewController: UIViewController {
    // MARK: - Properties
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let backButton: UIButton = {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .systemBlue
        return button
    }()
    
    private let headerLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Shared with me"
        label.textColor = .systemBlue
        label.font = .systemFont(ofSize: 17)
        label.isUserInteractionEnabled = true  // Enable user interaction
        return label
    }()
    
    // Create a container view for the header elements
    private let headerContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()
    
//    private let titleLabel: UILabel = {
//        let label = UILabel()
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.text = "Shared by Rehmat"
//        label.font = .boldSystemFont(ofSize: 24)
//        return label
//    }()
    private let titleLabel: UILabel = {
           let label = UILabel()
           label.translatesAutoresizingMaskIntoConstraints = false
           label.text = "Shared by Rehmat"
           label.font = .boldSystemFont(ofSize: 24)
           label.tag = 100  // Add a tag to identify the label
           return label
       }()
    
    private let mathLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Mathematics"
        label.font = .boldSystemFont(ofSize: 20)
        return label
    }()
    
    private let mathScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let mathStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 15
        return stackView
    }()
    
    private let automataLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Formal Language Automata"
        label.font = .boldSystemFont(ofSize: 20)
        return label
    }()
    
    private let automataScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        return scrollView
    }()
    
    private let automataStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 15
        return stackView
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        addSampleImages()
        setupNavigation()
        
    }
   
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add header container and its subviews
        contentView.addSubview(headerContainer)
        headerContainer.addSubview(backButton)
        headerContainer.addSubview(headerLabel)
        
        [titleLabel, mathLabel, mathScrollView,
         automataLabel, automataScrollView].forEach { contentView.addSubview($0) }
        
        mathScrollView.addSubview(mathStackView)
        automataScrollView.addSubview(automataStackView)
    }
    
    private func setupNavigation() {
        // Setup back button action
        backButton.addTarget(self, action: #selector(navigateBack), for: .touchUpInside)
        
        // Setup tap gesture for header label
        let headerTapGesture = UITapGestureRecognizer(target: self, action: #selector(navigateBack))
        headerLabel.addGestureRecognizer(headerTapGesture)
        
        // Setup tap gesture for the entire header container
        let containerTapGesture = UITapGestureRecognizer(target: self, action: #selector(navigateBack))
        headerContainer.addGestureRecognizer(containerTapGesture)
    }
    
//    @objc private func navigateBack() {
//        if let navigationController = navigationController {
//            navigationController.popViewController(animated: true)
//        } else {
//            dismiss(animated: true, completion: nil)
//        }
//    }
    @objc private func navigateBack() {
        // Always use pop since we're using push navigation
        navigationController?.popViewController(animated: true)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Main scroll view
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Header container
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            headerContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Back button
            backButton.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            // Header label
            headerLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            headerLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            
            // Title label
            titleLabel.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            // Math section
            mathLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            mathLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            mathScrollView.topAnchor.constraint(equalTo: mathLabel.bottomAnchor, constant: 15),
            mathScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            mathScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            mathScrollView.heightAnchor.constraint(equalToConstant: 200),
            
            mathStackView.topAnchor.constraint(equalTo: mathScrollView.topAnchor),
            mathStackView.leadingAnchor.constraint(equalTo: mathScrollView.leadingAnchor, constant: 20),
            mathStackView.trailingAnchor.constraint(equalTo: mathScrollView.trailingAnchor, constant: -20),
            mathStackView.bottomAnchor.constraint(equalTo: mathScrollView.bottomAnchor),
            mathStackView.heightAnchor.constraint(equalTo: mathScrollView.heightAnchor),
            
            // Automata section
            automataLabel.topAnchor.constraint(equalTo: mathScrollView.bottomAnchor, constant: 30),
            automataLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            
            automataScrollView.topAnchor.constraint(equalTo: automataLabel.bottomAnchor, constant: 15),
            automataScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            automataScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            automataScrollView.heightAnchor.constraint(equalToConstant: 200),
            automataScrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -100),
            
            automataStackView.topAnchor.constraint(equalTo: automataScrollView.topAnchor),
            automataStackView.leadingAnchor.constraint(equalTo: automataScrollView.leadingAnchor, constant: 20),
            automataStackView.trailingAnchor.constraint(equalTo: automataScrollView.trailingAnchor, constant: -20),
            automataStackView.bottomAnchor.constraint(equalTo: automataScrollView.bottomAnchor),
            automataStackView.heightAnchor.constraint(equalTo: automataScrollView.heightAnchor)
        ])
    }
    
//    private func addSampleImages() {
//        // Add sample images to math section
//        for i in 0..<2 {
//            let imageView = createImageView(named: "math_\(i)")
//            mathStackView.addArrangedSubview(imageView)
//        }
//        
//        // Add sample images to automata section
//        for i in 0..<2 {
//            let imageView = createImageView(named: "automata_\(i)")
//            automataStackView.addArrangedSubview(imageView)
//        }
//    }
//    
//    private func createImageView(named: String) -> UIImageView {
//        let imageView = UIImageView()
//        imageView.translatesAutoresizingMaskIntoConstraints = false
//        imageView.backgroundColor = .systemGray5 // Placeholder color
//        imageView.layer.cornerRadius = 8
//        imageView.clipsToBounds = true
//        imageView.contentMode = .scaleAspectFit
//        
//        // Set width constraint to maintain aspect ratio
//        imageView.widthAnchor.constraint(equalToConstant: 150).isActive = true
//        
//        return imageView
//    }
    private func createImageView(named imageName: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: imageName) // Load the actual image
        imageView.backgroundColor = .systemGray5 // Fallback color if image fails to load
        imageView.layer.cornerRadius = 8
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill // Changed to scaleAspectFill for better appearance
        
        // Set constraints for a reasonable size
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 150),
            imageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        return imageView
    }

    private func addSampleImages() {
        // Add math images
        let mathImages = ["math_0", "math_1"]
        for imageName in mathImages {
            let imageView = createImageView(named: imageName)
            mathStackView.addArrangedSubview(imageView)
        }
        
        // Add automata images
        let automataImages = ["automata_0", "automata_1"]
        for imageName in automataImages {
            let imageView = createImageView(named: imageName)
            automataStackView.addArrangedSubview(imageView)
        }
    }
}

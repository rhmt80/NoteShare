import UIKit

class InterestsViewController: UIViewController {
    
    private let backButton: UIButton = {
        var config = UIButton.Configuration.plain()
               config.title = "Back"
               config.image = UIImage(systemName: "chevron.left")
               config.baseForegroundColor = .systemBlue
               config.imagePlacement = .leading
               config.imagePadding = 8
               let button = UIButton(configuration: config)
               button.translatesAutoresizingMaskIntoConstraints = false
               return button
    }()
    
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your Interests"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select the topics you'd like to explore"
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let continueButton: UIButton = {
            let button = UIButton(type: .system)
            button.setTitle("Continue", for: .normal)
            button.backgroundColor = .systemBlue
            button.setTitleColor(.white, for: .normal)
            button.layer.cornerRadius = 25
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
            button.translatesAutoresizingMaskIntoConstraints = false
            return button
        }()


    private var selectedRecommendedInterests: Set<String> = []
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let interestsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let interests = [
        
        "Mathematics",
        "Algorithms",
        "Data Structures",
        "Computer Architecture",
        "Operating Systems",
        "Networking",
        "Database Systems",
        "System Design",
        
        
        "Python",
        "Java",
        "C++",
        "JavaScript",
        "Swift",
        "Rust",
        "Go",
        "TypeScript",
        
        
        "Artificial Intelligence",
        "Machine Learning",
        "Deep Learning",
        "Natural Language Processing",
        "Computer Vision",
        "Reinforcement Learning",
        "LLMs",
        "Neural Networks",
        
        
        "Web Development",
        "Mobile Development",
        "Frontend",
        "Backend",
        "UI/UX Design",
        "DevOps",
        "Cloud Computing",
        
        
        "Calculus",
        "Linear Algebra",
        "Statistics",
        "Probability",
        "Discrete Mathematics",
        "Graph Theory",
        "Automata Theory",
        
        
        "Blockchain",
        "Cybersecurity",
        "IoT",
        "AR/VR",
        "Quantum Computing",
        "Edge Computing",
        "Robotics"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        setupUI()
        setupBackButton()
        view.addSubview(continueButton)
        updateContinueButton()
    }
    
    
    
    private func setupBackButton() {
        
        guard backButton.superview == nil else { return }
        
        
        view.addSubview(backButton)
        
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(scrollView)
        view.addSubview(continueButton)
        
        scrollView.addSubview(interestsContainer)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),
            
            interestsContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            interestsContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            interestsContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            interestsContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            interestsContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            

        ])
       
        createInterestButtons()
    }
    
    private let recommendedInterests = [
            "UI/UX",
            "Web Development",
            "Cybersecurity",
            "Artificial Intelligence",
            "iOS Development"
        ]
        
        private func createInterestButtons() {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            let spacing: CGFloat = 10
            var maxHeight: CGFloat = 0
            
            //  Recommended Topics Label
            let recommendedLabel = UILabel()
            recommendedLabel.text = "Recommended for You"
            recommendedLabel.font = .systemFont(ofSize: 20, weight: .semibold)
            recommendedLabel.frame = CGRect(x: 0, y: currentY, width: view.bounds.width - 40, height: 40)
            interestsContainer.addSubview(recommendedLabel)
            currentY += 50
            
            for interest in recommendedInterests {
                let button = createInterestButton(withTitle: interest, isRecommended: true)
                let buttonWidth = button.intrinsicContentSize.width + 20
                
                if currentX + buttonWidth > (view.bounds.width - 40) {
                    currentX = 0
                    currentY += 40 + spacing
                }
                
                button.frame = CGRect(x: currentX, y: currentY, width: buttonWidth, height: 40)
                interestsContainer.addSubview(button)
                
                currentX += buttonWidth + spacing
            }
            
            //separator
            let separator = UIView()
            separator.backgroundColor = .systemGray4
            separator.frame = CGRect(x: 0, y: currentY + 50, width: view.bounds.width - 40, height: 1)
            interestsContainer.addSubview(separator)
            currentY += 60
            
            
            currentX = 0
            

            let allInterestsLabel = UILabel()
            allInterestsLabel.text = "All Topics"
            allInterestsLabel.font = .systemFont(ofSize: 20, weight: .semibold)
            allInterestsLabel.frame = CGRect(x: 0, y: currentY, width: view.bounds.width - 40, height: 40)
            interestsContainer.addSubview(allInterestsLabel)
            currentY += 50
            
            
            for interest in interests {
                let button = createInterestButton(withTitle: interest)
                let buttonWidth = button.intrinsicContentSize.width + 20
                
                if currentX + buttonWidth > (view.bounds.width - 40) {
                    currentX = 0
                    currentY += 40 + spacing
                }
                
                button.frame = CGRect(x: currentX, y: currentY, width: buttonWidth, height: 40)
                interestsContainer.addSubview(button)
                
                currentX += buttonWidth + spacing
                maxHeight = currentY + 40
            }
            
            let containerHeight = maxHeight + 100
            interestsContainer.heightAnchor.constraint(equalToConstant: containerHeight).isActive = true
        }
        
    private func createInterestButton(withTitle title: String, isRecommended: Bool = false) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .systemGray6
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 20
        button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
        button.addTarget(self, action: #selector(interestButtonTapped(_:)), for: .touchUpInside)
        if isRecommended {
            button.tag = 1000
        }
        
        return button
    }
    
    @objc private func interestButtonTapped(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        if sender.tag == 1000 { // Recommended button
            if selectedRecommendedInterests.contains(title) {
                selectedRecommendedInterests.remove(title)
                sender.backgroundColor = .systemGray6
                sender.setTitleColor(.systemBlue, for: .normal)
            } else {
                // Select -  limited to 2
                if selectedRecommendedInterests.count < 2 {
                    selectedRecommendedInterests.insert(title)
                    sender.backgroundColor = .systemBlue
                    sender.setTitleColor(.white, for: .normal)
                } else {
                    // Show alert if trying to select more than 2
                    let alert = UIAlertController(
                        title: "Selection Limit",
                        message: "Please select only 2 recommended topics",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                    present(alert, animated: true)
                }
            }
        } else {
            sender.isSelected.toggle()
            sender.backgroundColor = sender.isSelected ? .systemBlue : .systemGray6
            sender.setTitleColor(sender.isSelected ? .white : .systemBlue, for: .normal)
        }
        updateContinueButton()
    }
    
    private func updateContinueButton() {
        continueButton.isEnabled = selectedRecommendedInterests.count == 2
        continueButton.backgroundColor = selectedRecommendedInterests.count == 2 ? .systemBlue : .systemGray4
        continueButton.setTitleColor(selectedRecommendedInterests.count == 2 ? .white : .systemGray, for: .normal)
    }
    
    @objc private func continueButtonTapped() {
        guard selectedRecommendedInterests.count == 2 else {
            let alert = UIAlertController(
                title: "Topic Selection",
                message: "Please select exactly 2 recommended topics",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true)
            return
        }
        if let delegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
            delegate.gototab()
        }
    }
}

#Preview {
    InterestsViewController()
}

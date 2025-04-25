
import UIKit
import FirebaseAuth
import FirebaseFirestore

class CollegeSelectionViewController: UIViewController {
    
    // MARK: - Properties
    private let db = Firestore.firestore()
    
    private lazy var collegeDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select College", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.menu = createCollegeMenu()
        button.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }()
    
        private lazy var selectedInterestsStackView: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .vertical
            stackView.spacing = 8
            stackView.alignment = .leading  // Changed to leading alignment
            stackView.distribution = .fillProportionally
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()
    
        private lazy var currentRowStackView: UIStackView = {
            let stackView = UIStackView()
            stackView.axis = .horizontal
            stackView.spacing = 8
            stackView.alignment = .leading  // Changed to leading alignment
            stackView.distribution = .fill  // Changed to fill
            stackView.translatesAutoresizingMaskIntoConstraints = false
            return stackView
        }()
    
        @objc private func removeInterest(_ sender: UIButton) {
            guard let interest = sender.accessibilityLabel,
                  let index = selectedInterests.firstIndex(of: interest) else { return }
    
            selectedInterests.remove(at: index)
            updateSelectedInterestsUI()
        }
    
    
    private lazy var yearDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Year", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.menu = createYearMenu()
        button.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }()
    
    private lazy var courseDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Course", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.menu = createCourseMenu()
        button.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }()
    
    private lazy var interestDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Interests", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.menu = createInterestMenu()
        button.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }()
    
    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        return button
    }()
    
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
    
    // Sample data
    private let colleges = [
        "SRM",
        "VIT",
        "Amity",
        "KIIT",
        "Manipal",
        "LPU"
    ]
    
    private let courses = [
        "Computer Science",
        "ECE",
        "Mechanical",
        "Civil",
        "Electrical"
    ]
    
    private let interests = [
        "Core Cse",
        "Web & App Development",
        "AIML",
        "Core ECE",
        "Core Mechanical",
        "Core Civil",
        "Core Electrical",
        "Physics",
        "Maths"
    ]
    
    // User selections
    private var selectedCollege: String?
    private var selectedYear: Int = 0
    private var selectedCourse: String?
    private var selectedInterests: [String] = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadUserData()
        
        navigationItem.hidesBackButton = true
        navigationController?.navigationBar.isHidden = true
    }
    
    // MARK: - Firebase Integration
    private func loadUserData() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self,
                  let data = snapshot?.data(),
                  error == nil else { return }
            
            if let college = data["college"] as? String {
                self.selectedCollege = college
                self.collegeDropdownButton.setTitle(college, for: .normal)
            }
            
            if let year = data["year"] as? Int {
                self.selectedYear = year
                self.yearDropdownButton.setTitle("Year \(year)", for: .normal)
            }
            
            if let course = data["course"] as? String {
                self.selectedCourse = course
                self.courseDropdownButton.setTitle(course, for: .normal)
            }
            
            if let interests = data["interests"] as? [String] {
                self.selectedInterests = interests
                self.updateSelectedInterestsUI()
            }
        }
    }
    
    private func saveUserData(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            completion(false)
            return
        }
        
        let userData: [String: Any] = [
            "college": selectedCollege ?? "",
            "year": selectedYear,
            "course": selectedCourse ?? "",
            "interests": selectedInterests,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        db.collection("users").document(userId).setData(userData, merge: true) { error in
            completion(error == nil)
        }
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(continueButton)
        
        // Setup main stack view
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 15
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        // Add components to stack
        let collegeLabel = createLabel(text: "Select your College")
        mainStack.addArrangedSubview(collegeLabel)
        mainStack.addArrangedSubview(collegeDropdownButton)
        
        let yearLabel = createLabel(text: "Select your current academic year")
        mainStack.addArrangedSubview(yearLabel)
        mainStack.addArrangedSubview(yearDropdownButton)
        
        let courseLabel = createLabel(text: "Select your course")
        mainStack.addArrangedSubview(courseLabel)
        mainStack.addArrangedSubview(courseDropdownButton)
        
        let interestLabel = createLabel(text: "Select your interests")
        mainStack.addArrangedSubview(interestLabel)
        mainStack.addArrangedSubview(interestDropdownButton)
        
        // Add the selected interests stack view
        mainStack.addArrangedSubview(selectedInterestsStackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        return label
    }
    
    // MARK: - Menu Creation
    private func createCollegeMenu() -> UIMenu {
        let actions = colleges.map { college in
            UIAction(title: college) { [weak self] _ in
                self?.selectedCollege = college
                self?.collegeDropdownButton.setTitle(college, for: .normal)
            }
        }
        return UIMenu(title: "Select College", children: actions)
    }
    
    private func createYearMenu() -> UIMenu {
        let actions = (1...4).map { year in
            UIAction(title: "Year \(year)") { [weak self] _ in
                self?.selectedYear = year
                self?.yearDropdownButton.setTitle("Year \(year)", for: .normal)
            }
        }
        return UIMenu(title: "Select Academic Year", children: actions)
    }
    
    private func createCourseMenu() -> UIMenu {
        let actions = courses.map { course in
            UIAction(title: course) { [weak self] _ in
                self?.selectedCourse = course
                self?.courseDropdownButton.setTitle(course, for: .normal)
            }
        }
        return UIMenu(title: "Select Course", children: actions)
    }
    
    private func createInterestMenu() -> UIMenu {
        let actions = interests.map { interest in
            UIAction(title: interest, state: selectedInterests.contains(interest) ? .on : .off) { [weak self] _ in
                if let index = self?.selectedInterests.firstIndex(of: interest) {
                    self?.selectedInterests.remove(at: index)
                } else {
                    self?.selectedInterests.append(interest)
                }
                self?.updateSelectedInterestsUI()
            }
        }
        return UIMenu(title: "Select Interests", children: actions)
    }
    
    // Rest of the methods (updateSelectedInterestsUI, createInterestChip, etc.) remain the same
    // Include them here with their original implementation
    
        private func updateSelectedInterestsUI() {
            // Clear all stack views
            selectedInterestsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
            currentRowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    
            var currentRowWidth: CGFloat = 0
            let maxWidth = UIScreen.main.bounds.width - 40 // Account for margins
    
            // Create new row stack view
            currentRowStackView = UIStackView()
            currentRowStackView.axis = .horizontal
            currentRowStackView.spacing = 8
            currentRowStackView.alignment = .leading
            currentRowStackView.distribution = .fill
            selectedInterestsStackView.addArrangedSubview(currentRowStackView)
    
            for interest in selectedInterests {
                let chipView = createInterestChip(with: interest)
    
                // Calculate the width of this chip
                let chipWidth = interest.size(withAttributes: [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium)
                ]).width + 50 // Add padding for margins and cross icon
    
                if currentRowWidth + chipWidth > maxWidth {
                    // Create new row
                    currentRowWidth = 0
                    currentRowStackView = UIStackView()
                    currentRowStackView.axis = .horizontal
                    currentRowStackView.spacing = 8
                    currentRowStackView.alignment = .leading
                    currentRowStackView.distribution = .fill
                    selectedInterestsStackView.addArrangedSubview(currentRowStackView)
                }
    
                currentRowStackView.addArrangedSubview(chipView)
                currentRowWidth += chipWidth + 8 // Add spacing
    
                // Add flexible space after each chip
                let spacerView = UIView()
                spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                currentRowStackView.addArrangedSubview(spacerView)
            }
    
            // Update the dropdown button title
            interestDropdownButton.setTitle(selectedInterests.isEmpty ? "Select Interests" : selectedInterests.joined(separator: ", "), for: .normal)
        }
    
        private func createInterestChip(with interest: String) -> UIView {
            // Create container view
            let containerView = UIView()
            containerView.translatesAutoresizingMaskIntoConstraints = false
    
            // Create the background view
            let backgroundView = UIView()
            backgroundView.backgroundColor = .systemBlue
            backgroundView.layer.cornerRadius = 15
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
    
            // Create label
            let label = UILabel()
            label.text = interest
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.translatesAutoresizingMaskIntoConstraints = false
    
            // Create cross button
            let crossButton = UIButton(type: .system)
            crossButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
            crossButton.tintColor = .white
            crossButton.translatesAutoresizingMaskIntoConstraints = false
    
            // Add views to hierarchy
            containerView.addSubview(backgroundView)
            containerView.addSubview(label)
            containerView.addSubview(crossButton)
    
            // Setup constraints
            NSLayoutConstraint.activate([
                // Container constraints
                containerView.heightAnchor.constraint(equalToConstant: 30),
    
                // Background view constraints
                backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
    
                // Label constraints
                label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
                label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
    
                // Cross button constraints
                crossButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 5),
                crossButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                crossButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
                crossButton.widthAnchor.constraint(equalToConstant: 16),
                crossButton.heightAnchor.constraint(equalToConstant: 16)
            ])
    
            // Add tap handler for the cross button
            crossButton.addTarget(self, action: #selector(removeInterest(_:)), for: .touchUpInside)
            crossButton.accessibilityLabel = interest
    
            return containerView
        }
    
        private func validateSelections() -> Bool {
            let collegeSelected = selectedCollege != nil
            let yearSelected = selectedYear != 0
            let courseSelected = selectedCourse != nil
            let interestsSelected = !selectedInterests.isEmpty
    
            return collegeSelected && yearSelected && courseSelected && interestsSelected
        }
    
    
    
    @objc private func continueButtonTapped() {
        if validateSelections() {
            saveUserData { [weak self] success in
                guard let self = self else { return }
                
                if success {
                    if let delegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                        delegate.gototab()
                    }
                } else {
                    self.showErrorAlert()
                }
            }
        } else {
            showIncompleteSelectionAlert()
        }
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Failed to save your selections. Please try again.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showIncompleteSelectionAlert() {
        let alert = UIAlertController(
            title: "Incomplete Selection",
            message: "Please complete all selections including at least one interest",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

#Preview {
    CollegeSelectionViewController()
}

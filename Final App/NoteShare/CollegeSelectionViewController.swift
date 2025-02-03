
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
    
    private let courseCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: (UIScreen.main.bounds.width - 50) / 2, height: 60)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(CourseCell.self, forCellWithReuseIdentifier: "CourseCell")
        collection.allowsSelection = true
        collection.allowsMultipleSelection = false
        return collection
    }()
    
    private let interestsLabel: UILabel = {
        let label = UILabel()
        label.text = "Select your interests"
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let interestsCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: (UIScreen.main.bounds.width - 50) / 2, height: 40)
        
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.translatesAutoresizingMaskIntoConstraints = false
        collection.register(InterestCell.self, forCellWithReuseIdentifier: "InterestCell")
        collection.allowsMultipleSelection = true
        return collection
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
        "Computer Science"
    ]
    
    private let interests = [
        "Core Cse",
        "Web & App Development",
        "AIML",
        "Data Science Analysis",
        "Cybersecurity & Hacking",
        "Core Cse",
        "Physics",
        "Chemistry",
        "Maths",
        "DevOps & Cloud Computing",
        "Others*"
    ]
    
        
        private func saveUserData(completion: @escaping (Bool) -> Void) {
            guard let userId = Auth.auth().currentUser?.uid else {
                completion(false)
                return
            }
            
            // Convert selected interest indices to strings
            let interestStrings = selectedInterests.map { interests[$0] }
            
            let userData: [String: Any] = [
                "college": selectedCollege ?? "",
                "year": selectedYear,
                "courseIndex": selectedCourse ?? 0,
                "interests": interestStrings,
                "updatedAt": FieldValue.serverTimestamp()
            ]
            
            db.collection("users").document(userId).setData(userData, merge: true) { error in
                completion(error == nil)
            }
        }
    
    // User selections
    private var selectedCollege: String?
    private var selectedYear: Int = 0
    private var selectedCourse: Int?
    private var selectedInterests: Set<Int> = []
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
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
            
            // Load saved selections
            if let college = data["college"] as? String {
                self.selectedCollege = college
                self.collegeDropdownButton.setTitle(college, for: .normal)
            }
            
            if let year = data["year"] as? Int {
                self.selectedYear = year
                self.yearDropdownButton.setTitle("Year \(year)", for: .normal)
            }
            
            if let courseIndex = data["courseIndex"] as? Int {
                self.selectedCourse = courseIndex
                let indexPath = IndexPath(item: courseIndex, section: 0)
                self.courseCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            }
            
                    if let interestStrings = data["interests"] as? [String] {
                                    self.selectedInterests = Set(interestStrings.compactMap { interestString in
                                        self.interests.firstIndex(of: interestString)
                                    })
                                    
                                    self.selectedInterests.forEach { interest in
                                        let indexPath = IndexPath(item: interest, section: 0)
                                        self.interestsCollectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
                                    }
                
                
            }
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
            mainStack.spacing = 15 // Reduced spacing
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
            mainStack.addArrangedSubview(courseCollectionView)
    
            mainStack.addArrangedSubview(interestsLabel)
            mainStack.addArrangedSubview(interestsCollectionView)
    
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
    
                collegeDropdownButton.heightAnchor.constraint(equalToConstant: 50),
                yearDropdownButton.heightAnchor.constraint(equalToConstant: 50),
                courseCollectionView.heightAnchor.constraint(equalToConstant: 80),
                // Adjusted height to accommodate larger cells and more rows
                interestsCollectionView.heightAnchor.constraint(equalToConstant: 250),
    
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
    
    private func setupDelegates() {
        courseCollectionView.delegate = self
        courseCollectionView.dataSource = self
        interestsCollectionView.delegate = self
        interestsCollectionView.dataSource = self
    }
    
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
    
    private func validateSelections() -> Bool {
        let collegeSelected = selectedCollege != nil
        let yearSelected = selectedYear != 0
        let courseSelected = selectedCourse != nil
        let interestsSelected = !selectedInterests.isEmpty
        
        return collegeSelected && yearSelected && courseSelected && interestsSelected
    }
    
    // MARK: - Actions
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

// MARK: - CollectionView Delegate & DataSource
extension CollegeSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return collectionView == courseCollectionView ? courses.count : interests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == courseCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseCell", for: indexPath) as! CourseCell
            cell.configure(with: courses[indexPath.row])
            return cell
        } else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InterestCell", for: indexPath) as! InterestCell
            cell.configure(with: interests[indexPath.row])
            return cell
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == courseCollectionView {
            selectedCourse = indexPath.row
        } else {
            selectedInterests.insert(indexPath.row)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if collectionView == interestsCollectionView {
            selectedInterests.remove(indexPath.row)
        }
    }
}


class InterestCell: UICollectionViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        return label
    }()
    
    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 20
        
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
    
    private func updateSelectionState() {
        UIView.animate(withDuration: 0.2) {
            self.backgroundColor = self.isSelected ? .systemBlue : .systemGray6
            self.titleLabel.textColor = self.isSelected ? .white : .label
        }
    }
}

// MARK: - Course Cell
class CourseCell: UICollectionViewCell {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 2
        label.textColor = .label
        return label
    }()
    
    override var isSelected: Bool {
        didSet {
            updateSelectionState()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupCell() {
        backgroundColor = .systemGray6
        layer.cornerRadius = 12
        
        // Add shadow to the cell
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        // Configure contentView
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        contentView.backgroundColor = .systemGray6
        
        // Add and constrain titleLabel
        contentView.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(with title: String) {
        titleLabel.text = title
    }
    
    private func updateSelectionState() {
        UIView.animate(withDuration: 0.2) {
            self.contentView.backgroundColor = self.isSelected ? .systemBlue : .systemGray6
            self.titleLabel.textColor = self.isSelected ? .white : .label
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        isSelected = false
        titleLabel.text = nil
    }
    
    // Handle highlighted state
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
    
    // Update layout for trait changes (e.g., dark mode)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            layer.shadowColor = UIColor.black.cgColor
        }
    }
}


#Preview {
    CollegeSelectionViewController()
}

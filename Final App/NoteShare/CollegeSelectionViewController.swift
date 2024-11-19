import UIKit

class CollegeSelectionViewController: UIViewController {
    
    // MARK: - Properties
    private let collegeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Choose your college"
        textField.borderStyle = .roundedRect
        textField.backgroundColor = .systemBackground
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.layer.borderWidth = 1
        textField.layer.cornerRadius = 8
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        return textField
    }()
    
    private let collegeTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.isHidden = true
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.layer.borderWidth = 1
        tableView.layer.cornerRadius = 8
        tableView.clipsToBounds = true
        return tableView
    }()
    
    private let yearStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
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
    
    
    private lazy var continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // Sample data
    private let colleges = ["SRM", "Stanford", "VIT", "Oxford", "IIT", "MIT", "Harvard", "Cambridge"]
    private var filteredColleges: [String] = []
    private let courses = ["Computer Science", "MBA", "Medicine", "Law", "Engineering", "Arts", "Physics", "Mathematics"]
    private var selectedYear: Int = 0
    private var selectedCourse: Int?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
        
        navigationItem.hidesBackButton = true
        navigationController?.navigationBar.isHidden = true
        
        // Initialize filtered colleges
        filteredColleges = colleges
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        tap.cancelsTouchesInView = false
        self.view.addGestureRecognizer(tap)
    }
    
    @objc
    func hideKeyboard() {
        collegeTextField.resignFirstResponder()
        collegeTableView.isHidden = true
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup main stack view
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 30
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainStack)
        view.addSubview(continueButton)
        view.addSubview(collegeTableView)
        
        // College Selection Section
        let collegeLabel = createLabel(text: "Select your College")
        mainStack.addArrangedSubview(collegeLabel)
        mainStack.addArrangedSubview(collegeTextField)
        
        // Year Selection Section
        let yearLabel = createLabel(text: "Select your current academic year")
        mainStack.addArrangedSubview(yearLabel)
        mainStack.addArrangedSubview(yearStackView)
        
        // Setup year buttons
        for year in 1...4 {
            let yearButton = createYearButton(year: year)
            yearStackView.addArrangedSubview(yearButton)
        }
        
        // Course Selection Section
        let courseLabel = createLabel(text: "Select your course")
        mainStack.addArrangedSubview(courseLabel)
        mainStack.addArrangedSubview(courseCollectionView)
        
        // Constraints
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            mainStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mainStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            collegeTextField.heightAnchor.constraint(equalToConstant: 50),
            yearStackView.heightAnchor.constraint(equalToConstant: 80),
            courseCollectionView.heightAnchor.constraint(equalToConstant: 350),
            
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 56),
            
            collegeTableView.topAnchor.constraint(equalTo: collegeTextField.bottomAnchor, constant: 5),
            collegeTableView.leadingAnchor.constraint(equalTo: collegeTextField.leadingAnchor),
            collegeTableView.trailingAnchor.constraint(equalTo: collegeTextField.trailingAnchor),
            collegeTableView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        collegeTableView.register(UITableViewCell.self, forCellReuseIdentifier: "CollegeCell")
        
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        collegeTextField.addTarget(self, action: #selector(collegeTextFieldEditingChanged), for: .editingChanged)
    }
    
    private func createLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .label
        return label
    }
    
    private func createYearButton(year: Int) -> UIButton {
        let button = UIButton()
        let size: CGFloat = 60
        button.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: size),
            button.heightAnchor.constraint(equalToConstant: size)
        ])
        
        button.setTitle("\(year)", for: .normal)
        button.backgroundColor = .systemGray5
        button.setTitleColor(.label, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .medium)
        button.layer.cornerRadius = size / 2
        button.clipsToBounds = true
        
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.1
        
        button.tag = year
        button.addTarget(self, action: #selector(yearButtonTapped), for: .touchUpInside)
        
        return button
    }
    
    private func setupDelegates() {
        collegeTableView.delegate = self
        collegeTableView.dataSource = self
        courseCollectionView.delegate = self
        courseCollectionView.dataSource = self
        collegeTextField.delegate = self
    }
    
    // MARK: - Actions
    @objc private func collegeTextFieldEditingChanged() {
        let searchText = collegeTextField.text?.lowercased() ?? ""
        filteredColleges = colleges.filter { $0.lowercased().contains(searchText) }
        if searchText.isEmpty {
            filteredColleges = colleges
        }
        collegeTableView.isHidden = false
        collegeTableView.reloadData()
    }
    
    @objc private func continueButtonTapped() {
        let loginVC = InterestsViewController()
        navigationController?.pushViewController(loginVC, animated: true)
    }
    
    @objc private func yearButtonTapped(_ sender: UIButton) {
        selectedYear = sender.tag
        
        yearStackView.arrangedSubviews.forEach { view in
            if let button = view as? UIButton {
                UIView.animate(withDuration: 0.2) {
                    button.backgroundColor = button.tag == sender.tag ? .systemBlue : .systemGray5
                    button.setTitleColor(button.tag == sender.tag ? .white : .label, for: .normal)
                }
            }
        }
    }
}

// MARK: - TableView Delegate & DataSource
extension CollegeSelectionViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredColleges.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CollegeCell", for: indexPath)
        cell.textLabel?.text = filteredColleges[indexPath.row]
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        collegeTextField.text = filteredColleges[indexPath.row]
        collegeTableView.isHidden = true
        collegeTextField.resignFirstResponder()
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - CollectionView Delegate & DataSource
extension CollegeSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return courses.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CourseCell", for: indexPath) as! CourseCell
        cell.configure(with: courses[indexPath.row])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        selectedCourse = indexPath.row
        
        // Deselect any previously selected cells
        if let previousSelectedIndexPath = collectionView.indexPathsForSelectedItems?.first,
           previousSelectedIndexPath != indexPath {
            collectionView.deselectItem(at: previousSelectedIndexPath, animated: true)
        }
    }
}

// MARK: - TextField Delegate
extension CollegeSelectionViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        collegeTableView.isHidden = false
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
        
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.1
        
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
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
#Preview() {
    CollegeSelectionViewController()
}

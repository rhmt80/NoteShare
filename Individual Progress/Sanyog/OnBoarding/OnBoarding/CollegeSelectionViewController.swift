//
//  CollegeSelectionViewController.swift
//  OnBoarding
//
//  Created by admin24 on 05/11/24.
//


import UIKit

class CollegeSelectionViewController: UIViewController {
    // Previous UI elements remain the same
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let backButton: UIButton = {
        let button = UIButton()
        let image = UIImage(systemName: "chevron.left")
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select your college"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private lazy var collegeDropdown: DropdownField = {
        return createDropdownField(placeholder: "Select below")
    }()
    
    private lazy var yearDropdown: DropdownField = {
        return createDropdownField(placeholder: "Select below")
    }()
    
    private lazy var courseDropdown: DropdownField = {
        return createDropdownField(placeholder: "Select below")
    }()
    
    // New UI elements for interests section
    
    private let continueButton: UIButton = {
        let button = UIButton()
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private func setupDropdowns() {
            // Set up college dropdown
            collegeDropdown.options = [
                "Harvard University",
                "MIT",
                "Stanford University",
                "Yale University",
                "Princeton University"
            ]
            collegeDropdown.addTarget(self, action: #selector(dropdownValueChanged(_:)), for: .valueChanged)
            
            // Set up year dropdown
            yearDropdown.options = [
                "First Year",
                "Second Year",
                "Third Year",
                "Fourth Year"
            ]
            yearDropdown.addTarget(self, action: #selector(dropdownValueChanged(_:)), for: .valueChanged)
            
            // Set up course dropdown
            courseDropdown.options = [
                "Computer Science",
                "Engineering",
                "Mathematics",
                "Physics",
                "Business Administration"
            ]
            courseDropdown.addTarget(self, action: #selector(dropdownValueChanged(_:)), for: .valueChanged)
        }
        
        @objc private func dropdownValueChanged(_ sender: DropdownField) {
            // Handle the selection
            if sender === collegeDropdown {
                print("Selected college: \(sender.selectedOption ?? "None")")
            } else if sender === yearDropdown {
                print("Selected year: \(sender.selectedOption ?? "None")")
            } else if sender === courseDropdown {
                print("Selected course: \(sender.selectedOption ?? "None")")
            }
        }
    
    // Sample data
    private let colleges = ["SRM University","VIT","Manipal University","Harvard University", "MIT", "Stanford University", "Yale University"]
    private let years = ["First Year", "Second Year", "Third Year", "Fourth Year"]
    private let courses = ["Computer Science", "Medical Science", "Business", "Arts","Entreprunership"]
    
    private var interests: [(name: String, isSelected: Bool)] = [
        ("IOS Dev", false),
        ("Android Dev", false),
        ("WebDev", false),
        ("C++", false),
        ("Maths", false),
        ("COA", false),
        ("Physics", false),
        ("Automata", false),
        ("Chem", false),
        ("Swift", false),
        ("Data Structures", false),
        ("OS", false)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupActions()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(backButton)
        view.addSubview(stackView)
        view.addSubview(continueButton)
        
        stackView.addArrangedSubview(titleLabel)
        
        let collegeLabel = createSectionLabel(text: "Select your college")
        stackView.addArrangedSubview(collegeLabel)
        stackView.addArrangedSubview(collegeDropdown)
        
        let yearLabel = createSectionLabel(text: "Enter current college year")
        stackView.addArrangedSubview(yearLabel)
        stackView.addArrangedSubview(yearDropdown)
        
        let courseLabel = createSectionLabel(text: "Enter your course")
        stackView.addArrangedSubview(courseLabel)
        stackView.addArrangedSubview(courseDropdown)
    
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            stackView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
        
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -300),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
   
    // Previous helper methods remain the same
    private func setupActions() {
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
        
        collegeDropdown.options = colleges
        yearDropdown.options = years
        courseDropdown.options = courses
    }
    
    private func createSectionLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 16, weight: .regular)
        return label
    }
    
    private func createDropdownField(placeholder: String) -> DropdownField {
        let field = DropdownField()
        field.placeholder = placeholder
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return field
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func continueButtonTapped() {
        let selectedInterests = interests.filter { $0.isSelected }.map { $0.name }
        print("Selected interests: \(selectedInterests)")
    }
}

// Collection View Extension
extension CollegeSelectionViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return interests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InterestCell", for: indexPath) as! InterestCell
        cell.configure(with: interests[indexPath.item].name, isSelected: interests[indexPath.item].isSelected)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        interests[indexPath.item].isSelected.toggle()
        collectionView.reloadItems(at: [indexPath])
    }
}

// Interest Cell
class InterestCell: UICollectionViewCell {
    private let label: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        contentView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        contentView.layer.cornerRadius = 15
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    func configure(with text: String, isSelected: Bool) {
        label.text = text
        if isSelected {
            contentView.backgroundColor = .systemBlue
            label.textColor = .white
        } else {
            contentView.backgroundColor = UIColor(white: 0.95, alpha: 1)
            label.textColor = .black
        }
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 35)
        let size = contentView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .defaultHigh, verticalFittingPriority: .defaultHigh)
        attributes.frame = CGRect(origin: attributes.frame.origin, size: size)
        return attributes
    }
}

// Previous DropdownField class remains the same
class DropdownField: UIControl {
    // MARK: - Properties
    private(set) var selectedOption: String? {
        didSet {
            textField.text = selectedOption
        }
    }
    
    var options: [String] = [] {
        didSet {
            pickerView.reloadAllComponents()
        }
    }
    
    var placeholder: String = "" {
        didSet {
            textField.placeholder = placeholder
        }
    }
    
    // MARK: - UI Elements
    private lazy var textField: UITextField = {
        let field = UITextField()
        field.borderStyle = .none
        field.backgroundColor = .systemBackground
        field.translatesAutoresizingMaskIntoConstraints = false
        field.delegate = self
        return field
    }()
    
    private lazy var pickerView: UIPickerView = {
        let picker = UIPickerView()
        picker.delegate = self
        picker.dataSource = self
        return picker
    }()
    
    private let bottomLine: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray4
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let dropdownIndicator: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "chevron.down")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup
    private func setupUI() {
        addSubview(textField)
        addSubview(bottomLine)
        addSubview(dropdownIndicator)
        
        // Setup picker view as input view
        textField.inputView = pickerView
        
        // Add toolbar with Done button
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonTapped))
        toolbar.setItems([flexSpace, doneButton], animated: false)
        textField.inputAccessoryView = toolbar
        
        // Add tap gesture to the entire view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(viewTapped))
        addGestureRecognizer(tapGesture)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // TextField constraints
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: dropdownIndicator.leadingAnchor, constant: -8),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            // Bottom line constraints
            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            bottomLine.heightAnchor.constraint(equalToConstant: 1),
            
            // Dropdown indicator constraints
            dropdownIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),
            dropdownIndicator.trailingAnchor.constraint(equalTo: trailingAnchor),
            dropdownIndicator.widthAnchor.constraint(equalToConstant: 20),
            dropdownIndicator.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    // MARK: - Actions
    @objc private func doneButtonTapped() {
        if selectedOption == nil && !options.isEmpty {
            // If nothing is selected, select the first option
            selectedOption = options[0]
            pickerView.selectRow(0, inComponent: 0, animated: false)
        }
        textField.resignFirstResponder()
        sendActions(for: .valueChanged)
    }
    
    @objc private func viewTapped() {
        textField.becomeFirstResponder()
    }
}

// MARK: - UIPickerView Delegate & DataSource
extension DropdownField: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return options.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return options[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedOption = options[row]
        sendActions(for: .valueChanged)
    }
}

// MARK: - UITextField Delegate
extension DropdownField: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false // Prevent manual text input
    }
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        // Rotate the dropdown indicator when opening
        UIView.animate(withDuration: 0.3) {
            self.dropdownIndicator.transform = CGAffineTransform(rotationAngle: .pi)
        }
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Reset the dropdown indicator rotation when closing
        UIView.animate(withDuration: 0.3) {
            self.dropdownIndicator.transform = .identity
        }
    }
}

#Preview {
    CollegeSelectionViewController()
}

import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class ScannedPDFUploadViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var scannedPDFData: Data?
    private let db = Firestore.firestore()

    init(scannedPDFData: Data?) {
        self.scannedPDFData = scannedPDFData
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // UI Components
    private let titleLabel = UILabel()
    private lazy var categoryDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Category", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.menu = createCategoryMenu()
        button.showsMenuAsPrimaryAction = true
        NSLayoutConstraint.activate([
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
        return button
    }()
    private let collegePickerTextField = UITextField()
    private let subjectCodeTextField = UITextField()
    private let subjectNameTextField = UITextField()
    private let fileNameTextField = UITextField()
    private let uploadButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private let collegePickerView = UIPickerView()

    private let categories = [
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

    private var selectedCategory: String?
    private let colleges = ["SRM", "VIT", "KIIT", "Manipal", "LPU", "Amity"]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupDelegates()
        setupActions()
        fetchUserCollege()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // MARK: - Create Category Menu
    private func createCategoryMenu() -> UIMenu {
        let actions = categories.map { category in
            UIAction(title: category) { [weak self] action in
                self?.selectedCategory = category
                self?.categoryDropdownButton.setTitle(category, for: .normal)
            }
        }
        return UIMenu(title: "", children: actions)
    }

    // MARK: - Fetch User College
    private func fetchUserCollege() {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        loadingIndicator.center = collegePickerTextField.center
        view.addSubview(loadingIndicator)

        db.collection("users").document(userId).getDocument { [weak self] (document, error) in
            DispatchQueue.main.async {
                loadingIndicator.removeFromSuperview()
                
                guard let self = self else { return }
                
                if let error = error {
                    self.showAlert(title: "Error", message: "Failed to fetch college: \(error.localizedDescription)")
                    return
                }
                
                if let document = document, document.exists,
                   let college = document.data()?["college"] as? String {
                    self.collegePickerTextField.text = college
                }
            }
        }
    }

    // MARK: - Setup UI
    private func setupUI() {
        titleLabel.text = "Upload Scanned PDF"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)

        collegePickerTextField.placeholder = "Select College"
        collegePickerTextField.borderStyle = .roundedRect

        subjectCodeTextField.placeholder = "Subject Code"
        subjectCodeTextField.borderStyle = .roundedRect

        subjectNameTextField.placeholder = "Subject Name"
        subjectNameTextField.borderStyle = .roundedRect

        fileNameTextField.placeholder = "Major Topics"
        fileNameTextField.borderStyle = .roundedRect

        uploadButton.setTitle("Upload", for: .normal)
        uploadButton.backgroundColor = .systemBlue
        uploadButton.layer.cornerRadius = 10
        uploadButton.setTitleColor(.white, for: .normal)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .systemRed
        cancelButton.layer.cornerRadius = 10
        cancelButton.setTitleColor(.white, for: .normal)

        // Add subviews
        [titleLabel, categoryDropdownButton, collegePickerTextField, subjectCodeTextField,
         subjectNameTextField, fileNameTextField, uploadButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            categoryDropdownButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            categoryDropdownButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryDropdownButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            collegePickerTextField.topAnchor.constraint(equalTo: categoryDropdownButton.bottomAnchor, constant: 20),
            collegePickerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collegePickerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subjectCodeTextField.topAnchor.constraint(equalTo: collegePickerTextField.bottomAnchor, constant: 20),
            subjectCodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectCodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subjectNameTextField.topAnchor.constraint(equalTo: subjectCodeTextField.bottomAnchor, constant: 20),
            subjectNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            fileNameTextField.topAnchor.constraint(equalTo: subjectNameTextField.bottomAnchor, constant: 20),
            fileNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fileNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            uploadButton.topAnchor.constraint(equalTo: fileNameTextField.bottomAnchor, constant: 30),
            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            uploadButton.heightAnchor.constraint(equalToConstant: 50),

            cancelButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 20),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            cancelButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    // MARK: - Setup Delegates
    private func setupDelegates() {
        collegePickerView.delegate = self
        collegePickerView.dataSource = self
        collegePickerTextField.inputView = collegePickerView
    }

    // MARK: - Setup Actions
    private func setupActions() {
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }

    // MARK: - Picker View Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return colleges.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return colleges[row]
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        collegePickerTextField.text = colleges[row]
        dismissKeyboard()
    }

    // MARK: - Dismiss Keyboard
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Button Actions
    @objc private func uploadButtonTapped() {
        guard let scannedPDFData = scannedPDFData,
              let fileName = fileNameTextField.text, !fileName.isEmpty,
              let category = selectedCategory,
              let college = collegePickerTextField.text, !college.isEmpty,
              let subjectCode = subjectCodeTextField.text, !subjectCode.isEmpty,
              let subjectName = subjectNameTextField.text, !subjectName.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields.")
            return
        }

        // Update user's college in Firestore
        if let userId = Auth.auth().currentUser?.uid {
            db.collection("users").document(userId).setData([
                "college": college
            ], merge: true)
        }

        let loadingAlert = UIAlertController(title: nil, message: "Uploading...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: loadingAlert.view.topAnchor, constant: 20),
            loadingAlert.view.bottomAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20)
        ])

        present(loadingAlert, animated: true) {
            // Save the scanned PDF data to a temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
            do {
                try scannedPDFData.write(to: tempFileURL)
            } catch {
                self.showAlert(title: "Error", message: "Failed to save scanned PDF: \(error.localizedDescription)")
                return
            }

            // Upload the temporary file to Firebase
            FirebaseManager.shared.uploadPDF(
                fileURL: tempFileURL,
                fileName: fileName,
                category: category,
                collegeName: college,
                subjectCode: subjectCode,
                subjectName: subjectName,
                privacy: "public",
                userId: Auth.auth().currentUser?.uid ?? ""
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.dismiss(animated: true) {
                        switch result {
                        case .success:
                            let successAlert = UIAlertController(title: "Success", message: "File uploaded successfully!", preferredStyle: .alert)
                            successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                self?.dismiss(animated: true)
                            })
                            self?.present(successAlert, animated: true)
                        case .failure(let error):
                            self?.showAlert(title: "Error", message: "Upload failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Helper Methods
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

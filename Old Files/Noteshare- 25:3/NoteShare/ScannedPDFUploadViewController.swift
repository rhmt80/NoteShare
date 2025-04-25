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
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Upload Scanned PDF"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    private lazy var categoryDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Select Category", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        button.layer.masksToBounds = true
        button.menu = createCategoryMenu()
        button.showsMenuAsPrimaryAction = true
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
        return button
    }()
    
    private let subjectCodeTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Subject Code"
        textField.borderStyle = .none
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.font = .systemFont(ofSize: 16)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        return textField
    }()
    
    private let subjectNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Subject Name"
        textField.borderStyle = .none
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.font = .systemFont(ofSize: 16)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        return textField
    }()
    
    private let fileNameTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Major Topics"
        textField.borderStyle = .none
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.font = .systemFont(ofSize: 16)
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        return textField
    }()
    
    private let uploadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upload", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        button.setTitleColor(.white, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.backgroundColor = .systemRed.withAlphaComponent(0.9)
        button.layer.cornerRadius = 12
        button.setTitleColor(.white, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 20, bottom: 14, right: 20)
        return button
    }()

    private let categories = [
        "Core Cse", "Web & App Development", "AIML", "Core ECE",
        "Core Mechanical", "Core Civil", "Core Electrical", "Physics", "Maths"
    ]

    private var selectedCategory: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupActions()

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

    // MARK: - Setup UI
    private func setupUI() {
        [titleLabel, categoryDropdownButton, subjectCodeTextField, subjectNameTextField,
         fileNameTextField, uploadButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            categoryDropdownButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            categoryDropdownButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryDropdownButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            categoryDropdownButton.heightAnchor.constraint(equalToConstant: 50),

            subjectCodeTextField.topAnchor.constraint(equalTo: categoryDropdownButton.bottomAnchor, constant: 20),
            subjectCodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectCodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            subjectCodeTextField.heightAnchor.constraint(equalToConstant: 50),

            subjectNameTextField.topAnchor.constraint(equalTo: subjectCodeTextField.bottomAnchor, constant: 20),
            subjectNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            subjectNameTextField.heightAnchor.constraint(equalToConstant: 50),

            fileNameTextField.topAnchor.constraint(equalTo: subjectNameTextField.bottomAnchor, constant: 20),
            fileNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fileNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            fileNameTextField.heightAnchor.constraint(equalToConstant: 50),

            uploadButton.topAnchor.constraint(equalTo: fileNameTextField.bottomAnchor, constant: 40),
            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            cancelButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 15),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Setup Actions
    private func setupActions() {
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
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
              let subjectCode = subjectCodeTextField.text, !subjectCode.isEmpty,
              let subjectName = subjectNameTextField.text, !subjectName.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields.")
            return
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
            let tempDir = FileManager.default.temporaryDirectory
            let tempFileURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
            do {
                try scannedPDFData.write(to: tempFileURL)
            } catch {
                self.showAlert(title: "Error", message: "Failed to save scanned PDF: \(error.localizedDescription)")
                return
            }

            FirebaseManager.shared.uploadPDF(
                fileURL: tempFileURL,
                fileName: fileName,
                category: category,
                collegeName: "", // Removed college from UI, passing empty string
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

    // MARK: - Picker View Methods (Removed since college is no longer used)
    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 0 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { return 0 }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { return nil }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {}
}


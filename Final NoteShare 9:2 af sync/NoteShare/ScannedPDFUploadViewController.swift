////
////  ScannedPDFUploadViewController.swift
////  NoteShare
////
////  Created by admin24 on 09/02/25.
////
//
//
import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth
//
//class ScannedPDFUploadViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
//    // MARK: - Properties
//    
//    var scannedPDFData: Data? // Scanned PDF data passed from the previous screen
//
//       // Custom Initializer
//       init(scannedPDFData: Data?) {
//           self.scannedPDFData = scannedPDFData
//           super.init(nibName: nil, bundle: nil)
//       }
//
//       required init?(coder: NSCoder) {
//           fatalError("init(coder:) has not been implemented")
//       }
//
//
//    // UI Components
//    private let titleLabel = UILabel()
//    private let categoryTextField = UITextField()
//    private let collegePickerTextField = UITextField()
//    private let subjectCodeTextField = UITextField()
//    private let subjectNameTextField = UITextField()
//    private let fileNameTextField = UITextField()
//    private let uploadButton = UIButton(type: .system)
//    private let cancelButton = UIButton(type: .system)
//
//    private let categoryPickerView = UIPickerView()
//    private let collegePickerView = UIPickerView()
//
//    private let categories = [
//        "Core Cse",
//        "Web & App Development",
//        "AIML",
//        "Core ECE",
//        "Core Mechanical",
//        "Core Civil",
//        "Core Electrical",
//        "Physics",
//        "Maths"
//    ]
//
//    private let colleges = ["SRM", "VIT", "KIIT", "Manipal", "LPU", "Amity"]
//
//    // MARK: - Lifecycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        view.backgroundColor = .systemBackground
//        setupUI()
//        setupDelegates()
//        setupActions()
//    }
//
//    // MARK: - Setup UI
//    private func setupUI() {
//        titleLabel.text = "Upload Scanned PDF"
//        titleLabel.textAlignment = .center
//        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)
//
//        categoryTextField.placeholder = "Select the category"
//        categoryTextField.borderStyle = .roundedRect
//
//        collegePickerTextField.placeholder = "Select college"
//        collegePickerTextField.borderStyle = .roundedRect
//
//        subjectCodeTextField.placeholder = "Enter subject code"
//        subjectCodeTextField.borderStyle = .roundedRect
//
//        subjectNameTextField.placeholder = "Enter subject name"
//        subjectNameTextField.borderStyle = .roundedRect
//
//        fileNameTextField.placeholder = "Enter the name of file"
//        fileNameTextField.borderStyle = .roundedRect
//
//        uploadButton.setTitle("Upload", for: .normal)
//        uploadButton.backgroundColor = .systemBlue
//        uploadButton.layer.cornerRadius = 10
//        uploadButton.setTitleColor(.white, for: .normal)
//
//        cancelButton.setTitle("Cancel", for: .normal)
//        cancelButton.backgroundColor = .systemRed
//        cancelButton.layer.cornerRadius = 10
//        cancelButton.setTitleColor(.white, for: .normal)
//
//        // Add subviews
//        [titleLabel, categoryTextField, collegePickerTextField, subjectCodeTextField,
//         subjectNameTextField, fileNameTextField, uploadButton, cancelButton].forEach {
//            $0.translatesAutoresizingMaskIntoConstraints = false
//            view.addSubview($0)
//        }
//
//        // Constraints
//        NSLayoutConstraint.activate([
//            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
//            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            categoryTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
//            categoryTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            categoryTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            collegePickerTextField.topAnchor.constraint(equalTo: categoryTextField.bottomAnchor, constant: 20),
//            collegePickerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            collegePickerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            subjectCodeTextField.topAnchor.constraint(equalTo: collegePickerTextField.bottomAnchor, constant: 20),
//            subjectCodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            subjectCodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            subjectNameTextField.topAnchor.constraint(equalTo: subjectCodeTextField.bottomAnchor, constant: 20),
//            subjectNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            subjectNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            fileNameTextField.topAnchor.constraint(equalTo: subjectNameTextField.bottomAnchor, constant: 20),
//            fileNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            fileNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//
//            uploadButton.topAnchor.constraint(equalTo: fileNameTextField.bottomAnchor, constant: 30),
//            uploadButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            uploadButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//            uploadButton.heightAnchor.constraint(equalToConstant: 50),
//
//            cancelButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 20),
//            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
//            cancelButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
//            cancelButton.heightAnchor.constraint(equalToConstant: 50)
//        ])
//    }
//
//    // MARK: - Setup Delegates
//    private func setupDelegates() {
//        categoryPickerView.delegate = self
//        categoryPickerView.dataSource = self
//        categoryTextField.inputView = categoryPickerView
//
//        collegePickerView.delegate = self
//        collegePickerView.dataSource = self
//        collegePickerTextField.inputView = collegePickerView
//    }
//
//    // MARK: - Setup Actions
//    private func setupActions() {
//        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
//        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
//    }
//
//    // MARK: - Picker View Methods
//    func numberOfComponents(in pickerView: UIPickerView) -> Int {
//        return 1
//    }
//
//    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
//        if pickerView == categoryPickerView {
//            return categories.count
//        } else {
//            return colleges.count
//        }
//    }
//
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        if pickerView == categoryPickerView {
//            return categories[row]
//        } else {
//            return colleges[row]
//        }
//    }
//
//    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//        if pickerView == categoryPickerView {
//            categoryTextField.text = categories[row]
//        } else {
//            collegePickerTextField.text = colleges[row]
//        }
//    }
//
//    // MARK: - Button Actions
//    @objc private func uploadButtonTapped() {
//        guard let scannedPDFData = scannedPDFData,
//              let fileName = fileNameTextField.text, !fileName.isEmpty,
//              let category = categoryTextField.text, !category.isEmpty,
//              let college = collegePickerTextField.text, !college.isEmpty,
//              let subjectCode = subjectCodeTextField.text, !subjectCode.isEmpty,
//              let subjectName = subjectNameTextField.text, !subjectName.isEmpty else {
//            showAlert(title: "Error", message: "Please fill in all fields.")
//            return
//        }
//
//        let loadingAlert = UIAlertController(title: nil, message: "Uploading...", preferredStyle: .alert)
//        let loadingIndicator = UIActivityIndicatorView(style: .medium)
//        loadingIndicator.startAnimating()
//        loadingAlert.view.addSubview(loadingIndicator)
//        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
//        NSLayoutConstraint.activate([
//            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
//            loadingIndicator.topAnchor.constraint(equalTo: loadingAlert.view.topAnchor, constant: 20),
//            loadingAlert.view.bottomAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20)
//        ])
//
//        present(loadingAlert, animated: true) {
//            // Save the scanned PDF data to a temporary file
//            let tempDir = FileManager.default.temporaryDirectory
//            let tempFileURL = tempDir.appendingPathComponent("\(UUID().uuidString).pdf")
//            do {
//                try scannedPDFData.write(to: tempFileURL)
//            } catch {
//                self.showAlert(title: "Error", message: "Failed to save scanned PDF: \(error.localizedDescription)")
//                return
//            }
//
//            // Upload the temporary file to Firebase
//            FirebaseManager.shared.uploadPDF(
//                fileURL: tempFileURL,
//                fileName: fileName,
//                category: category,
//                collegeName: college,
//                subjectCode: subjectCode,
//                subjectName: subjectName,
//                privacy: "public",
//                userId: Auth.auth().currentUser?.uid ?? ""
//            ) { [weak self] result in
//                DispatchQueue.main.async {
//                    self?.dismiss(animated: true) {
//                        switch result {
//                        case .success:
//                            let successAlert = UIAlertController(title: "Success", message: "File uploaded successfully!", preferredStyle: .alert)
//                            successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
//                                self?.dismiss(animated: true)
//                            })
//                            self?.present(successAlert, animated: true)
//                        case .failure(let error):
//                            self?.showAlert(title: "Error", message: "Upload failed: \(error.localizedDescription)")
//                        }
//                    }
//                }
//            }
//        }
//    }
//
//    @objc private func cancelButtonTapped() {
//        dismiss(animated: true, completion: nil)
//    }
//
//    // MARK: - Helper Methods
//    private func showAlert(title: String, message: String) {
//        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        present(alert, animated: true)
//    }
//}
//

class ScannedPDFUploadViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    // MARK: - Properties
    var scannedPDFData: Data? // Scanned PDF data passed from the previous screen

    // Custom Initializer
    init(scannedPDFData: Data?) {
        self.scannedPDFData = scannedPDFData
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // UI Components
    private let titleLabel = UILabel()
    private let categoryTextField = UITextField()
    private let collegePickerTextField = UITextField()
    private let subjectCodeTextField = UITextField()
    private let subjectNameTextField = UITextField()
    private let fileNameTextField = UITextField()
    private let uploadButton = UIButton(type: .system)
    private let cancelButton = UIButton(type: .system)

    private let categoryPickerView = UIPickerView()
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

    private let colleges = ["SRM", "VIT", "KIIT", "Manipal", "LPU", "Amity"]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        setupDelegates()
        setupActions()

        // Add tap gesture recognizer to dismiss the keyboard
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }

    // MARK: - Setup UI
    private func setupUI() {
        titleLabel.text = "Upload Scanned PDF"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)

        categoryTextField.placeholder = "Select the category"
        categoryTextField.borderStyle = .roundedRect

        collegePickerTextField.placeholder = "Select college"
        collegePickerTextField.borderStyle = .roundedRect

        subjectCodeTextField.placeholder = "Enter subject code"
        subjectCodeTextField.borderStyle = .roundedRect

        subjectNameTextField.placeholder = "Enter subject name"
        subjectNameTextField.borderStyle = .roundedRect

        fileNameTextField.placeholder = "Enter the name of file"
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
        [titleLabel, categoryTextField, collegePickerTextField, subjectCodeTextField,
         subjectNameTextField, fileNameTextField, uploadButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            categoryTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            categoryTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            collegePickerTextField.topAnchor.constraint(equalTo: categoryTextField.bottomAnchor, constant: 20),
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
        categoryPickerView.delegate = self
        categoryPickerView.dataSource = self
        categoryTextField.inputView = categoryPickerView

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
        if pickerView == categoryPickerView {
            return categories.count
        } else {
            return colleges.count
        }
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if pickerView == categoryPickerView {
            return categories[row]
        } else {
            return colleges[row]
        }
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if pickerView == categoryPickerView {
            categoryTextField.text = categories[row]
        } else {
            collegePickerTextField.text = colleges[row]
        }

        // Dismiss the keyboard after selecting a value
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
              let category = categoryTextField.text, !category.isEmpty,
              let college = collegePickerTextField.text, !college.isEmpty,
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

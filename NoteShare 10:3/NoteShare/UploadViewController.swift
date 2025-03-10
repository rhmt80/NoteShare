import UIKit
import FirebaseStorage
import FirebaseFirestore
import FirebaseAuth

class FirebaseManager {
    static let shared = FirebaseManager()
    private let storage = Storage.storage()
    private let db = Firestore.firestore()
    private init() {}

    func uploadPDF(
        fileURL: URL,
        fileName: String,
        category: String,
        collegeName: String,
        subjectCode: String,
        subjectName: String,
        privacy: String,
        userId: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        // Ensure user is authenticated
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])))
            return
        }

        let storageRef = Storage.storage().reference()
        let pdfRef = storageRef.child("pdfs/\(currentUserId)/\(UUID().uuidString).pdf")

        print("Uploading to path: \(pdfRef.fullPath)") // Debugging

        // ✅ Add metadata for PDF
        let metadata = StorageMetadata()
        metadata.contentType = "application/pdf"

        // ✅ Upload the file with metadata
        pdfRef.putFile(from: fileURL, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            // ✅ Retrieve download URL
            pdfRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }

                // ✅ Prepare Firestore document
                let document: [String: Any] = [
                    "fileName": fileName,
                    "category": category,
                    "collegeName": collegeName,
                    "subjectCode": subjectCode,
                    "subjectName": subjectName,
                    "privacy": privacy,
                    "downloadURL": downloadURL.absoluteString,
                    "uploadDate": FieldValue.serverTimestamp(),
                    "fileSize": metadata?.size ?? 0,
                    "userId": currentUserId
                ]

                // ✅ Save to Firestore
                Firestore.firestore().collection("pdfs").addDocument(data: document) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(downloadURL.absoluteString))
                    }
                }
            }
        }
    }


    func fetchUserData(userID: String, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        self.db.collection("users").document(userID).getDocument { document, error in
            if let error = error {
                completion(.failure(error))
            } else if let document = document, document.exists {
                completion(.success(document.data() ?? [:]))
            } else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "User document not found"])))
            }
        }
    }
}

// MARK: - BottomSheetPresentationController
class BottomSheetPresentationController: UIPresentationController {
    private let blurEffectView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .dark)
        let view = UIVisualEffectView(effect: blur)
        view.alpha = 0
        return view
    }()
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        let height = containerView.frame.height * 0.7
        return CGRect(x: 0, y: containerView.frame.height - height, width: containerView.frame.width, height: height)
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        blurEffectView.frame = containerView.bounds
        containerView.insertSubview(blurEffectView, at: 0)
        
        presentedView?.layer.cornerRadius = 20
        presentedView?.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        presentedView?.clipsToBounds = true
        
        guard let coordinator = presentedViewController.transitionCoordinator else {
            blurEffectView.alpha = 0.5
            return
        }
        
        coordinator.animate { _ in
            self.blurEffectView.alpha = 0.5
        }
    }
    
    override func dismissalTransitionWillBegin() {
        guard let coordinator = presentedViewController.transitionCoordinator else {
            blurEffectView.alpha = 0
            return
        }
        
        coordinator.animate { _ in
            self.blurEffectView.alpha = 0
        }
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        blurEffectView.frame = containerView?.bounds ?? .zero
    }
}

// MARK: - BottomSheetTransitionDelegate
class BottomSheetTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return BottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
    }
}
class UploadModalViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIDocumentPickerDelegate {
    private let transitionDelegate = BottomSheetTransitionDelegate()
    
    // MARK: - UI Components
    private let scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        return scroll
    }()
    
    private let containerView = UIView()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Upload PDF"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
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
    
    private func createCategoryMenu() -> UIMenu {
        var menuActions: [UIAction] = []
        
        for category in categories {
            let action = UIAction(title: category) { [weak self] _ in
                self?.categoryDropdownButton.setTitle(category, for: .normal)
            }
            menuActions.append(action)
        }
        
        return UIMenu(title: "Select Category", children: menuActions)
    }
    
    private let collegePickerTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Select College"
        field.borderStyle = .none
        field.backgroundColor = .systemGray6
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        field.isHidden = true // Hide it from UI
        return field
    }()

    
    private let courseCodeTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Subject Code"
        field.borderStyle = .none
        field.backgroundColor = .systemGray6
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return field
    }()
    
    private let subjectNameTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Subject Name"
        field.borderStyle = .none
        field.backgroundColor = .systemGray6
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return field
    }()
    
    private let fileNameTextField: UITextField = {
        let field = UITextField()
        field.placeholder = "Major Topics"
        field.borderStyle = .none
        field.backgroundColor = .systemGray6
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        field.leftViewMode = .always
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return field
    }()
    
    private let uploadCardView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 16
        return view
    }()
    
    private let uploadStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        return stack
    }()
    
    private lazy var uploadButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let image = UIImage(systemName: "doc.badge.arrow.up", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private let selectedFileLabel: UILabel = {
        let label = UILabel()
        label.text = "Select PDF"
        label.textAlignment = .center
        label.textColor = .gray
        label.font = .systemFont(ofSize: 14)
        return label
    }()
    
    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Submit", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemRed.withAlphaComponent(0.1)
        button.setTitleColor(.systemRed, for: .normal)
        button.layer.cornerRadius = 12
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }()
    
    var userCollege: String?
    var userCourse: String?
    var categoryPickerView = UIPickerView()
    var collegePickerView = UIPickerView()
    var selectedFileURL: URL?
    
    let categories = ["Core Cse", "Web & App Development", "AIML", "Core ECE",
                     "Core Mechanical", "Core Civil", "Core Electrical", "Physics", "Maths"]
    let colleges = ["SRM", "VIT", "KIIT", "Manipal", "LPU", "Amity"]
    
    // MARK: - Lifecycle
    init() {
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .custom
        transitioningDelegate = transitionDelegate
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupDelegates()
        setupActions()
        fetchUserData()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        setupScrollView()
        setupUploadCard()
        setupConstraints()
    }
    
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(containerView)
        
        [titleLabel, categoryDropdownButton, collegePickerTextField, courseCodeTextField,
         subjectNameTextField, fileNameTextField, uploadCardView,
         submitButton, cancelButton].forEach {
            containerView.addSubview($0)
        }
    }
    
    private func setupUploadCard() {
        uploadCardView.addSubview(uploadStackView)
        uploadStackView.addArrangedSubview(uploadButton)
        uploadStackView.addArrangedSubview(selectedFileLabel)
    }
    
    private func setupConstraints() {
        [scrollView, containerView, titleLabel, categoryDropdownButton, collegePickerTextField,
         courseCodeTextField, subjectNameTextField, fileNameTextField, uploadCardView,
         uploadStackView, uploadButton, selectedFileLabel, submitButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        collegePickerTextField.isHidden = true
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            containerView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            containerView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            categoryDropdownButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            categoryDropdownButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            categoryDropdownButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            courseCodeTextField.topAnchor.constraint(equalTo: categoryDropdownButton.bottomAnchor, constant: 16),
                courseCodeTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
                courseCodeTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            courseCodeTextField.topAnchor.constraint(equalTo: categoryDropdownButton.bottomAnchor, constant: 16),
            courseCodeTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            courseCodeTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            subjectNameTextField.topAnchor.constraint(equalTo: courseCodeTextField.bottomAnchor, constant: 16),
            subjectNameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            subjectNameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            fileNameTextField.topAnchor.constraint(equalTo: subjectNameTextField.bottomAnchor, constant: 16),
            fileNameTextField.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            fileNameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            uploadCardView.topAnchor.constraint(equalTo: fileNameTextField.bottomAnchor, constant: 24),
            uploadCardView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            uploadCardView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            uploadCardView.heightAnchor.constraint(equalToConstant: 120),
            
            uploadStackView.centerXAnchor.constraint(equalTo: uploadCardView.centerXAnchor),
            uploadStackView.centerYAnchor.constraint(equalTo: uploadCardView.centerYAnchor),
            
            submitButton.topAnchor.constraint(equalTo: uploadCardView.bottomAnchor, constant: 24),
            submitButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            
            cancelButton.topAnchor.constraint(equalTo: submitButton.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
            cancelButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
            cancelButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupDelegates() {
        categoryPickerView.delegate = self
        categoryPickerView.dataSource = self
//        categoryTextField.inputView = categoryPickerView
//
        collegePickerView.delegate = self
        collegePickerView.dataSource = self
        collegePickerTextField.inputView = collegePickerView
    }
    
    private func setupActions() {
        submitButton.addTarget(self, action: #selector(submitButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }
    
    private func updateUploadButtonState(isFileSelected: Bool) {
        let config = UIImage.SymbolConfiguration(pointSize: 40, weight: .medium)
        let imageName = isFileSelected ? "doc.badge.checkmark" : "doc.badge.arrow.up"
        let image = UIImage(systemName: imageName, withConfiguration: config)
        uploadButton.setImage(image, for: .normal)
        uploadButton.tintColor = isFileSelected ? .systemGreen : .systemBlue
        selectedFileLabel.text = isFileSelected ? selectedFileURL?.lastPathComponent : "Tap icon to select PDF"
        selectedFileLabel.textColor = isFileSelected ? .black : .gray
    }
    
    // MARK: - API Methods
    private func fetchUserData() {
        guard let userID = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not logged in.")
            return
        }
        
        FirebaseManager.shared.fetchUserData(userID: userID) { [weak self] result in
            switch result {
            case .success(let data):
                DispatchQueue.main.async {
                    self?.userCollege = data["college"] as? String
                    self?.userCourse = data["course"] as? String
                    self?.collegePickerTextField.text = self?.userCollege
                    
                    if let college = self?.userCollege,
                       let index = self?.colleges.firstIndex(of: college) {
                        self?.collegePickerView.selectRow(index, inComponent: 0, animated: false)
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self?.showAlert(title: "Error", message: "Failed to fetch user data: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - UIPickerView Methods
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerView == categoryPickerView ? categories.count : colleges.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            let label = UILabel()
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            label.textColor = .darkGray
            label.text = pickerView == categoryPickerView ? categories[row] : colleges[row]
            return label
        }
        
        func pickerView(_ pickerView: UIPickerView, rowHeightForComponent component: Int) -> CGFloat {
            return 40
        }
        
//        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
//            if pickerView == categoryPickerView {
//                categoryTextField.text = categories[row]
//            } else {
//                collegePickerTextField.text = colleges[row]
//            }
//            view.endEditing(true)
//        }
        
        // MARK: - Button Actions
        @objc private func uploadButtonTapped() {
            if selectedFileURL != nil {
                // If file is already selected, clear it
                selectedFileURL = nil
                updateUploadButtonState(isFileSelected: false)
                fileNameTextField.text = ""
            } else {
                // If no file is selected, show document picker
                let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
                documentPicker.delegate = self
                documentPicker.allowsMultipleSelection = false
                present(documentPicker, animated: true, completion: nil)
            }
        }
        
    @objc private func submitButtonTapped() {
        guard let userID = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not logged in.")
            return
        }
        let college = userCollege ?? "Unknown"
        print("Authenticated User ID: \(userID)") // Add this line for debugging

        guard let fileURL = selectedFileURL,
                  let category = categoryDropdownButton.titleLabel?.text, category != "Select Category",
                  let college = collegePickerTextField.text, !college.isEmpty,
                  let courseCode = courseCodeTextField.text, !courseCode.isEmpty,
                  let subjectName = subjectNameTextField.text, !subjectName.isEmpty,
                  let fileName = fileNameTextField.text, !fileName.isEmpty else {
                showAlert(title: "Error", message: "Please fill in all fields and select a file")
                return
            }

        let loadingAlert = UIAlertController(title: nil, message: "Uploading...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingAlert.view.addSubview(loadingIndicator)

        NSLayoutConstraint.activate([
            loadingIndicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            loadingIndicator.topAnchor.constraint(equalTo: loadingAlert.view.topAnchor, constant: 20),
            loadingAlert.view.bottomAnchor.constraint(equalTo: loadingIndicator.bottomAnchor, constant: 20)
        ])

        loadingIndicator.startAnimating()

        present(loadingAlert, animated: true) {
            FirebaseManager.shared.uploadPDF(
                fileURL: fileURL,
                fileName: fileName,
                category: category,
                collegeName: college,
                subjectCode: courseCode,
                subjectName: subjectName,
                privacy: "public",
                userId: userID
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
        
        // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        // Secure URL access
        url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }

        // Copy the file to a temporary location
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }
            try FileManager.default.copyItem(at: url, to: tempURL)
            selectedFileURL = tempURL // Use this new URL for uploading
            fileNameTextField.text = tempURL.lastPathComponent.replacingOccurrences(of: ".pdf", with: "")
            updateUploadButtonState(isFileSelected: true)
        } catch {
            showAlert(title: "Error", message: "Failed to copy file: \(error.localizedDescription)")
        }
    }

        
        // MARK: - Helper Methods
        private func showAlert(title: String, message: String) {
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }


    #Preview {
        UploadModalViewController()
    }

import UIKit
import FirebaseStorage
import FirebaseFirestore

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

//    override func dismissalTransitionWillBegin() {
//        guard let coordinator = presentedViewController.transitionCoordinator else {
//            blurEffectView.alpha = 0
//            return
//        }
//
//        coordinator.animate { _ in
//            self.blurEffectView.alpha = 0
//        }
//    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        presentedView?.frame = frameOfPresentedViewInContainerView
        blurEffectView.frame = containerView?.bounds ?? .zero
    }
}

class BottomSheetTransitionDelegate: NSObject, UIViewControllerTransitioningDelegate {
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        return BottomSheetPresentationController(presentedViewController: presented, presenting: presenting)
    }
}

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
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let storageRef = storage.reference().child("pdfs/\(UUID().uuidString)_\(fileName).pdf")

        storageRef.putFile(from: fileURL, metadata: nil) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            storageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let downloadURL = url else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get download URL"])))
                    return
                }

                let document: [String: Any] = [
                    "fileName": fileName,
                    "category": category,
                    "collegeName": collegeName,
                    "subjectCode": subjectCode,
                    "subjectName": subjectName,
                    "privacy": privacy,
                    "downloadURL": downloadURL.absoluteString,
                    "uploadDate": FieldValue.serverTimestamp(),
                    "fileSize": metadata?.size ?? 0
                ]

                self.db.collection("pdfs").addDocument(data: document) { error in
                    if let error = error {
                        completion(.failure(error))
                    } else {
                        completion(.success(downloadURL.absoluteString))
                    }
                }
            }
        }
    }
}

class UploadModalViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UIDocumentPickerDelegate {
    private let transitionDelegate = BottomSheetTransitionDelegate()

    let titleLabel = UILabel()
    let categoryTextField = UITextField()
    let collegePickerTextField = UITextField()
    let courseCodeTextField = UITextField()
    let subjectNameTextField = UITextField()
    let fileNameTextField = UITextField()
    let uploadCardView = UIView()
    let uploadImageView = UIImageView()
    let selectFileButton = UIButton(type: .system)
    let selectedFileLabel = UILabel()
    let uploadButton = UIButton(type: .system)
    let cancelButton = UIButton(type: .system)

    var categoryPickerView = UIPickerView()
    var collegePickerView = UIPickerView()
    
    let categories = [
        "DevOps",
        "Web Development",
        "Cybersecurity",
        "Artificial Intelligence",
        "iOS Development",
        "Machine Learning",
        "Data Science",
        "Cloud Computing"
    ]
    let colleges = ["SRM", "VIT", "KIIT", "Manipal", "LPU", "Amity"]
    
    var selectedFileURL: URL?

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
    }

    private func setupUI() {
        titleLabel.text = "Upload Here"
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.boldSystemFont(ofSize: 24)

        categoryTextField.placeholder = "Select the category"
        categoryTextField.borderStyle = .roundedRect

        collegePickerTextField.placeholder = "Select college"
        collegePickerTextField.borderStyle = .roundedRect

        courseCodeTextField.placeholder = "Enter subject code"
        courseCodeTextField.borderStyle = .roundedRect

        subjectNameTextField.placeholder = "Enter subject name"
        subjectNameTextField.borderStyle = .roundedRect

        fileNameTextField.placeholder = "Enter the name of file"
        fileNameTextField.borderStyle = .roundedRect

        uploadCardView.layer.cornerRadius = 10
        uploadCardView.backgroundColor = .systemGray6

        uploadImageView.image = UIImage(systemName: "icloud.and.arrow.up")
        uploadImageView.contentMode = .scaleAspectFit
        uploadImageView.tintColor = .systemBlue

        selectFileButton.setTitle("Select File", for: .normal)

        selectedFileLabel.text = "No file selected"
        selectedFileLabel.textAlignment = .center
        selectedFileLabel.textColor = .gray

        uploadButton.setTitle("Upload", for: .normal)
        uploadButton.backgroundColor = .systemBlue
        uploadButton.layer.cornerRadius = 10
        uploadButton.setTitleColor(.white, for: .normal)

        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .systemRed
        cancelButton.layer.cornerRadius = 10
        cancelButton.setTitleColor(.white, for: .normal)

        setupConstraints()
    }

    private func setupConstraints() {
        // Add subviews
        [titleLabel, categoryTextField, collegePickerTextField, courseCodeTextField,
         subjectNameTextField, fileNameTextField, uploadCardView, selectFileButton,
         selectedFileLabel, uploadButton, cancelButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        uploadCardView.addSubview(uploadImageView)
        uploadImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            categoryTextField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            categoryTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            categoryTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            collegePickerTextField.topAnchor.constraint(equalTo: categoryTextField.bottomAnchor, constant: 20),
            collegePickerTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collegePickerTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            courseCodeTextField.topAnchor.constraint(equalTo: collegePickerTextField.bottomAnchor, constant: 20),
            courseCodeTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            courseCodeTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subjectNameTextField.topAnchor.constraint(equalTo: courseCodeTextField.bottomAnchor, constant: 20),
            subjectNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subjectNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            fileNameTextField.topAnchor.constraint(equalTo: subjectNameTextField.bottomAnchor, constant: 20),
            fileNameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            fileNameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            uploadCardView.topAnchor.constraint(equalTo: fileNameTextField.bottomAnchor, constant: 20),
            uploadCardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            uploadCardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            uploadCardView.heightAnchor.constraint(equalToConstant: 100),
            
            uploadImageView.centerXAnchor.constraint(equalTo: uploadCardView.centerXAnchor),
            uploadImageView.centerYAnchor.constraint(equalTo: uploadCardView.centerYAnchor),
            uploadImageView.heightAnchor.constraint(equalToConstant: 50),
            uploadImageView.widthAnchor.constraint(equalToConstant: 50),
            
            selectFileButton.topAnchor.constraint(equalTo: uploadCardView.bottomAnchor, constant: 20),
            selectFileButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            selectedFileLabel.topAnchor.constraint(equalTo: selectFileButton.bottomAnchor, constant: 20),
            selectedFileLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            uploadButton.topAnchor.constraint(equalTo: selectedFileLabel.bottomAnchor, constant: 30),
            uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            uploadButton.widthAnchor.constraint(equalToConstant: 150),
            
            cancelButton.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 20),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func setupDelegates() {
        categoryPickerView.delegate = self
        categoryPickerView.dataSource = self
        categoryTextField.inputView = categoryPickerView
        
        collegePickerView.delegate = self
        collegePickerView.dataSource = self
        collegePickerTextField.inputView = collegePickerView
    }

    private func setupActions() {
        selectFileButton.addTarget(self, action: #selector(selectFileButtonTapped), for: .touchUpInside)
        uploadButton.addTarget(self, action: #selector(uploadButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
    }

    // Picker view methods
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
        view.endEditing(true)
    }

    @objc private func selectFileButtonTapped() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.data])
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }

    @objc private func uploadButtonTapped() {
        guard let fileURL = selectedFileURL,
              let category = categoryTextField.text,
              let college = collegePickerTextField.text,
              let courseCode = courseCodeTextField.text,
              let subjectName = subjectNameTextField.text,
              let fileName = fileNameTextField.text,
              !fileName.isEmpty,
              !courseCode.isEmpty,
              !subjectName.isEmpty else {
            showAlert(title: "Error", message: "Please fill in all fields and select a file")
            return
        }

        let loadingAlert = UIAlertController(title: nil, message: "Uploading...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)

        present(loadingAlert, animated: true) {
            FirebaseManager.shared.uploadPDF(
                fileURL: fileURL,
                fileName: fileName,
                category: category,
                collegeName: college,
                subjectCode: courseCode,
                subjectName: subjectName,
                privacy: "public"
            ) { [weak self] result in
                DispatchQueue.main.async {
                    self?.dismiss(animated: true) { // Dismiss the loading alert
                        switch result {
                        case .success:
                            let successAlert = UIAlertController(title: "Success", message: "File uploaded successfully!", preferredStyle: .alert)
                            successAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                                self?.dismiss(animated: true) // Close UploadModalViewController
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

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        selectedFileURL = url
        selectedFileLabel.text = url.lastPathComponent
        selectedFileLabel.textColor = .black
    }
}

#Preview {
    UploadModalViewController()
}

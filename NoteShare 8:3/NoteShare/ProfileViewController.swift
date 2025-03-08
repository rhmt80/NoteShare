
import FirebaseAuth
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    // MARK: - UI Components
    
    private let backButton: UIButton = {
            let button = UIButton(type: .system)
            let image = UIImage(systemName: "chevron.left")
            button.setImage(image, for: .normal)
            button.setTitle("Back", for: .normal)
            button.tintColor = .systemBlue
            button.titleLabel?.font = .systemFont(ofSize: 17)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.semanticContentAttribute = .forceLeftToRight
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
            return button
        }()
        
        private var selectedInterests: [String] = [] {
            didSet {
                updateSelectedInterestsUI()
            }
        }
        
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
        
        private let titleLabel: UILabel = {
            let label = UILabel()
            label.text = "Profile"
            label.font = .systemFont(ofSize: 32, weight: .bold)
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()
        
        private let profileContainer: UIView = {
            let view = UIView()
            view.backgroundColor = .systemBackground
            view.layer.cornerRadius = 16
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOffset = CGSize(width: 0, height: 4)
            view.layer.shadowRadius = 8
            view.layer.shadowOpacity = 0.1
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()
        
        private let profileImageView: UIImageView = {
            let imageView = UIImageView()
            imageView.image = UIImage(systemName: "person.crop.circle.fill")
            imageView.tintColor = .systemGray5
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 50
            imageView.isUserInteractionEnabled = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            // Add camera icon overlay
            let cameraIcon = UIImageView(image: UIImage(systemName: "camera.circle.fill"))
            cameraIcon.tintColor = .systemBlue
            cameraIcon.translatesAutoresizingMaskIntoConstraints = false
            imageView.addSubview(cameraIcon)
            
            NSLayoutConstraint.activate([
                cameraIcon.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
                cameraIcon.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
                cameraIcon.widthAnchor.constraint(equalToConstant: 30),
                cameraIcon.heightAnchor.constraint(equalToConstant: 30)
            ])
            
            return imageView
        }()
        
        private let nameLabel: UILabel = {
            let label = UILabel()
            label.text = "ABC"
            label.font = .systemFont(ofSize: 28, weight: .bold)
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            return label
        }()

    
    private let emailLabel: UILabel = {
        let label = UILabel()
        label.text = "abc@icloud.com"
        label.textColor = .systemGray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let educationLabel: UILabel = {
        let label = UILabel()
        label.text = "CSE 3rd Year"
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let institutionLabel: UILabel = {
        let label = UILabel()
        label.text = "SRM Institute of Science and Technology"
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let accountSettingsLabel: UILabel = {
        let label = UILabel()
        label.text = "Account Settings"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let signOutButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Sign Out"
        config.baseForegroundColor = .red
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0)
        let button = UIButton(configuration: config, primaryAction: nil)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .systemBackground
        button.contentHorizontalAlignment = .left
        return button
    }()

    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save Changes", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
  
    
    // MARK: - Interest Section
    
    private let interestsLabel: UILabel = {
        let label = UILabel()
        label.text = "Interests"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var selectedInterestsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.distribution = .fillProportionally
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var currentRowStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.alignment = .leading
        stackView.distribution = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let interestDropdownButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Interests", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .systemGray5
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        return button
    }()
    
    
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
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
                super.viewDidLoad()
                setupUI()
                fetchUserData() // This will now also fetch interests
                setupSignOutButton()
                setupPhotoUpload()
                setupInterestSection()
                setupSaveButton()
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }

@objc private func backButtonTapped() {
    // Handle the back button tap (e.g., pop the view controller)
    navigationController?.popViewController(animated: true)
}
    
    // MARK: - Setup UI
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Add backButton to the contentView
        [backButton, titleLabel, profileContainer, interestsLabel, selectedInterestsStackView, interestDropdownButton, saveButton, accountSettingsLabel, signOutButton].forEach { contentView.addSubview($0) }
        
        [profileImageView, nameLabel, emailLabel, educationLabel, institutionLabel]
            .forEach { profileContainer.addSubview($0) }
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Constraints for backButton
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            profileContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            profileContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            profileImageView.topAnchor.constraint(equalTo: profileContainer.topAnchor, constant: 24),
            profileImageView.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            nameLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -16),
            
            emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            emailLabel.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: 16),
            emailLabel.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -16),
            
            educationLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 16),
            educationLabel.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: 16),
            educationLabel.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -16),
            
            institutionLabel.topAnchor.constraint(equalTo: educationLabel.bottomAnchor, constant: 8),
            institutionLabel.leadingAnchor.constraint(equalTo: profileContainer.leadingAnchor, constant: 16),
            institutionLabel.trailingAnchor.constraint(equalTo: profileContainer.trailingAnchor, constant: -16),
            institutionLabel.bottomAnchor.constraint(equalTo: profileContainer.bottomAnchor, constant: -24),
            
            interestsLabel.topAnchor.constraint(equalTo: profileContainer.bottomAnchor, constant: 32),
            interestsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            selectedInterestsStackView.topAnchor.constraint(equalTo: interestsLabel.bottomAnchor, constant: 16),
            selectedInterestsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            selectedInterestsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            interestDropdownButton.topAnchor.constraint(equalTo: selectedInterestsStackView.bottomAnchor, constant: 16),
            interestDropdownButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            interestDropdownButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            interestDropdownButton.heightAnchor.constraint(equalToConstant: 50),
            
            saveButton.topAnchor.constraint(equalTo: interestDropdownButton.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            accountSettingsLabel.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 32),
            accountSettingsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            signOutButton.topAnchor.constraint(equalTo: accountSettingsLabel.bottomAnchor, constant: 16),
            signOutButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            signOutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            signOutButton.heightAnchor.constraint(equalToConstant: 44),
            signOutButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        setupPhotoUpload()
    }
    
    private func setupPhotoUpload() {
           let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePhotoUpload))
           profileImageView.addGestureRecognizer(tapGesture)
       }
    
    private func setupInterestSection() {
        interestDropdownButton.addTarget(self, action: #selector(showInterestMenu), for: .touchUpInside)
        updateSelectedInterestsUI()
    }
    
    @objc private func showInterestMenu() {
        let interestMenu = createInterestMenu()
        interestDropdownButton.menu = interestMenu
        interestDropdownButton.showsMenuAsPrimaryAction = true
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
    
    private func updateSelectedInterestsUI() {
        selectedInterestsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        currentRowStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        var currentRowWidth: CGFloat = 0
        let maxWidth = UIScreen.main.bounds.width - 40
        
        currentRowStackView = UIStackView()
        currentRowStackView.axis = .horizontal
        currentRowStackView.spacing = 8
        currentRowStackView.alignment = .leading
        currentRowStackView.distribution = .fill
        selectedInterestsStackView.addArrangedSubview(currentRowStackView)
        
        for interest in selectedInterests {
            let chipView = createInterestChip(with: interest)
            let chipWidth = interest.size(withAttributes: [.font: UIFont.systemFont(ofSize: 14, weight: .medium)]).width + 50
            
            if currentRowWidth + chipWidth > maxWidth {
                currentRowWidth = 0
                currentRowStackView = UIStackView()
                currentRowStackView.axis = .horizontal
                currentRowStackView.spacing = 8
                currentRowStackView.alignment = .leading
                currentRowStackView.distribution = .fill
                selectedInterestsStackView.addArrangedSubview(currentRowStackView)
            }
            
            currentRowStackView.addArrangedSubview(chipView)
            currentRowWidth += chipWidth + 8
            
            let spacerView = UIView()
            spacerView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            currentRowStackView.addArrangedSubview(spacerView)
        }
        
        interestDropdownButton.setTitle(selectedInterests.isEmpty ? "Select Interests" : selectedInterests.joined(separator: ", "), for: .normal)
    }
    
    private func createInterestChip(with interest: String) -> UIView {
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .systemBlue
        backgroundView.layer.cornerRadius = 15
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = interest
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let crossButton = UIButton(type: .system)
        crossButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        crossButton.tintColor = .white
        crossButton.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(backgroundView)
        containerView.addSubview(label)
        containerView.addSubview(crossButton)
        
        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(equalToConstant: 30),
            backgroundView.topAnchor.constraint(equalTo: containerView.topAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            crossButton.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 5),
            crossButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            crossButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            crossButton.widthAnchor.constraint(equalToConstant: 16),
            crossButton.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        crossButton.addTarget(self, action: #selector(removeInterest(_:)), for: .touchUpInside)
        crossButton.accessibilityLabel = interest
        
        return containerView
    }
    
    
    @objc private func removeInterest(_ sender: UIButton) {
        guard let interest = sender.accessibilityLabel,
              let index = selectedInterests.firstIndex(of: interest) else { return }

        selectedInterests.remove(at: index)
        updateSelectedInterestsUI()
    }

    private func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                let data = document.data()
                self.nameLabel.text = data?["name"] as? String ?? "No Name"
                self.emailLabel.text = data?["email"] as? String ?? "No Email"
                
                self.educationLabel.text = "\(data?["course"] as? String ?? "No Course") Branch"
                
                self.institutionLabel.text = "\(data?["college"] as? String ?? "No College")"
                
//                self.institutionLabel.text = "\(data?["college"] as? String ?? "No College") , Year : \(data?["year"] as? Int ?? 0)"
                
                // Fetch interests
                if let interests = data?["interests"] as? [String] {
                    self.selectedInterests = interests
                }
                
                // Fetch profile photo URL
                if let photoURL = data?["photoURL"] as? String, let url = URL(string: photoURL) {
                    self.loadImage(from: url)
                }
            } else {
                print("Document does not exist")
            }
        }
    }
    
    private func setupSaveButton() {
        saveButton.addTarget(self, action: #selector(saveChanges), for: .touchUpInside)
    }
    
    @objc private func saveChanges() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        // Show loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Saving changes...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true, completion: nil)
        
        // Update Firestore
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData([
            "interests": selectedInterests
        ]) { [weak self] error in
            guard let self = self else { return }
            
            // Dismiss loading indicator
            self.dismiss(animated: true) {
                if let error = error {
                    // Show error alert
                    let alert = UIAlertController(title: "Error", message: "Failed to save changes: \(error.localizedDescription)", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                } else {
                    // Show success alert
                    let alert = UIAlertController(title: "Success", message: "Changes saved successfully!", preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }

    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }.resume()
    }
    
    private func setupSignOutButton() {
        signOutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
    }
    
    @objc private func signOutTapped() {
        do {
            try Auth.auth().signOut()
            // Navigate back to the login screen or root view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.rootViewController = LandingViewController() // Replace with your login view controller
                window.makeKeyAndVisible()
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
   
    
    @objc private func handlePhotoUpload() {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            profileImageView.image = image
            uploadImageToFirebase(image: image)
        }
        dismiss(animated: true, completion: nil)
    }
    
    private func uploadImageToFirebase(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.75),
              let user = Auth.auth().currentUser else {
            return
        }
        
        let storageRef = Storage.storage().reference().child("profile_images/\(user.uid).jpg")
        
        storageRef.putData(imageData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                return
            }
            
            storageRef.downloadURL { url, error in
                if let downloadURL = url {
                    self.savePhotoURLToFirestore(downloadURL.absoluteString)
                }
            }
        }
    }
    
    private func savePhotoURLToFirestore(_ photoURL: String) {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).setData(["photoURL": photoURL], merge: true) { error in
            if let error = error {
                print("Error saving photo URL: \(error.localizedDescription)")
            } else {
                print("Photo URL saved successfully")
            }
        }
    }
}

#Preview {
    ProfileViewController()
}


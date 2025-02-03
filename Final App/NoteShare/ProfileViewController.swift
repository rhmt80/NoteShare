
import FirebaseAuth
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import PhotosUI

class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
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
        label.text = "Edit Profile"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
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
        return imageView
    }()
    
    private let uploadPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Upload Photo", for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        label.text = "BTech CSE 3rd Year"
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
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBackButton()
        fetchUserData()
        setupSignOutButton()
        setupPhotoUpload()
    }
    
    private func setupBackButton() {
        guard backButton.superview == nil else { return }
        view.addSubview(backButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        [titleLabel, profileContainer, accountSettingsLabel, signOutButton, saveButton].forEach { contentView.addSubview($0) }
        
        [profileImageView, uploadPhotoButton, nameLabel, emailLabel, educationLabel, institutionLabel]
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
            
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            profileContainer.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            profileContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            profileContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            profileImageView.topAnchor.constraint(equalTo: profileContainer.topAnchor, constant: 24),
            profileImageView.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor),
            profileImageView.widthAnchor.constraint(equalToConstant: 100),
            profileImageView.heightAnchor.constraint(equalToConstant: 100),
            
            uploadPhotoButton.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 8),
            uploadPhotoButton.centerXAnchor.constraint(equalTo: profileContainer.centerXAnchor),
            
            nameLabel.topAnchor.constraint(equalTo: uploadPhotoButton.bottomAnchor, constant: 16),
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
            
            accountSettingsLabel.topAnchor.constraint(equalTo: profileContainer.bottomAnchor, constant: 32),
            accountSettingsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            signOutButton.topAnchor.constraint(equalTo: accountSettingsLabel.bottomAnchor, constant: 16),
            signOutButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            signOutButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            signOutButton.heightAnchor.constraint(equalToConstant: 44),
            
            saveButton.topAnchor.constraint(equalTo: signOutButton.bottomAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
    }
    
    private func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { (document, error) in
            if let document = document, document.exists {
                let data = document.data()
                self.nameLabel.text = data?["name"] as? String ?? "No Name"
                self.emailLabel.text = data?["email"] as? String ?? "No Email"
                self.educationLabel.text = "BTech CSE \(data?["year"] as? Int ?? 0)rd Year"
                self.institutionLabel.text = data?["college"] as? String ?? "No College"
                
                // Fetch profile photo URL
                if let photoURL = data?["photoURL"] as? String, let url = URL(string: photoURL) {
                    self.loadImage(from: url)
                }
            } else {
                print("Document does not exist")
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
    
    private func setupPhotoUpload() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePhotoUpload))
        profileImageView.addGestureRecognizer(tapGesture)
        uploadPhotoButton.addTarget(self, action: #selector(handlePhotoUpload), for: .touchUpInside)
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

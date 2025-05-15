import UIKit
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import SafariServices

class RegistrationViewController: UIViewController {
    
    private let db = Firestore.firestore()
        
    @objc private func registerTapped() {
        guard let name = nameTextField.text, !name.isEmpty,
              let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Please fill all fields.")
            return
        }
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showAlert(message: "Registration failed: \(error.localizedDescription)")
                return
            }
            
            guard let userId = result?.user.uid else { return }
            
            let userData: [String: Any] = [
                "name": name,
                "email": email,
                "createdAt": FieldValue.serverTimestamp()
            ]
            
            self.db.collection("users").document(userId).setData(userData) { error in
                if let error = error {
                    print("Error storing user data: \(error)")
                    return
                }
                
                let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                changeRequest?.displayName = name
                changeRequest?.commitChanges(completion: nil)
                
                let collegeSelectionVC = CollegeSelectionViewController()
                self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
            }
        }
    }
    
    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "NoteShare"
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityLabel = "NoteShare logo"
        return label
    }()
    
    private func createTextField(placeholder: String, isSecure: Bool = false) -> UITextField {
        let textField = UITextField()
        textField.placeholder = placeholder
        textField.borderStyle = .none
        textField.backgroundColor = .systemBackground
        textField.layer.cornerRadius = 25
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray5.cgColor
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
        textField.leftViewMode = .always
        textField.isSecureTextEntry = isSecure
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.accessibilityHint = "Enter your \(placeholder.lowercased())"
        return textField
    }
    
    private lazy var nameTextField = createTextField(placeholder: "Enter your Name")
    private lazy var emailTextField = createTextField(placeholder: "Enter your Email")
    private lazy var passwordTextField = createTextField(placeholder: "Choose a password", isSecure: true)
    
    private lazy var registerButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Register", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Register"
        button.accessibilityHint = "Tap to create a new account"
        return button
    }()
    
    private let signInWithAppleButton: ASAuthorizationAppleIDButton = {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Sign in with Apple"
        button.accessibilityHint = "Tap to sign in using your Apple ID"
        return button
    }()
    
    private let termsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]
        
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        ]
        
        let attributedString = NSMutableAttributedString(
            string: "By tapping Register you agree to our\n",
            attributes: regularAttributes
        )
        attributedString.append(NSAttributedString(
            string: "Terms of Use",
            attributes: linkAttributes
        ))
        attributedString.append(NSAttributedString(
            string: " and ",
            attributes: regularAttributes
        ))
        attributedString.append(NSAttributedString(
            string: "Privacy Policy",
            attributes: linkAttributes
        ))
        
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.textAlignment = .center
        label.isUserInteractionEnabled = true
        label.accessibilityLabel = "Terms and Privacy Policy"
        label.accessibilityHint = "Tap Terms of Use or Privacy Policy to view details"
        return label
    }()

    private let loginPromptButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]
        
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        ]
        
        let attributedString = NSMutableAttributedString(
            string: "Have an account? ",
            attributes: regularAttributes
        )
        attributedString.append(NSAttributedString(
            string: "Login",
            attributes: linkAttributes
        ))
        
        button.setAttributedTitle(attributedString, for: .normal)
        button.accessibilityLabel = "Login prompt"
        button.accessibilityHint = "Tap to go to the login screen"
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTermsLabelTapGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [logoLabel, nameTextField, emailTextField, passwordTextField,
         registerButton, signInWithAppleButton, termsLabel, loginPromptButton].forEach {
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            nameTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 48),
            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            nameTextField.heightAnchor.constraint(equalToConstant: 50),
            
            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
            emailTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            emailTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            registerButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
            registerButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            registerButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            registerButton.heightAnchor.constraint(equalToConstant: 50),
            
            signInWithAppleButton.topAnchor.constraint(equalTo: registerButton.bottomAnchor, constant: 16),
            signInWithAppleButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
            signInWithAppleButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
            
            termsLabel.topAnchor.constraint(equalTo: signInWithAppleButton.bottomAnchor, constant: 24),
            termsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            termsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            loginPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            loginPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        loginPromptButton.addTarget(self, action: #selector(loginPromptTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupTermsLabelTapGestures() {
        let termsRange = (termsLabel.attributedText?.string as NSString?)?.range(of: "Terms of Use")
        let privacyRange = (termsLabel.attributedText?.string as NSString?)?.range(of: "Privacy Policy")
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTermsTap(_:)))
        termsLabel.addGestureRecognizer(tapGesture)
        
        self.termsRange = termsRange
        self.privacyRange = privacyRange
    }
    
    private var termsRange: NSRange?
    private var privacyRange: NSRange?
    
    @objc private func handleTermsTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let attributedText = label.attributedText else { return }
        
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: label.bounds.size)
        let textStorage = NSTextStorage(attributedString: attributedText)
        
        textContainer.lineFragmentPadding = 0
        textContainer.maximumNumberOfLines = label.numberOfLines
        textContainer.size = label.bounds.size
        
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        
        let location = gesture.location(in: label)
        let characterIndex = layoutManager.characterIndex(
            for: location,
            in: textContainer,
            fractionOfDistanceBetweenInsertionPoints: nil
        )
        
        if let termsRange = termsRange, NSLocationInRange(characterIndex, termsRange) {
            if let url = URL(string: "https://note-share-web.vercel.app/terms") {
                let safariVC = SFSafariViewController(url: url)
                present(safariVC, animated: true)
            }
        } else if let privacyRange = privacyRange, NSLocationInRange(characterIndex, privacyRange) {
            if let url = URL(string: "https://note-share-web.vercel.app/privacy") {
                let safariVC = SFSafariViewController(url: url)
                present(safariVC, animated: true)
            }
        }
    }
    
    @objc private func signInWithAppleTapped() {
        let provider = OAuthProvider(providerID: "apple.com")
        provider.getCredentialWith(nil) { [weak self] credential, error in
            guard let self = self, let credential = credential else {
                if let error = error {
                    self?.showAlert(message: "Apple Sign-In failed: \(error.localizedDescription)")
                }
                return
            }

            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    self.showAlert(message: "Sign-In failed: \(error.localizedDescription)")
                    return
                }
                
                let collegeSelectionVC = CollegeSelectionViewController()
                self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
            }
        }
    }
    
    @objc private func loginPromptTapped() {
        let loginVC = LoginViewController()
        navigationController?.pushViewController(loginVC, animated: true)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: "NoteShare", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

#Preview {
    RegistrationViewController()
}

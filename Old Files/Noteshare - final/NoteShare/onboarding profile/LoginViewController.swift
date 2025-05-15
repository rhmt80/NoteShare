import UIKit
import AuthenticationServices
import FirebaseAuth
import SafariServices

class LoginViewController: UIViewController {
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
    
    private lazy var emailTextField = createTextField(placeholder: "Enter your Email")
    private lazy var passwordTextField = createTextField(placeholder: "Enter your password", isSecure: true)
    
    private lazy var loginButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Login", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Login"
        button.accessibilityHint = "Tap to sign in to your account"
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
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.setTitleColor(UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Forgot Password"
        button.accessibilityHint = "Tap to reset your password"
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
            string: "By tapping Login you agree to our\n",
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
    
    private let signUpPromptButton: UIButton = {
        let button = UIButton(type: .system)
        let regularAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.gray
        ]
        let linkAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        ]
        let attributedString = NSMutableAttributedString(
            string: "Don't have an account? ",
            attributes: regularAttributes
        )
        attributedString.append(NSAttributedString(
            string: "Sign Up",
            attributes: linkAttributes
        ))
        button.setAttributedTitle(attributedString, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityLabel = "Sign Up prompt"
        button.accessibilityHint = "Tap to go to the registration screen"
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupTermsLabelTapGestures()
        loadSavedCredentials()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
        if Auth.auth().currentUser != nil && UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
            navigateToMainScreen()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [logoLabel, emailTextField, passwordTextField, loginButton, signInWithAppleButton,
         forgotPasswordButton, termsLabel, signUpPromptButton].forEach {
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // Adjusted top spacing to account for missing nameTextField
            emailTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 48 + 66), // 48 + (50+16) for nameTextField
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
            loginButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            signInWithAppleButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
            signInWithAppleButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            signInWithAppleButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
            
            forgotPasswordButton.topAnchor.constraint(equalTo: signInWithAppleButton.bottomAnchor, constant: 16),
            forgotPasswordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            termsLabel.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 24),
            termsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            termsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            signUpPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            signUpPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        signUpPromptButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
        
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
    
    private func loadSavedCredentials() {
        if let email = KeychainManager.shared.getCredential(service: "NoteShare", account: "userEmail") {
            emailTextField.text = email
            if let password = KeychainManager.shared.getCredential(service: "NoteShare", account: "userPassword") {
                passwordTextField.text = password
            }
        }
    }
    
    @objc private func loginTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showAlert(message: "Please fill in all fields.")
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showAlert(message: "Login failed: \(error.localizedDescription)")
                return
            }
            
            UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
            self.navigateToMainScreen()
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
                
                UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
                self.navigateToMainScreen()
            }
        }
    }
    
    private func navigateToMainScreen() {
        if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
            sceneDelegate.gototab()
        }
    }
    
    @objc private func forgotPasswordTapped() {
        guard let email = emailTextField.text, !email.isEmpty else {
            showAlert(message: "Please enter your email.")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                self?.showAlert(message: "Error: \(error.localizedDescription)")
                return
            }
            
            let alert = UIAlertController(title: "NoteShare", message: "Password reset email sent.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    @objc private func signUpTapped() {
        let signUpVC = RegistrationViewController()
        navigationController?.pushViewController(signUpVC, animated: true)
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

// Assuming KeychainManager is defined elsewhere as provided previously
class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func saveCredential(service: String, account: String, password: String) -> Bool {
        guard let passwordData = password.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getCredential(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        }
        
        return nil
    }
    
    func deleteCredential(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

#Preview {
    LoginViewController()
}

////import UIKit
////import FirebaseAuth
////
////class LoginViewController: UIViewController {
////    
////    private let logoLabel: UILabel = {
////        let label = UILabel()
////        label.text = "NoteShare"
////        label.font = .systemFont(ofSize: 40, weight: .bold)
////        label.textColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
////        label.textAlignment = .center
////        label.translatesAutoresizingMaskIntoConstraints = false
////        return label
////    }()
////    
////    private lazy var emailTextField = createTextField(placeholder: "Enter your Email")
////    private lazy var passwordTextField = createTextField(placeholder: "Enter your password", isSecure: true)
////    
////    private lazy var loginButton: UIButton = {
////        let button = UIButton(type: .system)
////        button.setTitle("Login", for: .normal)
////        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
////        button.setTitleColor(.white, for: .normal)
////        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
////        button.layer.cornerRadius = 25
////        button.translatesAutoresizingMaskIntoConstraints = false
////        return button
////    }()
////    
////    private let forgotPasswordButton: UIButton = {
////        let button = UIButton(type: .system)
////        button.setTitle("Forgot Password?", for: .normal)
////        button.setTitleColor(UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0), for: .normal)
////        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
////        button.translatesAutoresizingMaskIntoConstraints = false
////        return button
////    }()
////    
////    private let signUpPromptButton: UIButton = {
////        let button = UIButton(type: .system)
////        let regularAttributes: [NSAttributedString.Key: Any] = [
////            .font: UIFont.systemFont(ofSize: 14),
////            .foregroundColor: UIColor.gray
////        ]
////        let linkAttributes: [NSAttributedString.Key: Any] = [
////            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
////            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
////        ]
////        let attributedString = NSMutableAttributedString(string: "Don't have an account? ", attributes: regularAttributes)
////        attributedString.append(NSAttributedString(string: "Sign Up", attributes: linkAttributes))
////        button.setAttributedTitle(attributedString, for: .normal)
////        button.translatesAutoresizingMaskIntoConstraints = false
////        return button
////    }()
////    
////    override func viewDidLoad() {
////        super.viewDidLoad()
////        setupUI()
////        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
////            view.addGestureRecognizer(tapGesture)
////    }
////    @objc private func dismissKeyboard() {
////        view.endEditing(true)
////    }
////    
////    private func setupUI() {
////        view.backgroundColor = .systemBackground
////        
////        [logoLabel, emailTextField, passwordTextField, loginButton, forgotPasswordButton, signUpPromptButton].forEach {
////            view.addSubview($0)
////        }
////        
////        NSLayoutConstraint.activate([
////            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
////            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
////            
////            emailTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 60),
////            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
////            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
////            emailTextField.heightAnchor.constraint(equalToConstant: 50),
////            
////            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
////            passwordTextField.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
////            passwordTextField.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
////            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
////            
////            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 24),
////            loginButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
////            loginButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
////            loginButton.heightAnchor.constraint(equalToConstant: 50),
////            
////            forgotPasswordButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
////            forgotPasswordButton.trailingAnchor.constraint(equalTo: loginButton.trailingAnchor),
////            
////            signUpPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
////            signUpPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
////        ])
////        
////        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
////        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
////        signUpPromptButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
////    }
////    
////    private func createTextField(placeholder: String, isSecure: Bool = false) -> UITextField {
////        let textField = UITextField()
////        textField.placeholder = placeholder
////        textField.borderStyle = .none
////        textField.backgroundColor = .systemBackground
////        textField.layer.cornerRadius = 25
////        textField.layer.borderWidth = 1
////        textField.layer.borderColor = UIColor.systemGray5.cgColor
////        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
////        textField.leftViewMode = .always
////        textField.isSecureTextEntry = isSecure
////        textField.translatesAutoresizingMaskIntoConstraints = false
////        return textField
////    }
////    
////    @objc private func loginTapped() {
////        guard let email = emailTextField.text, !email.isEmpty,
////              let password = passwordTextField.text, !password.isEmpty else {
////            showError("Please fill in all fields.")
////            return
////        }
////        
////        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
////            if let error = error {
////                self?.showError("Login failed: \(error.localizedDescription)")
////                return
////            }
////            
////            // Successful login
////            let collegeSelectionVC = CollegeSelectionViewController() // College selection screen
////            collegeSelectionVC.view.backgroundColor = .systemBackground
////            self?.navigationController?.setViewControllers([collegeSelectionVC], animated: true)
////        }
////    }
////    
////    @objc private func forgotPasswordTapped() {
////        guard let email = emailTextField.text, !email.isEmpty else {
////            showError("Please enter your email.")
////            return
////        }
////        
////        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
////            if let error = error {
////                self?.showError("Error: \(error.localizedDescription)")
////                return
////            }
////            
////            let alert = UIAlertController(title: "Success", message: "Password reset email sent.", preferredStyle: .alert)
////            alert.addAction(UIAlertAction(title: "OK", style: .default))
////            self?.present(alert, animated: true)
////        }
////    }
////    
////    @objc private func signUpTapped() {
////        let signUpVC = RegistrationViewController()
////        navigationController?.pushViewController(signUpVC, animated: true)
////    }
////    
////    private func showError(_ message: String) {
////        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
////        alert.addAction(UIAlertAction(title: "OK", style: .default))
////        present(alert, animated: true)
////    }
////}
////
////
//
//import UIKit
//import FirebaseAuth
//
//class LoginViewController: UIViewController {
//    
//    private let logoLabel: UILabel = {
//        let label = UILabel()
//        label.text = "NoteShare"
//        label.font = .systemFont(ofSize: 40, weight: .bold)
//        label.textColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        label.textAlignment = .center
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private lazy var emailTextField = createTextField(placeholder: "Enter your Email")
//    private lazy var passwordTextField = createTextField(placeholder: "Enter your password", isSecure: true)
//    
//    private lazy var loginButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Login", for: .normal)
//        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        button.setTitleColor(.white, for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
//        button.layer.cornerRadius = 25
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
//    
//    private let forgotPasswordButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Forgot Password?", for: .normal)
//        button.setTitleColor(UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0), for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
//    
//    private let signUpPromptButton: UIButton = {
//        let button = UIButton(type: .system)
//        let regularAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14),
//            .foregroundColor: UIColor.gray
//        ]
//        let linkAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
//            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        ]
//        let attributedString = NSMutableAttributedString(string: "Don't have an account? ", attributes: regularAttributes)
//        attributedString.append(NSAttributedString(string: "Sign Up", attributes: linkAttributes))
//        button.setAttributedTitle(attributedString, for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
//    
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        loadSavedCredentials()
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        view.addGestureRecognizer(tapGesture)
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        // Check if user is already logged in
//        if Auth.auth().currentUser != nil && UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
//            navigateToMainScreen()
//        }
//    }
//    
//    @objc private func dismissKeyboard() {
//        view.endEditing(true)
//    }
//    
//    private func setupUI() {
//        view.backgroundColor = .systemBackground
//        
//        [logoLabel, emailTextField, passwordTextField, loginButton, forgotPasswordButton, signUpPromptButton].forEach {
//            view.addSubview($0)
//        }
//        
//        NSLayoutConstraint.activate([
//            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
//            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            
//            emailTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 60),
//            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
//            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
//            emailTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
//            passwordTextField.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
//            passwordTextField.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
//            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 24),
//            loginButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
//            loginButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
//            loginButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            forgotPasswordButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
//            forgotPasswordButton.trailingAnchor.constraint(equalTo: loginButton.trailingAnchor),
//            
//            signUpPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
//            signUpPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
//        ])
//        
//        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
//        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
//        signUpPromptButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
//    }
//    
//    private func createTextField(placeholder: String, isSecure: Bool = false) -> UITextField {
//        let textField = UITextField()
//        textField.placeholder = placeholder
//        textField.borderStyle = .none
//        textField.backgroundColor = .systemBackground
//        textField.layer.cornerRadius = 25
//        textField.layer.borderWidth = 1
//        textField.layer.borderColor = UIColor.systemGray5.cgColor
//        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 0))
//        textField.leftViewMode = .always
//        textField.isSecureTextEntry = isSecure
//        textField.translatesAutoresizingMaskIntoConstraints = false
//        return textField
//    }
//    
////    private func loadSavedCredentials() {
////        // Automatically load saved credentials from keychain if they exist
////        if let email = KeychainManager.shared.getCredential(service: "NoteShare", account: "userEmail") {
////            emailTextField.text = email
////            
////            if let password = KeychainManager.shared.getCredential(service: "NoteShare", account: "userPassword") {
////                passwordTextField.text = password
////            }
////        }
////    }
//    
//    private func loadSavedCredentials() {
//        // Get all saved email accounts from keychain
//        guard let savedEmails = KeychainManager.shared.getAllCredentials(service: "NoteShare", accountPrefix: "userEmail") else {
//            return // No saved accounts
//        }
//        
//        // If there are no saved accounts, just return
//        if savedEmails.isEmpty {
//            return
//        }
//        
//        // Create an alert controller for account selection
//        let alert = UIAlertController(title: "Select Account", message: "Choose an account to sign in with", preferredStyle: .actionSheet)
//        
//        // Add each saved email as an option
//        for email in savedEmails {
//            alert.addAction(UIAlertAction(title: email, style: .default) { [weak self] _ in
//                guard let self = self else { return }
//                
//                // Set the selected email
//                self.emailTextField.text = email
//                
//                if let passwords = KeychainManager.shared.getAllCredentials(service: "NoteShare", accountPrefix: "userPassword_\(email)"), let password = passwords.first {
//                    self.passwordTextField.text = password
//                }
//            })
//        }
//        
//        // Add a cancel option
//        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
//        
//        // Present the alert
//        present(alert, animated: true)
//    }
//    
//    @objc private func loginTapped() {
//        guard let email = emailTextField.text, !email.isEmpty,
//              let password = passwordTextField.text, !password.isEmpty else {
//            showError("Please fill in all fields.")
//            return
//        }
//        
//        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                self.showError("Login failed: \(error.localizedDescription)")
//                return
//            }
//            
//            // Save login state
//            UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
//            
//            // Automatically save credentials to keychain when login is successful
//            KeychainManager.shared.saveCredential(service: email, account: "NoteShare", password: "userEmail")
//            KeychainManager.shared.saveCredential(service: password, account: "NoteShare", password: "userPassword_\(email)")
//            
//            // Navigate to main screen
//            self.navigateToMainScreen()
//        }
//    }
//    
//    private func navigateToMainScreen() {
//        let collegeSelectionVC = HomeViewController() // College selection screen
//        collegeSelectionVC.view.backgroundColor = .systemBackground
//        self.navigationController?.setViewControllers([collegeSelectionVC], animated: true)
//    }
//    
//    @objc private func forgotPasswordTapped() {
//        guard let email = emailTextField.text, !email.isEmpty else {
//            showError("Please enter your email.")
//            return
//        }
//        
//        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
//            if let error = error {
//                self?.showError("Error: \(error.localizedDescription)")
//                return
//            }
//            
//            let alert = UIAlertController(title: "Success", message: "Password reset email sent.", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            self?.present(alert, animated: true)
//        }
//    }
//    
//    @objc private func signUpTapped() {
//        let signUpVC = RegistrationViewController()
//        navigationController?.pushViewController(signUpVC, animated: true)
//    }
//    
//    private func showError(_ message: String) {
//        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        present(alert, animated: true)
//    }
//}
//
//import Foundation
//import Security
//
//class KeychainManager {
//    static let shared = KeychainManager()
//    
//    private init() {}
//    
//    func saveCredential(service: String, account: String, password: String) -> Bool {
//        // Convert password string to data
//        guard let passwordData = password.data(using: .utf8) else {
//            return false
//        }
//        
//        // Create query for deletion
//        let deleteQuery: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account
//        ]
//        
//        // Delete any existing item
//        SecItemDelete(deleteQuery as CFDictionary)
//        
//        // Create query for addition
//        let addQuery: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account,
//            kSecValueData as String: passwordData,
//            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
//        ]
//        
//        // Add new item to keychain
//        let status = SecItemAdd(addQuery as CFDictionary, nil)
//        return status == errSecSuccess
//    }
//    // Add this to your KeychainManager class
//    func getAllCredentials(service: String, accountPrefix: String) -> [String]? {
//        var query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecMatchLimit as String: kSecMatchLimitAll,
//            kSecReturnAttributes as String: true
//        ]
//        
//        var result: CFTypeRef?
//        let status = SecItemCopyMatching(query as CFDictionary, &result)
//        
//        if status == errSecSuccess {
//            if let items = result as? [[String: Any]] {
//                var accounts: [String] = []
//                for item in items {
//                    if let account = item[kSecAttrAccount as String] as? String,
//                       account.hasPrefix(accountPrefix) {
//                        accounts.append(account)
//                    }
//                }
//                return accounts
//            }
//        }
//        
//        return nil
//    }
//    
//    func deleteCredential(service: String, account: String) -> Bool {
//        // Create query dictionary
//        let query: [String: Any] = [
//            kSecClass as String: kSecClassGenericPassword,
//            kSecAttrService as String: service,
//            kSecAttrAccount as String: account
//        ]
//        
//        // Delete the keychain item
//        let status = SecItemDelete(query as CFDictionary)
//        return status == errSecSuccess
//    }
//}
//
//


import UIKit
import FirebaseAuth

class LoginViewController: UIViewController {
    
    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "NoteShare"
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
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
        return button
    }()
    
    private let forgotPasswordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Forgot Password?", for: .normal)
        button.setTitleColor(UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        let attributedString = NSMutableAttributedString(string: "Don't have an account? ", attributes: regularAttributes)
        attributedString.append(NSAttributedString(string: "Sign Up", attributes: linkAttributes))
        button.setAttributedTitle(attributedString, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedCredentials()
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Check if user is already logged in
        if Auth.auth().currentUser != nil && UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
            navigateToMainScreen()
        }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [logoLabel, emailTextField, passwordTextField, loginButton, forgotPasswordButton, signUpPromptButton].forEach {
            view.addSubview($0)
        }
        
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            emailTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 60),
            emailTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            emailTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            emailTextField.heightAnchor.constraint(equalToConstant: 50),
            
            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
            passwordTextField.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
            
            loginButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 24),
            loginButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            forgotPasswordButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
            forgotPasswordButton.trailingAnchor.constraint(equalTo: loginButton.trailingAnchor),
            
            signUpPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            signUpPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
        signUpPromptButton.addTarget(self, action: #selector(signUpTapped), for: .touchUpInside)
    }
    
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
        return textField
    }
    
    private func loadSavedCredentials() {
        // Automatically load saved credentials from keychain if they exist
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
            showError("Please fill in all fields.")
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showError("Login failed: \(error.localizedDescription)")
                return
            }
            
            // Save login state
            UserDefaults.standard.set(true, forKey: "isUserLoggedIn")
            
            // Automatically save credentials to keychain when login is successful
            KeychainManager.shared.saveCredential(service: "NoteShare", account: "userEmail", password: email)
            KeychainManager.shared.saveCredential(service: "NoteShare", account: "userPassword", password: password)
            
            // Navigate to main screen
            self.navigateToMainScreen()
        }
    }
    
    private func navigateToMainScreen() {
        let collegeSelectionVC = HomeViewController() // College selection screen
        collegeSelectionVC.view.backgroundColor = .systemBackground
        self.navigationController?.setViewControllers([collegeSelectionVC], animated: true)
    }
    
    @objc private func forgotPasswordTapped() {
        guard let email = emailTextField.text, !email.isEmpty else {
            showError("Please enter your email.")
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            if let error = error {
                self?.showError("Error: \(error.localizedDescription)")
                return
            }
            
            let alert = UIAlertController(title: "Success", message: "Password reset email sent.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
    
    @objc private func signUpTapped() {
        let signUpVC = RegistrationViewController()
        navigationController?.pushViewController(signUpVC, animated: true)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

import Foundation
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    private init() {}
    
    func saveCredential(service: String, account: String, password: String) -> Bool {
        // Convert password string to data
        guard let passwordData = password.data(using: .utf8) else {
            return false
        }
        
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    func getCredential(service: String, account: String) -> String? {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Search for keychain item
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        // Check if item was found
        if status == errSecSuccess, let retrievedData = dataTypeRef as? Data {
            return String(data: retrievedData, encoding: .utf8)
        }
        
        return nil
    }
    
    func deleteCredential(service: String, account: String) -> Bool {
        // Create query dictionary
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // Delete the keychain item
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}

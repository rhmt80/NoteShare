//import UIKit
//import AuthenticationServices
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
//    private let signInWithAppleButton: ASAuthorizationAppleIDButton = {
//        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
//        button.cornerRadius = 25
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
//        button.translatesAutoresizingMaskIntoConstraints = false
//        
//        let regularAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14),
//            .foregroundColor: UIColor.gray
//        ]
//        
//        let linkAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
//            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        ]
//        
//        let attributedString = NSMutableAttributedString(string: "Don't have an account? ", attributes: regularAttributes)
//        attributedString.append(NSAttributedString(string: "Sign Up", attributes: linkAttributes))
//        
//        button.setAttributedTitle(attributedString, for: .normal)
//        return button
//    }()
//    
//    // MARK: - Lifecycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        navigationController?.isNavigationBarHidden = true
//    }
//    
//    // MARK: - UI Setup
//    private func setupUI() {
//        view.backgroundColor = .systemBackground
//        
//        // Add subviews
//        [logoLabel, emailTextField, passwordTextField,
//         forgotPasswordButton, loginButton, signInWithAppleButton,
//         signUpPromptButton].forEach { view.addSubview($0) }
//        
//        // Setup constraints
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
//            forgotPasswordButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
//            forgotPasswordButton.trailingAnchor.constraint(equalTo: passwordTextField.trailingAnchor),
//            
//            loginButton.topAnchor.constraint(equalTo: forgotPasswordButton.bottomAnchor, constant: 24),
//            loginButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
//            loginButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
//            loginButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            signInWithAppleButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
//            signInWithAppleButton.leadingAnchor.constraint(equalTo: emailTextField.leadingAnchor),
//            signInWithAppleButton.trailingAnchor.constraint(equalTo: emailTextField.trailingAnchor),
//            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            signUpPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
//            signUpPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
//        ])
//        
//        // Add targets
//        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
//        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
//        signUpPromptButton.addTarget(self, action: #selector(signUpPromptTapped), for: .touchUpInside)
//        forgotPasswordButton.addTarget(self, action: #selector(forgotPasswordTapped), for: .touchUpInside)
//        
//        // Add tap gesture to dismiss keyboard
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        view.addGestureRecognizer(tapGesture)
//    }
//    
//    // MARK: - Actions
//    @objc private func loginTapped() {
//        let collegeSelectionVC = CollegeSelectionViewController()
//        navigationController?.setNavigationBarHidden(true, animated: false)
//        navigationController?.pushViewController(collegeSelectionVC, animated: true)
//    }
//    
//    @objc private func signInWithAppleTapped() {
//        
//    }
//    
//    @objc private func signUpPromptTapped() {
//        let signUpVC = RegistrationViewController()
//        navigationController?.setNavigationBarHidden(true, animated: false)
//        navigationController?.pushViewController(signUpVC, animated: true)
//    }
//    
//    @objc private func forgotPasswordTapped() {
//        
//    }
//    
//    @objc private func dismissKeyboard() {
//        view.endEditing(true)
//    }
//}

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
    
    @objc private func loginTapped() {
        guard let email = emailTextField.text, !email.isEmpty,
              let password = passwordTextField.text, !password.isEmpty else {
            showError("Please fill in all fields.")
            return
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.showError("Login failed: \(error.localizedDescription)")
                return
            }
            
            // Successful login
            let collegeSelectionVC = CollegeSelectionViewController() // College selection screen
            collegeSelectionVC.view.backgroundColor = .systemBackground
            self?.navigationController?.setViewControllers([collegeSelectionVC], animated: true)
        }
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



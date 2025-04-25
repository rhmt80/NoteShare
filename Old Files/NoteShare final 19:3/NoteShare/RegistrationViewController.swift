import UIKit
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore


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
                
                // Store user data in Firestore
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
                    
                    // Update display name
                    let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
                    changeRequest?.displayName = name
                    changeRequest?.commitChanges(completion: nil)
                    
                    // Navigate to college selection
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
        return button
    }()
    
    private let signInWithAppleButton: ASAuthorizationAppleIDButton = {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
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
        
        let attributedString = NSMutableAttributedString(string: "By tapping Register you agree to our\n", attributes: regularAttributes)
        attributedString.append(NSAttributedString(string: "Terms of Use", attributes: linkAttributes))
        attributedString.append(NSAttributedString(string: " and ", attributes: regularAttributes))
        attributedString.append(NSAttributedString(string: "Privacy Policy", attributes: linkAttributes))
        
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.textAlignment = .center
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
        
        let attributedString = NSMutableAttributedString(string: "Have an account? ", attributes: regularAttributes)
        attributedString.append(NSAttributedString(string: "Login", attributes: linkAttributes))
        
        button.setAttributedTitle(attributedString, for: .normal)
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [logoLabel, nameTextField, emailTextField, passwordTextField,
         registerButton, signInWithAppleButton, termsLabel, loginPromptButton].forEach { view.addSubview($0) }
        
        // Setup constraints
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            nameTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 60),
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
    
    // MARK: - Actions
//    @objc private func registerTapped() {
//        guard let name = nameTextField.text, !name.isEmpty,
//              let email = emailTextField.text, !email.isEmpty,
//              let password = passwordTextField.text, !password.isEmpty else {
//            showAlert(message: "Please fill all fields.")
//            return
//        }
//        
//        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                self.showAlert(message: "Registration failed: \(error.localizedDescription)")
//                return
//            }
//            
//            // Save the user's name
//            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
//            changeRequest?.displayName = name
//            changeRequest?.commitChanges { error in
//                if let error = error {
//                    print("Failed to set display name: \(error)")
//                }
//            }
//            
//            // Navigate to the next screen
//            let collegeSelectionVC = CollegeSelectionViewController()
//            self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
//        }
//    }
    
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
                
                // Navigate to the next screen
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

//----------------------------------lksdhjkls-----------------------












//-------------------------------------Google Auth ----------------

//import UIKit
//import AuthenticationServices
//import FirebaseAuth
//import FirebaseFirestore
//import GoogleSignIn
//import MessageUI
//import FirebaseCore
//import CryptoKit
//
//class RegistrationViewController: UIViewController {
//    
//    private let db = Firestore.firestore()
//    private var isVerifyingEmail = false
//    private var currentNonce: String?
//    private var activityIndicator: UIActivityIndicatorView?
//    
//    // MARK: - UI Elements
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
//    private lazy var nameTextField = createTextField(placeholder: "Enter your Name")
//    private lazy var emailTextField = createTextField(placeholder: "Enter your Email")
//    private lazy var passwordTextField = createTextField(placeholder: "Choose a password", isSecure: true)
//    private lazy var otpTextField = createTextField(placeholder: "Enter OTP")
//    
//    private lazy var registerButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Register", for: .normal)
//        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        button.setTitleColor(.white, for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
//        button.layer.cornerRadius = 25
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
//    
//    private lazy var verifyButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Verify Email", for: .normal)
//        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        button.setTitleColor(.white, for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
//        button.layer.cornerRadius = 25
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.isHidden = true
//        return button
//    }()
//    
//    private lazy var resendOTPButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Resend OTP", for: .normal)
//        button.setTitleColor(UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0), for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        button.isHidden = true
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
//    private lazy var signInWithGoogleButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setTitle("Sign in with Google", for: .normal)
//        button.setTitleColor(.white, for: .normal)
//        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
//        button.backgroundColor = UIColor(red: 0.85, green: 0.26, blue: 0.22, alpha: 1.0)
//        button.layer.cornerRadius = 25
//        button.translatesAutoresizingMaskIntoConstraints = false
//        
//        // Add Google logo
//        let googleIcon = UIImageView(image: UIImage(named: "google_logo"))
//        googleIcon.contentMode = .scaleAspectFit
//        googleIcon.translatesAutoresizingMaskIntoConstraints = false
//        button.addSubview(googleIcon)
//        
//        NSLayoutConstraint.activate([
//            googleIcon.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 15),
//            googleIcon.centerYAnchor.constraint(equalTo: button.centerYAnchor),
//            googleIcon.widthAnchor.constraint(equalToConstant: 20),
//            googleIcon.heightAnchor.constraint(equalToConstant: 20)
//        ])
//        
//        return button
//    }()
//    
//    private let termsLabel: UILabel = {
//        let label = UILabel()
//        label.translatesAutoresizingMaskIntoConstraints = false
//        
//        let regularAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14),
//            .foregroundColor: UIColor.gray
//        ]
//        
//        let linkAttributes: [NSAttributedString.Key: Any] = [
//            .font: UIFont.systemFont(ofSize: 14),
//            .foregroundColor: UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
//        ]
//        
//        let attributedString = NSMutableAttributedString(string: "By tapping Register you agree to our\n", attributes: regularAttributes)
//        attributedString.append(NSAttributedString(string: "Terms of Use", attributes: linkAttributes))
//        attributedString.append(NSAttributedString(string: " and ", attributes: regularAttributes))
//        attributedString.append(NSAttributedString(string: "Privacy Policy", attributes: linkAttributes))
//        
//        label.attributedText = attributedString
//        label.numberOfLines = 0
//        label.textAlignment = .center
//        return label
//    }()
//    
//    private let loginPromptButton: UIButton = {
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
//        let attributedString = NSMutableAttributedString(string: "Have an account? ", attributes: regularAttributes)
//        attributedString.append(NSAttributedString(string: "Login", attributes: linkAttributes))
//        
//        button.setAttributedTitle(attributedString, for: .normal)
//        return button
//    }()
//    
//    private let orLabel: UILabel = {
//        let label = UILabel()
//        label.text = "OR"
//        label.font = .systemFont(ofSize: 14, weight: .medium)
//        label.textColor = .systemGray
//        label.textAlignment = .center
//        label.translatesAutoresizingMaskIntoConstraints = false
//        return label
//    }()
//    
//    private let leftSeparator: UIView = {
//        let view = UIView()
//        view.backgroundColor = .systemGray5
//        view.translatesAutoresizingMaskIntoConstraints = false
//        return view
//    }()
//    
//    private let rightSeparator: UIView = {
//        let view = UIView()
//        view.backgroundColor = .systemGray5
//        view.translatesAutoresizingMaskIntoConstraints = false
//        return view
//    }()
//    
//    // Timer for OTP expiration
//    private var otpTimer: Timer?
//    private var remainingTime = 300 // 5 minutes in seconds
//    private lazy var timerLabel: UILabel = {
//        let label = UILabel()
//        label.font = .systemFont(ofSize: 14)
//        label.textColor = .systemRed
//        label.textAlignment = .center
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.isHidden = true
//        return label
//    }()
//    
//    // MARK: - Lifecycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
//        view.addGestureRecognizer(tapGesture)
//        
//        // Set up Google Sign In
//        setupGoogleSignIn()
//    }
//    
//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        navigationController?.isNavigationBarHidden = true
//    }
//    
//    deinit {
//        otpTimer?.invalidate()
//    }
//    
//    // MARK: - UI Setup
//    private func setupUI() {
//        view.backgroundColor = .systemBackground
//        
//        // Add all subviews
//        [logoLabel, nameTextField, emailTextField, passwordTextField, otpTextField,
//         registerButton, verifyButton, resendOTPButton, timerLabel,
//         leftSeparator, orLabel, rightSeparator,
//         signInWithAppleButton, signInWithGoogleButton, termsLabel, loginPromptButton].forEach { view.addSubview($0) }
//        
//        // Initially hide the OTP field
//        otpTextField.isHidden = true
//        
//        // Setup constraints
//        NSLayoutConstraint.activate([
//            logoLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
//            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            
//            nameTextField.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 40),
//            nameTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
//            nameTextField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
//            nameTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            emailTextField.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 16),
//            emailTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            emailTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            emailTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            passwordTextField.topAnchor.constraint(equalTo: emailTextField.bottomAnchor, constant: 16),
//            passwordTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            passwordTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            passwordTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            otpTextField.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 16),
//            otpTextField.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            otpTextField.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            otpTextField.heightAnchor.constraint(equalToConstant: 50),
//            
//            timerLabel.topAnchor.constraint(equalTo: otpTextField.bottomAnchor, constant: 8),
//            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            
//            registerButton.topAnchor.constraint(equalTo: passwordTextField.bottomAnchor, constant: 32),
//            registerButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            registerButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            registerButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            verifyButton.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 16),
//            verifyButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            verifyButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            verifyButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            resendOTPButton.topAnchor.constraint(equalTo: verifyButton.bottomAnchor, constant: 8),
//            resendOTPButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            
//            leftSeparator.centerYAnchor.constraint(equalTo: orLabel.centerYAnchor),
//            leftSeparator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
//            leftSeparator.trailingAnchor.constraint(equalTo: orLabel.leadingAnchor, constant: -16),
//            leftSeparator.heightAnchor.constraint(equalToConstant: 1),
//            
//            orLabel.topAnchor.constraint(equalTo: registerButton.bottomAnchor, constant: 24),
//            orLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            
//            rightSeparator.centerYAnchor.constraint(equalTo: orLabel.centerYAnchor),
//            rightSeparator.leadingAnchor.constraint(equalTo: orLabel.trailingAnchor, constant: 16),
//            rightSeparator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
//            rightSeparator.heightAnchor.constraint(equalToConstant: 1),
//            
//            signInWithAppleButton.topAnchor.constraint(equalTo: orLabel.bottomAnchor, constant: 24),
//            signInWithAppleButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            signInWithAppleButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            signInWithGoogleButton.topAnchor.constraint(equalTo: signInWithAppleButton.bottomAnchor, constant: 16),
//            signInWithGoogleButton.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor),
//            signInWithGoogleButton.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor),
//            signInWithGoogleButton.heightAnchor.constraint(equalToConstant: 50),
//            
//            termsLabel.topAnchor.constraint(equalTo: signInWithGoogleButton.bottomAnchor, constant: 24),
//            termsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
//            termsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
//            
//            loginPromptButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
//            loginPromptButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
//        ])
//        
//        // Add targets to buttons
//        registerButton.addTarget(self, action: #selector(registerTapped), for: .touchUpInside)
//        verifyButton.addTarget(self, action: #selector(verifyOTPTapped), for: .touchUpInside)
//        resendOTPButton.addTarget(self, action: #selector(resendOTPTapped), for: .touchUpInside)
//        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
//        signInWithGoogleButton.addTarget(self, action: #selector(signInWithGoogleTapped), for: .touchUpInside)
//        loginPromptButton.addTarget(self, action: #selector(loginPromptTapped), for: .touchUpInside)
//    }
//    
//    private func setupGoogleSignIn() {
//        // Configure Google Sign In
//        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
//        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
//    }
//    
//    // MARK: - Actions
//    @objc private func registerTapped() {
//        guard let name = nameTextField.text, !name.isEmpty,
//              let email = emailTextField.text, !email.isEmpty,
//              let password = passwordTextField.text, !password.isEmpty else {
//            showAlert(message: "Please fill all fields.")
//            return
//        }
//        
//        // Validate email format
//        if !isValidEmail(email) {
//            showAlert(message: "Please enter a valid email address.")
//            return
//        }
//        
//        // Password strength check
//        if password.count < 8 {
//            showAlert(message: "Password must be at least 8 characters long.")
//            return
//        }
//        
//        if isVerifyingEmail {
//            // User has already requested verification, show the OTP field
//            // This case shouldn't happen now because we hide the register button when in verification mode
//            showOTPFields()
//            return
//        }
//        
//        // Show loading indicator
//        showLoadingIndicator()
//        
//        // First check if email already exists
//        Auth.auth().fetchSignInMethods(forEmail: email) { [weak self] (methods, error) in
//            guard let self = self else { return }
//            
//            self.hideLoadingIndicator()
//            
//            if let error = error {
//                self.showAlert(message: "Error: \(error.localizedDescription)")
//                return
//            }
//            
//            if let methods = methods, !methods.isEmpty {
//                self.showAlert(message: "Email is already registered. Please login or use a different email.")
//                return
//            }
//            
//            // Send verification email with OTP
//            self.sendEmailVerification(email: email, name: name, password: password)
//        }
//    }
//    
//    @objc private func resendOTPTapped() {
//        guard let email = emailTextField.text, !email.isEmpty,
//              let name = nameTextField.text, !name.isEmpty,
//              let password = passwordTextField.text, !password.isEmpty else {
//            showAlert(message: "Please fill all fields.")
//            return
//        }
//        
//        // Reset OTP timer
//        otpTimer?.invalidate()
//        
//        // Resend OTP
//        sendEmailVerification(email: email, name: name, password: password)
//    }
//    
//    private func showOTPFields() {
//        // Update UI for OTP verification
//        isVerifyingEmail = true
//        
//        // Hide registration elements
//        registerButton.isHidden = true
//        signInWithAppleButton.isHidden = true
//        signInWithGoogleButton.isHidden = true
//        leftSeparator.isHidden = true
//        rightSeparator.isHidden = true
//        orLabel.isHidden = true
//        termsLabel.isHidden = true
//        
//        // Show OTP elements
//        otpTextField.isHidden = false
//        verifyButton.isHidden = false
//        resendOTPButton.isHidden = false
//        timerLabel.isHidden = false
//        
//        // Make fields read-only when in verification mode
//        nameTextField.isEnabled = false
//        emailTextField.isEnabled = false
//        passwordTextField.isEnabled = false
//        
//        // Focus on OTP field
//        otpTextField.becomeFirstResponder()
//        
//        // Start OTP timer
//        startOTPTimer()
//    }
//    
//    private func startOTPTimer() {
//           // Reset timer values
//           remainingTime = 300 // 5 minutes
//           updateTimerLabel()
//           
//           // Invalidate any existing timer
//           otpTimer?.invalidate()
//           
//           // Create and start new timer - FIXED: added userInfo and repeats parameters
//           otpTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateOTPTimer), userInfo: nil, repeats: true)
//       }
//    
//    @objc private func updateOTPTimer() {
//        remainingTime -= 1
//        updateTimerLabel()
//        
//        if remainingTime <= 0 {
//            otpTimer?.invalidate()
//            otpTimer = nil
//            showAlert(message: "OTP has expired. Please request a new one.")
//        }
//    }
//    
//    private func updateTimerLabel() {
//        let minutes = remainingTime / 60
//        let seconds = remainingTime % 60
//        timerLabel.text = String(format: "OTP expires in: %02d:%02d", minutes, seconds)
//    }
//    
//    private func sendEmailVerification(email: String, name: String, password: String) {
//        // Show loading indicator
//        showLoadingIndicator()
//        
//        // Generate a random 6-digit OTP
//        let otp = String(format: "%06d", Int.random(in: 0...999999))
//        
//        // In a real app, you would integrate with an email service here
//        // For now, we'll store the OTP in Firestore
//        
//        // Store OTP in Firestore with expiration time (5 minutes)
//        let otpData: [String: Any] = [
//            "email": email,
//            "name": name,
//            "otp": otp,
//            "password": password, // In production, consider not storing the password directly
//            "createdAt": FieldValue.serverTimestamp(),
//            "expiresAt": Timestamp(date: Date().addingTimeInterval(300)) // 5 minutes
//        ]
//        
//        self.db.collection("otpVerifications").document(email).setData(otpData) { [weak self] error in
//            guard let self = self else { return }
//            
//            self.hideLoadingIndicator()
//            
//            if let error = error {
//                self.showAlert(message: "Error: \(error.localizedDescription)")
//                return
//            }
//            
//            // In a production app, send an email with the OTP here
//            // For demonstration, we'll just show the OTP in an alert
//            self.showAlert(message: "Verification code sent to \(email). For demo purposes, your OTP is: \(otp)")
//            
//            // Show OTP fields after user acknowledges the alert
//            DispatchQueue.main.async {
//                self.showOTPFields()
//            }
//        }
//    }
//    
//    @objc private func verifyOTPTapped() {
//        guard let email = emailTextField.text, !email.isEmpty,
//              let otp = otpTextField.text, !otp.isEmpty else {
//            showAlert(message: "Please enter the OTP sent to your email.")
//            return
//        }
//        
//        // Show loading indicator
//        showLoadingIndicator()
//        
//        // Verify OTP from Firestore
//        let otpRef = db.collection("otpVerifications").document(email)
//        otpRef.getDocument { [weak self] (document, error) in
//            guard let self = self else { return }
//            
//            self.hideLoadingIndicator()
//            
//            if let error = error {
//                self.showAlert(message: "Error: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let document = document, document.exists,
//                  let data = document.data(),
//                  let storedOTP = data["otp"] as? String,
//                  let name = data["name"] as? String,
//                  let password = data["password"] as? String,
//                  let expiresAt = data["expiresAt"] as? Timestamp else {
//                self.showAlert(message: "Invalid or expired OTP. Please try again.")
//                return
//            }
//            
//            // Check if OTP is expired
//            if expiresAt.dateValue() < Date() {
//                self.showAlert(message: "OTP has expired. Please request a new one.")
//                return
//            }
//            
//            // Verify OTP
//            if otp == storedOTP {
//                // OTP is valid, create the user account
//                self.createUserAccount(email: email, password: password, name: name)
//            } else {
//                self.showAlert(message: "Invalid OTP. Please check and try again.")
//            }
//        }
//    }
//    
//    private func createUserAccount(email: String, password: String, name: String) {
//        // Show loading indicator
//        showLoadingIndicator()
//        
//        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
//            guard let self = self else { return }
//            
//            self.hideLoadingIndicator()
//            
//            if let error = error {
//                self.showAlert(message: "Registration failed: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let userId = result?.user.uid else { return }
//            
//            // Send email verification from Firebase (optional)
//            result?.user.sendEmailVerification { error in
//                if let error = error {
//                    print("Error sending verification email: \(error)")
//                }
//            }
//            
//            // Store user data in Firestore
//            let userData: [String: Any] = [
//                "name": name,
//                "email": email,
//                "createdAt": FieldValue.serverTimestamp(),
//                "emailVerified": true  // We've already verified via OTP
//            ]
//            
//            self.db.collection("users").document(userId).setData(userData) { error in
//                if let error = error {
//                    print("Error storing user data: \(error)")
//                    return
//                }
//                
//                // Update display name
//                let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
//                changeRequest?.displayName = name
//                changeRequest?.commitChanges { error in
//                    if let error = error {
//                        print("Failed to set display name: \(error)")
//                    }
//                }
//                
//                // Clean up OTP document
//                self.db.collection("otpVerifications").document(email).delete()
//                
//                // Stop OTP timer
//                self.otpTimer?.invalidate()
//                
//                // Reset UI state
//                self.isVerifyingEmail = false
//                
//                // Show success message and navigate to next screen
//                self.showSuccessMessage {
//                    // Navigate to college selection
//                    let collegeSelectionVC = CollegeSelectionViewController()
//                    self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
//                }
//            }
//        }
//    }
//    
//    private func showSuccessMessage(completion: @escaping () -> Void) {
//        let alert = UIAlertController(title: "Success", message: "Your account has been created successfully!", preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in
//            completion()
//        })
//        present(alert, animated: true)
//    }
//    
//    @objc private func signInWithAppleTapped() {
//        let provider = ASAuthorizationAppleIDProvider()
//        let request = provider.createRequest()
//        request.requestedScopes = [.fullName, .email]
//        
//        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
//        authorizationController.delegate = self
//        authorizationController.presentationContextProvider = self
//        authorizationController.performRequests()
//    }
//    
//    @objc private func signInWithGoogleTapped() {
//        // Start the sign in flow
//        GIDSignIn.sharedInstance.signIn(withPresenting: self) { [weak self] result, error in
//            guard let self = self else { return }
//            
//            if let error = error {
//                self.showAlert(message: "Google Sign-In failed: \(error.localizedDescription)")
//                return
//            }
//            
//            guard let user = result?.user,
//                  let idToken = user.idToken?.tokenString else {
//                self.showAlert(message: "Failed to get user from Google Sign In")
//                return
//            }
//            
//            // Create Firebase credential with Google ID token
//            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: user.accessToken.tokenString)
//            
//            // Sign in with Firebase
//            self.signInWithFirebase(credential: credential)
//        }
//    }
//    
//    private func signInWithFirebase(credential: AuthCredential) {
//        // Show loading indicator
//        showLoadingIndicator()
//        
//        Auth.auth().signIn(with: credential) { [weak self] result, error in
//            guard let self = self else { return }
//            
//            self.hideLoadingIndicator()
//            
//            if let error = error {
//                self.showAlert(message: "Sign-In failed: \(error.localizedDescription)")
//                return
//            }
//            
//            // Check if this is a new user
//            let isNewUser = result?.additionalUserInfo?.isNewUser ?? false
//            
//            if isNewUser {
//                // Get user info
//                let fullName = result?.user.displayName ?? "User"
//                let email = result?.user.email ?? ""
//                
//                // Store user data in Firestore
//                let userData: [String: Any] = [
//                    "name": fullName,
//                    "email": email,
//                    "createdAt": FieldValue.serverTimestamp(),
//                    "authProvider": credential.provider,
//                    "emailVerified": true
//                ]
//                
//                self.db.collection("users").document(result!.user.uid).setData(userData) { error in
//                    if let error = error {
//                        print("Error storing user data: \(error)")
//                        return
//                    }
//                    
//                    // Navigate to college selection
//                    let collegeSelectionVC = CollegeSelectionViewController()
//                    self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
//                }
//            } else {
//                // Navigate to college selection
//                let collegeSelectionVC = CollegeSelectionViewController()
//                self.navigationController?.pushViewController(collegeSelectionVC, animated: true)
//            }
//        }
//    }
//    
//    @objc private func loginPromptTapped() {
//        let loginVC = LoginViewController()
//        navigationController?.pushViewController(loginVC, animated: true)
//    }
//    
//    @objc private func dismissKeyboard() {
//        view.endEditing(true)
//    }
//    
//    // MARK: - Helper Methods
//    private func isValidEmail(_ email: String) -> Bool {
//        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
//        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
//        return emailPred.evaluate(with: email)
//    }
//    
//    private func showAlert(message: String) {
//        let alert = UIAlertController(title: "NoteShare", message: message, preferredStyle: .alert)
//        alert.addAction(UIAlertAction(title: "OK", style: .default))
//        present(alert, animated: true)
//    }
//    
//    
//    private func showLoadingIndicator() {
//        if activityIndicator == nil {
//            activityIndicator = UIActivityIndicatorView(style: .large)
//            activityIndicator?.center = view.center
//            activityIndicator?.hidesWhenStopped = true
//            view.addSubview(activityIndicator!)
//        }
//        
//        activityIndicator?.startAnimating()
//        view.isUserInteractionEnabled = false
//    }
//    
//    private func hideLoadingIndicator() {
//        activityIndicator?.stopAnimating()
//        view.isUserInteractionEnabled = true
//    }
//    
//   
//    
//}
//
//extension RegistrationViewController: ASAuthorizationControllerDelegate {
//    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
//        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
//            guard let nonce = currentNonce else {
//                showAlert(message: "Invalid state: A login callback was received, but no login request was sent.")
//                return
//            }
//            
//            guard let appleIDToken = appleIDCredential.identityToken else {
//                showAlert(message: "Unable to fetch identity token")
//                return
//            }
//            
//            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
//                showAlert(message: "Unable to serialize token string from data")
//                return
//            }
//            
//            // Create Firebase credential
//            let credential = OAuthProvider.credential(withProviderID: "apple.com",
//                                                      idToken: idTokenString,
//                                                      rawNonce: nonce)
//            
//            // Get user info
//            var fullName = "User"
//            if let firstName = appleIDCredential.fullName?.givenName,
//               let lastName = appleIDCredential.fullName?.familyName {
//                fullName = "\(firstName) \(lastName)"
//            }
//            
//            // Sign in with Firebase
//            signInWithFirebase(credential: credential)
//        }
//    }
//    
//    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
//        showAlert(message: "Sign in with Apple failed: \(error.localizedDescription)")
//    }
//}
//
//extension RegistrationViewController: ASAuthorizationControllerPresentationContextProviding {
//    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//        return view.window!
//    }
//}
//
//extension RegistrationViewController {
//    private func randomNonceString(length: Int = 32) -> String {
//        precondition(length > 0)
//        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
//        var result = ""
//        var remainingLength = length
//        
//        while remainingLength > 0 {
//            let randoms: [UInt8] = (0 ..< 16).map { _ in
//                var random: UInt8 = 0
//                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
//                if errorCode != errSecSuccess {
//                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
//                }
//                return random
//            }
//            
//            randoms.forEach { random in
//                if remainingLength == 0 {
//                    return
//                }
//                
//                if random < charset.count {
//                    result.append(charset[Int(random)])
//                    remainingLength -= 1
//                }
//            }
//        }
//        
//        return result
//    }
//}
//    
//    private func sha256(_ input: String) -> String {
//        let inputData = Data(input.utf8)
//        let hashedData = SHA256.hash(data: inputData)
//        let hashString = hashedData.compactMap {
//            String(format: "%02x", $0)
//        }.joined()
//        
//        return hashString
//    }
//
//
//extension RegistrationViewController: MFMailComposeViewControllerDelegate {
//    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
//        controller.dismiss(animated: true)
//    }
//
//}
//
//

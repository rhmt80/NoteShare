//
//  LoginViewController.swift
//  OnBoarding
//
//  Created by admin24 on 05/11/24.
//

import UIKit
import AuthenticationServices

class LoginViewController: UIViewController {
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = true
    }
    
    // MARK: - UI Components
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
    
    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "NoteShare"
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let emailTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your Email"
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.keyboardType = .emailAddress
        textField.autocapitalizationType = .none
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private let passwordTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Enter your password"
        textField.borderStyle = .none
        textField.backgroundColor = .clear
        textField.isSecureTextEntry = true
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    private lazy var loginButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Login"
        configuration.baseBackgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        configuration.cornerStyle = .large
        
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let signInWithAppleButton: ASAuthorizationAppleIDButton = {
        let button = ASAuthorizationAppleIDButton(type: .signIn, style: .black)
        button.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
//    private let signUpPromptLabel: UILabel = {
//        let label = UILabel()
//        label.translatesAutoresizingMaskIntoConstraints = false
//        label.text = "Don't have an account? Sign Up"
//        label.textAlignment = .center
//        label.font = .systemFont(ofSize: 14)
//        label.textColor = .label
//        return label
//    }()
    
    private let signUpPromptLabel: UIButton = {
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
        attributedString.append(NSAttributedString(string: "Sign Up", attributes: linkAttributes))
        
        button.setAttributedTitle(attributedString, for: .normal)
        return button
    }()
    
    // MARK: - TextFields Container Views
    private func createTextFieldContainer(textField: UITextField) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .systemBackground
        container.layer.borderColor = UIColor.systemGray5.cgColor
        container.layer.borderWidth = 1
        container.layer.cornerRadius = 8
        
        container.addSubview(textField)
        
        let clearButton = UIButton(type: .system)
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = .systemGray3
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(clearButton)
        
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            textField.topAnchor.constraint(equalTo: container.topAnchor),
            textField.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            clearButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            clearButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),
            
            container.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        clearButton.addTarget(self, action: #selector(clearTextField(_:)), for: .touchUpInside)
        clearButton.tag = [emailTextField, passwordTextField].firstIndex(of: textField) ?? 0
        
        return container
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardHandling()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        let emailContainer = createTextFieldContainer(textField: emailTextField)
        let passwordContainer = createTextFieldContainer(textField: passwordTextField)
        
        [logoLabel, emailContainer, passwordContainer, loginButton, signInWithAppleButton, signUpPromptLabel].forEach(contentView.addSubview)
        
        // Setup constraints
        let safeArea = view.safeAreaLayoutGuide
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            logoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 60),
            logoLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            
            emailContainer.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 60),
            emailContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            emailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            
            passwordContainer.topAnchor.constraint(equalTo: emailContainer.bottomAnchor, constant: 16),
            passwordContainer.leadingAnchor.constraint(equalTo: emailContainer.leadingAnchor),
            passwordContainer.trailingAnchor.constraint(equalTo: emailContainer.trailingAnchor),
            
            loginButton.topAnchor.constraint(equalTo: passwordContainer.bottomAnchor, constant: 32),
            loginButton.leadingAnchor.constraint(equalTo: emailContainer.leadingAnchor),
            loginButton.trailingAnchor.constraint(equalTo: emailContainer.trailingAnchor),
            loginButton.heightAnchor.constraint(equalToConstant: 50),
            
            signInWithAppleButton.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 16),
            signInWithAppleButton.leadingAnchor.constraint(equalTo: emailContainer.leadingAnchor),
            signInWithAppleButton.trailingAnchor.constraint(equalTo: emailContainer.trailingAnchor),
            signInWithAppleButton.heightAnchor.constraint(equalToConstant: 50),
            
            signUpPromptLabel.topAnchor.constraint(equalTo: signInWithAppleButton.bottomAnchor, constant: 24),
            signUpPromptLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            signUpPromptLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // Add targets
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)
        signInWithAppleButton.addTarget(self, action: #selector(signInWithAppleTapped), for: .touchUpInside)
        
        // Add tap gesture to sign up prompt
//        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(signUpPromptTapped))
//        signUpPromptLabel.isUserInteractionEnabled = true
//        signUpPromptLabel.addGestureRecognizer(tapGesture)
        
        signUpPromptLabel.addTarget(self, action: #selector(signUpPromptTapped), for: .touchUpInside)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow),
                                             name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide),
                                             name: UIResponder.keyboardWillHideNotification, object: nil)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Actions
    @objc private func loginTapped() {
        // Handle login
        let collegeSelectionVC = CollegeSelectionViewController()
        collegeSelectionVC.modalPresentationStyle = .fullScreen
           present(collegeSelectionVC, animated: true)
    }
    
    @objc private func signInWithAppleTapped() {
        // Handle Apple sign in
        print("Sign in with Apple tapped")
    }
    
    @objc private func signUpPromptTapped() {
        // Handle sign up navigation
        let signUpVC = RegistrationViewController()
        signUpVC.modalPresentationStyle = .fullScreen
           present(signUpVC, animated: true)
    }
    
    @objc private func clearTextField(_ sender: UIButton) {
        let textFields = [emailTextField, passwordTextField]
        textFields[sender.tag].text = ""
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
            return
        }
        
        let contentInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: keyboardSize.height, right: 0.0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
}

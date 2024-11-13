//
//  CollegeSelectionViewController.swift
//  OnBoarding
//
//  Created by admin24 on 05/11/24.
//

import UIKit

class CollegeSelectionViewController: UIViewController {
    
    // MARK: - UI Components
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select your college"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
//    private let collegeSelectionButton: UIButton = {
//        let button = UIButton()
//        button.setTitle("Select below", for: .normal)
//        button.setTitleColor(.gray, for: .normal)
//        button.contentHorizontalAlignment = .left
//        button.layer.borderWidth = 1
//        button.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
//        button.layer.cornerRadius = 8
//        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
//        let image = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
//        button.setImage(image, for: .normal)
//        button.tintColor = .systemBlue
//        button.semanticContentAttribute = .forceRightToLeft
//        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
//        return button
//    }()
    
    private let collegeSelectionButton: UIButton = {
        var configuration = UIButton.Configuration.plain()
        
        // Configure button text
        var container = AttributeContainer()
        container.font = .systemFont(ofSize: 16)
        container.foregroundColor = .gray
        configuration.attributedTitle = AttributedString("Select below", attributes: container)
        
        // Configure content padding
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
        
        // Configure image
        configuration.image = UIImage(systemName: "chevron.down")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 0  // Remove padding between text and image
        
        // Maximize the distance between title and image
        configuration.titleAlignment = .leading  // Align text to leading edge
        
        // Create button with configuration
        let button = UIButton(configuration: configuration)
        
        // Configure button layout
        button.contentHorizontalAlignment = .leading  // Align entire content to leading edge
        button.configuration?.titleAlignment = .leading  // Ensure title stays left-aligned
        
        // Add constraints to ensure button spans full width
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure border and other properties
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        button.layer.cornerRadius = 8
        button.tintColor = .systemBlue
        
        return button
    }()
    
    private let yearLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter current college year"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private let yearSelectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Select below", for: .normal)
        button.setTitleColor(.gray, for: .normal)
        button.contentHorizontalAlignment = .left
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let image = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        return button
    }()
    
    private let courseLabel: UILabel = {
        let label = UILabel()
        label.text = "Enter your course"
        label.font = .systemFont(ofSize: 24, weight: .bold)
        return label
    }()
    
    private let courseSelectionButton: UIButton = {
        let button = UIButton()
        button.setTitle("Select below", for: .normal)
        button.setTitleColor(.gray, for: .normal)
        button.contentHorizontalAlignment = .left
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.gray.withAlphaComponent(0.3).cgColor
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let image = UIImage(systemName: "chevron.down")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .systemBlue
        button.semanticContentAttribute = .forceRightToLeft
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        return button
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton()
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "chevron.left"),
            style: .plain,
            target: self,
            action: #selector(backButtonTapped)
        )
        
        view.addSubview(stackView)
        view.addSubview(continueButton)
        
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(collegeSelectionButton)
        stackView.addArrangedSubview(yearLabel)
        stackView.addArrangedSubview(yearSelectionButton)
        stackView.addArrangedSubview(courseLabel)
        stackView.addArrangedSubview(courseSelectionButton)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50),
            
            collegeSelectionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collegeSelectionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
               
        ])
        
        // Add targets for buttons
        collegeSelectionButton.addTarget(self, action: #selector(collegeButtonTapped), for: .touchUpInside)
        yearSelectionButton.addTarget(self, action: #selector(yearButtonTapped), for: .touchUpInside)
        courseSelectionButton.addTarget(self, action: #selector(courseButtonTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func collegeButtonTapped() {
        // Implement college selection logic
    }
    
    @objc private func yearButtonTapped() {
        // Implement year selection logic
    }
    
    @objc private func courseButtonTapped() {
        // Implement course selection logic
    }
    
    @objc private func continueButtonTapped() {
        // Implement continue logic
    }
}

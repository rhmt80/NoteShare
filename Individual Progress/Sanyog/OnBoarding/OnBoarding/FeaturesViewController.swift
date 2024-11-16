//
//  FeaturesViewController.swift
//  OnBoarding
//
//  Created by admin24 on 02/11/24.
//

import UIKit

class FeaturesViewController: UIViewController {
    
    // MARK: - UI Components
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 75
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "What's New!"
        label.font = .systemFont(ofSize: 40, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let featuresStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 55
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var continueButton: UIButton = {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Continue"
        configuration.baseBackgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        configuration.cornerStyle = .large
        
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Feature Items
    private func createFeatureView(icon: String, title: String, description: String) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        iconImageView.image = UIImage(systemName: icon)?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        )
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 27, weight: .semibold)
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = description
        descriptionLabel.font = .systemFont(ofSize: 15)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(descriptionLabel)
        
        let contentStack = UIStackView()
        contentStack.axis = .horizontal
        contentStack.spacing = 16
        contentStack.alignment = .top
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        
        contentStack.addArrangedSubview(iconImageView)
        contentStack.addArrangedSubview(textStack)
        
        container.addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),
            
            contentStack.topAnchor.constraint(equalTo: container.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add subviews
        view.addSubview(stackView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(featuresStack)
        view.addSubview(continueButton)
        
        // Add features
        let features = [
            ("house.fill", "Handwritten Exclusivity", "Capture the personal touch and authenticity that handwritten notes can offer."),
            ("magnifyingglass", "Explore", "Browse and discover notes by subject, course, or topic shared by your peers."),
            ("books.vertical.fill", "My Notes", "Organise your own notes and easily add materials from the explore section for future reference.")
        ]
        
        features.forEach { icon, title, description in
            featuresStack.addArrangedSubview(createFeatureView(icon: icon, title: title, description: description))
        }
        
        // Setup constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        // Add button action
        continueButton.addTarget(self, action: #selector(continueTapped), for: .touchUpInside)
    }
    // MARK: - Actions
    @objc private func continueTapped() {
        let registrationVC = RegistrationViewController()
           registrationVC.modalPresentationStyle = .fullScreen
           present(registrationVC, animated: true)
    }
}

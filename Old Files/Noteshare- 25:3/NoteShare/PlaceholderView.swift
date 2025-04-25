//
//  PlaceholderView.swift
//  NoteShare
//
//  Created by admin40 on 19/03/25.
//

import Foundation
import UIKit

class PlaceholderView: UIView {
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    
    private var actionHandler: (() -> Void)?
    
    init(image: UIImage?, title: String, message: String, buttonTitle: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.actionHandler = action
        setupViews()
        
        imageView.image = image
        imageView.tintColor = .systemBlue
        
        titleLabel.text = title
        messageLabel.text = message
        actionButton.setTitle(buttonTitle, for: .normal)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        backgroundColor = .clear
        
        // Configure image view
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure labels
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure button
        actionButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        actionButton.backgroundColor = .systemBlue
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        
        // Add subviews
        addSubview(imageView)
        addSubview(titleLabel)
        addSubview(messageLabel)
        addSubview(actionButton)
        
        // Set constraints
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            imageView.widthAnchor.constraint(equalToConstant: 70),
            imageView.heightAnchor.constraint(equalToConstant: 70),
            
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            messageLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            
            actionButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            actionButton.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 24)
        ])
    }
    
    @objc private func buttonTapped() {
        actionHandler?()
    }
    
    // Add a method to update the message
    func updateMessage(_ message: String) {
        messageLabel.text = message
    }
    
    // Add a method to update the title too
    func updateTitle(_ title: String) {
        titleLabel.text = title
    }
    
    // Add a method to update the button title
    func updateButtonTitle(_ title: String) {
        actionButton.setTitle(title, for: .normal)
    }
    
    // Add a method to update the image
    func updateImage(_ image: UIImage?) {
        imageView.image = image
    }
}

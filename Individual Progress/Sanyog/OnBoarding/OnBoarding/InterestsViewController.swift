//
//  InterestsViewController.swift
//  OnBoarding
//
//  Created by admin24 on 15/11/24.
//

import UIKit

class InterestsViewController: UIViewController {
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your Interests"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 25
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let interestsContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let interests = [
        "Mathematics",
        "Swift Programing",
        "Python",
        "Artificial Intelligence",
        "LLMS",
        "WebDev",
        "Android Dev",
        "Operating system",
        "Java Devlopment",
        "Computer Architecture",
        "Deep Learning",
        "Algorithms",
        "Machine Learning",
        "C++",
        "Computer vision",
        "NLP",
        "Graph Theory",
        "Automata Language",
        "Data Structures",
        "Database",
        "Networking",
        "Others",
        "calculus"
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(scrollView)
        view.addSubview(continueButton)
        
        scrollView.addSubview(interestsContainer)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -20),
            
            interestsContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            interestsContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            interestsContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            interestsContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            // Make the container width equal to scroll view width minus padding
            interestsContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        createInterestButtons()
    }
    
    private func createInterestButtons() {
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        let spacing: CGFloat = 10
        var maxHeight: CGFloat = 0
        
        for interest in interests {
            let button = createInterestButton(withTitle: interest)
            let buttonWidth = button.intrinsicContentSize.width + 20
            
            // Check if button needs to go to next line
            if currentX + buttonWidth > (view.bounds.width - 40) { // 40 is total horizontal padding
                currentX = 0
                currentY += 40 + spacing
            }
            
            button.frame = CGRect(x: currentX, y: currentY, width: buttonWidth, height: 40)
            interestsContainer.addSubview(button)
            
            currentX += buttonWidth + spacing
            maxHeight = currentY + 40 // Update max height
        }
        
        // Set the container height to fit all buttons
        let containerHeight = maxHeight + 40 // Add extra padding at bottom
        interestsContainer.heightAnchor.constraint(equalToConstant: containerHeight).isActive = true
    }
    
    private func createInterestButton(withTitle title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.backgroundColor = .systemGray6
        button.setTitleColor(.systemBlue, for: .normal)
        button.layer.cornerRadius = 20
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        button.addTarget(self, action: #selector(interestButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    @objc private func interestButtonTapped(_ sender: UIButton) {
        sender.isSelected.toggle()
        sender.backgroundColor = sender.isSelected ? .systemBlue : .systemGray6
        sender.setTitleColor(sender.isSelected ? .white : .systemBlue, for: .normal)
    }
    
    @objc private func continueButtonTapped() {
        // Handle continue action
    }
    
    @objc private func backButtonTapped() {
        // Handle back navigation
    }
}
#Preview {
    InterestsViewController()
}

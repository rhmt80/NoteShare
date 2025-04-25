import FirebaseAuth
import SafariServices
import SwiftUI
import SwiftUICore
import UIKit
import Firebase
import FirebaseFirestore
import FirebaseStorage
import PhotosUI
import ObjectiveC


class ProfileViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDelegate, UITableViewDataSource{
    
    // MARK: - Properties
    
    private var selectedInterests: [String] = []
    private var userName: String = "User Name"
    private var userEmail: String = "user@example.com"
    private var userCourse: String = "Computer Science"
    private var userCollege: String = "SRM"
    private var isEditMode: Bool = false
    
    private enum Section: Int, CaseIterable {
        case profile
        case education
        case interests
        case privacy
        case logout
    }
    
    private let interests = [
        "Core Cse",
        "Web & App Development",
        "AIML",
        "Core ECE",
        "Core Mechanical",
        "Core Civil",
        "Core Electrical",
        "Physics",
        "Maths"
    ]
    
    // MARK: - UI Components
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0) // Matte white finish
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.contentInsetAdjustmentBehavior = .automatic
        tableView.showsVerticalScrollIndicator = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        return tableView
    }()
    
    private let backButton: UIButton = {
            let button = UIButton(type: .system)
            let image = UIImage(systemName: "chevron.left")
            button.setImage(image, for: .normal)
            button.setTitle("Back", for: .normal)
            button.tintColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
            button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
            return button
    }()
    
    private let editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Edit", for: .normal)
        button.tintColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Profile"
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private let profileImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "person.crop.circle.fill")
        imageView.tintColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 45
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupTableView()
        fetchUserData()
        setupPhotoUpload()
    }
    
    // MARK: - Setup Methods
    
    private func setupNavigationBar() {
        view.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0) // Matte white finish
        navigationController?.navigationBar.isHidden = true
        
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(editButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            
            editButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            editButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Adjust the table view insets for more compact appearance
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.layoutMargins = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 40
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.estimatedSectionFooterHeight = 10
    }
    
    private func setupPhotoUpload() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handlePhotoUpload))
        profileImageView.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Table View Data Source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .profile:
            return 1
        case .education:
            return 2
        case .interests:
            return 1 // Always just one row for interests
        case .privacy:
            return 2
        case .logout:
            return 1
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return cell }
        
        switch sectionType {
        case .profile:
            configureProfileCell(cell)
        case .education:
            configureEducationCell(cell, forRow: indexPath.row)
        case .interests:
            configureInterestsCell(cell, forRow: indexPath.row)
        case .privacy:
            configurePrivacyCell(cell, forRow: indexPath.row)
        case .logout:
            configureLogoutCell(cell)
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .profile:
            return 0
        case .education:
            return 50
        case .interests:
            return 50
        case .privacy:
            return 50
        case .logout:
            return 25
        }
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard let sectionType = Section(rawValue: section) else { return 0 }
        
        switch sectionType {
        case .profile:
            return 10
        case .education:
            return 10
        case .interests:
            return 10
        case .privacy:
            return 10
        case .logout:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        footerView.backgroundColor = .clear
        return footerView
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let sectionType = Section(rawValue: indexPath.section) else { return UITableView.automaticDimension }
        
        switch sectionType {
        case .profile:
            return 100 // Fixed height for profile cell
        case .education, .privacy:
            return 48 // Standard height for these cells
        case .interests:
            if !selectedInterests.isEmpty {
                // Fixed height for interests row with horizontal scrollable collection view
                return 68 // Height for collection view plus padding
            } else {
                return 56 // Standard height for "No interests selected" cell
            }
        case .logout:
            return 52 // Reduced height for logout button
        }
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let sectionType = Section(rawValue: section) else { return nil }
        
        let headerView = UIView()
        headerView.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        
        switch sectionType {
        case .profile:
            return nil
        case .education:
            titleLabel.text = "Education"
            titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
            
        case .interests:
            titleLabel.text = "Interests"
            titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        case .privacy:
            titleLabel.text = "PRIVACY & INFORMATION"
            titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
            titleLabel.textColor = .darkGray
        case .logout:
            return nil
        }
        
        headerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8)
        ])
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Immediately deselect the row with animation
        tableView.deselectRow(at: indexPath, animated: true)
        
        guard let sectionType = Section(rawValue: indexPath.section) else { return }
        
        switch sectionType {
        case .privacy:
            handlePrivacyRowSelection(indexPath.row)
        case .logout:
            signOutTapped()
        case .interests:
            // Handle interests tapping in edit mode directly from the cell tap
            if isEditMode {
                showInterestSelectionView()
            }
        default:
            break
        }
    }
    
    // MARK: - Cell Configurations
    
    private func configureProfileCell(_ cell: UITableViewCell) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.accessoryType = .none // Ensure no chevron appears
        cell.backgroundColor = .systemBackground
        cell.contentView.backgroundColor = .systemBackground
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        if isEditMode {
            // Editable profile cell
            let nameTextField = UITextField()
            nameTextField.text = userName
            nameTextField.font = .systemFont(ofSize: 28, weight: .bold)
            nameTextField.translatesAutoresizingMaskIntoConstraints = false
            nameTextField.borderStyle = .none
            nameTextField.tag = 1 // Tag for identification
            nameTextField.isEnabled = true
            nameTextField.returnKeyType = .done
            nameTextField.autocapitalizationType = .words
            nameTextField.delegate = self
            
            // Create iOS-style edit indicator with subtle styling
            let editBackground = UIView()
            editBackground.translatesAutoresizingMaskIntoConstraints = false
            editBackground.backgroundColor = UIColor.systemGray6
            editBackground.layer.cornerRadius = 8
            
            containerView.addSubview(editBackground)
            containerView.addSubview(nameTextField)
            
            // Add iOS-standard padding around text field
            NSLayoutConstraint.activate([
                editBackground.leadingAnchor.constraint(equalTo: nameTextField.leadingAnchor, constant: -8),
                editBackground.trailingAnchor.constraint(equalTo: nameTextField.trailingAnchor, constant: 8),
                editBackground.topAnchor.constraint(equalTo: nameTextField.topAnchor, constant: -6),
                editBackground.bottomAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 6)
            ])
            
            let emailLabel = UILabel()
            emailLabel.text = userEmail
            emailLabel.font = .systemFont(ofSize: 16)
            emailLabel.textColor = .secondaryLabel
            emailLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(profileImageView)
            containerView.addSubview(emailLabel)
            
            NSLayoutConstraint.activate([
                nameTextField.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
                nameTextField.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
                nameTextField.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
                
                emailLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
                emailLabel.topAnchor.constraint(equalTo: nameTextField.bottomAnchor, constant: 8),
                emailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            // First, clean up any existing edit icon containers from previous uses
            profileImageView.subviews.forEach { $0.removeFromSuperview() }
            
            // Add edit icon overlay to indicate the profile picture is editable - iOS 16 style
            let editIconContainer = UIView()
            editIconContainer.translatesAutoresizingMaskIntoConstraints = false
            editIconContainer.backgroundColor = .systemBlue
            editIconContainer.layer.cornerRadius = 13
            editIconContainer.clipsToBounds = true
            
            let editIcon = UIImageView(image: UIImage(systemName: "pencil"))
            editIcon.tintColor = .white
            editIcon.contentMode = .scaleAspectFit
            editIcon.translatesAutoresizingMaskIntoConstraints = false
            
            editIconContainer.addSubview(editIcon)
            profileImageView.addSubview(editIconContainer)
            
            // Add "Tap to change" label below profile image
            let tapToChangeLabel = UILabel()
            tapToChangeLabel.text = "Edit"
            tapToChangeLabel.font = .systemFont(ofSize: 13, weight: .medium)
            tapToChangeLabel.textColor = .systemBlue
            tapToChangeLabel.textAlignment = .center
            tapToChangeLabel.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(tapToChangeLabel)
            
            NSLayoutConstraint.activate([
                editIcon.centerXAnchor.constraint(equalTo: editIconContainer.centerXAnchor),
                editIcon.centerYAnchor.constraint(equalTo: editIconContainer.centerYAnchor),
                editIcon.widthAnchor.constraint(equalToConstant: 12),
                editIcon.heightAnchor.constraint(equalToConstant: 12),
                
                editIconContainer.bottomAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: -2),
                editIconContainer.trailingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: -2),
                editIconContainer.widthAnchor.constraint(equalToConstant: 26),
                editIconContainer.heightAnchor.constraint(equalToConstant: 26),
                
                tapToChangeLabel.topAnchor.constraint(equalTo: profileImageView.bottomAnchor, constant: 4),
                tapToChangeLabel.centerXAnchor.constraint(equalTo: profileImageView.centerXAnchor),
                tapToChangeLabel.widthAnchor.constraint(equalTo: profileImageView.widthAnchor)
            ])
            
            // Add a light circular border around the profile image
            profileImageView.layer.borderWidth = 1
            profileImageView.layer.borderColor = UIColor.systemGray5.cgColor
        } else {
            // Standard profile cell
            let nameLabel = UILabel()
            nameLabel.text = userName
            nameLabel.font = .systemFont(ofSize: 28, weight: .bold)
            nameLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let emailLabel = UILabel()
            emailLabel.text = userEmail
            emailLabel.font = .systemFont(ofSize: 16)
            emailLabel.textColor = .secondaryLabel
            emailLabel.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(profileImageView)
            containerView.addSubview(nameLabel)
            containerView.addSubview(emailLabel)
            
            NSLayoutConstraint.activate([
                nameLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
                nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
                nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                
                emailLabel.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: 16),
                emailLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
                emailLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
            ])
            
            // Remove any edit indicators
            profileImageView.subviews.forEach { $0.removeFromSuperview() }
            profileImageView.layer.borderWidth = 0
        }
        
        cell.contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            profileImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            profileImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor, constant: isEditMode ? -10 : 0), // Adjust position in edit mode
            profileImageView.widthAnchor.constraint(equalToConstant: 90),
            profileImageView.heightAnchor.constraint(equalToConstant: 90),
        ])
    }
    
    private func configureEducationCell(_ cell: UITableViewCell, forRow row: Int) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .systemBackground
        cell.selectionStyle = .none // Disable selection completely
        cell.accessoryType = .none // Ensure no chevron is shown

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView()
        iconView.tintColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        // Standard education cell (always non-editable)
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        
        switch row {
        case 0:
            label.text = userCourse
            iconView.image = UIImage(systemName: "graduationcap.fill")
        case 1:
            label.text = userCollege
            iconView.image = UIImage(systemName: "building.columns.fill")
        default:
            break
        }
        
        containerView.addSubview(iconView)
        containerView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: containerView.trailingAnchor)
        ])
        
        cell.contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            
            iconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),
        ])
        
        // Add separator line if not the last cell
        if row == 0 {
            let separatorLine = UIView()
            separatorLine.backgroundColor = UIColor.systemGray5
            separatorLine.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(separatorLine)
            
            NSLayoutConstraint.activate([
                separatorLine.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                separatorLine.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                separatorLine.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
    }
    
    private func configureInterestsCell(_ cell: UITableViewCell, forRow row: Int) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .systemBackground
        
        // Reset any previous configuration
        cell.textLabel?.text = nil
        cell.imageView?.image = nil
        cell.detailTextLabel?.text = nil
        
        // Make the cell selectable when in edit mode only
        cell.selectionStyle = isEditMode ? .default : .none
        
        // Only show chevron in edit mode
        cell.accessoryType = isEditMode ? .disclosureIndicator : .none
        
        // Add a subtle highlight effect
        let highlightView = UIView()
        highlightView.backgroundColor = UIColor.systemGray6
        highlightView.layer.cornerRadius = 10
        highlightView.translatesAutoresizingMaskIntoConstraints = false
        cell.selectedBackgroundView = highlightView
        
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(containerView)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 12),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -12)
        ])
        
        // Make the entire cell tappable in edit mode
        if isEditMode {
            let tapAreaButton = UIButton(type: .custom)
            tapAreaButton.backgroundColor = .clear
            tapAreaButton.translatesAutoresizingMaskIntoConstraints = false
            
            cell.contentView.addSubview(tapAreaButton)
            
            NSLayoutConstraint.activate([
                tapAreaButton.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
                tapAreaButton.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                tapAreaButton.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                tapAreaButton.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
            ])
            
            tapAreaButton.addTarget(self, action: #selector(interestCellTapped), for: .touchUpInside)
        }
        
        // Create iOS-style tag collection display
        if !selectedInterests.isEmpty {
            // Use flexible row layout for tags
            let flowLayout = UICollectionViewFlowLayout()
            flowLayout.scrollDirection = .horizontal
            flowLayout.minimumInteritemSpacing = 12  // More spacing between items
            flowLayout.minimumLineSpacing = 12       // More line spacing
            flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) // No extra right padding since we use accessoryType
            
            let tagsCollectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
            tagsCollectionView.translatesAutoresizingMaskIntoConstraints = false
            tagsCollectionView.backgroundColor = .clear
            tagsCollectionView.isScrollEnabled = true
            tagsCollectionView.isUserInteractionEnabled = true
            tagsCollectionView.alwaysBounceHorizontal = true
            tagsCollectionView.decelerationRate = .fast
            tagsCollectionView.register(InterestTagCell.self, forCellWithReuseIdentifier: "tagCell")
            tagsCollectionView.showsHorizontalScrollIndicator = false
            tagsCollectionView.clipsToBounds = false // Allow items to be visible during scroll
            tagsCollectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: isEditMode ? 24 : 0) // Extra padding only in edit mode
            
            containerView.addSubview(tagsCollectionView)
            
            NSLayoutConstraint.activate([
                tagsCollectionView.topAnchor.constraint(equalTo: containerView.topAnchor),
                tagsCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                tagsCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                tagsCollectionView.heightAnchor.constraint(equalToConstant: 44),  // Height for the collection view
                tagsCollectionView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            // Configure the collection view to show all interests
            tagsCollectionView.dataSource = self
            tagsCollectionView.delegate = self
            
            // Store the full interests array for the collection view to use
            objc_setAssociatedObject(tagsCollectionView, "fullInterestsList", selectedInterests, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        } else {
            // Display "No interests selected" message
            let noInterestsLabel = UILabel()
            noInterestsLabel.translatesAutoresizingMaskIntoConstraints = false
            noInterestsLabel.font = .systemFont(ofSize: 16)
            noInterestsLabel.textColor = .secondaryLabel
            noInterestsLabel.text = "No interests selected"
            
            containerView.addSubview(noInterestsLabel)
            
            NSLayoutConstraint.activate([
                noInterestsLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
                noInterestsLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                noInterestsLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                noInterestsLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }
    }
    
    @objc private func interestCellTapped() {
        if isEditMode {
            // Open interest selection in edit mode
            showInterestSelectionView()
        } else {
            // In view mode, do nothing special - the scrollable collection view is already visible
        }
    }
    
    private func configurePrivacyCell(_ cell: UITableViewCell, forRow row: Int) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .systemBackground
        cell.accessoryType = .disclosureIndicator
        cell.selectionStyle = .default
        
        let label = UILabel()
        label.font = .systemFont(ofSize: 17)
        label.textColor = UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0) // Blue link color
        label.translatesAutoresizingMaskIntoConstraints = false
        
        switch row {
        case 0:
            label.text = "Privacy Policy"
        case 1:
            label.text = "Terms & Conditions"
        default:
            break
        }
        
        cell.contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
        
        // Add separator line if not the last cell
        if row < 2 {
            let separatorLine = UIView()
            separatorLine.backgroundColor = UIColor.systemGray5
            separatorLine.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(separatorLine)
            
            NSLayoutConstraint.activate([
                separatorLine.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
                separatorLine.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
                separatorLine.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                separatorLine.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }
    }
    
    private func configureLogoutCell(_ cell: UITableViewCell) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        // Make sure no accessory is shown
        cell.accessoryType = .none
        cell.selectionStyle = .none
        
        // Add container view for the whole cell
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(containerView)
        
        // Create logout button with light red background and red text
        let logoutButton = UIButton(type: .system)
        logoutButton.setTitle("Logout", for: .normal)
        logoutButton.setTitleColor(UIColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0), for: .normal) // Red text
        logoutButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        logoutButton.backgroundColor = UIColor(red: 1.0, green: 0.9, blue: 0.9, alpha: 1.0) // Light red background
        logoutButton.layer.cornerRadius = 12
        // Add slight shadow for better appearance
        logoutButton.layer.shadowColor = UIColor.black.cgColor
        logoutButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        logoutButton.layer.shadowRadius = 2
        logoutButton.layer.shadowOpacity = 0.1
        logoutButton.layer.masksToBounds = false
        logoutButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        logoutButton.addTarget(self, action: #selector(signOutTapped), for: .touchUpInside)
        containerView.addSubview(logoutButton)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -8),
            
            logoutButton.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            logoutButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 4),
            logoutButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -4),
            logoutButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    // MARK: - Helper Methods
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func signOutTapped() {
        let alert = UIAlertController(title: "Sign Out", message: "Are you sure you want to sign out?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        alert.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            do {
                try Auth.auth().signOut()
                UserDefaults.standard.set(false, forKey: "isUserLoggedIn") // Reset login state
                
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.showLoginScreen()
                }
            } catch {
                print("Error signing out: \(error.localizedDescription)")
                let errorAlert = UIAlertController(title: "Error", message: "Failed to sign out: \(error.localizedDescription)", preferredStyle: .alert)
                errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(errorAlert, animated: true)
            }
        })
        
        present(alert, animated: true)
    }
   
    private func handlePrivacyRowSelection(_ row: Int) {
        let urlString: String
        switch row {
        case 0:
            urlString = "https://note-share-web.vercel.app/privacy"
        case 1:
            urlString = "https://note-share-web.vercel.app/terms"
        default:
            return
        }

        if let url = URL(string: urlString) {
            let safariVC = SFSafariViewController(url: url)
            safariVC.modalPresentationStyle = .pageSheet  // Native modal presentation
            safariVC.preferredControlTintColor = .systemBlue  // Match app color theme
            present(safariVC, animated: true)
        }
    }

    
    // MARK: - Firebase Methods
    
    private func fetchUserData() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).getDocument { [weak self] (document, error) in
            guard let self = self else { return }
            
            if let document = document, document.exists {
                let data = document.data()
                self.userName = data?["name"] as? String ?? "No Name"
                self.userEmail = data?["email"] as? String ?? "No Email"
                self.userCourse = data?["course"] as? String ?? "No Course"
                self.userCollege = data?["college"] as? String ?? "No College"
                
                if let interests = data?["interests"] as? [String] {
                    self.selectedInterests = interests
                }
                
                // Fetch profile photo URL
                if let photoURL = data?["photoURL"] as? String, let url = URL(string: photoURL) {
                    self.loadImage(from: url)
                }
                
                self.tableView.reloadData()
            } else {
                print("Document does not exist")
            }
        }
    }
    
    private func saveUserInterests() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData([
            "interests": selectedInterests
        ]) { error in
            if let error = error {
                print("Error saving interests: \(error.localizedDescription)")
            } else {
                print("Interests saved successfully")
            }
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImageView.image = image
                }
            }
        }.resume()
    }
    
    @objc private func handlePhotoUpload() {
        // Only allow photo upload in edit mode
        guard isEditMode else { return }
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let image = info[.originalImage] as? UIImage {
            profileImageView.image = image
            uploadImageToFirebase(image: image)
        }
        dismiss(animated: true, completion: nil)
    }
    
    private func uploadImageToFirebase(image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.75),
              let user = Auth.auth().currentUser else {
            return
        }
        
        // Use a nested path: profile_images/{userId}/{fileName}
        let storageRef = Storage.storage().reference().child("profile_images/\(user.uid)/profile.jpg")
        
        // Show a loading indicator
        let loadingAlert = UIAlertController(title: nil, message: "Uploading image...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingAlert.view.addSubview(loadingIndicator)
        present(loadingAlert, animated: true, completion: nil)
        
        storageRef.putData(imageData, metadata: nil) { [weak self] metadata, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.dismiss(animated: true) {
                    if let error = error {
                        let alert = UIAlertController(title: "Error", message: "Failed to upload image: \(error.localizedDescription)", preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                        return
                    }
                    
                    storageRef.downloadURL { url, error in
                        if let error = error {
                            let alert = UIAlertController(title: "Error", message: "Failed to get image URL: \(error.localizedDescription)", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default))
                            self.present(alert, animated: true)
                            return
                        }
                        
                        if let downloadURL = url {
                            self.savePhotoURLToFirestore(downloadURL.absoluteString)
                        }
                    }
                }
            }
        }
    }
    
    private func savePhotoURLToFirestore(_ photoURL: String) {
        guard let user = Auth.auth().currentUser else {
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData(["photoURL": photoURL]) { error in
            if let error = error {
                print("Error saving photo URL: \(error.localizedDescription)")
                let alert = UIAlertController(title: "Error", message: "Failed to save photo URL: \(error.localizedDescription)", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                DispatchQueue.main.async {
                    self.present(alert, animated: true)
                }
            } else {
                print("Photo URL saved successfully")
            }
        }
    }
    
    @objc private func editButtonTapped() {
        isEditMode = !isEditMode
        
        // Update button title and style
        UIView.animate(withDuration: 0.3) {
            if self.isEditMode {
                self.editButton.setTitle("Done", for: .normal)
                self.editButton.setTitleColor(UIColor.systemBlue, for: .normal)
            } else {
                self.editButton.setTitle("Edit", for: .normal)
                self.editButton.setTitleColor(UIColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0), for: .normal)
                self.saveUserData()
                
                // Show save success feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
        
        // Reload table with animation for smooth transition
        tableView.reloadSections(IndexSet(integersIn: 0..<Section.allCases.count), with: .fade)
    }
    
    private func saveUserData() {
        // Find the name text field and get its value
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: Section.profile.rawValue)),
           let nameTextField = cell.contentView.subviews.first?.subviews.compactMap({ $0 as? UITextField }).first {
            if let newName = nameTextField.text, !newName.isEmpty {
                userName = newName
            }
        }
        
        // Education fields are not editable, so we don't need to save them
        
        // Save to Firebase
        updateUserDataInFirebase()
    }
    
    private func updateUserDataInFirebase() {
        guard let user = Auth.auth().currentUser else {
            print("No user is signed in.")
            return
        }
        
        // Show loading indicator
        let loadingIndicator = UIActivityIndicatorView(style: .medium)
        loadingIndicator.center = view.center
        loadingIndicator.startAnimating()
        view.addSubview(loadingIndicator)
        
        let db = Firestore.firestore()
        db.collection("users").document(user.uid).updateData([
            "name": userName
            // Education fields are not editable, so we don't update them
        ]) { [weak self] error in
            guard let self = self else { return }
            
            // Remove loading indicator
            loadingIndicator.removeFromSuperview()
            
            if let error = error {
                print("Error updating user data: \(error.localizedDescription)")
                // Show an error alert to the user
                let banner = NotificationBanner(title: "Update Failed", subtitle: "Could not update your profile. Please try again.", style: .danger)
                banner.show()
            } else {
                print("User data updated successfully")
                // Show a success indicator using subtle animation instead of alert
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
    
    // MARK: - Interest Management
    
    private func showInterestSelectionView() {
        let interestVC = UIViewController()
        interestVC.view.backgroundColor = .systemBackground
        interestVC.title = "Select Interests"
        
        // Set preferred content size for the popover
        interestVC.preferredContentSize = CGSize(width: 320, height: min(400, CGFloat(interests.count * 44 + 20)))
        
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "interestCell")
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 0)
        tableView.layer.cornerRadius = 10
        tableView.clipsToBounds = true
        tableView.isScrollEnabled = true
        
        interestVC.view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: interestVC.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: interestVC.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: interestVC.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: interestVC.view.bottomAnchor)
        ])
        
        // Set up the table view data source and delegate
        class InterestSelectionDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
            let allInterests: [String]
            var selectedInterests: [String]
            weak var delegate: InterestDropdownViewControllerDelegate?
            
            init(allInterests: [String], selectedInterests: [String], delegate: InterestDropdownViewControllerDelegate?) {
                self.allInterests = allInterests
                self.selectedInterests = selectedInterests
                self.delegate = delegate
            }
            
            func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
                return allInterests.count
            }
            
            func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
                let cell = tableView.dequeueReusableCell(withIdentifier: "interestCell", for: indexPath)
                let interest = allInterests[indexPath.row]
                
                // Configure cell appearance
                cell.textLabel?.text = interest
                cell.accessoryType = selectedInterests.contains(interest) ? .checkmark : .none
                
                return cell
            }
            
            func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
                tableView.deselectRow(at: indexPath, animated: true)
                
                let interest = allInterests[indexPath.row]
                
                if let index = selectedInterests.firstIndex(of: interest) {
                    // If already selected, deselect it
                    selectedInterests.remove(at: index)
                    tableView.cellForRow(at: indexPath)?.accessoryType = .none
                } else {
                    // If not selected, select it
                    selectedInterests.append(interest)
                    tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
                }
                
                // Notify delegate of changes
                delegate?.interestDropdownViewController(
                    InterestDropdownViewController(),
                    didSelectInterests: selectedInterests
                )
            }
        }
        
        let dataSource = InterestSelectionDataSource(
            allInterests: interests,
            selectedInterests: selectedInterests,
            delegate: self
        )
        
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        
        // Store the data source to prevent deallocation
        objc_setAssociatedObject(tableView, "dataSource", dataSource, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Configure as a popover
        interestVC.modalPresentationStyle = .popover
        
        if let popover = interestVC.popoverPresentationController {
            // Find the interests cell to position the popover
            if let interestsIndexPath = indexPathForInterestsSection(),
               let interestsCell = self.tableView.cellForRow(at: interestsIndexPath) {
                popover.sourceView = interestsCell
                popover.sourceRect = interestsCell.bounds
                popover.permittedArrowDirections = [.up, .down]
                popover.delegate = self
            }
        }
        
        // Use a navigation controller to have the title and done button
        let navController = UINavigationController(rootViewController: interestVC)
        navController.modalPresentationStyle = .popover
        
        if let popover = navController.popoverPresentationController {
            // Find the interests cell to position the popover
            if let interestsIndexPath = indexPathForInterestsSection() {
                let interestsCell = self.tableView.cellForRow(at: interestsIndexPath) ?? self.tableView
                popover.sourceView = interestsCell
                popover.sourceRect = interestsCell.bounds
                popover.permittedArrowDirections = [.up, .down]
                popover.delegate = self
            }
        }
        
        
        present(navController, animated: true)
    }
    
    private func indexPathForInterestsSection() -> IndexPath? {
        return IndexPath(row: 0, section: Section.interests.rawValue)
    }
    
    @objc private func dismissInterestSelection() {
        dismiss(animated: true)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension ProfileViewController: UIPopoverPresentationControllerDelegate {
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none // Force it to use popover even on iPhone
    }
    
    // Ensure the correct size on different devices
    func presentationController(_ controller: UIPresentationController, viewControllerForAdaptivePresentationStyle style: UIModalPresentationStyle) -> UIViewController? {
        // On iPhone, add a "Done" button
        if let navController = controller.presentedViewController as? UINavigationController {
            return navController
        }
        
        // If we don't have a navigation controller, wrap it in one
        if controller.presentedViewController != nil {
            let presented = controller.presentedViewController
            let navController = UINavigationController(rootViewController: presented)
            return navController
        }
        
        return controller.presentedViewController
    }
}

// MARK: - Interest Dropdown Delegate
extension ProfileViewController: InterestDropdownViewControllerDelegate {
    func interestDropdownViewController(_ viewController: InterestDropdownViewController, didSelectInterests interests: [String]) {
        self.selectedInterests = interests
        saveUserInterests()
        tableView.reloadSections(IndexSet(integer: Section.interests.rawValue), with: .automatic)
    }
}

// MARK: - Interest Dropdown View Controller

protocol InterestDropdownViewControllerDelegate: AnyObject {
    func interestDropdownViewController(_ viewController: InterestDropdownViewController, didSelectInterests interests: [String])
}

class InterestDropdownViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    private let tableView = UITableView(frame: .zero, style: .plain)
    var allInterests: [String] = []
    var selectedInterests: Set<String> = []
    weak var delegate: InterestDropdownViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Adjust preferred size based on actual content
        preferredContentSize = CGSize(
            width: 280,
            height: min(400, CGFloat(allInterests.count * 44 + 10)) // Just enough height for all interests
        )
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup table view with iOS native styling
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        tableView.layer.cornerRadius = 13
        tableView.clipsToBounds = true
        tableView.isScrollEnabled = true
        
        // Add subtle styling to match iOS native menus
        view.layer.cornerRadius = 13
        view.layer.masksToBounds = true
        
        // Add shadow and border for iOS 14+ menu look
        if #available(iOS 14.0, *) {
            view.layer.shadowColor = UIColor.black.cgColor
            view.layer.shadowOpacity = 0.2
            view.layer.shadowOffset = CGSize(width: 0, height: 2)
            view.layer.shadowRadius = 8
        }
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Table View Data Source
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allInterests.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let interest = allInterests[indexPath.row]
        
        // Configure cell to match iOS menu style
        cell.backgroundColor = .clear
        cell.textLabel?.text = interest
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.accessoryType = selectedInterests.contains(interest) ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let interest = allInterests[indexPath.row]
        
        if selectedInterests.contains(interest) {
            selectedInterests.remove(interest)
        } else {
            selectedInterests.insert(interest)
        }
        
        // Apply changes immediately
        delegate?.interestDropdownViewController(self, didSelectInterests: Array(selectedInterests))
        
        // Update the checkmark
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}

#Preview {
    ProfileViewController()
}

// MARK: - UITextFieldDelegate
extension ProfileViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        // Save changes as they are made for a more responsive experience
        switch textField.tag {
        case 1: // Name field
            if let newName = textField.text, !newName.isEmpty {
                userName = newName
            }
        // No more education field cases since they are not editable
        default:
            break
        }
    }
}

// Helper class for showing in-app banners
class NotificationBanner {
    private let bannerView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    enum BannerStyle {
        case success
        case danger
    }
    
    init(title: String, subtitle: String, style: BannerStyle) {
        // Configure banner appearance
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        bannerView.layer.cornerRadius = 10
        bannerView.clipsToBounds = true
        
        // Background color based on style
        switch style {
        case .success:
            bannerView.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.9)
        case .danger:
            bannerView.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        }
        
        // Configure labels
        titleLabel.text = title
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .white
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.numberOfLines = 2
        
        bannerView.addSubview(titleLabel)
        bannerView.addSubview(subtitleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: bannerView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: bannerView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: bannerView.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: bannerView.bottomAnchor, constant: -12)
        ])
    }
    
    func show() {
        guard let window = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else { return }
        
        window.addSubview(bannerView)
        
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: window.safeAreaLayoutGuide.topAnchor, constant: 8),
            bannerView.leadingAnchor.constraint(equalTo: window.leadingAnchor, constant: 16),
            bannerView.trailingAnchor.constraint(equalTo: window.trailingAnchor, constant: -16)
        ])
        
        // Start with banner off-screen
        bannerView.transform = CGAffineTransform(translationX: 0, y: -200)
        
        // Animate in
        UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.bannerView.transform = .identity
        }, completion: { _ in
            // Auto-dismiss after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                UIView.animate(withDuration: 0.5, animations: {
                    self.bannerView.transform = CGAffineTransform(translationX: 0, y: -200)
                }, completion: { _ in
                    self.bannerView.removeFromSuperview()
                })
            }
        })
    }
}

// MARK: - Interest Tag Collection View

// Cell for displaying interest tags
class InterestTagCell: UICollectionViewCell {
    let label = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // We need to separate the shadow and corner rendering
        contentView.layer.cornerRadius = 16
        contentView.clipsToBounds = true
        contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        
        // Add subtle border for depth
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        
        // Apply shadow to the cell (not the content view)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 1.5
        layer.shadowOpacity = 0.12
        layer.masksToBounds = false
        
        // Configure the label
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor.systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8)
        ])
    }
    
    // Reset the cell when it's reused
    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        contentView.layer.borderColor = UIColor.systemBlue.withAlphaComponent(0.25).cgColor
        label.textColor = UIColor.systemBlue
    }
}

// Extend the view controller to support collection view
extension ProfileViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // Check if this is the collection view within the profile or a separate one
        if let fullInterests = objc_getAssociatedObject(collectionView, "fullInterestsList") as? [String] {
            return fullInterests.count
        }
        
        return selectedInterests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "tagCell", for: indexPath) as! InterestTagCell
        
        // Get interest text based on the data source
        if let fullInterests = objc_getAssociatedObject(collectionView, "fullInterestsList") as? [String] {
            if indexPath.row < fullInterests.count {
                cell.label.text = fullInterests[indexPath.row]
            }
        } else if indexPath.row < selectedInterests.count {
            cell.label.text = selectedInterests[indexPath.row]
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        // Get the appropriate width for the cell based on text content
        var text = ""
        
        // Get interest text based on the data source
        if let fullInterests = objc_getAssociatedObject(collectionView, "fullInterestsList") as? [String] {
            if indexPath.row < fullInterests.count {
                text = fullInterests[indexPath.row]
            }
        } else if indexPath.row < selectedInterests.count {
            text = selectedInterests[indexPath.row]
        }
        
        // Calculate text width with some additional padding for better appearance
        let font = UIFont.systemFont(ofSize: 15, weight: .medium)
        let textWidth = text.size(withAttributes: [.font: font]).width
        
        // Add more generous padding for the content
        let cellWidth = textWidth + 36
        
        // Ensure minimum size and consistent height
        return CGSize(width: max(cellWidth, 60), height: 36)
    }
}



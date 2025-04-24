import UIKit

protocol InterestEditingViewControllerDelegate: AnyObject {
    func interestEditingViewController(_ viewController: InterestEditingViewController, didSelectInterests interests: [String])
}

class InterestEditingViewController: UIViewController {
    
    // MARK: - Properties
    
    var selectedInterests: [String] = []
    var allInterests: [String] = []
    weak var delegate: InterestEditingViewControllerDelegate?
    
    // MARK: - UI Components
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Choose your interests"
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Select all that apply to you"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let image = UIImage(systemName: "chevron.left")
        button.setImage(image, for: .normal)
        button.setTitle("Back", for: .normal)
        button.tintColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
        return button
    }()
    
    private let continueButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Continue", for: .normal)
        button.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 20
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsVerticalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.allowsMultipleSelection = true
        collectionView.register(InterestCell.self, forCellWithReuseIdentifier: "InterestCell")
        return collectionView
    }()
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(backButton)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(collectionView)
        view.addSubview(continueButton)
        
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            collectionView.bottomAnchor.constraint(equalTo: continueButton.topAnchor, constant: -24),
            
            continueButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            continueButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            continueButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            continueButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        continueButton.addTarget(self, action: #selector(continueButtonTapped), for: .touchUpInside)
    }
    
    private func setupCollectionView() {
        collectionView.delegate = self
        collectionView.dataSource = self
        
        // Calculate cell size based on screen width for a grid layout
        let layout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
        
        // Determine number of cells per row based on screen size
        let numberOfCellsPerRow: CGFloat = UIScreen.main.bounds.width > 375 ? 3 : 2
        let spacing: CGFloat = 16
        let availableWidth = view.bounds.width - (spacing * (numberOfCellsPerRow + 1))
        let cellWidth = availableWidth / numberOfCellsPerRow
        
        layout.itemSize = CGSize(width: cellWidth, height: cellWidth)
        layout.minimumLineSpacing = spacing
        layout.minimumInteritemSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
    }
    
    // MARK: - Actions
    
    @objc private func backButtonTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func continueButtonTapped() {
        delegate?.interestEditingViewController(self, didSelectInterests: selectedInterests)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Collection View Delegate & Data Source

extension InterestEditingViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return allInterests.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InterestCell", for: indexPath) as! InterestCell
        
        let interest = allInterests[indexPath.item]
        cell.configure(with: interest)
        
        // Pre-select cells for already selected interests
        if selectedInterests.contains(interest) {
            collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
            cell.isSelected = true
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let interest = allInterests[indexPath.item]
        
        // Add to selected interests with animation
        if let cell = collectionView.cellForItem(at: indexPath) as? InterestCell {
            // Spring animation for a more interactive feel
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: [], animations: {
                cell.setSelected(true, animated: true)
            })
        }
        
        if !selectedInterests.contains(interest) {
            selectedInterests.append(interest)
        }
        
        // Update continue button visibility based on selection
        updateContinueButton()
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        let interest = allInterests[indexPath.item]
        
        // Remove from selected interests with animation
        if let cell = collectionView.cellForItem(at: indexPath) as? InterestCell {
            UIView.animate(withDuration: 0.3, animations: {
                cell.setSelected(false, animated: true)
            })
        }
        
        if let index = selectedInterests.firstIndex(of: interest) {
            selectedInterests.remove(at: index)
        }
        
        // Update continue button visibility based on selection
        updateContinueButton()
    }
    
    private func updateContinueButton() {
        // Enable the continue button only if at least one interest is selected
        let hasSelectedInterests = !selectedInterests.isEmpty
        continueButton.isEnabled = hasSelectedInterests
        continueButton.alpha = hasSelectedInterests ? 1.0 : 0.5
    }
}

// MARK: - Interest Cell

class InterestCell: UICollectionViewCell {
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()
    
    override var isSelected: Bool {
        didSet {
            setSelected(isSelected, animated: false)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Make the container perfectly circular
        containerView.layer.cornerRadius = containerView.bounds.width / 2
    }
    
    private func setupCell() {
        contentView.addSubview(containerView)
        containerView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8)
        ])
        
        // Add subtle shadow
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 2
    }
    
    func configure(with interest: String) {
        titleLabel.text = interest
    }
    
    func setSelected(_ selected: Bool, animated: Bool) {
        let duration = animated ? 0.3 : 0.0
        
        if selected {
            UIView.animate(withDuration: duration) {
                self.containerView.backgroundColor = UIColor(red: 0.33, green: 0.49, blue: 1.0, alpha: 1.0)
                self.titleLabel.textColor = .white
                self.containerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                
                // Add subtle shadow for selected state
                self.layer.shadowOpacity = 0.3
                self.layer.shadowRadius = 5
            }
        } else {
            UIView.animate(withDuration: duration) {
                self.containerView.backgroundColor = .systemGray6
                self.titleLabel.textColor = .label
                self.containerView.transform = .identity
                
                // Reduce shadow for unselected state
                self.layer.shadowOpacity = 0.1
                self.layer.shadowRadius = 2
            }
        }
    }
}

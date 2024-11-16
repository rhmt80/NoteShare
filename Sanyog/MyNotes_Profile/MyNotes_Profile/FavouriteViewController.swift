import UIKit
class FavouriteViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout,UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    
    private let tableView: UITableView = {
            let tableView = UITableView()
            tableView.translatesAutoresizingMaskIntoConstraints = false
            return tableView
        }()
    

        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            setupUI()
            setupCollectionView()
            
            // Set up the table view
            view.addSubview(tableView)
            tableView.dataSource = self
            tableView.delegate = self
            
            // Register a cell class
            tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
            
//             Set up layout constraints
//            NSLayoutConstraint.activate([
//                tableView.topAnchor.constraint(equalTo: view.topAnchor),
//                tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
//                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
//                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
//            ])
            
            NSLayoutConstraint.activate([
                tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
                tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

                tableView.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
                tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        }
        
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 1 // Single row
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            cell.textLabel?.text = "Hello, this is a single row"
            return cell
        }
        
        // MARK: - UITableViewDelegate Methods
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return 50 // Customize row height
        }
    
    // Add the title label
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "My Notes"
        label.backgroundColor = .systemGray6
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Add the icons
    private let addNoteButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let moreOptionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .prominent
        searchBar.placeholder = "Search"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private let collectionsLabel: UILabel = {
        let label = UILabel()
        label.text = "Collections"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

//    private let collectionsButton: UIButton = {
//        let button = UIButton(type: .system)
//        button.setImage(UIImage(systemName: "chevron.right"), for: .normal)
//        button.translatesAutoresizingMaskIntoConstraints = false
//        return button
//    }()
    
    
    private let navigateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        button.addTarget(FavouriteViewController.self, action: #selector(navigateToDetailPage), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    
    private let separatorView: UIView = {
            let view = UIView()
            view.backgroundColor = .systemGray5
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()


    private let favouritesLabel: UILabel = {
        let label = UILabel()
        label.text = "Favourites"
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var favouritesCollectionView: UICollectionView?

    private let noteCards: [NoteCard] = [
        NoteCard(
            title: "iOS Development",
            author: "By Sanyog",
            description: "Take a deep dive into the world of iOS",
            coverImage: UIImage(named: "ios")
        ),
        NoteCard(
            title: "Physics Concepts",
            author: "By Raj",
            description: "Fundamental Physics Concepts Explained",
            coverImage: UIImage(named: "physics")
        ),
        NoteCard(
            title: "Chemistry Lab Report",
            author: "By Sai",
            description: "Detailed Lab Report on Chemical Reactions",
            coverImage: UIImage(named: "chem")
        ),
        NoteCard(
            title: "Trigonometry",
            author: "By Raj",
            description: "Advanced Trigonometry Practices and Types",
            coverImage: UIImage(named: "math1")
        ),
    
        NoteCard(
            title: "DM Notes",
            author: "By Sanyog",
            description: "Discrete Mathematics with the advance concepts",
            coverImage: UIImage(named: "math2")
        )
    ]

//    override func viewDidLoad() {
//        super.viewDidLoad()
//        setupUI()
//        setupCollectionView()
//    }

    private func setupUI() {
        view.backgroundColor = .systemGray6

        // Add the title label
        view.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])

        // Add the buttons
        view.addSubview(addNoteButton)
        view.addSubview(moreOptionsButton)
        NSLayoutConstraint.activate([
            addNoteButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            addNoteButton.trailingAnchor.constraint(equalTo: moreOptionsButton.leadingAnchor, constant: -16),

            moreOptionsButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            moreOptionsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        // Add Search Bar
        view.addSubview(searchBar)
        searchBar.delegate = self
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        // Add the buttons
//        view.addSubview(collectionsButton)
//        collectionsButton.addTarget(self, action: #selector(navigateToDetailPage), for: .touchUpInside)
//        
//        


        // Add Collections Section
        view.addSubview(collectionsLabel)
        view.addSubview(navigateButton)
//        collectionsLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(collectionsTapped)))
        NSLayoutConstraint.activate([
            collectionsLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            collectionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            navigateButton.centerYAnchor.constraint(equalTo: collectionsLabel.centerYAnchor),
            navigateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])
        
//        view.addSubview(navigateButton)
//        NSLayoutConstraint.activate([
//            navigateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
//            navigateButton.centerYAnchor.constraint(equalTo: view.centerYAnchor)
//        ])
        

        // Add Favourites Section Label
        view.addSubview(favouritesLabel)
        NSLayoutConstraint.activate([
            favouritesLabel.topAnchor.constraint(equalTo: collectionsLabel.bottomAnchor, constant: 40),
            favouritesLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16)
        ])
    }

    private func setupCollectionView() {
        // Collection View Layout
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 20

        // Collection View
        favouritesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        favouritesCollectionView?.delegate = self
        favouritesCollectionView?.dataSource = self
        favouritesCollectionView?.translatesAutoresizingMaskIntoConstraints = false
        favouritesCollectionView?.register(NoteCardCell.self, forCellWithReuseIdentifier: NoteCardCell.identifier)
        favouritesCollectionView?.backgroundColor = .clear
        guard let favouritesCollectionView = favouritesCollectionView else {
            return
        }
        view.addSubview(favouritesCollectionView)
        view.addSubview(navigateButton)
        NSLayoutConstraint.activate([
            favouritesCollectionView.topAnchor.constraint(equalTo: favouritesLabel.bottomAnchor, constant: 10),
            favouritesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            favouritesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            favouritesCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])
    }

    // Collection View Data Source
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return noteCards.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: NoteCardCell.identifier, for: indexPath) as! NoteCardCell
        let noteCard = noteCards[indexPath.item]
        cell.configure(with: noteCard)
        return cell
    }
  
    // Button Actions
    @objc private func addNoteTapped() {
        print("Add Note Tapped")
    }

    @objc private func organizeTapped() {
        print("Organize Tapped")
    }
    
//    @objc private func collectionsTapped() {
//        let collectionVC = CollectionViewController()
//        collectionVC.modalPresentationStyle = .fullScreen
//            present(collectionVC, animated: true)
//
//    }
    
    @objc private func navigateToDetailPage() {
        let detailVC = CollectionViewController()
        navigationController?.pushViewController(detailVC, animated: true)
    }

    


}

// Custom Collection View Cell for Note Card
class NoteCardCell: UICollectionViewCell {
    static let identifier = "NoteCardCell"

    private let coverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 3
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let favoriteIcon: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "heart.fill"))
        imageView.tintColor = .red
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOffset = CGSize(width: 3, height: 4)
        self.layer.shadowRadius = 6
        self.layer.shadowOpacity = 0.3
        self.layer.masksToBounds = false
        
        self.contentView.layer.masksToBounds = true
        self.layer.masksToBounds = false
        self.layer.cornerRadius = 12
        self.contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))

        contentView.addSubview(coverImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(favoriteIcon)
        

        NSLayoutConstraint.activate([
            // Larger cover image with full width
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            coverImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverImageView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9), // 90% of card width
            coverImageView.heightAnchor.constraint(equalTo: coverImageView.widthAnchor), // Make it square

            // Title below image
            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            // Favorite icon and author
            favoriteIcon.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            favoriteIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 20),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 20),

            authorLabel.centerYAnchor.constraint(equalTo: favoriteIcon.centerYAnchor),
            authorLabel.leadingAnchor.constraint(equalTo: favoriteIcon.trailingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            // Description at the bottom
            descriptionLabel.topAnchor.constraint(equalTo: favoriteIcon.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            descriptionLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with noteCard: NoteCard) {
        titleLabel.text = noteCard.title
        authorLabel.text = noteCard.author
        descriptionLabel.text = noteCard.description
        coverImageView.image = noteCard.coverImage
    }
}

// Update the collection view cell size in FavouriteViewController
extension FavouriteViewController {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width / 2) - 10
        return CGSize(width: width, height: 330) // Increased height to accommodate larger image
    }
}

struct NoteCard {
    let title: String
    let author: String
    let description: String
    let coverImage: UIImage?

    init(title: String, author: String, description: String, coverImage: UIImage?) {
        self.title = title
        self.author = author
        self.description = description
        self.coverImage = coverImage
    }
}

#Preview {
    FavouriteViewController()
}

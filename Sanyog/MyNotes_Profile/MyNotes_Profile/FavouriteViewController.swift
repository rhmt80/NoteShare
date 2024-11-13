//
//  FavouriteViewController.swift
//  MyNotes_Profile
//
//  Created by admin24 on 13/11/24.
//

import UIKit

class FavouriteViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UISearchBarDelegate {

    // Add the title label
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "My Notes"
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
        searchBar.placeholder = "Search"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()

    private let collectionsLabel: UILabel = {
        let label = UILabel()
        label.text = "Collections"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let collectionsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let separatorView: UIView = {
            let view = UIView()
            view.backgroundColor = .gray
            view.translatesAutoresizingMaskIntoConstraints = false
            return view
        }()


    private let favouritesLabel: UILabel = {
        let label = UILabel()
        label.text = "Favourites"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private var favouritesCollectionView: UICollectionView?

    private let noteCards: [NoteCard] = [
        NoteCard(
            title: "World War II",
            author: "By Sanyog",
            description: "World War II was a global conflict between two coalitions.",
            coverImage: UIImage(named: "history")
        ),
        NoteCard(
            title: "Trigonometry",
            author: "By Raj",
            description: "Advanced Trigonometry Practices and Types",
            coverImage: UIImage(named: "math")
        ),
        NoteCard(
            title: "DSA Notes",
            author: "By Sai",
            description: "Data Structure and Algorithms",
            coverImage: UIImage(named: "cs")
        ),
        NoteCard(
            title: "DM Notes",
            author: "By Sanyog",
            description: "Discrete Mathematics with the advance concepts",
            coverImage: UIImage(named: "math2")
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
        )
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }

    private func setupUI() {
        view.backgroundColor = .white

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

        // Add Collections Section
        view.addSubview(collectionsLabel)
        view.addSubview(collectionsButton)
        NSLayoutConstraint.activate([
            collectionsLabel.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 20),
            collectionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            collectionsButton.centerYAnchor.constraint(equalTo: collectionsLabel.centerYAnchor),
            collectionsButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

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

    // Collection View Delegate Flow Layout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: (collectionView.frame.width / 2) - 10, height: 220)
    }

    // Button Actions
    @objc private func addNoteTapped() {
        print("Add Note Tapped")
    }

    @objc private func organizeTapped() {
        print("Organize Tapped")
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
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let authorLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.numberOfLines = 2
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
        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true

        contentView.addSubview(coverImageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(authorLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(favoriteIcon)

        // Layout constraints
        NSLayoutConstraint.activate([
            coverImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            coverImageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            coverImageView.widthAnchor.constraint(equalToConstant: 80),
            coverImageView.heightAnchor.constraint(equalToConstant: 100),

            titleLabel.topAnchor.constraint(equalTo: coverImageView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),

            favoriteIcon.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            favoriteIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            favoriteIcon.widthAnchor.constraint(equalToConstant: 20),
            favoriteIcon.heightAnchor.constraint(equalToConstant: 20),

            authorLabel.centerYAnchor.constraint(equalTo: favoriteIcon.centerYAnchor),
            authorLabel.leadingAnchor.constraint(equalTo: favoriteIcon.trailingAnchor, constant: 5),

            descriptionLabel.topAnchor.constraint(equalTo: favoriteIcon.bottomAnchor, constant: 4),
            descriptionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            descriptionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with noteCard: NoteCard) {
        titleLabel.text = noteCard.title
        authorLabel.text = noteCard.author
        descriptionLabel.text = noteCard.description
        if let coverImage = noteCard.coverImage {
            coverImageView.image = coverImage
        } else {
            coverImageView.image = nil
        }
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

import UIKit
import SwiftUI
import Combine

enum Category: String, Codable, CaseIterable, Hashable {
    case work = "Work"
    case personal = "Personal"
    case ideas = "Ideas"
    case ai = "AI"
    case tasks = "Tasks"
    
    var color: UIColor {
        switch self {
        case .work: return .systemBlue
        case .personal: return .systemGreen
        case .ideas: return .systemPurple
        case .ai: return .systemOrange
        case .tasks: return .systemRed
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .ideas: return "lightbulb.fill"
        case .ai: return "brain.head.profile"
        case .tasks: return "checklist"
        }
    }
}

class NotesViewModel {
    @Published var notes: [AiNote] = []
    @Published var filteredNotes: [AiNote] = []
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadNotes()
        setupBindings()
    }
    
    private func setupBindings() {
        $notes
            .sink { [weak self] notes in
                self?.filteredNotes = notes
            }
            .store(in: &cancellables)
    }
    
    func loadNotes() {
        notes = [
            AiNote(title: "Project Planning", content: "Define project scope and timeline",
                  category: .work, tags: ["planning", "project"], isPinned: true),
            AiNote(title: "Timetable", content: "time and table",
                  category: .personal, tags: ["shopping"]),
            AiNote(title: "Feature Ideas", content: "New app features brainstorming",
                  category: .ideas, tags: ["product", "innovation"], aiEnhanced: true)
        ]
    }
    
    func addNote(_ note: AiNote) {
        notes.insert(note, at: 0)
    }
    
    func deleteNote(at indexPath: IndexPath) {
        notes.remove(at: indexPath.item)
    }
    
    func togglePin(for note: AiNote) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            var updatedNote = note
            updatedNote.isPinned.toggle()
            notes[index] = updatedNote
        }
    }
    
    func filterNotes(by category: Category?) {
        if let category = category {
            filteredNotes = notes.filter { $0.category == category }
        } else {
            filteredNotes = notes
        }
    }
    
    func searchNotes(with query: String) {
        if query.isEmpty {
            filteredNotes = notes
        } else {
            filteredNotes = notes.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.content.localizedCaseInsensitiveContains(query) ||
                $0.tags.contains(where: { $0.localizedCaseInsensitiveContains(query) })
            }
        }
    }
}

// MARK: - Custom Views
class CategoryButton: UIButton {
    var category: Category? {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        layer.cornerRadius = 15
        titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        
    }
    private func updateAppearance() {
        guard let category = category else { return }
        backgroundColor = category.color.withAlphaComponent(0.2)
        setTitleColor(category.color, for: .normal)
        setTitle(category.rawValue, for: .normal)
        
        let imageConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        setImage(UIImage(systemName: category.icon, withConfiguration: imageConfig)?
            .withTintColor(category.color, renderingMode: .alwaysOriginal), for: .normal)
        imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 0)
    }
}

class EnhancedNoteCell: UICollectionViewCell {
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let categoryView = CategoryButton()
    private let tagsStackView = UIStackView()
    private let pinnedImageView = UIImageView()
    private let aiEnhancedBadge = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Container setup
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .systemBackground
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.1
        containerView.layer.shadowRadius = 10
        containerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        contentView.addSubview(containerView)
        
        // Labels setup
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        contentLabel.font = .systemFont(ofSize: 14)
        contentLabel.numberOfLines = 3
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .secondaryLabel
        
        // Tags stack view setup
        tagsStackView.axis = .horizontal
        tagsStackView.spacing = 8
        tagsStackView.alignment = .center
        
        // Badges setup
        pinnedImageView.image = UIImage(systemName: "pin.fill")
        pinnedImageView.tintColor = .systemYellow
        pinnedImageView.isHidden = true
        
        aiEnhancedBadge.image = UIImage(systemName: "brain.head.profile")
        aiEnhancedBadge.tintColor = .systemPurple
        aiEnhancedBadge.isHidden = true
        
        [titleLabel, contentLabel, dateLabel, categoryView, tagsStackView,
         pinnedImageView, aiEnhancedBadge].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview($0)
        }
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            pinnedImageView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            pinnedImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            pinnedImageView.widthAnchor.constraint(equalToConstant: 20),
            pinnedImageView.heightAnchor.constraint(equalToConstant: 20),
            
            titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: pinnedImageView.leadingAnchor, constant: -8),
            
            categoryView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            categoryView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            
            contentLabel.topAnchor.constraint(equalTo: categoryView.bottomAnchor, constant: 8),
            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            contentLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            tagsStackView.topAnchor.constraint(equalTo: contentLabel.bottomAnchor, constant: 8),
            tagsStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            tagsStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            dateLabel.topAnchor.constraint(equalTo: tagsStackView.bottomAnchor, constant: 8),
            dateLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            dateLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            
            aiEnhancedBadge.centerYAnchor.constraint(equalTo: dateLabel.centerYAnchor),
            aiEnhancedBadge.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            aiEnhancedBadge.widthAnchor.constraint(equalToConstant: 20),
            aiEnhancedBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with note: AiNote) {
        titleLabel.text = note.title
        contentLabel.text = note.content
        categoryView.category = note.category
        dateLabel.text = DateFormatter.localizedString(from: note.date, dateStyle: .medium, timeStyle: .short)
        pinnedImageView.isHidden = !note.isPinned
        aiEnhancedBadge.isHidden = !note.aiEnhanced
        
        tagsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        note.tags.forEach { tag in
            let tagLabel = UILabel()
            tagLabel.text = "#\(tag)"
            tagLabel.font = .systemFont(ofSize: 12)
            tagLabel.textColor = .secondaryLabel
            tagsStackView.addArrangedSubview(tagLabel)
        }
    }
}

// MARK: - Main View Controller
protocol NoteDetailViewControllerDelegate: AnyObject {
    func noteDetailViewController(_ controller: NoteDetailViewController, didUpdate note: AiNote)
}

class AIAssistantViewController: UIViewController {
    // MARK: - Properties
    private let viewModel = NotesViewModel()
    private var cancellables = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<Int, AiNote>!
    
    // MARK: - UI Elements
    private lazy var collectionView: UICollectionView = {
        let layout = createCompositionalLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemGroupedBackground
        cv.delegate = self
        cv.register(EnhancedNoteCell.self, forCellWithReuseIdentifier: "NoteCell")
        return cv
    }()
    
    private lazy var searchController: UISearchController = {
        let sc = UISearchController(searchResultsController: nil)
        sc.searchResultsUpdater = self
        sc.obscuresBackgroundDuringPresentation = false
        sc.searchBar.placeholder = "Search notes..."
        return sc
    }()
    
    private lazy var categoryFilterView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        return sv
    }()
    
    private lazy var filterStackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        return sv
    }()
    
    private lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let image = UIImage(systemName: "plus.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        return button
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
        setupNavigationBar()
        setupDataSource()
    }
    
    // MARK: - Setup Methods
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        [categoryFilterView, collectionView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        
        categoryFilterView.addSubview(filterStackView)
        filterStackView.translatesAutoresizingMaskIntoConstraints = false
        
        setupFilterButtons()
        setupConstraints()
    }
    
    private func setupNavigationBar() {
            navigationItem.title = "AI Notes"
            navigationItem.searchController = searchController
            navigationItem.rightBarButtonItem = UIBarButtonItem(customView: addButton)
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        
        private func setupFilterButtons() {
            let allButton = CategoryButton(frame: .zero)
            allButton.setTitle("All", for: .normal)
            allButton.backgroundColor = .systemGray5
            allButton.setTitleColor(.label, for: .normal)
            allButton.tag = -1
            allButton.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
            filterStackView.addArrangedSubview(allButton)
            
            Category.allCases.forEach { category in
                let button = CategoryButton(frame: .zero)
                button.category = category
                button.tag = Category.allCases.firstIndex(of: category) ?? 0
                button.addTarget(self, action: #selector(filterButtonTapped(_:)), for: .touchUpInside)
                filterStackView.addArrangedSubview(button)
            }
        }
        
        private func setupConstraints() {
            NSLayoutConstraint.activate([
                categoryFilterView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                categoryFilterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                categoryFilterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                categoryFilterView.heightAnchor.constraint(equalToConstant: 50),
                
                filterStackView.topAnchor.constraint(equalTo: categoryFilterView.topAnchor, constant: 8),
                filterStackView.leadingAnchor.constraint(equalTo: categoryFilterView.leadingAnchor, constant: 16),
                filterStackView.trailingAnchor.constraint(equalTo: categoryFilterView.trailingAnchor, constant: -16),
                filterStackView.bottomAnchor.constraint(equalTo: categoryFilterView.bottomAnchor, constant: -8),
                
                collectionView.topAnchor.constraint(equalTo: categoryFilterView.bottomAnchor),
                collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        
        private func setupBindings() {
            viewModel.$filteredNotes
                .receive(on: DispatchQueue.main)
                .sink { [weak self] notes in
                    self?.updateDataSource(with: notes)
                }
                .store(in: &cancellables)
        }
        
        private func setupDataSource() {
            dataSource = UICollectionViewDiffableDataSource<Int, AiNote>(
                collectionView: collectionView
            ) { [weak self] (collectionView, indexPath, note) -> UICollectionViewCell? in
                guard let cell = collectionView.dequeueReusableCell(
                    withReuseIdentifier: "NoteCell",
                    for: indexPath
                ) as? EnhancedNoteCell else {
                    return nil
                }
                cell.configure(with: note)
                return cell
            }
            
            updateDataSource(with: viewModel.notes)
        }
        
        private func createCompositionalLayout() -> UICollectionViewLayout {
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(200)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .estimated(200)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 8
            section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
            
            return UICollectionViewCompositionalLayout(section: section)
        }
        
        private func updateDataSource(with notes: [AiNote]) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, AiNote>()
            snapshot.appendSections([0])
            snapshot.appendItems(notes)
            dataSource.apply(snapshot, animatingDifferences: true)
        }
        
        // MARK: - Actions
        @objc private func addButtonTapped() {
            let detailVC = NoteDetailViewController()
            detailVC.delegate = self
            let navController = UINavigationController(rootViewController: detailVC)
            present(navController, animated: true)
        }
        
        @objc private func filterButtonTapped(_ sender: UIButton) {
            if sender.tag == -1 {
                viewModel.filterNotes(by: nil)
            } else {
                let category = Category.allCases[sender.tag]
                viewModel.filterNotes(by: category)
            }
        }
    }

    // MARK: - UICollectionViewDelegate
    extension AIAssistantViewController: UICollectionViewDelegate {
        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let note = dataSource.itemIdentifier(for: indexPath) else { return }
            let detailVC = NoteDetailViewController(note: note)
            detailVC.delegate = self
            let navController = UINavigationController(rootViewController: detailVC)
            present(navController, animated: true)
        }
    }

    // MARK: - UISearchResultsUpdating
    extension AIAssistantViewController: UISearchResultsUpdating {
        func updateSearchResults(for searchController: UISearchController) {
            guard let query = searchController.searchBar.text else { return }
            viewModel.searchNotes(with: query)
        }
    }

    // MARK: - NoteDetailViewControllerDelegate
    extension AIAssistantViewController: NoteDetailViewControllerDelegate {
        func noteDetailViewController(_ controller: NoteDetailViewController, didUpdate note: AiNote) {
            if let index = viewModel.notes.firstIndex(where: { $0.id == note.id }) {
                viewModel.notes[index] = note
            } else {
                viewModel.addNote(note)
            }
            controller.dismiss(animated: true)
        }
    }

class NoteDetailViewController: UIViewController {
    weak var delegate: NoteDetailViewControllerDelegate?
    private var note: AiNote?
    
    private lazy var titleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Title"
        tf.font = .systemFont(ofSize: 20, weight: .bold)
        return tf
    }()
    
    private lazy var contentTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        return tv
    }()
    
    private lazy var categorySegmentedControl: UISegmentedControl = {
        let items = Category.allCases.map { $0.rawValue }
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        return sc
    }()
    
    init(note: AiNote? = nil) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        if let note = note {
            configureWithNote(note)
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        let stackView = UIStackView(arrangedSubviews: [
            titleTextField,
            categorySegmentedControl,
            contentTextView
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            contentTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }
    
    private func setupNavigationBar() {
        title = note == nil ? "New Note" : "Edit Note"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveButtonTapped)
        )
    }
    
    private func configureWithNote(_ note: AiNote) {
        titleTextField.text = note.title
        contentTextView.text = note.content
        if let index = Category.allCases.firstIndex(of: note.category) {
            categorySegmentedControl.selectedSegmentIndex = index
        }
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveButtonTapped() {
        guard let title = titleTextField.text, !title.isEmpty,
              let content = contentTextView.text, !content.isEmpty else {
            // Show alert for empty fields
            return
        }
        
        let category = Category.allCases[categorySegmentedControl.selectedSegmentIndex]
        
        if var existingNote = note {
            existingNote.title = title
            existingNote.content = content
            existingNote.category = category
            delegate?.noteDetailViewController(self, didUpdate: existingNote)
        } else {
            let newNote = AiNote(
                title: title,
                content: content,
                category: category
            )
            delegate?.noteDetailViewController(self, didUpdate: newNote)
        }
    }
}


#Preview{
    AIAssistantViewController()
}

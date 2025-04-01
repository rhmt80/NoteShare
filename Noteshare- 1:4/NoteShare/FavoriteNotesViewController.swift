import Foundation
import UIKit

class FavoriteNotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    
    private var groupedNotes: [String: [SavedFireNote]] = [:]
    private var sectionTitles: [String] = []
    private var filteredNotes: [String: [SavedFireNote]] = [:]
    private var filteredSectionTitles: [String] = []
    private var subjectIcons: [String: UIImage] = [:]
    private var subjectColors: [String: UIColor] = [:]

    private let iconSet = ["book", "pencil", "doc.text", "folder", "globe", "brain.head.profile"]
    private let colorSet: [UIColor] = [
        .systemBlue, .systemGreen, .systemPurple,
        .systemOrange, .systemPink, .systemTeal
    ]

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(NoteSubjectCell1.self, forCellReuseIdentifier: NoteSubjectCell1.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionFooterHeight = 8
        tableView.sectionHeaderHeight = 8
        return tableView
    }()
    
    private let searchController: UISearchController = {
        let search = UISearchController(searchResultsController: nil)
        search.obscuresBackgroundDuringPresentation = false
        search.searchBar.placeholder = "Search by Subject Code or Name"
        return search
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Favorite Notes"
        
        setupUI()
        setupSearchController()
        
        tableView.dataSource = self
        tableView.delegate = self
    }
    
    private func setupUI() {
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSearchController() {
        navigationItem.searchController = searchController
        searchController.searchResultsUpdater = self
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    func configure(with notes: [SavedFireNote]) {
        groupedNotes = Dictionary(grouping: notes) { $0.subjectCode ?? "Uncategorized" }
        sectionTitles = Array(groupedNotes.keys).sorted()
        
        for subject in sectionTitles {
            if subjectIcons[subject] == nil {
                let randomIconName = iconSet.randomElement() ?? "folder"
                subjectIcons[subject] = UIImage(systemName: randomIconName)
            }
            if subjectColors[subject] == nil {
                subjectColors[subject] = colorSet.randomElement() ?? .systemBlue
            }
        }

        filteredNotes = groupedNotes
        filteredSectionTitles = sectionTitles
        tableView.reloadData()
    }
    
    // MARK: - Search Filtering
    func updateSearchResults(for searchController: UISearchController) {
        guard let query = searchController.searchBar.text?.lowercased(), !query.isEmpty else {
            filteredNotes = groupedNotes
            filteredSectionTitles = sectionTitles
            tableView.reloadData()
            return
        }
        
        filteredNotes = groupedNotes.filter { (key, notes) in
            let subjectCodeMatches = key.lowercased().contains(query)
            let subjectNameMatches = notes.contains { $0.subjectName?.lowercased().contains(query) ?? false }
            return subjectCodeMatches || subjectNameMatches
        }
        
        filteredSectionTitles = Array(filteredNotes.keys).sorted()
        tableView.reloadData()
    }
    
    // MARK: - UITableView Methods
    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredSectionTitles.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteSubjectCell1.identifier, for: indexPath) as? NoteSubjectCell1 else {
            return UITableViewCell()
        }
        
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredNotes[subjectCode] ?? []
        let subjectName = notes.first?.subjectName ?? "Unknown Subject"
        let subjectColor = subjectColors[subjectCode] ?? .systemBlue
        
        cell.configure(
            title: subjectName,
            subtitle: subjectCode,
            icon: subjectIcons[subjectCode],
            backgroundColor: subjectColor.withAlphaComponent(0.1),
            chevronColor: subjectColor // Added to match chevron color
        )
        // Removed cell.accessoryType since we're using custom chevron
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subjectCode = filteredSectionTitles[indexPath.section]
        let savedNotes = filteredNotes[subjectCode] ?? []

//        let fireNotes: [FireNote] = savedNotes.map { savedNote in
//            FireNote(
//                id: savedNote.id,
//                title: savedNote.title,
//                description: "",
//                author: savedNote.author,
//                coverImage: savedNote.coverImage,
//                pdfUrl: savedNote.pdfUrl ?? "",
//                dateAdded: savedNote.dateAdded,
//                pageCount: savedNote.pageCount,
//                fileSize: savedNote.fileSize,
//                isFavorite: savedNote.isFavorite,
//                category: "",
//                subjectCode: savedNote.subjectCode ?? "Uncategorized",
//                subjectName: savedNote.subjectName ?? "Unknown Subject"
//            )
//        }
        
        let subjectNotesVC = UploadedSubjectNotesViewController(subjectCode: subjectCode, notes: savedNotes)
        navigationController?.pushViewController(subjectNotesVC, animated: true)
    }
}

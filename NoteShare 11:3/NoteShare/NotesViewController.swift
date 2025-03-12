import UIKit

class NotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private var groupedNotes: [String: [FireNote]] = [:]
    private var sectionTitles: [String] = []
    private var subjectIcons: [String: UIImage] = [:]
    
    private var filteredGroupedNotes: [String: [FireNote]] = [:]
    private var filteredSectionTitles: [String] = []
    
    private let iconSet = ["book", "pencil", "doc.text", "folder", "globe", "brain.head.profile"] // SF Symbols
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search by Subject Code or Name"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(NoteSubjectCell.self, forCellReuseIdentifier: NoteSubjectCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false // Allow table view interactions
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }


    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        searchBar.delegate = self
        tableView.dataSource = self
        tableView.delegate = self

        // Spacing changes
        tableView.sectionHeaderHeight = 4 // You can adjust this value as needed
        tableView.sectionFooterHeight = 4 // You can adjust this value as needed

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    func configure(with collegeNotes: [String: [FireNote]]) {
        self.groupedNotes = collegeNotes
        self.sectionTitles = Array(collegeNotes.keys).sorted()
        
        // Ensure filtered data is also updated
        self.filteredGroupedNotes = groupedNotes
        self.filteredSectionTitles = sectionTitles

        // Assign random icons to subjects if not already assigned
        for subject in sectionTitles {
            if subjectIcons[subject] == nil {
                let randomIconName = iconSet.randomElement() ?? "folder"
                subjectIcons[subject] = UIImage(systemName: randomIconName)
            }
        }
        
        self.tableView.reloadData()
    }


    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1 // Each subject row represents the subject code
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteSubjectCell.identifier, for: indexPath) as? NoteSubjectCell else {
            return UITableViewCell()
        }
        
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredGroupedNotes[subjectCode] ?? []
        let subjectName = notes.first?.subjectName ?? "Unknown Subject"

        cell.configure(title: subjectName, subtitle: subjectCode, icon: subjectIcons[subjectCode])
        cell.accessoryType = .disclosureIndicator // Show arrow
        return cell
    }
   
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100 // Restore original height
    }


    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredSectionTitles.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredGroupedNotes[subjectCode] ?? []
        let subjectNotesVC = SubjectNotesViewController(subjectCode: subjectCode, notes: notes)
        navigationController?.pushViewController(subjectNotesVC, animated: true)
    }

    // MARK: - Search Filtering
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredGroupedNotes = groupedNotes
            filteredSectionTitles = sectionTitles
        } else {
            filteredGroupedNotes = groupedNotes.filter { (subjectCode, notes) in
                let subjectName = notes.first?.subjectName.lowercased() ?? ""
                return subjectCode.lowercased().contains(searchText.lowercased()) ||
                       subjectName.contains(searchText.lowercased())
            }
            filteredSectionTitles = Array(filteredGroupedNotes.keys).sorted()
        }
        tableView.reloadData()
    }
}

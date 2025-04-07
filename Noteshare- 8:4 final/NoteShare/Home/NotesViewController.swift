import UIKit

class NotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private var groupedNotes: [String: [FireNote]] = [:]
    private var sectionTitles: [String] = []
    private var subjectIcons: [String: UIImage] = [:]
    private var subjectColors: [String: UIColor] = [:]
    
    private var filteredGroupedNotes: [String: [FireNote]] = [:]
    private var filteredSectionTitles: [String] = []
    
    private var visitedSubjects: Set<String> = []
    
    private let iconSet = ["book", "pencil", "doc.text", "folder", "globe", "brain.head.profile"]
    private let colorSet: [UIColor] = [
        .systemBlue ]
//        .systemGreen, .systemPurple,
//        .systemOrange, .systemPink, .systemTeal
    
    
    private let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search by Subject Code or Name"
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(NoteSubjectCell1.self, forCellReuseIdentifier: NoteSubjectCell1.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionHeaderHeight = 8
        tableView.sectionFooterHeight = 8
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
        
        loadVisitedSubjects()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        tableView.reloadData()
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    // MARK: - Visited Subjects Tracking
    
    private func loadVisitedSubjects() {
        guard let userId = FirebaseService.shared.currentUserId else { return }
        if let visitedArray = UserDefaults.standard.array(forKey: "visitedSubjects_\(userId)") as? [String] {
            visitedSubjects = Set(visitedArray)
        }
    }
    
    private func saveVisitedSubjects() {
        guard let userId = FirebaseService.shared.currentUserId else { return }
        UserDefaults.standard.set(Array(visitedSubjects), forKey: "visitedSubjects_\(userId)")
    }

    private func setupUI() {
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        searchBar.delegate = self
        self.title = "Notes"
        tableView.dataSource = self
        tableView.delegate = self

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
        
        self.filteredGroupedNotes = groupedNotes
        self.filteredSectionTitles = sectionTitles

        for subject in sectionTitles {
            if subjectIcons[subject] == nil {
                let randomIconName = iconSet.randomElement() ?? "folder"
                subjectIcons[subject] = UIImage(systemName: randomIconName)
            }
            if subjectColors[subject] == nil {
                subjectColors[subject] = colorSet.randomElement() ?? .systemBlue
            }
        }
        
        self.tableView.reloadData()
    }

    // MARK: - UITableView Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteSubjectCell1.identifier, for: indexPath) as? NoteSubjectCell1 else {
            return UITableViewCell()
        }
        
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredGroupedNotes[subjectCode] ?? []
        let subjectName = notes.first?.subjectName ?? "Unknown Subject"
        let subjectColor = subjectColors[subjectCode] ?? .systemBlue

        cell.configure(
            title: subjectName,
            subtitle: subjectCode,
            icon: subjectIcons[subjectCode],
            backgroundColor: subjectColor.withAlphaComponent(0.1),
            chevronColor: subjectColor // Match chevron color to subject color
        )
        
        return cell
    }
   
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return filteredSectionTitles.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredGroupedNotes[subjectCode] ?? []
        
        visitedSubjects.insert(subjectCode)
        saveVisitedSubjects()
        
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

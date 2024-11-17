// created by Sayong Dani
import UIKit

class CollectionViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    // Properties for search
    private var filteredItems: [String] = []
    private var isSearching: Bool = false
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Collection"
        label.font = .systemFont(ofSize: 32, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search"
        searchBar.searchBarStyle = .minimal // This gives the clean look
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        return searchBar
    }()
    
    let tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()
    
    // Data for table view
    let items = ["Saved", "Subjects", "Favourites", "Recents"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Add subviews
        view.addSubview(titleLabel)
        view.addSubview(searchBar)
        view.addSubview(tableView)
        
        // Setup elements
        setupTableView()
        setupSearchBar()
        
        // Initialize filtered items
        filteredItems = items
        
        // Setup layout constraints
        setupLayout()
    }
    
    // MARK: - Setup Methods
    
    func setupSearchBar() {
        searchBar.delegate = self
    }
    
    func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    func setupLayout() {
        NSLayoutConstraint.activate([
    
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -8),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            
            // Search Bar
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8), // Reduced from 16 to 8
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Table View
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredItems.count : items.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        cell.textLabel?.text = isSearching ? filteredItems[indexPath.row] : items[indexPath.row]
        cell.accessoryType = .disclosureIndicator // Adds arrow on the right
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let selectedItem = isSearching ? filteredItems[indexPath.row] : items[indexPath.row]
        
        if selectedItem == "Saved" {
            let profileVC = CollectionSavedViewController()
            navigationController?.pushViewController(profileVC, animated: true)
        }
        
        if selectedItem == "Subjects" {
            let profileVC = CollectionSubjectViewController()
            navigationController?.pushViewController(profileVC, animated: true)
        }
        
        if selectedItem == "Favourites" {
            let profileVC = CollectionFavViewController()
            navigationController?.pushViewController(profileVC, animated: true)
        }
        
        if selectedItem == "Recents" {
            let profileVC = CollectionRecentViewController()
            navigationController?.pushViewController(profileVC, animated: true)
        }
    }
    
    // MARK: - SearchBar Delegate Methods
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredItems = items
            isSearching = false
            searchBar.resignFirstResponder()
        } else {
            filteredItems = items.filter { $0.lowercased().contains(searchText.lowercased()) }
            isSearching = true
        }
        tableView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredItems = items
        isSearching = false
        searchBar.resignFirstResponder()
        tableView.reloadData()
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
    }
}

#Preview {
    CollectionViewController()
}


//
//  FavoriteNotesViewController.swift
//  NoteShare
//
//  Created by admin40 on 19/03/25.
//

import Foundation
import UIKit

class FavoriteNotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    
    private var groupedNotes: [String: [SavedFireNote]] = [:]
    private var sectionTitles: [String] = []
    private var filteredNotes: [String: [SavedFireNote]] = [:]
    private var filteredSectionTitles: [String] = []
    private var subjectIcons: [String: UIImage] = [:]

    private let iconSet = ["book", "pencil", "doc.text", "folder", "globe", "brain.head.profile"]

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.register(NoteSubjectCell.self, forCellReuseIdentifier: NoteSubjectCell.identifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
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
        // Ensure the search bar is always visible
        navigationItem.hidesSearchBarWhenScrolling = false
    }
    
    func configure(with notes: [SavedFireNote]) {
        groupedNotes = Dictionary(grouping: notes) { $0.subjectCode ?? "Uncategorized" }
        sectionTitles = Array(groupedNotes.keys).sorted()
        
        // Assign random icons to subjects
        for subject in sectionTitles {
            if subjectIcons[subject] == nil {
                let randomIconName = iconSet.randomElement() ?? "folder"
                subjectIcons[subject] = UIImage(systemName: randomIconName)
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
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteSubjectCell.identifier, for: indexPath) as? NoteSubjectCell else {
            return UITableViewCell()
        }
        
        let subjectCode = filteredSectionTitles[indexPath.section]
        let notes = filteredNotes[subjectCode] ?? []
        let subjectName = notes.first?.subjectName ?? "Unknown Subject"
        
        cell.configure(title: subjectName, subtitle: subjectCode, icon: subjectIcons[subjectCode])
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let subjectCode = filteredSectionTitles[indexPath.section]
        let savedNotes = filteredNotes[subjectCode] ?? []

        // Convert SavedFireNote array to FireNote array
        let fireNotes: [FireNote] = savedNotes.map { savedNote in
            FireNote(
                id: savedNote.id,
                title: savedNote.title,
                description: savedNote.description,
                author: savedNote.author,
                coverImage: savedNote.coverImage,
                pdfUrl: savedNote.pdfUrl,
                dateAdded: savedNote.dateAdded,
                pageCount: savedNote.pageCount,
                fileSize: savedNote.fileSize,
                isFavorite: savedNote.isFavorite,
                category: savedNote.description, // Mapping description to category
                subjectCode: savedNote.subjectCode ?? "Uncategorized",
                subjectName: savedNote.subjectName ?? "Unknown Subject"
            )
        }
        
        let subjectNotesVC = SubjectNotesViewController(subjectCode: subjectCode, notes: fireNotes)
        navigationController?.pushViewController(subjectNotesVC, animated: true)
    }
}

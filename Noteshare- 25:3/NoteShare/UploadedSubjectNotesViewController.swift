//
//  UploadedSubjectNotesViewController.swift
//  NoteShare
//
//  Created by admin40 on 19/03/25.
//

import Foundation
import UIKit
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class UploadedSubjectNotesViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    private let subjectCode: String
    private var notes: [SavedFireNote]
    
    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 14, left: 14, bottom: 20, right: 14)
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(NoteCollectionViewCell1.self, forCellWithReuseIdentifier: "UploadedNoteCell")
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        return collectionView
    }()
    
    init(subjectCode: String, notes: [SavedFireNote]) {
        self.subjectCode = subjectCode
        self.notes = notes
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = subjectCode
        view.backgroundColor = .systemBackground
        setupCollectionView()
    }
    
    private func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.dataSource = self
        collectionView.delegate = self
        
        // Update layout to ensure proper left alignment and row-wise arrangement
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.minimumInteritemSpacing = 12
            flowLayout.minimumLineSpacing = 12
            
            // Update insets to ensure proper left alignment
            let sideInset: CGFloat = 14
            flowLayout.sectionInset = UIEdgeInsets(top: 14, left: sideInset, bottom: 20, right: sideInset)
            
            // Ensure items start from left
            flowLayout.itemSize = calculateItemSize()
            
            // Force left-to-right, top-to-bottom layout
            flowLayout.scrollDirection = .vertical
        }
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // Extract item size calculation to a separate method for reuse
    private func calculateItemSize() -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let sideInset: CGFloat = 14
        let minimumSpacing: CGFloat = 12
        
        // Calculate width for exactly 2 items per row with equal spacing
        let availableWidth = screenWidth - (sideInset * 2) - minimumSpacing
        let cellWidth = floor(availableWidth / 2)
        let cellHeight = cellWidth * 1.3
        
        return CGSize(width: cellWidth, height: cellHeight)
    }
    
    // UICollectionViewDataSource
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return notes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UploadedNoteCell", for: indexPath) as! NoteCollectionViewCell1
        let note = notes[indexPath.row]
        cell.configure(with: note)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.5
        cell.addGestureRecognizer(longPress)
        cell.noteId = note.id
        
        return cell
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began,
              let cell = gesture.view as? NoteCollectionViewCell1,
              let noteId = cell.noteId else { return }
        
        showEditNoteAlert(for: noteId)
    }
    
    private func showEditNoteAlert(for noteId: String) {
        let note = notes.first { $0.id == noteId }
        guard let note = note else { return }
        
        let alert = UIAlertController(title: "Edit Note", message: "Update or delete note", preferredStyle: .actionSheet)
        
        // Edit Action
        alert.addAction(UIAlertAction(title: "Edit", style: .default) { [weak self] _ in
            self?.showEditDetailsAlert(for: noteId, currentNote: note)
        })
        
        // Delete Action
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.deleteNote(noteId: noteId)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
    
    private func showEditDetailsAlert(for noteId: String, currentNote: SavedFireNote) {
        let alert = UIAlertController(title: "Edit Note", message: "Update note details", preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.text = currentNote.title
            textField.placeholder = "Title"
        }
        alert.addTextField { textField in
            textField.text = currentNote.subjectName
            textField.placeholder = "Subject Name"
        }
        alert.addTextField { textField in
            textField.text = currentNote.subjectCode
            textField.placeholder = "Subject Code"
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let titleField = alert.textFields?[0].text, !titleField.isEmpty,
                  let subjectNameField = alert.textFields?[1].text, !subjectNameField.isEmpty,
                  let subjectCodeField = alert.textFields?[2].text, !subjectCodeField.isEmpty else {
                self?.showAlert(title: "Error", message: "All fields must be filled.")
                return
            }
            self?.updateNoteDetails(noteId: noteId, title: titleField, subjectName: subjectNameField, subjectCode: subjectCodeField)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func deleteNote(noteId: String) {
        let db = Firestore.firestore()
        let storage = Storage.storage()
        
        guard let userId = Auth.auth().currentUser?.uid else {
            showAlert(title: "Error", message: "User not authenticated")
            return
        }
        
        guard let note = notes.first(where: { $0.id == noteId }) else {
            showAlert(title: "Error", message: "Note not found")
            return
        }
        
        db.collection("pdfs").document(noteId).delete { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                self.showAlert(title: "Error", message: "Failed to delete note: \(error.localizedDescription)")
                return
            }
            
            // Delete from favorites if it exists
            db.collection("userFavorites").document(userId)
                .collection("favorites").document(noteId).delete { error in
                    if let error = error {
                        print("Error deleting from favorites: \(error.localizedDescription)")
                    }
                }
            
            // Delete from Storage
            storage.reference(forURL: note.pdfUrl ?? "").delete { error in
                if let error = error {
                    self.showAlert(title: "Warning", message: "Note deleted from database but failed to delete file: \(error.localizedDescription)")
                }
                self.fetchNotes()
            }
        }
    }
    
    private func updateNoteDetails(noteId: String, title: String, subjectName: String, subjectCode: String) {
        let db = Firestore.firestore()
        db.collection("pdfs").document(noteId).updateData([
            "fileName": title,
            "subjectName": subjectName,
            "subjectCode": subjectCode
        ]) { [weak self] error in
            if let error = error {
                self?.showAlert(title: "Error", message: "Failed to update note: \(error.localizedDescription)")
            } else {
                self?.fetchNotes()
            }
        }
    }

    private func fetchNotes() {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        FirebaseService1.shared.observeNotes(userId: userID) { [weak self] allNotes in
            guard let self = self else { return }
            self.notes = allNotes.filter { $0.subjectCode == self.subjectCode }
            self.collectionView.reloadData()
        }
    }

    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }

    @objc private func editModeTapped() {
        
        // Optional: Add additional edit mode functionality if needed
    }
    
    // UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        
        // Show loading view
        self.showLoadingView {
            // Check if we already have this PDF in cache
            if let cachedPDFPath = PDFCache.shared.getCachedPDFPath(for: note.id) {
                self.hideLoadingView {
                    // Open the PDF viewer with the cached path
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                }
                return
            }
            
            // Also check URL-based cache
            if let pdfUrl = note.pdfUrl, !pdfUrl.isEmpty,
               let url = URL(string: pdfUrl),
               let cachedData = CacheManager.shared.getCachedPDF(url: url) {
                
                self.hideLoadingView {
                    // Write cached data to temporary file
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(note.id).pdf")
                    do {
                        try cachedData.write(to: tempURL)
                        
                        // Cache for document ID for future use
                        PDFCache.shared.cachePDFPath(for: note.id, fileURL: tempURL)
                        
                        // Open the PDF viewer
                        let pdfVC = PDFViewerViewController(documentId: note.id)
                        let navController = UINavigationController(rootViewController: pdfVC)
                        pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                            barButtonSystemItem: .close,
                            target: self,
                            action: #selector(self.closePDF)
                        )
                        navController.modalPresentationStyle = .fullScreen
                        self.present(navController, animated: true)
                    } catch {
                        // If writing fails, download normally
                        self.downloadAndPresentPDF(note: note)
                    }
                }
                return
            }
            
            // Not in cache, download and cache
            self.downloadAndPresentPDF(note: note)
        }
    }
    
    private func downloadAndPresentPDF(note: SavedFireNote) {
        guard let pdfUrl = note.pdfUrl, !pdfUrl.isEmpty else {
            self.hideLoadingView {
                self.showAlert(title: "Error", message: "PDF URL is missing")
            }
            return
        }
        
        FirebaseService1.shared.downloadPDF(from: pdfUrl) { [weak self] result in
            guard let self = self else { return }
            
            self.hideLoadingView {
                switch result {
                case .success(let url):
                    // Cache the downloaded PDF
                    PDFCache.shared.cachePDFPath(for: note.id, fileURL: url)
                    
                    // Also cache for URL-based access if possible
                    if let pdfUrl = URL(string: pdfUrl), let pdfData = try? Data(contentsOf: url) {
                        try? CacheManager.shared.cachePDF(url: pdfUrl, data: pdfData)
                    }
                    
                    // Present the PDF viewer
                    let pdfVC = PDFViewerViewController(documentId: note.id)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self.present(navController, animated: true)
                    
                case .failure(let error):
                    self.showAlert(title: "Error", message: "Failed to download PDF: \(error.localizedDescription)")
                    print("Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showLoadingView(completion: @escaping () -> Void) {
        // Create and configure loading view
        let loadingController = UIAlertController(title: nil, message: "Loading PDF...", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()
        loadingController.view.addSubview(loadingIndicator)
        
        present(loadingController, animated: true, completion: completion)
    }
    
    private func hideLoadingView(completion: @escaping () -> Void) {
        if let loadingController = presentedViewController as? UIAlertController,
           loadingController.message == "Loading PDF..." {
            loadingController.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
    
    // MARK: - UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return calculateItemSize()
    }
    
    @objc private func closePDF() {
        dismiss(animated: true)
    }
}

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
        layout.minimumInteritemSpacing = 10
        layout.minimumLineSpacing = 10
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
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
            storage.reference(forURL: note.pdfUrl).delete { error in
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
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func editModeTapped() {
        // Optional: Add additional edit mode functionality if needed
    }
    
    // UICollectionViewDelegate
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        FirebaseService1.shared.downloadPDF(from: note.pdfUrl) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    let pdfVC = PDFViewerViewController(pdfURL: url, title: note.title)
                    let navController = UINavigationController(rootViewController: pdfVC)
                    pdfVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                        barButtonSystemItem: .close,
                        target: self,
                        action: #selector(self?.closePDF)
                    )
                    navController.modalPresentationStyle = .fullScreen
                    self?.present(navController, animated: true)
                case .failure(let error):
                    print("Failed to download PDF: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // UICollectionViewDelegateFlowLayout
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.frame.width - 20) / 2
        return CGSize(width: width, height: 280)
    }
    
    @objc private func closePDF() {
        dismiss(animated: true)
    }
}

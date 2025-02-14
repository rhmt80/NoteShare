import UIKit

// MARK: - NotesManager
class NotesManager {
    static let shared = NotesManager()
    
    private let userDefaults = UserDefaults.standard
    private let filesManager = FileManager.default
    private let notesKey = "savedNotes"
    
    private var notes: [CNote] = []
    
    private init() {
        loadNotes()
    }
    
    // MARK: - Public Methods
    func getAllNotes() -> [CNote] {
        return notes
    }
    
    func addNote(title: String, description: String, author: String, pdfUrl: URL) -> Bool {
        do {
            // Create a copy of the file in the app's documents directory
            let destinationUrl = try copyFileToDocuments(from: pdfUrl)
            
            // Create new note
            let newNote = CNote(
                title: title,
                description: description,
                author: author,
                coverImage: UIImage(systemName: "doc.text.fill"),
                pdfUrl: destinationUrl
            )
            
            // Add to array and save
            notes.append(newNote)
            try saveNotes()
            
            // Notify observers
            NotificationCenter.default.post(name: .notesDidUpdate, object: nil)
            return true
            
        } catch {
            print("Error adding note: \(error.localizedDescription)")
            return false
        }
    }
    
    func deleteNote(at index: Int) {
        guard index < notes.count else { return }
        
        let noteToDelete = notes[index]
        
        // Delete the PDF file
        do {
            try filesManager.removeItem(at: noteToDelete.pdfUrl)
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
        }
        
        // Remove from array and save
        notes.remove(at: index)
        try? saveNotes()
        
        // Notify observers
        NotificationCenter.default.post(name: .notesDidUpdate, object: nil)
    }
    
    // MARK: - Private Methods
    private func getDocumentsDirectory() -> URL {
        return filesManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func copyFileToDocuments(from sourceUrl: URL) throws -> URL {
        let documentsDirectory = getDocumentsDirectory()
        let fileName = UUID().uuidString + "_" + sourceUrl.lastPathComponent
        let destinationUrl = documentsDirectory.appendingPathComponent(fileName)
        
        if filesManager.fileExists(atPath: destinationUrl.path) {
            try filesManager.removeItem(at: destinationUrl)
        }
        
        try filesManager.copyItem(at: sourceUrl, to: destinationUrl)
        return destinationUrl
    }
    
    private func saveNotes() throws {
        // Convert notes to dictionary representation for saving
        let noteData = notes.map { note -> [String: Any] in
            return [
                "title": note.title,
                "description": note.description,
                "author": note.author,
                "pdfUrl": note.pdfUrl.path,
                "dateCreated": note.dateCreated
            ]
        }
        userDefaults.set(noteData, forKey: notesKey)
    }
    
    private func loadNotes() {
        guard let savedNoteData = userDefaults.array(forKey: notesKey) as? [[String: Any]] else { return }
        
        notes = savedNoteData.compactMap { noteDict -> CNote? in
            guard let title = noteDict["title"] as? String,
                  let description = noteDict["description"] as? String,
                  let author = noteDict["author"] as? String,
                  let pdfPath = noteDict["pdfUrl"] as? String,
                  let dateCreated = noteDict["dateCreated"] as? Date else {
                return nil
            }
            
            let pdfUrl = URL(fileURLWithPath: pdfPath)
            return CNote(
                title: title,
                description: description,
                author: author,
                coverImage: UIImage(systemName: "doc.text.fill"),
                pdfUrl: pdfUrl,
                dateCreated: dateCreated
            )
        }
    }
}



// MARK: - Notification Extension
extension Notification.Name {
    static let notesDidUpdate = Notification.Name("notesDidUpdate")
}



struct CNote {
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let pdfUrl: URL
    let dateCreated: Date
    
    init(title: String, description: String, author: String, coverImage: UIImage?, pdfUrl: URL, dateCreated: Date = Date()) {
        self.title = title
        self.description = description
        self.author = author
        self.coverImage = coverImage
        self.pdfUrl = pdfUrl
        self.dateCreated = dateCreated
    }
}

//class College {
//    var title: String
//    var subtitle: String
//    var image: UIImage
//    init(title: String, subtitle: String, image: UIImage) {
//        self.title = title
//        self.subtitle = subtitle
//        self.image = image
//    }
//}

struct Subject {
    let title: String
    let subtitle: String
    let image: UIImage
    let pdfURL: URL
}
struct Sub {
    let title: String
    let subtitle: String
    let image: UIImage
    let pdfURL: URL
}

struct ExploreSubject {
    let title: String
    let subtitle: String
    let image: UIImage
}

struct Note: Equatable {
    var id: UUID  // Add an id for unique identification
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let dateCreated: Date
    let lastModified: Date
    var isFavorite: Bool
    let pdfUrl: URL
    
    init(title: String, description: String, author: String, coverImage: UIImage?,
         dateCreated: Date = Date(), lastModified: Date = Date(), isFavorite: Bool = false, pdfUrl: URL) {
        self.id = UUID()  // Generate unique ID
        self.title = title
        self.description = description
        self.author = author
        self.coverImage = coverImage
        self.dateCreated = dateCreated
        self.lastModified = lastModified
        self.isFavorite = isFavorite
        self.pdfUrl = pdfUrl
    }
    
    static func == (lhs: Note, rhs: Note) -> Bool {
        return lhs.id == rhs.id
    }
}
struct Subs {
    let title: String
    let subtitle: String
    let image: UIImage
    let pdfURL: URL
}

struct RecentFile {
    let name: String
    let icon: UIImage?
    let dateModified: Date
    let fileSize: String
    let pdfURL: URL
    
    init(name: String, icon: UIImage?, dateModified: Date = Date(), fileSize: String = "0 KB" , pdfURL: URL) {
        self.name = name
        self.icon = icon
        self.dateModified = dateModified
        self.fileSize = fileSize
        self.pdfURL = pdfURL
    }
}

struct ScannedDocument {
    let id: UUID
    let title: String
    let pdfUrl: URL
    let thumbnailImage: UIImage
    let dateCreated: Date
    let numberOfPages: Int
    
    init(id: UUID = UUID(),
         title: String,
         pdfUrl: URL,
         thumbnailImage: UIImage,
         dateCreated: Date = Date(),
         numberOfPages: Int) {
        self.id = id
        self.title = title
        self.pdfUrl = pdfUrl
        self.thumbnailImage = thumbnailImage
        self.dateCreated = dateCreated
        self.numberOfPages = numberOfPages
    }
}

struct NoteCard {
   let title: String
   let author: String
   let description: String
   let coverImage: UIImage?
   let pdfUrl: URL

   init(title: String, author: String, description: String,pdfUrl: URL,coverImage: UIImage?) {
       self.title = title
       self.author = author
       self.description = description
       self.coverImage = coverImage
       self.pdfUrl = pdfUrl
   }
}


//struct AiNote: Codable, Identifiable, Hashable {
//    let id: UUID
//    var title: String
//    var content: String
//    var date: Date
//    var category: Category
//    var tags: [String]
//    var isPinned: Bool
//    var isLocked: Bool
//    var aiEnhanced: Bool
//    
//    init(id: UUID = UUID(), title: String, content: String, date: Date = Date(),
//         category: Category, tags: [String] = [], isPinned: Bool = false,
//         isLocked: Bool = false, aiEnhanced: Bool = false) {
//        self.id = id
//        self.title = title
//        self.content = content
//        self.date = date
//        self.category = category
//        self.tags = tags
//        self.isPinned = isPinned
//        self.isLocked = isLocked
//        self.aiEnhanced = aiEnhanced
//    }
//    
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//        hasher.combine(title)
//        hasher.combine(content)
//        hasher.combine(date)
//        hasher.combine(category)
//        hasher.combine(tags)
//        hasher.combine(isPinned)
//        hasher.combine(isLocked)
//        hasher.combine(aiEnhanced)
//    }
//}

struct CardItem {
    let image: String
    let title: String
    let description: String
    let pdfURL: URL
}


struct FavouritesNoteCard {
    let title: String
    let author: String
    let description: String
    let pdfUrl: URL
    let coverImage: UIImage?
}

// Sample Note Card Data
extension FavouritesNoteCard {
    static let sampleNoteCards: [FavouritesNoteCard] = [
        FavouritesNoteCard(
            title: "iOS Development",
            author: "By Sanyog",
            description: "Take a deep dive into the world of iOS",
            pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!,
            coverImage: UIImage(named: "ios")
        ),
        FavouritesNoteCard(
            title: "Physics Concepts",
            author: "By Raj",
            description: "Fundamental Physics Concepts Explained",
            pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!,
            coverImage: UIImage(named: "physics")
        ),
        FavouritesNoteCard(
            title: "Chemistry Lab Report",
            author: "By Sai",
            description: "Detailed Lab Report on Chemical Reactions",
            pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!,
            coverImage: UIImage(named: "chem")
        ),
        FavouritesNoteCard(
            title: "Trigonometry",
            author: "By Raj",
            description: "Advanced Trigonometry Practices and Types",
            pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!,
            coverImage: UIImage(named: "math1")
        ),
        FavouritesNoteCard(
            title: "DM Notes",
            author: "By Sanyog",
            description: "Discrete Mathematics with the advanced concepts",
            pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!,
            coverImage: UIImage(named: "math2")
        )
    ]
}

import UIKit

struct NoteModel {
    let title: String
    let description: String
    let author: String
    let coverImage: UIImage?
    let pdfUrl: URL
    let dateCreated: Date
    
    init(title: String,
         description: String,
         author: String,
         coverImage: UIImage?,
         pdfUrl: URL,
         dateCreated: Date = Date()) {
        self.title = title
        self.description = description
        self.author = author
        self.coverImage = coverImage
        self.pdfUrl = pdfUrl
        self.dateCreated = dateCreated
    }
}
// Create FavoriteManager to handle favorites
class FavoritesManager {
    static let shared = FavoritesManager()
    
    private init() {
        loadFavorites()
    }
    
    private(set) var favorites: [Note] = []
    private let userDefaults = UserDefaults.standard
    private let favoritesKey = "favoriteNotes"
    
    func toggleFavorite(_ note: Note) {
        if let index = favorites.firstIndex(where: { $0.id == note.id }) {
            favorites.remove(at: index)
        } else {
            var updatedNote = note
            updatedNote.isFavorite = true
            favorites.append(updatedNote)
        }
        saveFavorites()
        NotificationCenter.default.post(name: NSNotification.Name("FavoritesUpdated"), object: nil)
    }
    
    func isFavorite(_ note: Note) -> Bool {
        return favorites.contains(where: { $0.id == note.id })
    }
    
    private func saveFavorites() {
        let favoriteData = favorites.map { note -> [String: Any] in
            return [
                "id": note.id.uuidString,
                "title": note.title,
                "description": note.description,
                "author": note.author,
                "dateCreated": note.dateCreated,
                "lastModified": note.lastModified,
                "isFavorite": true,
                "pdfUrl": note.pdfUrl.absoluteString
            ]
        }
        userDefaults.set(favoriteData, forKey: favoritesKey)
    }
    
    private func loadFavorites() {
        guard let savedFavorites = userDefaults.array(forKey: favoritesKey) as? [[String: Any]] else { return }
        
        favorites = savedFavorites.compactMap { dict -> Note? in
            guard let idString = dict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  let title = dict["title"] as? String,
                  let description = dict["description"] as? String,
                  let author = dict["author"] as? String,
                  let dateCreated = dict["dateCreated"] as? Date,
                  let lastModified = dict["lastModified"] as? Date,
                  let pdfUrlString = dict["pdfUrl"] as? String,
                  let pdfUrl = URL(string: pdfUrlString) else {
                return nil
            }
            
            var note = Note(title: title,
                          description: description,
                          author: author,
                          coverImage: nil,
                          dateCreated: dateCreated,
                          lastModified: lastModified,
                          isFavorite: true,
                          pdfUrl: pdfUrl)
            // Override the auto-generated id with the saved one
            note.id = id
            return note
        }
    }
}

// Sample data for notes
extension NoteModel {
    static func getSampleNotes() -> [NoteModel] {
        return [
            NoteModel(title: "Double Integrals",
                  description: "An introduction to double integrals, focusing on area calculations in higher dimensions.",
                  author: "Awnish",
                  coverImage: UIImage(named: "maths_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            NoteModel(title: "Functions",
                  description: "A deep dive into mathematical functions and their properties.",
                  author: "Hindberg",
                  coverImage: UIImage(named: "functions_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            NoteModel(title: "Integrals",
                  description: "A comprehensive study on integrals and their applications.",
                  author: "Amit",
                  coverImage: UIImage(named: "integral_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            NoteModel(title: "Algebra",
                  description: "Understanding the basics and advanced topics in algebra.",
                  author: "Allen Johnson",
                  coverImage: UIImage(named: "algebra_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            NoteModel(title: "Trigonometry",
                  description: "Exploring the relationships between angles and sides of triangles.",
                  author: "prof john",
                  coverImage: UIImage(named: "trigo_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            NoteModel(title: "Physics",
                  description: "A comprehensive guide to concepts in classical and modern physics.",
                  author: "Prof. John",
                  coverImage: UIImage(named: "pie_notes_icon"),
                  pdfUrl: Bundle.main.url(forResource: "test", withExtension: "pdf")!)
        ]
    }
}

import UIKit

class SubjectNotesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let subjectCode: String
    private let notes: [FireNote]

    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PDFCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        return tableView
    }()

    init(subjectCode: String, notes: [FireNote]) {
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
        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PDFCell", for: indexPath)
        let note = notes[indexPath.row]
        cell.textLabel?.text = note.title
        cell.detailTextLabel?.text = note.author
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let note = notes[indexPath.row]
        if let pdfURL = URL(string: note.pdfUrl) {
            let pdfVC = PDFViewerViewController(pdfURL: pdfURL, title: note.title)
            navigationController?.pushViewController(pdfVC, animated: true)
        } else {
            print("Invalid PDF URL: \(note.pdfUrl)")
        }
    }
}

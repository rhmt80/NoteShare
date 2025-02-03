
import UIKit

class PDFSummaryViewController: UIViewController {

    // MARK: - UI Components
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "PDF Summarizer"
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let uploadButton: UIButton = {
               let button = UIButton(type: .system)
               // Create AI logo configuration
               let aiLogoConfig = UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)
               let normalImage = UIImage(systemName: "apple.intelligence", withConfiguration: aiLogoConfig)
               let selectedImage = UIImage(systemName: "apple.intelligence.fill", withConfiguration: aiLogoConfig)
               button.setImage(normalImage, for: .normal)
               button.setImage(selectedImage, for: .highlighted)
               button.tintColor = .white
               button.backgroundColor = .systemBlue
               button.layer.cornerRadius = 8
               button.translatesAutoresizingMaskIntoConstraints = false
               return button
           }()
    private let tableView: UITableView = {
        let table = UITableView()
        table.register(PDFFolderCell.self, forCellReuseIdentifier: PDFFolderCell.identifier)
        table.translatesAutoresizingMaskIntoConstraints = false
        return table
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()

    // MARK: - Data
    private var summaries: [(title: String, summary: String)] = [
        ("Document 1", "This is the summary of the first PDF document."),
        ("Document 2", "This is the summary of the second PDF document."),
        ("Document 3", "This is the summary of the third PDF document.")
    ]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupActions()
        setupTableView()
    }

    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .white

        // Add components to the view
        view.addSubview(titleLabel)
        view.addSubview(uploadButton)
        view.addSubview(tableView)
        view.addSubview(activityIndicator)

        // Set constraints
        NSLayoutConstraint.activate([
            // Center the title label
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Update upload button constraints
            uploadButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            uploadButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            uploadButton.widthAnchor.constraint(equalToConstant: 50),
            uploadButton.heightAnchor.constraint(equalToConstant: 50),

            tableView.topAnchor.constraint(equalTo: uploadButton.bottomAnchor, constant: 20),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    // MARK: - Setup TableView
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
    }

    // MARK: - Actions
    private func setupActions() {
        uploadButton.addTarget(self, action: #selector(uploadPDF), for: .touchUpInside)
    }

    @objc private func uploadPDF() {
        // Simulate PDF upload and processing
        activityIndicator.startAnimating()

        // Simulate API call or processing delay
        DispatchQueue.global().async {
            sleep(3) // Simulate processing time

            // Add a new summary to the list
            let newSummary = ("New Document", "This is the summary of the newly uploaded PDF document.")
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.summaries.append(newSummary)
                self.tableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension PDFSummaryViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return summaries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: PDFFolderCell.identifier, for: indexPath) as? PDFFolderCell else {
            return UITableViewCell()
        }
        let summary = summaries[indexPath.row]
        cell.configure(with: summary.title)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let summary = summaries[indexPath.row]
        let detailVC = PDFDetailViewController(summary: summary)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - Custom TableViewCell for Folder Format
class PDFFolderCell: UITableViewCell {
    static let identifier = "PDFFolderCell"

    private let folderIcon: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "folder.fill")
        imageView.tintColor = .systemBlue
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        contentView.addSubview(folderIcon)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            folderIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            folderIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            folderIcon.widthAnchor.constraint(equalToConstant: 24),
            folderIcon.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: folderIcon.trailingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with title: String) {
        titleLabel.text = title
    }
}

// MARK: - Detail ViewController for PDF Summary
class PDFDetailViewController: UIViewController {
    private let summary: (title: String, summary: String)

    private let summaryTextView: UITextView = {
        let textView = UITextView()
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.isEditable = false
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    init(summary: (title: String, summary: String)) {
        self.summary = summary
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        title = summary.title

        view.addSubview(summaryTextView)
        NSLayoutConstraint.activate([
            summaryTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            summaryTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            summaryTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            summaryTextView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        summaryTextView.text = summary.summary
    }
}

#Preview {
    PDFSummaryViewController()
}

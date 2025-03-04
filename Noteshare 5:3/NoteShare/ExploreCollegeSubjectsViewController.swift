import UIKit
import PDFKit

// MARK: - StudyMaterial Model
struct StudyMaterial {
    let subjectName: String
    let courseDescription: String
    let image: UIImage?
    let pdfURL: URL
    
    init(subjectName: String, courseDescription: String, imageName: String, pdfURL: URL) {
        self.subjectName = subjectName
        self.courseDescription = courseDescription
        self.image = UIImage(named: imageName) ?? UIImage(systemName: "questionmark.square")
        self.pdfURL = pdfURL
    }
}

// MARK: - StudyMaterialCell
class StudyMaterialCell: UICollectionViewCell {
    static let identifier = "StudyMaterialCell"
    
    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let subjectIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(systemName: "questionmark.square")
        return imageView
    }()
    
    private let subjectNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let courseDetailsLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .white
        layer.cornerRadius = 12
        
        contentView.addSubview(containerView)
        containerView.addSubview(subjectIconView)
        contentView.addSubview(subjectNameLabel)
        contentView.addSubview(courseDetailsLabel)
        
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor),
            
            subjectIconView.topAnchor.constraint(equalTo: containerView.topAnchor),
            subjectIconView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            subjectIconView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            subjectIconView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            
            subjectNameLabel.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 12),
            subjectNameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            subjectNameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            courseDetailsLabel.topAnchor.constraint(equalTo: subjectNameLabel.bottomAnchor, constant: 4),
            courseDetailsLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            courseDetailsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }
    
    private func createAttributedString(for description: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: description)
        
        
        if let trendingRange = description.range(of: "#Trending") {
            let nsRange = NSRange(trendingRange, in: description)
            attributedString.addAttribute(.foregroundColor,
                                       value: UIColor.systemBlue,
                                       range: nsRange)
        }
        
        
        let fullRange = NSRange(location: 0, length: description.count)
        attributedString.addAttribute(.foregroundColor,
                                    value: UIColor.gray,
                                    range: fullRange)
        
        // applies blue color to #Trending
        if let trendingRange = description.range(of: "#Trending") {
            let nsRange = NSRange(trendingRange, in: description)
            attributedString.addAttribute(.foregroundColor,
                                        value: UIColor.systemBlue,
                                        range: nsRange)
        }
        
        return attributedString
    }
    
    func configure(with material: StudyMaterial) {
        subjectNameLabel.text = material.subjectName
        courseDetailsLabel.attributedText = createAttributedString(for: material.courseDescription)
        subjectIconView.image = material.image
    }
}
// MARK: - AcademicResourcesViewController
class AcademicResourcesViewController: UIViewController {
    var instituteName: String?
    var instituteLogo: UIImage?
    
    private let instituteHeaderView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let instituteBrandView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let instituteTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var resourcesCollectionView: UICollectionView!
    
    private let studyMaterials: [StudyMaterial] = [
            StudyMaterial(subjectName: "DS Algorithms",
                  courseDescription: "Dijkstra algorithm, #Trending",
                          imageName: "algorithms_cover" ,
                          pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            StudyMaterial(subjectName: "iOS Development",
                  courseDescription: "Develop in Swift Fundamentals",
                  imageName: "ios_dev_cover",
                  pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!),
            StudyMaterial(subjectName: "Physics",
                  courseDescription: "Semiconductors #Trending",
                  imageName: "pie_notes_icon",pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!),

            StudyMaterial(subjectName: "Discrete Maths",
                  courseDescription: "Permutation Group, Cyclic Group",
                  imageName: "maths_notes_icon",pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!),

            StudyMaterial(subjectName: "Machine Learning",
                  courseDescription: " Regression  #Trending",
                  imageName: "ml_cover",pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!),

            StudyMaterial(subjectName: "Computer Networks",
                  courseDescription: "Networking Protocols",
                  imageName: "automata_icon",pdfURL: Bundle.main.url(forResource: "test", withExtension: "pdf")!)

        ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupInstituteHeader()
        setupResourcesCollection()
        updateInstituteInfo()
    }
    
    private func setupInstituteHeader() {
        view.addSubview(instituteHeaderView)
        instituteHeaderView.addSubview(instituteBrandView)
        instituteHeaderView.addSubview(instituteTitleLabel)
        
        NSLayoutConstraint.activate([
            instituteHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            instituteHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            instituteHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            instituteHeaderView.heightAnchor.constraint(equalToConstant: 100),
            
            instituteBrandView.leadingAnchor.constraint(equalTo: instituteHeaderView.leadingAnchor, constant: 20),
            instituteBrandView.centerYAnchor.constraint(equalTo: instituteHeaderView.centerYAnchor),
            instituteBrandView.widthAnchor.constraint(equalToConstant: 60),
            instituteBrandView.heightAnchor.constraint(equalToConstant: 60),
            
            instituteTitleLabel.leadingAnchor.constraint(equalTo: instituteBrandView.trailingAnchor, constant: 16),
            instituteTitleLabel.centerYAnchor.constraint(equalTo: instituteHeaderView.centerYAnchor),
            instituteTitleLabel.trailingAnchor.constraint(equalTo: instituteHeaderView.trailingAnchor, constant: -20)
        ])
    }
    
    private func setupResourcesCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        
        resourcesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        resourcesCollectionView.backgroundColor = .systemBackground
        resourcesCollectionView.delegate = self
        resourcesCollectionView.dataSource = self
        resourcesCollectionView.register(StudyMaterialCell.self, forCellWithReuseIdentifier: StudyMaterialCell.identifier)
        resourcesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(resourcesCollectionView)
        
        NSLayoutConstraint.activate([
            resourcesCollectionView.topAnchor.constraint(equalTo: instituteHeaderView.bottomAnchor),
            resourcesCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resourcesCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resourcesCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func updateInstituteInfo() {
        instituteTitleLabel.text = instituteName
        instituteBrandView.image = instituteLogo
    }
}

extension AcademicResourcesViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return studyMaterials.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StudyMaterialCell.identifier, for: indexPath) as! StudyMaterialCell
        cell.configure(with: studyMaterials[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 48) / 2
        return CGSize(width: width, height: width * 1.3)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedSubject = studyMaterials[indexPath.item]
         let pdfViewerVC = PDFViewerViewController(pdfURL: selectedSubject.pdfURL)
         navigationController?.pushViewController(pdfViewerVC, animated: true)
     }
    
}


#Preview() {
    AcademicResourcesViewController()
}

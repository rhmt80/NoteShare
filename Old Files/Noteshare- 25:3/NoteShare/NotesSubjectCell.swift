import UIKit

class NoteSubjectCell: UITableViewCell {
    static let identifier = "NoteSubjectCell"
    
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        // Add container view for better styling control
        contentView.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.layer.cornerRadius = 10
        containerView.clipsToBounds = true
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        stackView.axis = .vertical
        stackView.spacing = 4

        containerView.addSubview(iconImageView)
        containerView.addSubview(stackView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            iconImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            iconImageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            stackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            stackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16)
        ])
        
        // Configure appearance
        iconImageView.tintColor = .systemBlue
        iconImageView.contentMode = .scaleAspectFit
        
        // Remove default selection style
        selectionStyle = .none
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        UIView.animate(withDuration: animated ? 0.2 : 0) {
            self.containerView.alpha = highlighted ? 0.8 : 1.0
            self.containerView.transform = highlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            UIView.animate(withDuration: animated ? 0.2 : 0) {
                self.containerView.alpha = 0.8
                self.containerView.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            }
        } else {
            UIView.animate(withDuration: animated ? 0.2 : 0) {
                self.containerView.alpha = 1.0
                self.containerView.transform = .identity
            }
        }
    }

    func configure(title: String, subtitle: String, icon: UIImage?) {
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = .gray

        iconImageView.image = icon
        
        // Reset appearance first
        containerView.backgroundColor = .systemBackground
        containerView.layer.borderWidth = 0
    }
    
    func configureAsVisited() {
        // No special styling for visited cells anymore
        configureAsUnvisited()
    }
    
    func configureAsUnvisited() {
        containerView.backgroundColor = .systemBackground
        containerView.layer.borderWidth = 0
        titleLabel.textColor = .label
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        configureAsUnvisited()
    }
}

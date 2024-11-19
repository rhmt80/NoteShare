import UIKit
class OptionsMenuViewController: UIViewController {
    private let menuView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        view.layer.cornerRadius = 15
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
        view.layer.masksToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false

        let blurEffect = UIBlurEffect(style: .systemMaterialLight)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(blurView, at: 0)

        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let menuItems: [(title: String, icon: String, section: Int)] = [
        ("Select", "checkmark.circle", 0),
        ("New Folder", "folder.badge.plus", 0),
        ("Scan Documents", "doc.text.viewfinder", 0),
        ("Icons", "square.grid.2x2", 1),
        ("List", "list.bullet", 1),
        ("Name", "text.alignleft", 2),
        ("Kind", "tag", 2),
        ("Date", "calendar", 2),
        ("Size", "arrow.up.arrow.down", 2),
//        ("Tags", "tag.circle", 2)
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupMenuItems()
        menuView.transform = CGAffineTransform(translationX: 0, y: 20)
        UIView.animate(withDuration: 0.6,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5,
                       options: [.curveEaseOut],
                       animations: {
            self.menuView.transform = .identity
            self.view.backgroundColor = .black.withAlphaComponent(0.4)
        }, completion: nil)
    }

    private func setupView() {
        view.backgroundColor = .black.withAlphaComponent(0.4)

        view.addSubview(menuView)
        menuView.addSubview(stackView)

        NSLayoutConstraint.activate([
            menuView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            menuView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.7), // Increased width
            menuView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            menuView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.6), // Reduced height
            stackView.topAnchor.constraint(equalTo: menuView.topAnchor, constant: 20), // Added margin to move down
            stackView.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: menuView.bottomAnchor)
        ])

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissMenu))
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        menuView.isUserInteractionEnabled = true
    }

    private func setupMenuItems() {
        var currentSection = -1

        for (index, item) in menuItems.enumerated() {
            if currentSection != item.section {
                if currentSection != -1 {
                    let sectionSeparator = createSectionSeparator()
                    stackView.addArrangedSubview(sectionSeparator)
                }
                currentSection = item.section
            }

            let button = createMenuButton(title: item.title, icon: item.icon)
            stackView.addArrangedSubview(button)

            if index < menuItems.count - 1 && menuItems[index + 1].section == currentSection {
                let separator = createSeparator()
                stackView.addArrangedSubview(separator)
            }
        }
    }

    private func createMenuButton(title: String, icon: String) -> UIButton {
        let button = UIButton(type: .system)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true

        let imageView = UIImageView(image: UIImage(systemName: icon))
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = title
        label.textColor = .label
        label.font = .systemFont(ofSize: 17)
        label.translatesAutoresizingMaskIntoConstraints = false

        button.addSubview(imageView)
        button.addSubview(label)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 16),
            imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 28),
            imageView.heightAnchor.constraint(equalToConstant: 28),

            label.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 12),
            label.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16)
        ])

        button.addTarget(self, action: #selector(menuItemTapped(_:)), for: .touchUpInside)
        return button
    }

    private func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator.withAlphaComponent(0.3)
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return separator
    }

    private func createSectionSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator.withAlphaComponent(0.3)
        separator.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return separator
    }

    @objc private func menuItemTapped(_ sender: UIButton) {
        if let label = sender.subviews.compactMap({ $0 as? UILabel }).first {
            let title = label.text ?? ""
            print("Selected: \(title)")
            
            if title == "Scan Documents" {
                let scanVC = PDFScannerViewController()
                let navigationController = UINavigationController(rootViewController: scanVC)
                navigationController.modalPresentationStyle = .fullScreen
                navigationController.navigationBar.prefersLargeTitles = true
                present(navigationController, animated: true)
            } else {
                dismissMenuWithAnimation()
            }
        }
    }

    @objc private func dismissMenu() {
        dismissMenuWithAnimation()
    }

    private func dismissMenuWithAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            self.menuView.transform = CGAffineTransform(translationX: self.menuView.bounds.width, y: 0)
            self.view.backgroundColor = .clear
        }) { _ in
            self.dismiss(animated: false)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension OptionsMenuViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        return !menuView.frame.contains(location)
    }
}

#Preview{
    OptionsMenuViewController()
}

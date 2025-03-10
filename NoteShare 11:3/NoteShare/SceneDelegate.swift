import UIKit
import SwiftUI
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        
        // Check authentication state
        if let _ = Auth.auth().currentUser {
            // User is logged in, go to the tab bar interface
            gototab()
        } else {
            // User is not logged in, start with LandingViewController
            let landingVC = LandingViewController()
            let navigationController = UINavigationController(rootViewController: landingVC)
            window?.rootViewController = navigationController
        }
        
        window?.makeKeyAndVisible()
    }
    
    func gototab() {
        let myNotesViewController = SavedViewController()
        myNotesViewController.tabBarItem = UITabBarItem(
            title: "My Notes",
            image: UIImage(systemName: "book"),
            selectedImage: UIImage(systemName: "book.fill")
        )
        
        // Wrap AdvancedChatView in UIHostingController
        let aiViewController = UIHostingController(rootView: AdvancedChatView())
        aiViewController.tabBarItem = UITabBarItem(
            title: "AI",
            image: UIImage(systemName: "apple.intelligence"),
            selectedImage: UIImage(systemName: "apple.intelligence.fill")
        )
        
        let searchViewController = PDFListViewController()
        searchViewController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        let homeViewController = HomeViewController()
        homeViewController.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            UINavigationController(rootViewController: homeViewController),
            UINavigationController(rootViewController: myNotesViewController),
            UINavigationController(rootViewController: searchViewController),
            UINavigationController(rootViewController: aiViewController)
        ]
        
        // Customize tab bar appearance
        let tabBar = tabBarController.tabBar
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .gray
        
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .systemGray6
            
            let normalItemAppearance = UITabBarItemAppearance()
            normalItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
            normalItemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
            appearance.stackedLayoutAppearance = normalItemAppearance
            
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        } else {
            tabBar.barTintColor = .systemGray6
            tabBar.isTranslucent = false
        }
        
        window?.rootViewController = tabBarController
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}

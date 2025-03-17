import UIKit
import SwiftUI
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        
        // Check if user is already logged in
        if Auth.auth().currentUser != nil && UserDefaults.standard.bool(forKey: "isUserLoggedIn") {
            // User is logged in, go directly to the tab bar
            gototab()
        } else {
            // User is not logged in, start with the landing screen
            let landingVC = LandingViewController()
            let navigationController = UINavigationController(rootViewController: landingVC)
            window?.rootViewController = navigationController
        }
        
        window?.makeKeyAndVisible()
    }
    // In SceneDelegate.swift
    func showLoginScreen() {
        let loginVC = LoginViewController()
        let navController = UINavigationController(rootViewController: loginVC)
//        gototab()
        window?.rootViewController = navController
        window?.makeKeyAndVisible()
    }
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
    
    func gototab() {
        // Use myNotesViewController directly
        let myNotesVC = SavedViewController()
        myNotesVC.tabBarItem = UITabBarItem(
            title: "My Notes",
            image: UIImage(systemName: "book"),
            selectedImage: UIImage(systemName: "book.fill")
        )
        
        // Wrap AdvancedChatView in UIHostingController
        let aiViewController = UIHostingController(rootView: AdvancedChatView())
        // Use a symbol that's available on all iOS versions
        aiViewController.tabBarItem = UITabBarItem(
            title: "AI",
            image: UIImage(systemName: "text.bubble"),
            selectedImage: UIImage(systemName: "text.bubble.fill")
        )
        
        let searchVC = PDFListViewController()
        searchVC.tabBarItem = UITabBarItem(
            title: "Explore",
            image: UIImage(systemName: "doc.text.magnifyingglass"),
            selectedImage: UIImage(systemName: "doc.text.magnifyingglass")
        )
        
        // Fix: Rename to avoid naming conflict with the class name
        let homeVC = HomeViewController()
        homeVC.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            UINavigationController(rootViewController: homeVC),
            UINavigationController(rootViewController: myNotesVC),
            UINavigationController(rootViewController: searchVC),
            UINavigationController(rootViewController: aiViewController)
        ]
        
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
}


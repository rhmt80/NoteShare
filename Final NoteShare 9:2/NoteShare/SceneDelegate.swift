//import UIKit
//class SceneDelegate: UIResponder, UIWindowSceneDelegate {
//    var window: UIWindow?
//    
//    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
//        guard let windowScene = (scene as? UIWindowScene) else { return }
//        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
//        window?.windowScene = windowScene
//        let landingVC = LandingViewController()
//        let navigationController = UINavigationController(rootViewController: landingVC)
//        window?.rootViewController = navigationController
//        
//        window?.makeKeyAndVisible()
//        
//        
//    }
//    func sceneDidDisconnect(_ scene: UIScene) { }
//    func sceneDidBecomeActive(_ scene: UIScene) { }
//    func sceneWillResignActive(_ scene: UIScene) { }
//    func sceneWillEnterForeground(_ scene: UIScene) { }
//    func sceneDidEnterBackground(_ scene: UIScene) { }
//    
//    func gototab(){
//        
//        
//        let MyNotesViewController = SavedViewController()
//        MyNotesViewController.tabBarItem = UITabBarItem(
//            title: "My Notes",
//            image: UIImage(systemName: "book"),
//            selectedImage: UIImage(systemName: "book.fill")
//        )
//        let AiViewController = PDFSummaryViewController()
//        AiViewController.tabBarItem = UITabBarItem(
//            title: "AI",
//            image: UIImage(systemName: "apple.intelligence"),
//            selectedImage: UIImage(systemName: "apple.intelligence.fill")
//        )
//        
//        let SearchViewController = PDFListViewController()
//        SearchViewController.tabBarItem = UITabBarItem(
//            title: "Search",
//            image: UIImage(systemName: "magnifyingglass"),
//            selectedImage: UIImage(systemName: "magnifyingglass")
//        )
//        
//        let HomeViewController = HomeViewController()
//        HomeViewController.tabBarItem = UITabBarItem(
//            title: "Home",
//            image: UIImage(systemName: "house"),
//            selectedImage: UIImage(systemName: "house.fill")
//        )
//        
//        let tabBarController = UITabBarController()
//        tabBarController.viewControllers = [
//            UINavigationController(rootViewController: HomeViewController),
//            UINavigationController(rootViewController: MyNotesViewController),
//            UINavigationController(rootViewController: SearchViewController),
//            UINavigationController(rootViewController: AiViewController)
//            
//            
//        ]
//        
//        let tabBar = tabBarController.tabBar
//        tabBar.tintColor = .systemBlue
//        tabBar.unselectedItemTintColor = .gray
//        
//        if #available(iOS 15.0, *) {
//            let appearance = UITabBarAppearance()
//            appearance.configureWithOpaqueBackground()
//            appearance.backgroundColor = .systemGray6
//            
//            let normalItemAppearance = UITabBarItemAppearance()
//            normalItemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]
//            normalItemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
//            appearance.stackedLayoutAppearance = normalItemAppearance
//            
//            tabBar.standardAppearance = appearance
//            tabBar.scrollEdgeAppearance = appearance
//        }
//        
//        else {
//            tabBar.barTintColor = .systemGray6
//            tabBar.isTranslucent = false
//        }
//        
//        window?.rootViewController = tabBarController
//        
//    }
//}
//
import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(frame: windowScene.coordinateSpace.bounds)
        window?.windowScene = windowScene
        
        // Start with the login screen
        let landingVC = LandingViewController()
        let navigationController = UINavigationController(rootViewController: landingVC)
        window?.rootViewController = navigationController
        
        window?.makeKeyAndVisible()
    }

    
    
    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
    
    func gototab() {
        let MyNotesViewController = SavedViewController()
        MyNotesViewController.tabBarItem = UITabBarItem(
            title: "My Notes",
            image: UIImage(systemName: "book"),
            selectedImage: UIImage(systemName: "book.fill")
        )
        
        // Wrap AdvancedChatView in UIHostingController
        let AiViewController = UIHostingController(rootView: AdvancedChatView())
        AiViewController.tabBarItem = UITabBarItem(
            title: "AI",
            image: UIImage(systemName: "apple.intelligence"),
            selectedImage: UIImage(systemName: "apple.intelligence.fill")
        )
        
        let SearchViewController = PDFListViewController()
        SearchViewController.tabBarItem = UITabBarItem(
            title: "Search",
            image: UIImage(systemName: "magnifyingglass"),
            selectedImage: UIImage(systemName: "magnifyingglass")
        )
        
        let HomeViewController = HomeViewController()
        HomeViewController.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house"),
            selectedImage: UIImage(systemName: "house.fill")
        )
        
        let tabBarController = UITabBarController()
        tabBarController.viewControllers = [
            UINavigationController(rootViewController: HomeViewController),
            UINavigationController(rootViewController: MyNotesViewController),
            UINavigationController(rootViewController: SearchViewController),
            UINavigationController(rootViewController: AiViewController)
        ]
        
        // Rest of the method remains the same...
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

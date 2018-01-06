//
//  ViewControllerFactory.swift
//  ReadLater
//
//  Created by Xavi Moll on 24/12/2017.
//  Copyright © 2017 xmollv. All rights reserved.
//

import Foundation
import UIKit

final class ViewControllerFactory {
    
    private let dataProvider: DataProvider
    
    init(dataProvider: DataProvider) {
        self.dataProvider = dataProvider
    }
    
    func instantiate<T: ViewController>() -> T {
        let viewController = T(factory: self, dataProvider: self.dataProvider)
        return viewController
    }
    
    func instantiateListViewController(type: TypeOfList) -> ListViewController {
        return ListViewController(factory: self, dataProvider: self.dataProvider, type: type)
    }
    
    func establishViewControllers(on tabBarController: UITabBarController) {
        //My List
        let listViewController: ListViewController = self.instantiateListViewController(type: .myList)
        listViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("My List", comment: ""), image: #imageLiteral(resourceName: "list"), tag: 0)
        let favoritesViewController: ListViewController = self.instantiateListViewController(type: .favorites)
        favoritesViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Favorites", comment: ""), image: #imageLiteral(resourceName: "favorite"), tag: 1)
        let archiveViewController: ListViewController = self.instantiateListViewController(type: .archive)
        archiveViewController.tabBarItem = UITabBarItem(title: NSLocalizedString("Archive", comment: ""), image: #imageLiteral(resourceName: "archive"), tag: 2)
        
        let tabs = [listViewController, favoritesViewController, archiveViewController].map({ UINavigationController(rootViewController: $0) })
        
        tabBarController.setViewControllers(tabs, animated: false)
        //In case that it was hidden by the auth, we make sure that it's not hidden
        tabBarController.tabBar.isHidden = false
    }
    
    func establishAuthViewController(on tabBarController: UITabBarController) {
        let authViewController: AuthorizationViewController = self.instantiate()
        tabBarController.setViewControllers([authViewController], animated: false)
        tabBarController.tabBar.isHidden = true
    }
}

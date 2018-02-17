//
//  ViewController.swift
//  llitgi
//
//  Created by Xavi Moll on 24/12/2017.
//  Copyright © 2017 xmollv. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let factory: ViewControllerFactory
    let dataProvider: DataProvider
    let syncManager: SyncManager
    let userPreferences: PreferencesManager
    
    required init(factory: ViewControllerFactory, dependencies: Dependencies) {
        self.factory = factory
        self.dataProvider = dependencies.dataProvider
        self.syncManager = dependencies.syncManager
        self.userPreferences = dependencies.userPreferences
        super.init(nibName: String(describing: type(of: self)), bundle: Bundle(for: type(of: self)))
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Dependency Injection required")
    }
    
    func keyboardNotification(_ notification: NSNotification, constraint: NSLayoutConstraint, view: UIView, defaultConstraintValue: CGFloat = 0) {
        if let userInfo = notification.userInfo {
            guard let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {
                return
            }
            let duration:TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
            let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
            let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
            let animationCurve:UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
            
            if endFrame.origin.y >= UIScreen.main.bounds.size.height {
                constraint.constant = defaultConstraintValue
            } else {
                if let tabBarHeight = self.tabBarController?.tabBar.frame.size.height {
                    constraint.constant = (endFrame.size.height - tabBarHeight) + defaultConstraintValue
                } else {
                    constraint.constant = endFrame.size.height + defaultConstraintValue
                }
            }
            
            UIView.animate(withDuration: duration, delay: 0, options: animationCurve, animations: {
                view.layoutIfNeeded()
            }, completion: nil)
        } else {
            return
        }
    }

}

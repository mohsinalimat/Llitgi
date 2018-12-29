//
//  ManageTagsViewController.swift
//  llitgi
//
//  Created by Xavi Moll on 22/12/2018.
//  Copyright © 2018 xmollv. All rights reserved.
//

import UIKit

private enum Section: Int, CaseIterable {
    case currentTags = 0
    case availableTags = 1
    
    init(section: Int) {
        switch section {
        case 0: self = .currentTags
        case 1: self = .availableTags
        default: fatalError("You've messed up.")
        }
    }
    
    var title: String {
        switch self {
        case .currentTags: return L10n.Tags.current
        case .availableTags: return L10n.Tags.available
        }
    }
}

class ManageTagsViewController: UIViewController {
    
    //MARK:- IBOutlets
    @IBOutlet private var tableView: UITableView!
    @IBOutlet private var toolBar: UIToolbar!
    @IBOutlet private var newTagBarButtonItem: UIBarButtonItem!
    private lazy var cancelBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped(_:)))
        return barButtonItem
    }()
    private lazy var saveBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped(_:)))
        return barButtonItem
    }()
    private lazy var loadingButton: UIBarButtonItem = {
        let loading = UIActivityIndicatorView(style: .gray)
        loading.startAnimating()
        return UIBarButtonItem(customView: loading)
    }()
    
    //MARK:- Class properties
    let item: Item
    let dataProvider: DataProvider
    let themeManager: ThemeManager
    let completed: () -> Void
    private(set) var currentTags: [Tag] = []
    private(set) var availableTags: [Tag] = []
    
    
    //MARK:- Lifecycle
    init(item: Item, dataProvider: DataProvider, themeManager: ThemeManager, completed: @escaping () -> Void) {
        self.item = item
        self.dataProvider = dataProvider
        self.themeManager = themeManager
        self.completed = completed
        self.currentTags = item.tags
        self.availableTags = dataProvider.tags.filter { tag in
            return !item.tags.contains(where: { $0.name == tag.name} )
        }
        super.init(nibName: String(describing: ManageTagsViewController.self), bundle: Bundle(for: ManageTagsViewController.self))
        self.title = item.title
    }
    
    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return self.themeManager.theme.statusBarStyle
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.cancelBarButtonItem
        self.navigationItem.rightBarButtonItem = self.saveBarButtonItem
        self.apply(self.themeManager.theme)
        self.themeManager.addObserver(self) { [weak self] theme in
            self?.apply(theme)
        }
        self.tableView.register(TagPickerCell.self)
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.tableFooterView = UIView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.tableView.flashScrollIndicators()
    }
    
    @objc
    private func cancelTapped(_ sender: UIBarButtonItem) {
        self.completed()
    }
    
    @objc
    private func saveTapped(_ sender: UIBarButtonItem) {
        self.blockUserInterfaceForNetwork(true)

        let itemModification = ItemModification.init(action: .replaceTags(self.currentTags.map{ $0.name }), id: self.item.id)
        self.dataProvider.performInMemoryWithoutResultType(endpoint: .modify([itemModification])) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .isSuccess:
                strongSelf.dataProvider.syncLibrary { _ in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    strongSelf.completed()
                }
            case .isFailure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                strongSelf.blockUserInterfaceForNetwork(false)
                strongSelf.presentErrorAlert()
            }
        }
    }
    
    @IBAction func newTagTapped(_ sender: UIBarButtonItem) {
        let alertController = UIAlertController(title: L10n.Tags.newTagTitle,
                                                message: nil,
                                                preferredStyle: .alert)
        
        alertController.addTextField { [weak self] (textField) in
            guard let strongSelf = self else { return }
            textField.keyboardAppearance = strongSelf.themeManager.theme.keyboardAppearance
        }
        let cancel = UIAlertAction(title: L10n.General.cancel, style: .cancel, handler: nil)
        let add = UIAlertAction(title: L10n.General.add, style: .default) { [weak self, weak alertController] (action) in
            guard let strongSelf = self else { return }
            guard let text = alertController?.textFields?.first?.text, text != "" else { return }
            if let index = strongSelf.availableTags.firstIndex(where: { $0.name == text }) {
                let tag = strongSelf.availableTags.remove(at: index)
                strongSelf.currentTags.append(tag)
                strongSelf.currentTags.sort { $0.name < $1.name }
            } else if strongSelf.currentTags.firstIndex(where: { $0.name == text }) == nil {
                strongSelf.currentTags.append(InMemoryTag(name: text))
                strongSelf.currentTags.sort { $0.name < $1.name }
            }
            strongSelf.tableView.reloadData()
        }
        alertController.addAction(cancel)
        alertController.addAction(add)
        self.present(alertController, animated: true, completion: nil)
    }
    
    private func apply(_ theme: Theme) {
        self.view.backgroundColor = theme.backgroundColor
        self.navigationController?.navigationBar.barStyle = theme.barStyle
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: theme.textTitleColor]
        (self.loadingButton.customView as? UIActivityIndicatorView)?.color = theme.tintColor
        self.toolBar.barStyle = theme.barStyle
        self.tableView.backgroundColor = theme.backgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.tableView.indicatorStyle = theme.indicatorStyle
        self.tableView.reloadData()
    }
    
    private func blockUserInterfaceForNetwork(_ block: Bool) {
        if block {
            self.navigationItem.rightBarButtonItem = self.loadingButton
            self.newTagBarButtonItem.isEnabled = false
            self.tableView.isUserInteractionEnabled = false
        } else {
            self.navigationItem.rightBarButtonItem = self.saveBarButtonItem
            self.newTagBarButtonItem.isEnabled = true
            self.tableView.isUserInteractionEnabled = true
        }
    }
    
    private func remove(tag: Tag, from items: [Item], then: @escaping (Bool) -> Void) {
        let modifications = items.map { ItemModification(action: .removeTags([tag.name]), id: $0.id) }
        
        self.dataProvider.performInMemoryWithoutResultType(endpoint: .modify(modifications)) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .isSuccess:
                strongSelf.dataProvider.syncLibrary { _ in
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    then(true)
                }
            case .isFailure:
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                strongSelf.presentErrorAlert()
                then(false)
            }
        }
    }

}

//MARK:- UITableViewDelegate
extension ManageTagsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Section(section: indexPath.section) {
        case .currentTags:
            let tag = self.currentTags.remove(at: indexPath.row)
            self.availableTags.append(tag)
            self.availableTags.sort { $0.name < $1.name }
        case .availableTags:
            let tag = self.availableTags.remove(at: indexPath.row)
            self.currentTags.append(tag)
            self.currentTags.sort { $0.name < $1.name }
        }
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteAction = UIContextualAction(style: .destructive, title: L10n.Actions.delete) { [weak self] (action, view, success) in
            guard let strongSelf = self else { return }
            
            let tag: Tag
            switch Section(section: indexPath.section) {
            case .currentTags: tag = strongSelf.currentTags[indexPath.row]
            case .availableTags: tag = strongSelf.availableTags[indexPath.row]
            }
            let affectedItems = strongSelf.dataProvider.items(with: tag)
            let message = String(format: L10n.Tags.removeWarning, arguments: [tag.name, affectedItems.count])
            let alertController = UIAlertController(title: L10n.Tags.remove,
                                                    message: message,
                                                    preferredStyle: .alert)
            let cancel = UIAlertAction(title: L10n.General.cancel, style: .cancel) { action in
                success(false)
            }
            let remove = UIAlertAction(title: L10n.Tags.remove, style: .destructive) { action in
                strongSelf.blockUserInterfaceForNetwork(true)
                strongSelf.remove(tag: tag, from: affectedItems) { completed in
                    if completed {
                        success(true)
                        switch Section(section: indexPath.section) {
                        case .currentTags: strongSelf.currentTags.removeAll(where: { $0.name == tag.name })
                        case .availableTags: strongSelf.availableTags.removeAll(where: { $0.name == tag.name })
                        }
                        strongSelf.tableView.reloadData()
                    } else {
                        strongSelf.presentErrorAlert()
                        success(false)
                    }
                    strongSelf.blockUserInterfaceForNetwork(false)
                }
            }
            alertController.addAction(cancel)
            alertController.addAction(remove)
            strongSelf.present(alertController, animated: true)
        }
        
        let swipeConfiguration = UISwipeActionsConfiguration(actions: [deleteAction])
        swipeConfiguration.performsFirstActionWithFullSwipe = false
        return swipeConfiguration
    }
}

//MARK:- UITableViewDataSource
extension ManageTagsViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(section: section) {
        case .currentTags: return self.currentTags.count
        case .availableTags: return self.availableTags.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: TagPickerCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
        let tag: Tag
        switch Section(section: indexPath.section) {
        case .currentTags: tag = self.currentTags[indexPath.row]
        case .availableTags: tag = self.availableTags[indexPath.row]
        }
        cell.configure(with: tag, theme: self.themeManager.theme)
        return cell
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionHeaderView = SectionHeaderView(theme: self.themeManager.theme)
        
        let tagSection = Section(section: section)
        switch tagSection {
        case .currentTags where self.currentTags.count > 0:
            sectionHeaderView.text = tagSection.title
            return sectionHeaderView
        case .availableTags where self.availableTags.count > 0:
            sectionHeaderView.text = tagSection.title
            return sectionHeaderView
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(section: section) {
        case .currentTags:
            return self.currentTags.count > 0 ? UITableView.automaticDimension : 0
        case .availableTags:
            return self.availableTags.count > 0 ? UITableView.automaticDimension : 0
        }
    }
}

private struct InMemoryTag: Tag {
    let name: String
    let items: [Item] = []
}
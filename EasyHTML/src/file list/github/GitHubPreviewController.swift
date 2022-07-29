//
//  GitHubPreviewController.swift
//  EasyHTML
//
//  Created by Артем on 13.07.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

class GitHubPreviewController: BasicMasterController {
    
    var fileListManager: FileListManager!
    var activityIndicator: UIActivityIndicatorView!
    var queryRequest: GitHubAPI.QueueEntry!
    let refresh = UIRefreshControl()
    
    func anchorToTop(view: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        self.tableView.addSubview(view)
        view.centerXAnchor.constraint(equalTo: tableView.centerXAnchor).isActive = true
        view.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 20).isActive = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupThemeChangedNotificationHandling()
        
        tableView = UITableView(frame: tableView.frame, style: .grouped)
        
        setupToolBar()
        updateStyle()
        
        if #available(iOS 11.0, *) {
            tableView.contentInsetAdjustmentBehavior = .never
        } else {
            automaticallyAdjustsScrollViewInsets = false
        }
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refresh
        } else {
            tableView.addSubview(refresh)
        }
        
        edgesForExtendedLayout = []
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = 50
        
        activityIndicator = UIActivityIndicatorView()
        anchorToTop(view: activityIndicator)
        activityIndicator.startAnimating()
        activityIndicator.style = userPreferences.currentTheme.isDark ? .white : .gray
        
        refresh.addTarget(self, action: #selector(refreshData), for: .valueChanged)
    }
    
    @objc func refreshData() {
        
    }
    
    deinit {
        queryRequest?.cancel()
    }
}

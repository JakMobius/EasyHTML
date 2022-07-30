//
//  GitHubRepositoryHeaderCell.swift
//  EasyHTML
//
//  Created by Артем on 30/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubRepositoryController {
    class HeaderCell: UITableViewCell, NotificationHandler {

        static let descriptionFont = UIFont.systemFont(ofSize: 12, weight: .light)

        static let avatarColorDark = UIColor(red: 0.179, green: 0.16, blue: 0.14, alpha: 1)
        static let avatarColorLight = UIColor(red: 0.82, green: 0.839, blue: 0.859, alpha: 1)

        let repoName = UILabel()
        let avatar = UIImageView()
        let descriptionLabel = UITextView()
        var loadTask: URLSessionTask?
        var moreActionsButton = UIButton()
        var updateDate = UILabel()

        func clearAvatar() {
            avatar.image = nil
        }

        func cancelAvatarLoading() {
            if loadTask != nil {
                loadTask!.cancel()
                loadTask = nil
            }
        }

        func loadAvatar(link: String?, nick: String?) {
            guard link != nil else {
                return
            }
            guard nick != nil else {
                return
            }

            cancelAvatarLoading()

            if let cachedImage = GitHubUtils.userImageCache[nick!] {
                avatar.image = UIImage(data: cachedImage as Data)
                return
            }

            if userPreferences.currentTheme.isDark {
                avatar.backgroundColor = HeaderCell.avatarColorDark
            } else {
                avatar.backgroundColor = HeaderCell.avatarColorLight
            }

            if let url = URL(string: link!) {
                loadTask = GitHubUtils.avatarLoadingTask(url: url, callback: { data in
                    if let data = data {
                        self.avatar.image = UIImage(data: data)
                        GitHubUtils.userImageCache[nick!] = NSData(data: data)
                    }
                    self.loadTask = nil
                    self.avatar.backgroundColor = nil
                })
                loadTask?.resume()
            }
        }

        func updateTheme() {
            descriptionLabel.textColor = userPreferences.currentTheme.cellTextColor
            updateDate.textColor = userPreferences.currentTheme.secondaryTextColor
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            repoName.translatesAutoresizingMaskIntoConstraints = false
            avatar.translatesAutoresizingMaskIntoConstraints = false
            descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            moreActionsButton.translatesAutoresizingMaskIntoConstraints = false
            updateDate.translatesAutoresizingMaskIntoConstraints = false

            avatar.layer.cornerRadius = 3
            avatar.layer.masksToBounds = true

            repoName.lineBreakMode = .byTruncatingHead

            setupThemeChangedNotificationHandling()
            updateTheme()

            descriptionLabel.font = HeaderCell.descriptionFont
            updateDate.font = HeaderCell.descriptionFont

            contentView.addSubview(repoName)
            contentView.addSubview(avatar)
            contentView.addSubview(descriptionLabel)
            contentView.addSubview(moreActionsButton)
            contentView.addSubview(updateDate)

            moreActionsButton.setImage(UIImage(named: "more"), for: .normal)
            moreActionsButton.imageView!.tintColor = .gray

            avatar.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            avatar.widthAnchor.constraint(equalToConstant: 40).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 40).isActive = true

            repoName.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            repoName.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            repoName.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -44).isActive = true

            updateDate.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            updateDate.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 35).isActive = true
            updateDate.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true

            descriptionLabel.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 2).isActive = true
            descriptionLabel.leftAnchor.constraint(equalTo: avatar.leftAnchor, constant: 0).isActive = true
            descriptionLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
            descriptionLabel.isScrollEnabled = false
            descriptionLabel.backgroundColor = .clear
            descriptionLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true

            moreActionsButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
            moreActionsButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
            moreActionsButton.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            moreActionsButton.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            moreActionsButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 10, bottom: 7, right: 10)

            //...
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}



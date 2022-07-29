//
//  GitHubUserHeaderCell.swift
//  EasyHTML
//
//  Created by Артем on 30/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubUserController {
    class HeaderCell: UITableViewCell, NotificationHandler {

        static let descriptionFont = UIFont.systemFont(ofSize: 12, weight: .light)

        static let avatarColorDark = UIColor(red: 0.179, green: 0.16, blue: 0.14, alpha: 1)
        static let avatarColorLight = UIColor(red: 0.82, green: 0.839, blue: 0.859, alpha: 1)

        let userName = UILabel()
        let realName = UILabel()
        let avatar = UIImageView()
        let bio = UITextView()
        var loadTask: URLSessionTask?
        let moreActionsButton = UIButton()
        var bioHeightConstraint: NSLayoutConstraint!
        let statusLabel = UILabel()

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
            bio.textColor = userPreferences.currentTheme.cellTextColor
            userName.textColor = userPreferences.currentTheme.secondaryTextColor
            statusLabel.textColor = userPreferences.currentTheme.secondaryTextColor

            if userPreferences.currentTheme.isDark {
                realName.textColor = .white
            } else {
                realName.textColor = .darkGray
            }
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            userName.translatesAutoresizingMaskIntoConstraints = false
            avatar.translatesAutoresizingMaskIntoConstraints = false
            bio.translatesAutoresizingMaskIntoConstraints = false
            moreActionsButton.translatesAutoresizingMaskIntoConstraints = false
            realName.translatesAutoresizingMaskIntoConstraints = false
            statusLabel.translatesAutoresizingMaskIntoConstraints = false

            avatar.layer.cornerRadius = 3
            avatar.layer.masksToBounds = true

            userName.lineBreakMode = .byTruncatingHead

            setupThemeChangedNotificationHandling()
            updateTheme()

            userName.font = UIFont.systemFont(ofSize: 12)
            bio.font = HeaderCell.descriptionFont
            realName.font = UIFont.boldSystemFont(ofSize: 16)
            statusLabel.font = HeaderCell.descriptionFont
            statusLabel.lineBreakMode = .byTruncatingTail

            contentView.addSubview(userName)
            contentView.addSubview(avatar)
            contentView.addSubview(bio)
            contentView.addSubview(moreActionsButton)
            contentView.addSubview(realName)
            contentView.addSubview(statusLabel)

            moreActionsButton.setImage(UIImage(named: "more"), for: .normal)
            moreActionsButton.imageView!.tintColor = .gray

            avatar.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            avatar.widthAnchor.constraint(equalToConstant: 60).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 60).isActive = true

            userName.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            userName.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 20).isActive = true
            userName.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -44).isActive = true

            bio.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            bio.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 5).isActive = true
            bio.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            bio.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5).isActive = true
            bio.backgroundColor = .clear
            bio.textColor = userPreferences.currentTheme.cellTextColor
            bio.isScrollEnabled = false

            bioHeightConstraint = bio.heightAnchor.constraint(equalToConstant: 0)

            realName.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            realName.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 0).isActive = true
            realName.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -44).isActive = true

            statusLabel.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            statusLabel.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 45).isActive = true
            statusLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -5).isActive = true

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



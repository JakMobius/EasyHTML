//
//  GitHubUserCell.swift
//  EasyHTML
//
//  Created by Артем on 27/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubLobby {
    class UserCell: UITableViewCell, NotificationHandler {

        static let nickFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let nameFont = UIFont.systemFont(ofSize: 12, weight: .regular)
        static let bioFont = UIFont.systemFont(ofSize: 12, weight: .light)

        static let avatarColorDark = UIColor(red: 0.179, green: 0.16, blue: 0.14, alpha: 1)
        static let avatarColorLight = UIColor(red: 0.82, green: 0.839, blue: 0.859, alpha: 1)

        let userNick = UILabel()
        let bioLabel = UILabel()
        let avatar = UIImageView()
        var loadTask: URLSessionTask?

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
                avatar.backgroundColor = UserCell.avatarColorDark
            } else {
                avatar.backgroundColor = UserCell.avatarColorLight
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


            bioLabel.textColor = userPreferences.currentTheme.cellTextColor

            if userPreferences.currentTheme.isDark {
                userNick.textColor = GitHubUtils.tintDarkColor
            } else {
                userNick.textColor = GitHubUtils.tintLightColor
            }
        }

        var regularUsernameConstraint: NSLayoutConstraint!
        var bioLessUsernameConstraint: NSLayoutConstraint!

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            userNick.translatesAutoresizingMaskIntoConstraints = false
            avatar.translatesAutoresizingMaskIntoConstraints = false
            avatar.layer.cornerRadius = 3
            avatar.layer.masksToBounds = true
            bioLabel.translatesAutoresizingMaskIntoConstraints = false

            setupThemeChangedNotificationHandling()
            updateTheme()

            userNick.font = Self.nickFont
            bioLabel.font = Self.bioFont

            contentView.addSubview(userNick)
            contentView.addSubview(avatar)
            contentView.addSubview(bioLabel)

            avatar.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            avatar.widthAnchor.constraint(equalToConstant: 40).isActive = true
            avatar.heightAnchor.constraint(equalToConstant: 40).isActive = true
            avatar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true

            userNick.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            userNick.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true

            regularUsernameConstraint = userNick.topAnchor.constraint(equalTo: avatar.topAnchor)
            bioLessUsernameConstraint = userNick.centerYAnchor.constraint(equalTo: avatar.centerYAnchor)

            bioLabel.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            bioLabel.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            bioLabel.topAnchor.constraint(equalTo: avatar.topAnchor, constant: 23).isActive = true

            //...
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}



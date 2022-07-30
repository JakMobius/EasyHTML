//
//  GitHubRecentActivityCell.swift
//  EasyHTML
//
//  Created by Артем on 27/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubLobby {
    class RecentCell: UITableViewCell, NotificationHandler {

        static let nickFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let nameFont = UIFont.systemFont(ofSize: 13, weight: .medium)


        private var imageWidth: NSLayoutConstraint!
        private var imageLeft: NSLayoutConstraint!
        static private let imageSize: CGFloat = 30
        static private let imagePadding: CGFloat = 20
        let smallHeader = UILabel()
        let largeTitle = UILabel()
        let avatar = UIImageView()
        var loadTask: URLSessionTask?
        var observingItem: GitHubHistory.Entry? {
            didSet {
                cancelAvatarLoading()
                guard observingItem != nil else {
                    return
                }
                switch observingItem! {
                case .searched(let request):
                    smallHeader.text = localize("yousearched", .github)
                    largeTitle.text = request
                    avatar.image = nil
                    avatar.backgroundColor = nil
                case .visitedRepo(let name):
                    smallHeader.text = localize("youvisitedrepo", .github)
                    largeTitle.text = name
                    avatar.image = nil
                    avatar.backgroundColor = nil
                case .visitedUser(let nick, let id):
                    smallHeader.text = localize("youvisiteduser", .github)
                    largeTitle.text = nick
                    loadAvatar(nick: nick, link: "https://avatars0.githubusercontent.com/u/\(id)?v=4")
                }

                updateTheme()
            }
        }

        func clearAvatar() {
            guard observingItem != nil else {
                return
            }

            if case .visitedUser = observingItem! {
                avatar.image = nil
            }
        }

        func cancelAvatarLoading() {
            if loadTask != nil {
                loadTask!.cancel()
                loadTask = nil
            }
        }

        func loadAvatar(nick: String, link: String) {

            cancelAvatarLoading()

            if let cachedImage = GitHubUtils.userImageCache[nick] {
                avatar.image = UIImage(data: cachedImage as Data)
                return
            }

            if userPreferences.currentTheme.isDark {
                avatar.backgroundColor = UserCell.avatarColorDark
            } else {
                avatar.backgroundColor = UserCell.avatarColorLight
            }

            if let url = URL(string: link) {
                loadTask = GitHubUtils.avatarLoadingTask(url: url, callback: { data in
                    if let data = data {
                        self.avatar.image = UIImage(data: data)
                        self.avatar.backgroundColor = nil
                    }
                    self.loadTask = nil
                })
                loadTask?.resume()
            }
        }

        override func layoutSubviews() {

            guard observingItem != nil else {
                return
            }

            if case .visitedUser = observingItem! {
                imageWidth.constant = RecentCell.imageSize
                imageLeft.constant = RecentCell.imagePadding
            } else {
                imageWidth.constant = 0
                imageLeft.constant = RecentCell.imagePadding - 10
            }

            super.layoutSubviews()
        }

        func updateTheme() {

            guard observingItem != nil else {
                return
            }
            smallHeader.textColor = userPreferences.currentTheme.secondaryTextColor

            if case .searched = observingItem! {
                avatar.tintColor = userPreferences.currentTheme.secondaryTextColor
                largeTitle.textColor = userPreferences.currentTheme.cellTextColor
            } else {
                if userPreferences.currentTheme.isDark {
                    avatar.tintColor = .white
                    largeTitle.textColor = GitHubUtils.tintDarkColor
                } else {
                    avatar.tintColor = .black
                    largeTitle.textColor = GitHubUtils.tintLightColor
                }
            }
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            largeTitle.translatesAutoresizingMaskIntoConstraints = false
            avatar.translatesAutoresizingMaskIntoConstraints = false
            smallHeader.translatesAutoresizingMaskIntoConstraints = false
            avatar.layer.cornerRadius = 3
            avatar.layer.masksToBounds = true

            smallHeader.font = UIFont.systemFont(ofSize: 10, weight: .light)

            setupThemeChangedNotificationHandling()
            updateTheme()

            largeTitle.font = UserCell.nickFont

            contentView.addSubview(smallHeader)
            contentView.addSubview(largeTitle)
            contentView.addSubview(avatar)

            imageWidth = avatar.widthAnchor.constraint(equalToConstant: RecentCell.imageSize)
            avatar.heightAnchor.constraint(equalToConstant: RecentCell.imageSize).isActive = true
            imageLeft = avatar.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: RecentCell.imagePadding)
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true

            largeTitle.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            largeTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 23).isActive = true
            largeTitle.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true

            smallHeader.leftAnchor.constraint(equalTo: avatar.rightAnchor, constant: 10).isActive = true
            smallHeader.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true

            imageLeft.isActive = true
            imageWidth.isActive = true
            //...
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}

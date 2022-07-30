//
//  GitHubRepoCell.swift
//  EasyHTML
//
//  Created by Артем on 26/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubLobby {
    class RepoCell: UITableViewCell, NotificationHandler {

        override var backgroundColor: UIColor? {
            didSet {
                descField.backgroundColor = backgroundColor
            }
        }

        static let titleFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        static let descFont = UIFont.systemFont(ofSize: 13, weight: .medium)
        static let footerFont = UIFont.systemFont(ofSize: 12, weight: .regular)

        static let headerColorLight = UIColor(red: 0.011, green: 0.4, blue: 0.839, alpha: 1)
        static let headerColorDark = UIColor(red: 0.988, green: 0.6, blue: 0.1607, alpha: 1)
        static let descColorLight = UIColor(red: 0.345, green: 0.376, blue: 0.411, alpha: 1)
        static let descColorDark = UIColor(red: 0.655, green: 0.654, blue: 0.589, alpha: 1)

        let repoTitle = UILabel()
        let descField = UITextView()
        let footerText = UILabel()
        let languageView = AlwaysOpaqueView()
        let languageLabel = UILabel()
        let starsImage = UIImageView()
        let starsCount = UILabel()

        func updateTheme() {

            if userPreferences.currentTheme.isDark {
                repoTitle.textColor = RepoCell.headerColorDark
                descField.textColor = RepoCell.descColorDark
                footerText.textColor = RepoCell.descColorDark
                languageLabel.textColor = RepoCell.descColorDark
                starsCount.textColor = RepoCell.descColorDark
                starsImage.tintColor = .white
            } else {
                repoTitle.textColor = RepoCell.headerColorLight
                descField.textColor = RepoCell.descColorLight
                footerText.textColor = RepoCell.descColorLight
                languageLabel.textColor = RepoCell.descColorLight
                starsCount.textColor = RepoCell.descColorLight
                starsImage.tintColor = .black
            }

        }

        func setLanguage(language: String) {
            languageLabel.text = language
            languageView.backgroundColor = GitHubUtils.colorFor(language: language)
        }

        func setUpdateDateAndLicense(date: Date!, license: String?) {

            let dateString: String!

            if let date = date {
                dateString = GitHubUtils.dateFormatter.string(from: date)
            } else {
                dateString = nil
            }

            if license == nil || license == "Other" || dateString == nil {
                footerText.text = "\(localize("repolastupdate", .github)) \(dateString!)"
            } else {
                footerText.text = "\(license!) • \(localize("repolastupdate", .github)) \(dateString!)"
            }
        }

        func setStars(stars: Int) {
            var str = String(stars)
            let len = str.count

            if len > 3 {
                let truncate = len % 3
                let power = ["K", "M", "B", "T", "Q"]

                if truncate == 0 {
                    str = String(str.prefix(3))
                } else {
                    var truncated = Float(stars)
                    for _ in 3..<len {
                        truncated /= 10
                    }

                    var fraction = String(Int(round(truncated)))

                    fraction.insert(".", at: fraction.index(fraction.startIndex, offsetBy: truncate))

                    str = fraction
                }

                starsCount.text = "\(str)\(power[len / 3 - 1])"
            } else {
                starsCount.text = "\(str)"
            }
        }

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)

            repoTitle.translatesAutoresizingMaskIntoConstraints = false
            descField.translatesAutoresizingMaskIntoConstraints = false
            footerText.translatesAutoresizingMaskIntoConstraints = false
            languageView.translatesAutoresizingMaskIntoConstraints = false
            languageLabel.translatesAutoresizingMaskIntoConstraints = false
            starsImage.translatesAutoresizingMaskIntoConstraints = false
            starsCount.translatesAutoresizingMaskIntoConstraints = false

            setupThemeChangedNotificationHandling()
            updateTheme()

            repoTitle.font = RepoCell.titleFont
            descField.font = RepoCell.descFont
            footerText.font = RepoCell.footerFont
            languageLabel.font = RepoCell.descFont
            starsCount.font = RepoCell.descFont

            starsImage.image = UIImage(named: "github-star")

            contentView.addSubview(repoTitle)
            contentView.addSubview(descField)
            contentView.addSubview(footerText)
            contentView.addSubview(languageView)
            contentView.addSubview(languageLabel)
            contentView.addSubview(starsImage)
            contentView.addSubview(starsCount)

            repoTitle.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            repoTitle.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10).isActive = true
            repoTitle.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            repoTitle.lineBreakMode = .byTruncatingHead

            descField.backgroundColor = nil
            descField.isUserInteractionEnabled = false
            descField.isScrollEnabled = false
            descField.isEditable = false
            descField.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            descField.topAnchor.constraint(equalTo: repoTitle.bottomAnchor, constant: 0).isActive = true
            descField.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            descField.heightAnchor.constraint(lessThanOrEqualToConstant: 70).isActive = true
            descField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -50).isActive = true
            descField.setContentCompressionResistancePriority(.required, for: .vertical)

            languageView.heightAnchor.constraint(equalToConstant: 14).isActive = true
            languageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
            languageView.centerYAnchor.constraint(equalTo: languageLabel.centerYAnchor).isActive = true
            languageView.rightAnchor.constraint(equalTo: languageLabel.leftAnchor, constant: -5).isActive = true
            languageView.layer.cornerRadius = 7

            starsImage.heightAnchor.constraint(equalToConstant: 16).isActive = true
            starsImage.widthAnchor.constraint(equalToConstant: 14).isActive = true
            starsImage.centerYAnchor.constraint(equalTo: starsCount.centerYAnchor).isActive = true
            starsImage.rightAnchor.constraint(equalTo: starsCount.leftAnchor, constant: -5).isActive = true

            languageView.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            languageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true
            languageLabel.leftAnchor.constraint(lessThanOrEqualTo: starsImage.leftAnchor, constant: -10).isActive = true
            starsCount.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            starsImage.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10).isActive = true

            footerText.leftAnchor.constraint(equalTo: contentView.leftAnchor, constant: 10).isActive = true
            footerText.rightAnchor.constraint(equalTo: contentView.rightAnchor, constant: -10).isActive = true
            footerText.topAnchor.constraint(equalTo: descField.bottomAnchor, constant: 0).isActive = true

            //...
        }

        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
    }
}

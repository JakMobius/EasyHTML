//
//  GithubRepositoryStatisticCell.swift
//  EasyHTML
//
//  Created by Артем on 31/05/2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import UIKit

extension GitHubRepositoryController {
    class StatisticCell: UITableViewCell, NotificationHandler {
        class StatisticStackView: UIView {
            var icon = UIImageView()
            var label = UILabel()
            
            override init(frame: CGRect) {
                super.init(frame: CGRect(origin: frame.origin, size: CGSize(width: 50, height: 36)))
                
                addSubview(icon)
                addSubview(label)
                
                icon.contentMode = .center
                icon.frame = CGRect(x: 17, y: 0, width: 16, height: 16)
                label.frame = CGRect(x: 0, y: 20, width: 50, height: 16)
                label.textAlignment = .center
                label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
                label.adjustsFontSizeToFitWidth = true
            }
            
            required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
            }
        }
        
        class LanguageStackView: UIView {
            var languageIcon = AlwaysOpaqueView()
            var languageLabel = UILabel()
            var fractionLabel = UILabel()
            
            func update(language: String, fraction: Double) {
                languageLabel.text = language
                languageIcon.backgroundColor = GitHubUtils.colorFor(language: language) ?? .gray
                
                languageLabel.sizeToFit()
                languageLabel.frame.origin.x = (frame.width - languageLabel.frame.width + 16) / 2
                languageIcon.frame.origin.x = languageLabel.frame.origin.x - 16
                
                fractionLabel.text = "\(round(fraction * 1000) / 10) %"
            }
            
            override init(frame: CGRect) {
                super.init(frame: CGRect(origin: frame.origin, size: CGSize(width: 100, height: 36)))
                
                addSubview(languageIcon)
                addSubview(languageLabel)
                addSubview(fractionLabel)
                
                fractionLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
                
                fractionLabel.frame = CGRect(x: 0, y: 20, width: 100, height: 16)
                languageLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
                fractionLabel.textAlignment = .center
                
                languageIcon.layer.cornerRadius = 5
                languageIcon.frame = CGRect(x: 0, y: 5, width: 10, height: 10)
            }
            
            required init?(coder aDecoder: NSCoder) {
                super.init(coder: aDecoder)
            }
        }
        
        var statisticStackViews = [
            StatisticStackView(),
            StatisticStackView(),
            StatisticStackView(),
            StatisticStackView(),
            StatisticStackView()
        ]
        
        private var statisticContainer = UIView()
        private var languagesContainer = UIView()
        private var clipper = UIView()
        
        var languageStackViews: [LanguageStackView] = []
        
        func setLanguages(languages: [GitHubLanguageItem]) {
            
            let index = min(languages.count, 5)
            
            for i in 0 ..< index {
                let language = languages[i]
                
                let view: LanguageStackView
                
                if languageStackViews.count > i {
                    view = languageStackViews[i]
                } else {
                    view = LanguageStackView()
                    languageStackViews.append(view)
                }
                
                
                view.update(language: language.language, fraction: language.fraction)
                
                languagesContainer.addSubview(view)
                
                view.fractionLabel.textColor = userPreferences.currentTheme.secondaryTextColor
                view.languageLabel.textColor = userPreferences.currentTheme.cellTextColor
            }
            
            if languageStackViews.count > index {
                languageStackViews.removeLast(languageStackViews.count - index)
            }
            
            languagesDiagram.setLanguages(languages: languages)
        }
        
        static var images = [
            UIImage(named: "github-commits"),
            UIImage(named: "github-branches"),
            UIImage(named: "github-releases"),
            UIImage(named: "github-contributors"),
            UIImage(named: "github-license")
        ]
        
        private var languagesToggled = false
        
        func toggleLanguages() {
            
            if languageStackViews.isEmpty {
                return
            }
            
            statisticContainer.isHidden = false
            languagesContainer.isHidden = false
            
            setNeedsLayout()
            
            if languagesToggled {
                UIView.animate(withDuration: 0.4, animations: {
                    self.languagesContainer.transform = CGAffineTransform(translationX: 0, y: 60)
                    self.statisticContainer.transform = .identity
                }, completion: {
                    success in
                    if success {
                        self.languagesContainer.isHidden = true
                    }
                })
            } else {
                UIView.animate(withDuration: 0.4, animations: {
                    self.statisticContainer.transform = CGAffineTransform(translationX: 0, y: -60)
                    self.languagesContainer.transform = .identity
                }, completion: {
                    success in
                    if success {
                        self.statisticContainer.isHidden = true
                    }
                })
            }
            
            languagesToggled = !languagesToggled
        }
        
        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            
            var i = 0
            
            for view in statisticStackViews {
                
                view.icon.image = StatisticCell.images[i]
                i += 1
                
                statisticContainer.addSubview(view)
            }
            
            statisticContainer.translatesAutoresizingMaskIntoConstraints = false
            languagesContainer.translatesAutoresizingMaskIntoConstraints = false
            clipper.translatesAutoresizingMaskIntoConstraints = false
            
            contentView.addSubview(clipper)
            clipper.addSubview(statisticContainer)
            clipper.addSubview(languagesContainer)
            
            contentView.addSubview(languagesDiagram)
            
            statisticContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            statisticContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            statisticContainer.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            statisticContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            
            languagesContainer.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            languagesContainer.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            languagesContainer.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            languagesContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            
            clipper.leftAnchor.constraint(equalTo: contentView.leftAnchor).isActive = true
            clipper.rightAnchor.constraint(equalTo: contentView.rightAnchor).isActive = true
            clipper.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            clipper.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            
            languagesContainer.transform = CGAffineTransform(translationX: 0, y: 60)
            languagesContainer.isHidden = true
            
            selectionStyle = .none
            
            updateTheme()
            setupThemeChangedNotificationHandling()
            
            clipper.clipsToBounds = true
        }
        
        let languagesDiagram = LanguagesDiagram()
        
        func updateTheme() {
            
            let tint: UIColor
            
            if userPreferences.currentTheme.isDark {
                tint = .white
            } else {
                tint = .black
            }
            
            for view in statisticStackViews {
                view.icon.tintColor = userPreferences.currentTheme.secondaryTextColor
                view.label.textColor = tint
            }
            
            for view in languageStackViews {
                view.fractionLabel.textColor = userPreferences.currentTheme.secondaryTextColor
                view.languageLabel.textColor = userPreferences.currentTheme.cellTextColor
            }
        }
        
        required init?(coder aDecoder: NSCoder) {
            super.init(coder: aDecoder)
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            if !statisticContainer.isHidden {
                let delta = CGFloat(1) / CGFloat(statisticStackViews.count + 1)
                var fraction = delta
                
                let width = contentView.frame.size.width
                let y = contentView.frame.size.height / 2
                
                for view in statisticStackViews {
                    view.frame.origin.x = fraction * width - view.frame.width / 2
                    view.frame.origin.y = y - view.frame.height / 2
                    
                    fraction += delta
                }
            }
            if !languagesContainer.isHidden {
                
                if !languageStackViews.isEmpty {
                    let width = contentView.frame.size.width
                    let y = contentView.frame.size.height / 2
                    
                    if languageStackViews.count == 1 {
                        let view = languageStackViews.first!
                        view.frame.origin.x = width / 2 - view.frame.width / 2
                        view.frame.origin.y = y - view.frame.height / 2
                    } else {
                        let visibleCount = min(languageStackViews.count, Int((width - 20) / 100))
                        
                        let delta = CGFloat(1) / CGFloat(visibleCount - 1)
                        
                        let padding: CGFloat = 60
                        var fraction: CGFloat = 0
                        let availableWidth = width - padding * 2
                        
                        for i in 0 ..< languageStackViews.count {
                            let view = languageStackViews[i]
                            view.frame.origin.x = padding + fraction * availableWidth - view.frame.width / 2
                            view.frame.origin.y = y - view.frame.height / 2
                            view.isHidden = false
                            
                            fraction += delta
                        }
                        
                        let animation = self.layer.animation(forKey: "bounds.size")
                        
                        if let duration = animation?.duration {
                            
                            let dispatchTime = DispatchTime(uptimeNanoseconds: DispatchTime.now().uptimeNanoseconds + UInt64(duration * 1000000000))
                            
                            DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
                                for i in visibleCount ..< self.languageStackViews.count {
                                    self.languageStackViews[i].isHidden = true
                                }
                            }
                        } else {
                            for i in visibleCount ..< languageStackViews.count {
                                self.languageStackViews[i].isHidden = true
                            }
                        }
                    }
                }
            }
            
            
            
            languagesDiagram.frame.origin.x = 0
            languagesDiagram.frame.origin.y = contentView.frame.size.height - 5
            languagesDiagram.frame.size.height = 5
            languagesDiagram.frame.size.width = contentView.frame.width
        }
        
        deinit {
            clearNotificationHandling()
        }
    }
}

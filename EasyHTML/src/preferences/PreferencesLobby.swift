//
//  PreferencesLobby.swift
//  EasyHTML
//
//  Created by Артем on 19.12.2017.
//  Copyright © 2017 Артем. All rights reserved.
//

import UIKit

class PreferencesLobby: UICollectionViewController, NotificationHandler  {
    
    static weak var instance: PreferencesLobby!

    private var names = ["editor", "files", "layout", "language", "aboutprogram", "feedback"];
    private var images = ["editor-big", "fileicon", "layout", "language", "info", "email"]
    
    @objc func closeButtonAction(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    init() {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 130, height: 150)
        super.init(collectionViewLayout: layout)
        PreferencesLobby.instance = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: localize("close"), style: .plain, target: self, action: #selector(closeButtonAction(_:)))
        collectionView.register(PreferencesLobbyCollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        
        NotificationCenter.default.post(name: NSNotification.Name.TCPreferencesOpened, object: nil)
        updateTheme()
        setupThemeChangedNotificationHandling()
        
        title = localize("preferences")
    }
    
    var layoutFinished: Bool = false
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard !layoutFinished else { return }
        layoutFinished = true
        recalculateInsets(size: view.frame.size)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return names.count
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath) as! PreferencesLobbyCollectionViewCell
        cell.label.text = localize(names[indexPath.row], .preferences)
        cell.image.image = UIImage(named: images[indexPath.row])?.withRenderingMode(.alwaysTemplate)
        cell.image.contentMode = .scaleAspectFit
        cell.image.tintColor = UIColor.gray
        cell.collectionView = self
        cell.number = indexPath.row
        
        // Configure the cell
    
        return cell
    }
    
    internal func openMenu(tag: Int) {
        switch(tag) {
            case 0: EditorPreferencesMenu.present(from: self, clazz: EditorPreferencesMenu.self); return;
            case 1: FilesPreferencesMenu.present(from: self, clazz: FilesPreferencesMenu.self); return;
            case 2: LayoutPreferencesMenu.present(from: self, clazz: LayoutPreferencesMenu.self); return;
            case 3: LanguagePreferencesMenu.present(from: self, clazz: LanguagePreferencesMenu.self); return;
            case 4: AboutPreferencesMenu.present(from: self, clazz: AboutPreferencesMenu.self); return;
            case 5: FeedbackPreferencesMenu.present(from: self, clazz: FeedbackPreferencesMenu.self); return;
            default: return;
        }
    }
    
    private func recalculateInsets(size: CGSize) {
        
        var size = size
        var sideOffset: CGFloat = 0
        
        if(size.width == 812.0 && (size.height == 322.0 || size.height == 292.0 || size.height == 375)) {
            size.width -= 60
            sideOffset = 30
        }
        
        let count = Double(names.count)
        let w = CGFloat(count * 150)
        
        let rows = ceil(w / (size.width - 20))
        
        let heightinset = size.height * 0.5 - CGFloat(rows * 90);
        
        let widthinset = (w > size.width - 20 ? 10 : ((size.width - 20) - w) / 2) + sideOffset
        
        let layout = collectionViewLayout as? UICollectionViewFlowLayout
        
        layout?.sectionInset = UIEdgeInsets(top: heightinset + 3, left: widthinset, bottom: 0, right: widthinset)
     
        layout?.invalidateLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        recalculateInsets(size: size);
        
    }
    
    func updateTheme() {
        
        collectionView.backgroundColor = userPreferences.currentTheme.background
    }
    
    deinit {
        PreferencesLobby.instance = nil
        NotificationCenter.default.post(name: NSNotification.Name.TCPreferencesClosed, object: nil)
    }
}

class PreferencesLobbyCollectionViewCell: UICollectionViewCell, NotificationHandler {
    var shadowView = UIView()
    var label = UILabel()
    var image = UIImageView()
    
    internal weak var collectionView: PreferencesLobby? = nil;
    internal var number = -1
    
    override init(frame: CGRect) {
        
        super.init(frame: frame)
        
        addSubview(label)
        addSubview(shadowView)
        shadowView.addSubview(image)
        
        shadowView.cornerRadius = 10
        
        image.frame = CGRect(x: 17, y: 17, width: 60, height: 60)
        image.layer.shadowOpacity = 0
        shadowView.frame = CGRect(x: 18, y: 18, width: 94, height: 94)
        label.font = UIFont.systemFont(ofSize: 13)
        label.frame = CGRect(x: 0, y: 122, width: 130, height: 16)
        label.textAlignment = .center
        
        self.contentView.clipsToBounds = false
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(gesture(_:)))
        tap.minimumPressDuration = 0.0
        shadowView.addGestureRecognizer(tap)
        
        updateTheme()
    }
    
    func updateTheme() {
        
        
        shadowView.layer.backgroundColor = userPreferences.currentTheme.secondaryTextColor.withAlphaComponent(0.1).cgColor
        
        label.textColor = userPreferences.currentTheme.secondaryTextColor.withAlphaComponent(0.7)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func gesture(_ sender: UITapGestureRecognizer) {
        if(sender.state == .began) {
            shadowView.alpha = 0.4
        } else {
            UIView.animate(withDuration: 0.3, animations: {
                self.shadowView.alpha = 1.0
            })
            if sender.state == .ended {
                collectionView?.openMenu(tag: number)
            }
        }
    }
    
    deinit {
        clearNotificationHandling()
    }
}

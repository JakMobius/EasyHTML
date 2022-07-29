//
//  ReplicationView.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//

import UIKit

extension FilesRelocationManager {
    internal class ReplicationView: UIView {
        let label: UILabel
        let descriptionLabel: UILabel
        let deleteButton: UIImageView
        
        final func setEditing(_ isEditing: Bool) {
            
            if deleteButton.isHidden == isEditing {
                if isEditing {
                    deleteButton.alpha = 0.0
                    deleteButton.isHidden = false
                    
                    UIView.animate(withDuration: 0.3, animations: {
                        self.deleteButton.alpha = 1.0
                    })
                } else {
                    UIView.animate(withDuration: 0.3, animations: {
                        self.deleteButton.alpha = 0.0
                    }, completion: {
                        _ in
                        self.deleteButton.isHidden = true
                    })
                }
            }
        }
        
        final func describeFile(file: FSNode) {
            label.text = file.name
            descriptionLabel.text = localize(file is FSNode.Folder ? "folder" : "file")
        }
        
        internal override init(frame: CGRect) {
            
            label = UILabel()
            descriptionLabel = UILabel()
            deleteButton = UIImageView()
            
            super.init(frame: frame)
            
            label.translatesAutoresizingMaskIntoConstraints = false
            descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
            deleteButton.image = #imageLiteral(resourceName: "cancel")
            deleteButton.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            deleteButton.isHidden = true
            
            let path = UIBezierPath(
                roundedRect: deleteButton.bounds,
                byRoundingCorners: [.topLeft, .bottomRight],
                cornerRadii: CGSize(width: 4, height: 5)
            )
            let maskLayer = CAShapeLayer()
            
            maskLayer.path = path.cgPath
            deleteButton.layer.mask = maskLayer
            
            addSubview(label)
            addSubview(descriptionLabel)
            addSubview(deleteButton)
            
            label.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            label.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 80).isActive = true
            label.textColor = #colorLiteral(red: 0.3487617668, green: 0.5847071854, blue: 0.8868940473, alpha: 1)
            label.font = UIFont.systemFont(ofSize: 11)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.8
            
            descriptionLabel.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            descriptionLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5).isActive = true
            descriptionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80).isActive = true
            descriptionLabel.textColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
            descriptionLabel.font = UIFont.systemFont(ofSize: 11)
            
            backgroundColor = .white
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.1
            layer.cornerRadius = 5.0
            layer.shadowPath = CGPath(
                roundedRect: CGRect(x: -3, y: -3, width: 97, height: 156),
                cornerWidth: 3,
                cornerHeight: 3,
                transform: nil
            )
            
            self.frame = CGRect(x: 10, y: 5, width: 90, height: 150)
        }
        
        required internal init?(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
    
    internal func getReplicationView(for file: FSNode, index: Int) -> ReplicationView {
        let replicationView = ReplicationView()
        
        replicationView.describeFile(file: file)
        replicationView.tag = index
        
        return replicationView
    }
}

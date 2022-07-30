//
//  FileRelocationManager.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//


extension FilesRelocationManager {
    enum FileReceiveAbility {
        case yes, no(reason: RelocationForbiddenReason)
    }
}

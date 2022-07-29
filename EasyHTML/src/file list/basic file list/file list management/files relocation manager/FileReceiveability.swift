//
//  FileReceiveability.swift
//  EasyHTML
//
//  Created by Артем on 15/12/2018.
//  Copyright © 2018 Артем. All rights reserved.
//


extension FilesRelocationManager {
    enum FileReceiveability {
        case yes, no(reason: RelocationForbiddenReason)
    }
}

//
//  JSONParser.swift
//  EasyHTML
//
//  Created by Артем on 14.07.2019.
//  Copyright © 2019 Артем. All rights reserved.
//

import Foundation

class JSONParser {
    typealias Object = [String : Any]
    var object: Object!
    
    func valueByKey<T>(key: [String], value: T.Type, object: Object? = nil) -> T? {
        var value: Any? = object ?? self.object
        
        if(value == nil) {
            return nil
        }
        
        for item in key {
            value = (value as? Object)?[item]
            
            if(value == nil) {
                return nil
            }
        }
        
        return value as? T
    }
    
    func jumpTo(field: String) {
        self.object = self.object[field] as? Object
    }
    
    init(object: Object!) {
        self.object = object
    }
}


import Security

public class KeychainService: NSObject {
    
    private static let kSecClassValue = NSString(format: kSecClass)
    private static let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
    private static let kSecValueDataValue = NSString(format: kSecValueData)
    private static let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
    private static let kSecAttrServiceValue = NSString(format: kSecAttrService)
    private static let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
    private static let kSecReturnDataValue = NSString(format: kSecReturnData)
    private static let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)
    private static let kSecAttrAccessibleValue = NSString(format: kSecAttrAccessible)
    private static let kSecAttrAccessibleWhenUnlockedThisDeviceOnlyValue = NSString(format: kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
    
    class func query(service: String, account: String) -> NSMutableDictionary {
        
        let dictionary =  NSMutableDictionary()
        
        dictionary[kSecClassValue] = kSecClassGenericPasswordValue
        dictionary[kSecAttrServiceValue] = service
        dictionary[kSecAttrAccountValue] = account
        
        return dictionary
    }
    
    @discardableResult class func removePassword(service: String, account: String) -> Bool {
        
        let query = self.query(service: service, account: account)
        
        let status = SecItemDelete(query as CFDictionary)
        
        return status == errSecSuccess
    }
    
    
    @discardableResult class func savePassword(service: String, account:String, data: String) -> Bool {
        if let dataFromString = data.data(using: String.Encoding.utf8, allowLossyConversion: false) {
            
            let query = self.query(service: service, account: account)
            
            query[kSecValueDataValue] = dataFromString
            query[kSecAttrAccessibleValue] = kSecAttrAccessibleWhenUnlockedThisDeviceOnlyValue
            
            let status = SecItemAdd(query as CFDictionary, nil)
            
            return status == errSecSuccess
        }
        return false
    }
    
    class func loadPassword(service: String, account:String) -> String? {
        
        let query = self.query(service: service, account: account)
        
        query[kSecReturnDataValue] = kCFBooleanTrue
        query[kSecMatchLimitValue] = kSecMatchLimitOneValue
        
        var dataTypeRef : AnyObject?
        
        // Search for the keychain items
        
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                return String(data: retrievedData, encoding: String.Encoding.utf8)
            }
        } else {
            print("Nothing was retrieved from the keychain. Status code \(status)")
        }
        
        return nil
    }
    
}


import UIKit

struct WKAlertManager {
    internal static func presentAlert(message: String, on controller: UIViewController, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler()
        }))
        
        controller.present(alert, animated: true, completion: nil)
    }
    internal static func presentConfirmPanel(message: String, on controller: UIViewController, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            completionHandler(true)
        }))
        
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .default, handler: { (action) in
            completionHandler(false)
        }))
        
        controller.present(alert, animated: true, completion: nil)
    }
    internal static func presentInputPrompt(prompt: String, on controller: UIViewController, defaultText: String?, completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: "Alert", message: prompt, preferredStyle: .alert)
        
        alert.addTextField { (textField) in
            textField.text = defaultText
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            if let text = alert.textFields?.first?.text {
                completionHandler(text)
            } else {
                completionHandler(defaultText)
            }
        }))
        
        alert.addAction(UIAlertAction(title: localize("cancel"), style: .default, handler: { (action) in
            completionHandler(nil)
        }))
        
        controller.present(alert, animated: true, completion: nil)
    }
}

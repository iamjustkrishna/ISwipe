import UIKit

public class ThemeManager {
    public static let shared = ThemeManager()
    
    public var currentLanguage: KeyboardConstants.Language = KeyboardConstants.LANGUAGES.first! {
        didSet {
            NotificationCenter.default.post(name: NSNotification.Name("ThemeChanged"), object: nil)
        }
    }
    
    public var accentColor: UIColor {
        return color(fromHex: currentLanguage.accentColor)
    }
    
    public var keyboardBackgroundColor: UIColor {
        return color(fromHex: KeyboardConstants.COLOR_KEYBOARD_BG)
    }
    
    public var keyBackgroundColor: UIColor {
        return color(fromHex: KeyboardConstants.COLOR_KEY_BG)
    }
    
    public var keyTextColor: UIColor {
        return color(fromHex: KeyboardConstants.COLOR_KEY_TEXT)
    }
    
    public var specialKeyBackgroundColor: UIColor {
        return color(fromHex: KeyboardConstants.COLOR_SPECIAL_KEY_BG)
    }
    
    public var suggestionBackgroundColor: UIColor {
        return color(fromHex: KeyboardConstants.COLOR_SUGGESTION_BG)
    }
    
    public func color(fromHex hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let length = hexSanitized.count
        
        let r, g, b, a: CGFloat
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            a = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            r = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return .black
        }
        
        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
}

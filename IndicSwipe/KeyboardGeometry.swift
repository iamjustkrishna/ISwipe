import Foundation
import CoreGraphics

public class KeyboardGeometry {

    private static let TAG = "KeyboardGeometry"
    private static let ASSET_NAME = "keyboard_grid"
    private static let SPATIAL_GRID_SIZE = 6
    private static let CHAR_TOKEN_OFFSET: Int64 = 4
    private static let DEFAULT_WIDTH: Float = 360.0
    private static let DEFAULT_HEIGHT: Float = 220.0
    private static let VERTICAL_PENALTY: Float = 1.15
    private static let OUTSIDE_HITBOX_PENALTY: Float = 0.35

    public let trainWidth: Float = KeyboardConstants.TRAIN_WIDTH
    public let trainHeight: Float = KeyboardConstants.TRAIN_HEIGHT

    public var viewWidth: Float = KeyboardGeometry.DEFAULT_WIDTH
    public var viewHeight: Float = KeyboardGeometry.DEFAULT_HEIGHT

    public var scaleX: Float { trainWidth / max(viewWidth, 1.0) }
    public var scaleY: Float { trainHeight / max(viewHeight, 1.0) }
    
    public var keyCount: Int { allKeys.count }

    public struct Key {
        public let char: Character
        public let cx: Float
        public let cy: Float
        public let width: Float
        public let height: Float
        public let isSpecial: Bool
        public let specialName: String?
        
        public init(char: Character, cx: Float, cy: Float, width: Float, height: Float, isSpecial: Bool = false, specialName: String? = nil) {
            self.char = char
            self.cx = cx
            self.cy = cy
            self.width = width
            self.height = height
            self.isSpecial = isSpecial
            self.specialName = specialName
        }

        public var left: Float { cx - width / 2.0 }
        public var right: Float { cx + width / 2.0 }
        public var top: Float { cy - height / 2.0 }
        public var bottom: Float { cy + height / 2.0 }
    }

    private let allKeys: [Key]
    private let keyMap: [Character: Key]
    private var specialKeys = [String: Key]()

    private var spatialGrid: [[[Key]]]
    private let cellWidth: Float
    private let cellHeight: Float
    private let defaultKey: Character = "e"

    public init() {
        let t0 = CFAbsoluteTimeGetCurrent()
        var keys: [Key]

        do {
            keys = try KeyboardGeometry.loadFromJson()
        } catch {
            print("\(KeyboardGeometry.TAG): JSON load failed: \(error)")
            keys = KeyboardGeometry.createDefaultKeys()
        }

        self.allKeys = keys
        
        var tempKeyMap = [Character: Key]()
        for key in allKeys where !key.isSpecial && key.char >= "a" && key.char <= "z" {
            tempKeyMap[key.char] = key
        }
        self.keyMap = tempKeyMap

        self.cellWidth = trainWidth / Float(KeyboardGeometry.SPATIAL_GRID_SIZE)
        self.cellHeight = trainHeight / Float(KeyboardGeometry.SPATIAL_GRID_SIZE)

        self.spatialGrid = Array(repeating: Array(repeating: [Key](), count: KeyboardGeometry.SPATIAL_GRID_SIZE), count: KeyboardGeometry.SPATIAL_GRID_SIZE)

        for key in allKeys {
            let minCol = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((key.left / trainWidth) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))
            let maxCol = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((key.right / trainWidth) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))
            let minRow = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((key.top / trainHeight) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))
            let maxRow = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((key.bottom / trainHeight) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))
            
            for row in minRow...maxRow {
                for col in minCol...maxCol {
                    self.spatialGrid[row][col].append(key)
                }
            }
        }

        for key in allKeys where key.isSpecial {
            if let name = key.specialName {
                self.specialKeys[name] = key
            }
        }

        let regular = allKeys.filter { !$0.isSpecial }.count
        let special = allKeys.filter { $0.isSpecial }.count
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - t0) * 1000
        print("\(KeyboardGeometry.TAG): Loaded \(regular) regular + \(special) special keys in \(String(format: "%.0f", elapsedMs))ms")
    }

    // ── JSON loader ───────────────────────────────────────────────────────────

    private static func loadFromJson() throws -> [Key] {
        guard let url = Bundle.main.url(forResource: ASSET_NAME, withExtension: "json") else {
            throw NSError(domain: "KeyboardGeometry", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(ASSET_NAME).json"])
        }
        
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
              let qwerty = root["qwerty_english"] as? [String: Any] else {
            throw NSError(domain: "KeyboardGeometry", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }
        
        let rawW = Float(qwerty["width"] as? Double ?? Double(DEFAULT_WIDTH))
        let rawH = Float(qwerty["height"] as? Double ?? Double(DEFAULT_HEIGHT))
        
        let sx = KeyboardConstants.TRAIN_WIDTH / max(rawW, 1.0)
        let sy = KeyboardConstants.TRAIN_HEIGHT / max(rawH, 1.0)
        
        var keyList = [Key]()
        
        if let keysArray = qwerty["keys"] as? [[String: Any]] {
            for obj in keysArray {
                if let key = parseRegularKey(obj, sx: sx, sy: sy) {
                    keyList.append(key)
                }
            }
        }
        
        if let specialArray = qwerty["special_keys"] as? [[String: Any]] {
            for obj in specialArray {
                if let key = parseSpecialKey(obj, sx: sx, sy: sy) {
                    keyList.append(key)
                }
            }
        }
        
        return keyList
    }

    public func setDimensions(w: Float, h: Float) {
        if w <= 0 || h <= 0 { return }
        viewWidth = w
        viewHeight = h
    }

    private static func parseRegularKey(_ obj: [String: Any], sx: Float, sy: Float) -> Key? {
        guard let label = obj["label"] as? String, label.count == 1 else { return nil }
        let char = Character(label.lowercased())
        if char < "a" || char > "z" { return nil }

        guard let hb = obj["hitbox"] as? [String: Any] else { return nil }
        let kx = Float(hb["x"] as? Double ?? 0.0) * sx
        let ky = Float(hb["y"] as? Double ?? 0.0) * sy
        let kw = Float(hb["w"] as? Double ?? 32.0) * sx
        let kh = Float(hb["h"] as? Double ?? 48.0) * sy

        return Key(char: char, cx: kx + kw / 2.0, cy: ky + kh / 2.0, width: kw, height: kh)
    }

    private static func parseSpecialKey(_ obj: [String: Any], sx: Float, sy: Float) -> Key? {
        guard let label = obj["label"] as? String, !label.isEmpty else { return nil }

        guard let hb = obj["hitbox"] as? [String: Any] else { return nil }
        let kx = Float(hb["x"] as? Double ?? 0.0) * sx
        let ky = Float(hb["y"] as? Double ?? 0.0) * sy
        let kw = Float(hb["w"] as? Double ?? 50.0) * sx
        let kh = Float(hb["h"] as? Double ?? 48.0) * sy

        return Key(char: "\0", cx: kx + kw / 2.0, cy: ky + kh / 2.0, width: kw, height: kh, isSpecial: true, specialName: label)
    }

    private static func createDefaultKeys() -> [Key] {
        var keys = [Key]()
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        let kw = KeyboardConstants.TRAIN_WIDTH / 10.0
        let kh = KeyboardConstants.TRAIN_HEIGHT / 4.0
        let offsets: [Float] = [0.0, kw * 0.5, kw * 1.5]
        let ys: [Float] = [kh * 0.5, kh * 1.5, kh * 2.5]

        for (ri, row) in rows.enumerated() {
            for (ci, char) in row.enumerated() {
                keys.append(Key(char: char, cx: offsets[ri] + Float(ci) * kw + kw / 2.0, cy: ys[ri], width: kw, height: kh))
            }
        }
        let specials = [
            Key(char: "\0", cx: 27, cy: 136, width: 54, height: 48, isSpecial: true, specialName: "shift"),
            Key(char: "\0", cx: 333, cy: 136, width: 54, height: 48, isSpecial: true, specialName: "backspace"),
            Key(char: "\0", cx: 27, cy: 190, width: 54, height: 52, isSpecial: true, specialName: "symbol_toggle"),
            Key(char: "\0", cx: 72, cy: 190, width: 36, height: 52, isSpecial: true, specialName: "comma"),
            Key(char: "\0", cx: 180, cy: 190, width: 180, height: 52, isSpecial: true, specialName: "space"),
            Key(char: "\0", cx: 288, cy: 190, width: 36, height: 52, isSpecial: true, specialName: "period"),
            Key(char: "\0", cx: 333, cy: 190, width: 54, height: 52, isSpecial: true, specialName: "enter")
        ]
        keys.append(contentsOf: specials)
        return keys
    }

    // ── Public Accessors ──────────────────────────────────────────────────────

    public func getAllKeys() -> [Key] { return allKeys }

    public func getKeySize(_ char: Character) -> (Float, Float)? {
        guard let key = keyMap[Character(char.lowercased())] else { return nil }
        return (key.width, key.height)
    }

    public func getSpecialKeyRect(name: String) -> CGRect? {
        guard let key = specialKeys[name] else { return nil }
        return CGRect(x: CGFloat(key.left), y: CGFloat(key.top), width: CGFloat(key.width), height: CGFloat(key.height))
    }

    public func hitTestSpecial(tx: Float, ty: Float) -> String? {
        var bestKey: Key? = nil
        var minDistanceSq = Float.greatestFiniteMagnitude
        
        let scale: Float = 1.3

        for key in allKeys where key.isSpecial {
            let expandedW = key.width * scale
            let expandedH = key.height * scale
            let left = key.cx - expandedW / 2.0
            let right = key.cx + expandedW / 2.0
            let top = key.cy - expandedH / 2.0
            let bottom = key.cy + expandedH / 2.0

            if tx >= left && tx <= right && ty >= top && ty <= bottom {
                let dx = tx - key.cx
                let dy = ty - key.cy
                let distSq = dx * dx + dy * dy
                if distSq < minDistanceSq {
                    minDistanceSq = distSq
                    bestKey = key
                }
            }
        }
        return bestKey?.specialName
    }

    public func tapKeyChar(tx: Float, ty: Float) -> Character? {
        for key in allKeys where !key.isSpecial {
            if tx >= key.left && tx <= key.right && ty >= key.top && ty <= key.bottom {
                return key.char
            }
        }
        
        let char = nearestKeyChar(px: tx, py: ty)
        guard let k = keyMap[char] else { return nil }
        let dx = tx - k.cx
        let dy = ty - k.cy
        let distSq = dx * dx + dy * dy
        
        let thresholdSq = (k.width * 1.2) * (k.width * 1.2)
        return distSq < thresholdSq ? char : nil
    }

    public func nearestKeyCharEuclidean(px: Float, py: Float) -> Character {
        let cx = min(max(px, 0), trainWidth)
        let cy = min(max(py, 0), trainHeight)

        var bestKey = defaultKey
        var bestDistSq = Float.greatestFiniteMagnitude

        for key in allKeys where !key.isSpecial {
            let dx = cx - key.cx
            let dy = cy - key.cy
            let distSq = dx * dx + dy * dy
            if distSq < bestDistSq {
                bestDistSq = distSq
                bestKey = key.char
            }
        }
        return bestKey
    }

    public func nearestKeyChar(px: Float, py: Float) -> Character {
        let cx = min(max(px, 0), trainWidth)
        let cy = min(max(py, 0), trainHeight)

        let gridCol = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((cx / trainWidth) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))
        let gridRow = max(0, min(KeyboardGeometry.SPATIAL_GRID_SIZE - 1, Int((cy / trainHeight) * Float(KeyboardGeometry.SPATIAL_GRID_SIZE))))

        var bestKey = defaultKey
        var bestScore = Float.greatestFiniteMagnitude

        for dr in -1...1 {
            for dc in -1...1 {
                let r = gridRow + dr
                let c = gridCol + dc
                if r < 0 || r >= KeyboardGeometry.SPATIAL_GRID_SIZE || c < 0 || c >= KeyboardGeometry.SPATIAL_GRID_SIZE { continue }
                
                for key in spatialGrid[r][c] where !key.isSpecial {
                    let score = scorePointToKey(px: cx, py: cy, key: key)
                    if score < bestScore {
                        bestScore = score
                        bestKey = key.char
                    }
                }
            }
        }
        return bestKey
    }

    public func nearestKeyTokenId(px_train: Float, py_train: Float) -> Int64 {
        let char = nearestKeyChar(px: px_train, py: py_train)
        guard let asciiValue = char.asciiValue else { return 1 }
        return Int64(asciiValue) - Int64(Character("a").asciiValue!) + KeyboardGeometry.CHAR_TOKEN_OFFSET
    }

    public func getAlphabetAreaBounds() -> (Float, Float) {
        guard let qKey = keyMap["q"], let mKey = keyMap["m"] else { return (0, trainHeight) }
        
        let rowHeight = (mKey.cy - qKey.cy) / 2.0
        let top = qKey.cy - rowHeight / 2.0
        let height = 3.0 * rowHeight
        
        return (max(top, 0), height)
    }

    private func scorePointToKey(px: Float, py: Float, key: Key) -> Float {
        var dxOut: Float = 0
        if px < key.left { dxOut = key.left - px }
        else if px > key.right { dxOut = px - key.right }
        
        var dyOut: Float = 0
        if py < key.top { dyOut = key.top - py }
        else if py > key.bottom { dyOut = py - key.bottom }
        
        let inside = (dxOut == 0 && dyOut == 0)

        let normDx = dxOut / max(key.width, 1.0)
        let normDy = dyOut / max(key.height, 1.0)
        let outsideCost = normDx * normDx + (normDy * KeyboardGeometry.VERTICAL_PENALTY) * (normDy * KeyboardGeometry.VERTICAL_PENALTY)

        let cDx = (px - key.cx) / max(key.width, 1.0)
        let cDy = (py - key.cy) / max(key.height, 1.0)
        let centerCost = cDx * cDx + (cDy * KeyboardGeometry.VERTICAL_PENALTY) * (cDy * KeyboardGeometry.VERTICAL_PENALTY)

        return inside ? centerCost * 0.25 : centerCost + outsideCost * KeyboardGeometry.OUTSIDE_HITBOX_PENALTY
    }

    public func nearestTopKKeyTokens(px: Float, py: Float, k: Int = 3) -> [Int64] {
        let cx = min(max(px, 0), trainWidth)
        let cy = min(max(py, 0), trainHeight)

        var keysWithDist = allKeys.compactMap { key -> (Key, Float)? in
            if key.isSpecial || key.char < "a" || key.char > "z" { return nil }
            let dx = cx - key.cx
            let dy = cy - key.cy
            return (key, dx * dx + dy * dy)
        }
        
        keysWithDist.sort { $0.1 < $1.1 }
        let topK = Array(keysWithDist.prefix(k))
        
        var tokens = Array(repeating: Int64(1), count: k)
        for i in 0..<topK.count {
            let char = Character(topK[i].0.char.lowercased())
            if let ascii = char.asciiValue {
                tokens[i] = Int64(ascii) - Int64(Character("a").asciiValue!) + KeyboardGeometry.CHAR_TOKEN_OFFSET
            }
        }
        return tokens
    }

    public func getKeyCenter(_ char: Character) -> (Float, Float)? {
        guard let key = keyMap[Character(char.lowercased())] else { return nil }
        return (key.cx, key.cy)
    }
}

import UIKit

public class KeyboardViewController: UIInputViewController {

    // MARK: - Core Engines
    private var swipeDecoder: SwipeDecoder!
    private var xlitDecoder: XlitDecoder!
    private var dictionaryManager: DictionaryManager!
    private var keyboardGeometry: KeyboardGeometry!
    
    // MARK: - UI Components
    private var swipeView: SwipeView!
    private var keyboardContainer: UIView!
    private var suggestionBar: UIStackView!
    
    // MARK: - State
    private var currentLanguage: String = "hindi"
    private var isHindiMode: Bool = true
    private var activeSwipePoints = [[Float]]()
    private var touchStartTime: TimeInterval = 0
    private var isSwiping = false
    private var activeTouch: UITouch?
    private var lastKeyChar: Character?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        setupEngines()
        setupUI()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Update geometry based on actual layout size
        keyboardGeometry.setDimensions(w: Float(keyboardContainer.bounds.width), h: Float(keyboardContainer.bounds.height))
    }
    
    private func setupEngines() {
        dictionaryManager = DictionaryManager()
        dictionaryManager.loadDictionary(langId: currentLanguage)
        
        keyboardGeometry = KeyboardGeometry()
        
        swipeDecoder = SwipeDecoder(dictionary: dictionaryManager)
        swipeDecoder.setGeometry(keyboardGeometry)
        swipeDecoder.setLanguage(currentLanguage)
        
        xlitDecoder = XlitDecoder()
        xlitDecoder.setLanguage(currentLanguage)
        
        if let lang = KeyboardConstants.LANGUAGES.first(where: { $0.id == currentLanguage }) {
            isHindiMode = lang.isHindiMode
        }
    }
    
    private func setupUI() {
        self.view.backgroundColor = ThemeManager.shared.keyboardBackgroundColor
        
        suggestionBar = UIStackView()
        suggestionBar.axis = .horizontal
        suggestionBar.distribution = .fillEqually
        suggestionBar.backgroundColor = ThemeManager.shared.suggestionBackgroundColor
        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(suggestionBar)
        
        keyboardContainer = UIView()
        keyboardContainer.backgroundColor = .clear
        keyboardContainer.isUserInteractionEnabled = true
        keyboardContainer.isMultipleTouchEnabled = true
        keyboardContainer.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(keyboardContainer)
        
        swipeView = SwipeView()
        swipeView.translatesAutoresizingMaskIntoConstraints = false
        keyboardContainer.addSubview(swipeView)
        
        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: self.view.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            suggestionBar.heightAnchor.constraint(equalToConstant: KeyboardConstants.SUGGESTION_BAR_HEIGHT_DP),
            
            keyboardContainer.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            keyboardContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            keyboardContainer.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            swipeView.topAnchor.constraint(equalTo: keyboardContainer.topAnchor),
            swipeView.leadingAnchor.constraint(equalTo: keyboardContainer.leadingAnchor),
            swipeView.trailingAnchor.constraint(equalTo: keyboardContainer.trailingAnchor),
            swipeView.bottomAnchor.constraint(equalTo: keyboardContainer.bottomAnchor)
        ])
        
        drawKeyboard()
    }
    
    private func drawKeyboard() {
        // Here we would create UIButtons for each key based on KeyboardGeometry.
        // For simplicity in this structure, we rely on touch handling mapped to KeyboardGeometry.
        // A fully polished UI would render CAShapeLayers or UIButtons.
        
        for key in keyboardGeometry.getAllKeys() {
            let keyView = UIView()
            keyView.backgroundColor = key.isSpecial ? ThemeManager.shared.specialKeyBackgroundColor : ThemeManager.shared.keyBackgroundColor
            keyView.layer.cornerRadius = KeyboardConstants.KEY_CORNER_RADIUS_DP
            
            let label = UILabel()
            label.text = key.isSpecial ? (key.specialName == "space" ? "Space" : (key.specialName == "backspace" ? "⌫" : (key.specialName == "enter" ? "⏎" : "⇧"))) : String(key.char)
            label.textColor = ThemeManager.shared.keyTextColor
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 20)
            
            keyView.addSubview(label)
            label.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: keyView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: keyView.centerYAnchor)
            ])
            
            // Note: Since KeyboardGeometry coordinates are based on training size, 
            // we'd need to scale them here based on view size.
            // This requires overriding layoutSubviews.
            // For now, this is a placeholder renderer.
        }
    }
    
    // MARK: - Touch Handling
    
    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        activeTouch = touch
        
        let loc = touch.location(in: keyboardContainer)
        activeSwipePoints.removeAll()
        
        let scaledX = Float(loc.x) * keyboardGeometry.scaleX
        let scaledY = Float(loc.y) * keyboardGeometry.scaleY
        activeSwipePoints.append([scaledX, scaledY, 0.0])
        
        swipeView.clearTrail()
        swipeView.addPoint(loc)
        
        touchStartTime = touch.timestamp
        isSwiping = false
        lastKeyChar = keyboardGeometry.tapKeyChar(tx: scaledX, ty: scaledY)
    }
    
    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        
        let loc = touch.location(in: keyboardContainer)
        let scaledX = Float(loc.x) * keyboardGeometry.scaleX
        let scaledY = Float(loc.y) * keyboardGeometry.scaleY
        let timeMs = Float((touch.timestamp - touchStartTime) * 1000)
        
        activeSwipePoints.append([scaledX, scaledY, timeMs])
        swipeView.addPoint(loc)
        
        if activeSwipePoints.count > KeyboardConstants.MIN_POINTS_FOR_SWIPE {
            isSwiping = true
        }
    }
    
    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        
        swipeView.clearTrail()
        
        if isSwiping {
            handleSwipeComplete()
        } else {
            handleTap(touch: touch)
        }
        
        activeTouch = nil
        isSwiping = false
        activeSwipePoints.removeAll()
    }
    
    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        swipeView.clearTrail()
        activeTouch = nil
        isSwiping = false
        activeSwipePoints.removeAll()
    }
    
    // MARK: - Input Processing
    
    private func handleTap(touch: UITouch) {
        let loc = touch.location(in: keyboardContainer)
        let scaledX = Float(loc.x) * keyboardGeometry.scaleX
        let scaledY = Float(loc.y) * keyboardGeometry.scaleY
        
        if let special = keyboardGeometry.hitTestSpecial(tx: scaledX, ty: scaledY) {
            handleSpecialKey(special)
        } else if let char = keyboardGeometry.tapKeyChar(tx: scaledX, ty: scaledY) {
            typeCharacter(String(char))
        }
    }
    
    private func handleSwipeComplete() {
        guard activeSwipePoints.count >= KeyboardConstants.MIN_POINTS_FOR_SWIPE else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let result = self.swipeDecoder.decodeDetailed(rawPoints: self.activeSwipePoints)
            let bestWord = result.bestWord
            
            DispatchQueue.main.async {
                if !bestWord.isEmpty {
                    self.commitWord(bestWord)
                }
            }
        }
    }
    
    private func handleSpecialKey(_ name: String) {
        switch name {
        case "space":
            typeCharacter(" ")
        case "backspace":
            self.textDocumentProxy.deleteBackward()
        case "enter":
            typeCharacter("\n")
        default:
            print("Unhandled special key: \(name)")
        }
    }
    
    private func typeCharacter(_ char: String) {
        self.textDocumentProxy.insertText(char)
        // Autocorrect or transliterate based on language mode could be triggered here
    }
    
    private func commitWord(_ word: String) {
        if isHindiMode {
            // In Hindi mode, if the swipe decoded Roman chars, transliterate it.
            // (Assuming swipe model is trained on romanized skeleton of the word)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let transliterated = self.xlitDecoder.transliterate(word)
                
                DispatchQueue.main.async {
                    self.textDocumentProxy.insertText(transliterated.isEmpty ? word + " " : transliterated + " ")
                }
            }
        } else {
            self.textDocumentProxy.insertText(word + " ")
        }
    }
}

import Foundation

// Assuming onnxruntime_objc is available via Swift Package Manager or CocoaPods
// import onnxruntime_objc

public class XlitDecoder {

    private static let TAG = "XlitDecoder"
    private static let ASSET_XLIT_DIR = "models/xlit"
    private static let MAX_OUTPUT_LENGTH = 50
    private static let MAX_INPUT_LENGTH = 100

    private static let BOS_IDX = 0
    private static let PAD_IDX = 1
    private static let EOS_IDX = 2
    private static let UNK_IDX = 3

    private static let LANG_TAGS: [String: String] = [
        "hindi": "__hi__",
        "tamil": "__ta__",
        "marathi": "__mr__",
        "hinglish": "__hi__",
        "marathilish": "__mr__",
        "telugu": "__te__",
        "telugulish": "__te__"
    ]

    private var currentLangTag = "__hi__"

    public func setLanguage(_ langId: String) {
        currentLangTag = XlitDecoder.LANG_TAGS[langId] ?? "__hi__"
        print("\(XlitDecoder.TAG): Transliteration language set to: \(langId) (tag: \(currentLangTag))")
    }

    private let PHONETIC_OVERRIDES: [String: String] = [
        "tum": "तुम",
        "tu": "तू",
        "hai": "है",
        "hain": "हैं",
        "namaskar": "नमस्कार",
        "namashkar": "नमस्कार"
    ]

    // private var env: ORTEnv?
    // private var encoderSession: ORTSession?
    // private var decoderSession: ORTSession?

    private var srcVocab = [String]()
    private var tgtVocab = [String]()
    private var srcTokenToIdx = [String: Int]()

    private var initializationError: String? = nil

    public var isReady: Bool {
        // return encoderSession != nil && decoderSession != null && initializationError == nil
        return initializationError == nil
    }

    public init() {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            // env = try ORTEnv(loggingLevel: .warning)
            try loadVocabulary()
            try loadModels()
            
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("\(XlitDecoder.TAG): ✓ XlitDecoder initialized in \(String(format: "%.0f", elapsed))ms (src=\(srcVocab.count), tgt=\(tgtVocab.count))")
        } catch {
            initializationError = error.localizedDescription
            print("\(XlitDecoder.TAG): ✗ XlitDecoder initialization failed: \(error)")
        }
    }

    private func loadVocabulary() throws {
        let vocabUrl = Bundle.main.url(forResource: "vocab", withExtension: "json", subdirectory: XlitDecoder.ASSET_XLIT_DIR)
        guard let url = vocabUrl else {
            throw NSError(domain: "XlitDecoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "vocab.json not found"])
        }
        
        let data = try Data(contentsOf: url)
        guard let root = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            throw NSError(domain: "XlitDecoder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON"])
        }
        
        if let srcArray = root["src"] as? [String] {
            for (i, token) in srcArray.enumerated() {
                srcVocab.append(token)
                srcTokenToIdx[token] = i
            }
        }
        
        if let tgtArray = root["tgt"] as? [String] {
            for token in tgtArray {
                tgtVocab.append(token)
            }
        }
    }

    private func loadModels() throws {
        // let encoderUrl = Bundle.main.url(forResource: "indicxlit_encoder", withExtension: "onnx", subdirectory: XlitDecoder.ASSET_XLIT_DIR)
        // encoderSession = try ORTSession(env: env!, modelPath: encoderUrl!.path, sessionOptions: nil)
        
        // let decoderUrl = Bundle.main.url(forResource: "indicxlit_decoder_v2", withExtension: "onnx", subdirectory: XlitDecoder.ASSET_XLIT_DIR)
        // decoderSession = try ORTSession(env: env!, modelPath: decoderUrl!.path, sessionOptions: nil)
    }

    public func transliterate(_ word: String) -> String {
        let w = word.lowercased()
        if let override = PHONETIC_OVERRIDES[w] {
            return override
        }
        return runTransliteration(text: w)
    }

    private func runTransliteration(text: String) -> String {
        if !isReady {
            print("\(XlitDecoder.TAG): Decoder not ready: \(initializationError ?? "")")
            return ""
        }

        let input = text.lowercased().trimmingCharacters(in: .whitespaces)
        if input.isEmpty { return "" }

        if input.count > XlitDecoder.MAX_INPUT_LENGTH {
            print("\(XlitDecoder.TAG): Input too long, truncating")
            return transliterate(String(input.prefix(XlitDecoder.MAX_INPUT_LENGTH)))
        }

        do {
            return try greedyDecode(text: input)
        } catch {
            print("\(XlitDecoder.TAG): Transliteration failed for '\(input)': \(error)")
            return ""
        }
    }

    public func transliterateAll(words: [String]) -> [String] {
        return words.map { transliterate($0) }
    }

    private func tokenizeSource(_ text: String) -> [Int64] {
        var tokens = [Int64]()
        
        let langTagIdx = srcTokenToIdx[currentLangTag] ?? XlitDecoder.UNK_IDX
        tokens.append(Int64(langTagIdx))
        
        for char in text {
            let charStr = String(char)
            let idx = srcTokenToIdx[charStr] ?? XlitDecoder.UNK_IDX
            tokens.append(Int64(idx))
        }
        
        tokens.append(Int64(XlitDecoder.EOS_IDX))
        return tokens
    }

    private func detokenize(_ tokenIds: [Int]) -> String {
        var result = ""
        for i in 0..<tokenIds.count {
            if i == 0 { continue }
            let idx = tokenIds[i]
            if idx == XlitDecoder.EOS_IDX { break }
            if idx == XlitDecoder.BOS_IDX || idx == XlitDecoder.PAD_IDX || idx == XlitDecoder.UNK_IDX { continue }
            
            if idx >= 0 && idx < tgtVocab.count {
                result.append(tgtVocab[idx])
            }
        }
        return result
    }

    private func greedyDecode(text: String) throws -> String {
        // ONNX EXECUTION PLACEHOLDER
        // Since we cannot run ONNX without the ORT library loaded natively, 
        // this is a stub of the decoding loop logic.
        
        let srcIds = tokenizeSource(text)
        
        // let encoderInputs = ["src_tokens": srcIdsTensor]
        // let encoderMemory = encoderSession.run(encoderInputs)["encoder_out"]
        
        var outputTokens = [XlitDecoder.EOS_IDX]
        
        // for step in 0..<XlitDecoder.MAX_OUTPUT_LENGTH {
        //     let nextToken = decoderStep(encoderMemory, outputTokens)
        //     if nextToken == XlitDecoder.EOS_IDX { break }
        //     outputTokens.append(nextToken)
        // }
        
        // Return original text as a fallback when ONNX isn't compiled in
        return text 
    }

    private func logSoftmax(_ logits: [Float]) -> [Float] {
        var maxVal = Float.greatestFiniteMagnitude * -1
        for v in logits { if v > maxVal { maxVal = v } }
        
        var expSum: Double = 0
        for v in logits {
            expSum += exp(Double(v - maxVal))
        }
        let logExpSum = log(expSum)
        
        return logits.map { Float(Double($0 - maxVal) - logExpSum) }
    }
}

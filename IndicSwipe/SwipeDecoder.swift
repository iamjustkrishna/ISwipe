import Foundation

// Assuming onnxruntime_objc is available via Swift Package Manager or CocoaPods
// import onnxruntime_objc

public class SwipeDecoder {

    public struct Candidate {
        public let word: String
        public let score: Float
        
        public init(word: String, score: Float) {
            self.word = word
            self.score = score
        }
    }

    public struct DecodeResult {
        public let candidates: [Candidate]
        public let decodeTimeMs: Int64
        public let keyPath: String
        public let modelLogProbs: [String: Float]
        
        public init(candidates: [Candidate], decodeTimeMs: Int64, keyPath: String, modelLogProbs: [String: Float] = [:]) {
            self.candidates = candidates
            self.decodeTimeMs = decodeTimeMs
            self.keyPath = keyPath
            self.modelLogProbs = modelLogProbs
        }
        
        public var bestWord: String {
            return candidates.first?.word ?? ""
        }
    }

    private static let TAG = "SwipeDecoder"
    private static let TARGET_POINTS = 150
    private static let RESAMPLE_COUNT = 40
    private static let D_MODEL = 256
    private static let VOCAB_SIZE = 30
    private static let SOS_IDX = 2
    private static let EOS_IDX = 3

    // ONNX Runtime objects (commented out until ORT is imported)
    // private var env: ORTEnv?
    // private var encoderSession: ORTSession?
    // private var decoderSession: ORTSession?

    internal var geometry: KeyboardGeometry?
    internal var dictionaryManager: DictionaryManager?

    private var currentLang: String = "hindi"

    public init() {
        do {
            // env = try ORTEnv(loggingLevel: .warning)
            loadModels(lang: "hindi")
        } catch {
            print("\(SwipeDecoder.TAG): Init Error - \(error)")
        }
    }

    public convenience init(dictionary: DictionaryManager) {
        self.init()
        self.dictionaryManager = dictionary
    }

    private func loadModels(lang: String) {
        do {
            let folder: String
            if lang.localizedCaseInsensitiveContains("tamil") { folder = "tamil" }
            else if lang.localizedCaseInsensitiveContains("marathi") { folder = "marathi" }
            else { folder = "hindi" }
            
            if folder == currentLang /* && encoderSession != nil */ { return }
            
            // encoderSession = nil
            // decoderSession = nil
            
            let encoderPath = "models/swipe/\(folder)/swipe_model_character_quant.onnx"
            let decoderPath = "models/swipe/\(folder)/swipe_decoder_character_quant.onnx"
            
            // Load from Bundle
            // if let encUrl = Bundle.main.url(forResource: ..., withExtension: "onnx") {
            //     encoderSession = try ORTSession(env: env!, modelPath: encUrl.path, sessionOptions: nil)
            // }
            
            currentLang = folder
            print("\(SwipeDecoder.TAG): 🚀 Neural Core Calibrated for \(folder)")
        } catch {
            print("\(SwipeDecoder.TAG): Model Loading Error (\(lang)) - \(error)")
        }
    }

    public func setGeometry(_ geom: KeyboardGeometry) { self.geometry = geom }
    public func setDictionary(_ dict: DictionaryManager?) { self.dictionaryManager = dict }
    
    public func setLanguage(_ lang: String) {
        print("\(SwipeDecoder.TAG): Language: \(lang)")
        loadModels(lang: lang)
    }

    public func decode(rawPoints: [[Float]]) -> [Candidate] {
        return decodeDetailed(rawPoints: rawPoints).candidates
    }

    public func decodeDetailed(rawPoints: [[Float]], prevWord: String = "") -> DecodeResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        if rawPoints.isEmpty { return DecodeResult(candidates: [], decodeTimeMs: 0, keyPath: "") }

        let resampled = resampleTimeBased(points: rawPoints, intervalMs: KeyboardConstants.SAMPLING_CADENCE_MS)
        let activePoints = Array(resampled.prefix(SwipeDecoder.TARGET_POINTS))
        
        var trajData = [Float](repeating: 0, count: SwipeDecoder.TARGET_POINTS * 6)
        var keysData = [Int64](repeating: 0, count: SwipeDecoder.TARGET_POINTS)
        var maskData = [Bool](repeating: true, count: SwipeDecoder.TARGET_POINTS)
        
        var lastPoint = activePoints.first
        var lastVelX: Float = 0
        var lastVelY: Float = 0
        let activeCount = activePoints.count
        
        for i in 0..<SwipeDecoder.TARGET_POINTS {
            let p = i < activeCount ? activePoints[i] : nil
            if let p = p {
                let px = p[0]
                let py = p[1]
                let npx = px / KeyboardConstants.TRAIN_WIDTH
                let npy = py / KeyboardConstants.TRAIN_HEIGHT
                
                let nlastX = lastPoint?[0] != nil ? lastPoint![0] / KeyboardConstants.TRAIN_WIDTH : npx
                let nlastY = lastPoint?[1] != nil ? lastPoint![1] / KeyboardConstants.TRAIN_HEIGHT : npy
                
                var dt = p[2] - (lastPoint?[2] ?? p[2])
                if dt <= 0 { dt = KeyboardConstants.SAMPLING_CADENCE_MS }
                
                let vx = (npx - nlastX) / dt
                let vy = (npy - nlastY) / dt
                let ax = (vx - lastVelX) / dt
                let ay = (vy - lastVelY) / dt
                
                trajData[i*6+0] = npx
                trajData[i*6+1] = npy
                trajData[i*6+2] = max(-KeyboardConstants.FEATURE_CLIP_VAL, min(KeyboardConstants.FEATURE_CLIP_VAL, vx))
                trajData[i*6+3] = max(-KeyboardConstants.FEATURE_CLIP_VAL, min(KeyboardConstants.FEATURE_CLIP_VAL, vy))
                trajData[i*6+4] = max(-KeyboardConstants.FEATURE_CLIP_VAL, min(KeyboardConstants.FEATURE_CLIP_VAL, ax))
                trajData[i*6+5] = max(-KeyboardConstants.FEATURE_CLIP_VAL, min(KeyboardConstants.FEATURE_CLIP_VAL, ay))
                
                maskData[i] = false
                let char = geometry?.nearestKeyChar(px: px, py: py).lowercased().first ?? " "
                if let ascii = char.asciiValue {
                    let charIdx = Int(ascii) - Int(Character("a").asciiValue!)
                    keysData[i] = (charIdx >= 0 && charIdx <= 25) ? Int64(charIdx + 4) : 1
                } else {
                    keysData[i] = 1
                }
                
                lastPoint = p
                lastVelX = vx
                lastVelY = vy
            } else {
                keysData[i] = 0
                maskData[i] = true
            }
        }
        
        let keyPath = computeSkeletonPath(points: activePoints)
        
        // --- ONNX Execution Placeholder ---
        // let encoderInputs = ["trajectory_features": ..., "nearest_keys": ..., "src_mask": ...]
        // let memory = try encoderSession!.run(with: encoderInputs, outputNames: ["output"])["output"]
        
        // Since we cannot run ONNX without the ORT library, we simulate the phonetic beam search fallback
        // Normally, the ORT loop would populate `neuralGuess` here.
        let neuralGuess = "" 
        
        let sampledSwipe = samplePointsEquidistant(points: rawPoints, targetCount: 40)
        let pathPhysicalLength = calculateTotalPathDistanceRaw(points: rawPoints)
        let isExtremelyShort = pathPhysicalLength < KeyboardConstants.MIN_SWIPE_DISTANCE_PX * 1.5
        
        var finalCandidates = [Candidate]()

        if let dict = dictionaryManager {
            let candidatesFromDict = dict.findCandidates(anchors: neuralGuess, keyPath: keyPath, prevWord: "")
            let rescueWords = Array(Set(candidatesFromDict.map { $0.0 }))
            
            for word in rescueWords {
                guard let ideal = getIdealPath(word: word, targetCount: 40) else { continue }
                let rawDist = calculateShapeDistance(sampled: sampledSwipe, ideal: ideal)
                
                let freq = dict.getFrequency(word)
                var freqBonus: Float = 0
                var anchorPenalty: Float = 0
                
                if !word.isEmpty && !keyPath.isEmpty {
                    if word.first?.lowercased() != keyPath.first?.lowercased() { anchorPenalty += 500.0 }
                    if word.last?.lowercased() != keyPath.last?.lowercased() { anchorPenalty += 200.0 }
                }
                
                let spatialEditPenalty = calculateKeyboardEditDistance(s1: word, s2: keyPath) * 30.0
                let physicalLength = calculatePhysicalPathLength(word: word)
                let spatialBonus = (physicalLength / 100.0) * 12.0
                
                var lengthGuardPenalty: Float = 0
                let lenRatio = !word.isEmpty ? Float(keyPath.count) / Float(word.count) : 1.0
                
                if keyPath.count <= 5 && word.count > keyPath.count + 3 {
                    lengthGuardPenalty += Float(word.count - keyPath.count) * 50.0
                }
                if keyPath.count >= 10 && lenRatio > 2.2 && word.count >= 4 {
                    lengthGuardPenalty += (lenRatio - 2.2) * 100.0
                }
                if word.count <= 3 && keyPath.count > word.count {
                    if !dict.vocabularyTrie.isSubsequenceOf(word: word, sequence: keyPath) {
                        lengthGuardPenalty += Float(keyPath.count - word.count) * 40.0
                    }
                }
                
                var finalScore = rawDist - freqBonus + anchorPenalty + spatialEditPenalty - spatialBonus + lengthGuardPenalty
                
                if dict.vocabularyTrie.isSubsequenceOf(word: word, sequence: neuralGuess) || 
                   dict.vocabularyTrie.isSubsequenceOf(word: neuralGuess, sequence: word) {
                    finalScore -= 60.0
                    if word.count > keyPath.count && word.count > 5 { finalScore -= 25.0 }
                }
                
                if word.count > keyPath.count && word.count >= 6 {
                    if dict.vocabularyTrie.isSubsequenceOf(word: keyPath, sequence: word) {
                        finalScore -= 35.0
                    }
                }
                
                if word.lowercased() == neuralGuess.lowercased() {
                    var neuralBonus: Float = keyPath.count <= 2 ? 40.0 : 120.0
                    if lenRatio > 2.5 { neuralBonus *= 0.4 }
                    finalScore -= neuralBonus
                }
                
                if isExtremelyShort && word.count > 2 {
                    finalScore += 180.0
                }
                
                finalCandidates.append(Candidate(word: word, score: -finalScore))
            }
        }
        
        if !neuralGuess.isEmpty && !finalCandidates.contains(where: { $0.word == neuralGuess }) {
            finalCandidates.append(Candidate(word: neuralGuess, score: -1000.0))
        }

        let sorted = finalCandidates.sorted { $0.score > $1.score }.prefix(6)
        
        let elapsedMs = Int64((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
        return DecodeResult(candidates: Array(sorted), decodeTimeMs: elapsedMs, keyPath: keyPath)
    }

    private func samplePointsEquidistant(points: [[Float]], targetCount: Int) -> [(Float, Float)] {
        if points.isEmpty { return [] }
        var distances = [Float]()
        var totalDist: Float = 0
        distances.append(0)
        
        for i in 1..<points.count {
            let dx = points[i][0] - points[i-1][0]
            let dy = points[i][1] - points[i-1][1]
            totalDist += sqrt(dx * dx + dy * dy)
            distances.append(totalDist)
        }
        
        var result = [(Float, Float)]()
        for i in 0..<targetCount {
            let target = (Float(i) / Float(targetCount - 1)) * totalDist
            var low = 0
            var high = distances.count - 1
            while high - low > 1 {
                let mid = (low + high) / 2
                if distances[mid] < target { low = mid } else { high = mid }
            }
            let denom = distances[high] - distances[low]
            let t = denom > 0 ? (target - distances[low]) / denom : 0
            let x = points[low][0] + t * (points[high][0] - points[low][0])
            let y = points[low][1] + t * (points[high][1] - points[low][1])
            result.append((x, y))
        }
        return result
    }

    private func getIdealPath(word: String, targetCount: Int) -> [(Float, Float)]? {
        guard let geom = geometry else { return nil }
        var points = [[Float]]()
        for char in word {
            guard let center = geom.getKeyCenter(char) else { return nil }
            points.append([center.0, center.1])
        }
        return samplePointsEquidistant(points: points, targetCount: targetCount)
    }

    private func calculateShapeDistance(sampled: [(Float, Float)], ideal: [(Float, Float)]) -> Float {
        var sum: Float = 0
        let count = min(sampled.count, ideal.count)
        for i in 0..<count {
            let dx = sampled[i].0 - ideal[i].0
            let dy = sampled[i].1 - ideal[i].1
            sum += sqrt(dx * dx + dy * dy)
        }
        return count > 0 ? sum / Float(count) : 0
    }

    private func resampleTimeBased(points: [[Float]], intervalMs: Float) -> [[Float]] {
        if points.isEmpty { return [] }
        var result = [[Float]]()
        
        var nextTargetTime = Double(points[0][2])
        var i = 0
        var loopCount = 0
        var stationaryCount = 0
        let maxLoops = 2000
        
        while i < points.count - 1 && loopCount < maxLoops {
            loopCount += 1
            let p1 = points[i]
            let p2 = points[i+1]
            let t1 = Double(p1[2])
            let t2 = Double(p2[2])
            
            if nextTargetTime >= t1 && nextTargetTime <= t2 {
                let t = t2 != t1 ? (nextTargetTime - t1) / (t2 - t1) : 0
                let x = p1[0] + Float(t) * (p2[0] - p1[0])
                let y = p1[1] + Float(t) * (p2[1] - p1[1])
                
                let isStationary = !result.isEmpty && abs(x - result.last![0]) < 0.1 && abs(y - result.last![1]) < 0.1
                if isStationary { stationaryCount += 1 } else { stationaryCount = 0 }
                
                if stationaryCount < 8 {
                    result.append([x, y, Float(nextTargetTime)])
                }
                nextTargetTime += Double(intervalMs)
            } else if nextTargetTime < t1 {
                nextTargetTime += Double(intervalMs)
            } else {
                i += 1
            }
        }
        
        if result.count < 2 || (points.last![2] - result.last![2]) > intervalMs / 2 {
            result.append(points.last!)
        }
        return result
    }

    private func computeSkeletonPath(points: [[Float]]) -> String {
        if points.count < 2 { return "" }
        var path = ""
        var lastChar: Character = " "
        
        let PAUSE_VEL_THRESHOLD: Float = 0.5
        let CORNER_DEG_THRESHOLD = 65.0
        
        for i in 0..<points.count {
            let p = points[i]
            guard let c = geometry?.nearestKeyChar(px: p[0], py: p[1]) else { continue }
            
            if i == 0 || i == points.count - 1 {
                if c != lastChar {
                    path.append(c)
                    lastChar = c
                }
                continue
            }
            
            let pPrev = points[i-1]
            let pNext = points[min(i+1, points.count-1)]
            
            let dx = p[0] - pPrev[0]
            let dy = p[1] - pPrev[1]
            let velocity = sqrt(dx * dx + dy * dy)
            
            var isCorner = false
            let v1x = p[0] - pPrev[0]
            let v1y = p[1] - pPrev[1]
            let v2x = pNext[0] - p[0]
            let v2y = pNext[1] - p[1]
            let dot = v1x * v2x + v1y * v2y
            let mag1 = sqrt(v1x * v1x + v1y * v1y)
            let mag2 = sqrt(v2x * v2x + v2y * v2y)
            
            if mag1 > 0.05 && mag2 > 0.05 {
                let angle = acos(max(-1.0, min(1.0, dot / (mag1 * mag2)))) * (180.0 / Float.pi)
                if angle > Float(CORNER_DEG_THRESHOLD) { isCorner = true }
            }
            
            if velocity < PAUSE_VEL_THRESHOLD || isCorner {
                if c != lastChar {
                    path.append(c)
                    lastChar = c
                }
            }
        }
        return path
    }

    private func calculateKeyboardEditDistance(s1: String, s2: String) -> Float {
        let a1 = Array(s1)
        let a2 = Array(s2)
        let n = a1.count
        let m = a2.count
        
        var dp = Array(repeating: Array(repeating: Float(0), count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = Float(i) }
        for j in 0...m { dp[0][j] = Float(j) }
        
        for i in 1...n {
            for j in 1...m {
                if a1[i-1] == a2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    let c1 = geometry?.getKeyCenter(a1[i-1])
                    let c2 = geometry?.getKeyCenter(a2[j-1])
                    let dist: Float
                    if let c1 = c1, let c2 = c2 {
                        let dx = c1.0 - c2.0
                        let dy = c1.1 - c2.1
                        dist = sqrt(dx * dx + dy * dy) / 50.0
                    } else {
                        dist = 1.0
                    }
                    
                    let insertionCost: Float = (i > 1 && a1[i-1] == a1[i-2]) ? 0.01 : 1.5
                    
                    dp[i][j] = min(dp[i-1][j] + insertionCost, dp[i][j-1] + 1.2, dp[i-1][j-1] + dist)
                }
            }
        }
        return dp[n][m]
    }

    private func calculatePhysicalPathLength(word: String) -> Float {
        var length: Float = 0
        let chars = Array(word)
        var centers = [(Float, Float)]()
        for char in chars {
            if let center = geometry?.getKeyCenter(char) { centers.append(center) }
        }
        if centers.count < 2 { return 0 }
        
        for i in 1..<centers.count {
            let dx = centers[i].0 - centers[i-1].0
            let dy = centers[i].1 - centers[i-1].1
            length += sqrt(dx * dx + dy * dy)
        }
        return length
    }

    private func calculateTotalPathDistanceRaw(points: [[Float]]) -> Float {
        var total: Float = 0
        if points.count < 2 { return 0 }
        for i in 1..<points.count {
            let dx = points[i][0] - points[i-1][0]
            let dy = points[i][1] - points[i-1][1]
            total += sqrt(dx * dx + dy * dy)
        }
        return total
    }
}

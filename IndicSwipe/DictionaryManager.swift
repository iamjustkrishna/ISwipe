import Foundation

public class DictionaryManager {
    
    private let trie = VocabularyTrie()
    public var vocabularyTrie: VocabularyTrie { return trie }

    private var isLoaded = false
    private let loadLock = NSLock()

    private var wordFrequencies = [String: Float]()
    private var kenlm: LanguageModel? = nil

    private static let TAG = "DictionaryManager"
    private static let VOCAB_FILE = "vocabulary.txt"

    private static let SCORE_EXACT_MATCH: Float = 100.0
    private static let SCORE_EDIT_DIST_1_BASE: Float = 180.0
    private static let SCORE_EDIT_DIST_2_BASE: Float = 120.0
    private static let SCORE_PREFIX_MATCH_BASE: Float = 90.0
    private static let SCORE_SUBSEQ_BASE: Float = 80.0

    private static let PENALTY_PER_EDIT_DIST_1: Float = 15.0
    private static let PENALTY_PER_EDIT_DIST_2: Float = 12.0
    private static let PENALTY_PER_EDIT_PREFIX: Float = 8.0
    
    private static var PENALTY_NOT_IN_KEYPATH: Float { abs(KeyboardConstants.PATH_LEN_MISMATCH_PENALTY) }
    private static var BONUS_DICT_WORD: Float { KeyboardConstants.DICTIONARY_BONUS }
    private static var BONUS_LENGTH_MATCH: Float { KeyboardConstants.LENGTH_REWARD_FACTOR }
    private static var HIGH_CONFIDENCE_THRESHOLD: Float { abs(KeyboardConstants.NEURAL_HIGH_CONFIDENCE_THRESHOLD) * 10.0 }

    private static let PENALTY_WEAK_LENGTH_MISMATCH: Float = 15.0
    private static let PENALTY_EXCESSIVE_PATH: Float = 45.0
    private static let PENALTY_LAST_KEY_MISMATCH: Float = 50.0

    private static let BONUS_SUBSEQUENCE: Float = 25.0
    private static let BONUS_FIRST_LAST_MATCH: Float = 15.0
    private static let BONUS_ANCHOR_SUBSEQ: Float = 20.0
    private static let BONUS_KEYPATH_SUBSEQ_EXTRA: Float = 20.0
    private static let BONUS_WEAK_VOCAB_MODEL: Float = 15.0
    private static let BONUS_EXACT_ANCHOR_MODEL: Float = 40.0
    private static let BONUS_EXACT_PATH_MODEL: Float = 35.0
    private static let BONUS_VALID_MODEL_WORD: Float = 120.0
    private static let BONUS_SKELETON_MATCH: Float = 25.0
    private static let BONUS_DIRECT_SIMILARITY_SCALE: Float = 50.0
    private static let BONUS_BIGRAM_MATCH: Float = 65.0
    private static let BONUS_UNIGRAM_SCALE: Float = 0.0

    public init() {}

    private func mergeScore(in dict: inout [String: Float], word: String, newScore: Float) {
        if let existing = dict[word] {
            if newScore > existing { dict[word] = newScore }
        } else {
            dict[word] = newScore
        }
    }

    private func consonantSkeleton(_ s: String) -> String {
        let consonants: Set<Character> = ["b", "c", "d", "f", "g", "h", "j", "k", "l", "m", "n", "p", "q", "r", "s", "t", "v", "w", "x", "y", "z"]
        return String(s.lowercased().filter { consonants.contains($0) })
    }

    private func normalizedSimilarity(_ a: String, _ b: String) -> Float {
        if a.isEmpty && b.isEmpty { return 1.0 }
        if a.isEmpty || b.isEmpty { return 0.0 }
        let dist = Float(trie.editDistance(a, b))
        let maxLen = Float(max(max(a.count, b.count), 1))
        return max(0.0, min(1.0, 1.0 - (dist / maxLen)))
    }

    public func setLanguage(langId: String) {
        loadLock.lock()
        defer { loadLock.unlock() }

        isLoaded = false
        trie.clear()
        wordFrequencies.removeAll()
        
        kenlm?.close()
        kenlm = nil

        let lmFile = "models/swipe/\(langId)/roman_lm.klm"
        kenlm = LanguageModel(assetPath: lmFile, modelName: "\(langId)_roman_lm.klm")
        kenlm?.init()
        
        loadDictionaryUnsafe(langId: langId)
    }

    @discardableResult
    public func loadDictionary(langId: String = "hindi") -> Bool {
        if isLoaded { return true }
        loadLock.lock()
        defer { loadLock.unlock() }
        if isLoaded { return true }
        return loadDictionaryUnsafe(langId: langId)
    }

    private func loadDictionaryUnsafe(langId: String) -> Bool {
        let startTime = CFAbsoluteTimeGetCurrent()
        let basePath = "models/swipe/\(langId)"
        let vocabPath = "\(basePath)/\(DictionaryManager.VOCAB_FILE)"
        
        // Split path to find file in main bundle
        let parts = vocabPath.components(separatedBy: "/")
        guard let name = parts.last?.components(separatedBy: ".").first,
              let ext = parts.last?.components(separatedBy: ".").last,
              let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: Array(parts.dropLast()).joined(separator: "/")) else {
            print("\(DictionaryManager.TAG): Error loading dictionary for '\(langId)': Missing file")
            return false
        }
        
        do {
            let data = try String(contentsOf: url, encoding: .utf8)
            let lines = data.components(separatedBy: .newlines)
            
            for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                let tokens = line.components(separatedBy: " ")
                if tokens.count >= 2 {
                    let word = tokens[0].lowercased()
                    let freq = Float(tokens[1]) ?? 1.0
                    trie.addWord(word)
                    wordFrequencies[word] = freq
                } else {
                    let word = line.trimmingCharacters(in: .whitespaces).lowercased()
                    trie.addWord(word)
                    wordFrequencies[word] = 1.0
                }
            }
            
            isLoaded = true
            let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            print("\(DictionaryManager.TAG): Dictionary loaded for '\(langId)': \(trie.wordCount) words in \(String(format: "%.0f", elapsed))ms")
            return true
            
        } catch {
            print("\(DictionaryManager.TAG): Error loading dictionary for '\(langId)': \(error)")
            return false
        }
    }

    public func isValidPrefix(_ prefix: String) -> Bool { return trie.hasPrefix(prefix.lowercased()) }
    public func isCompleteWord(_ word: String) -> Bool { return trie.containsWord(word.lowercased()) }
    public func getFrequency(_ word: String) -> Float { return wordFrequencies[word.lowercased()] ?? 0.0 }
    
    public func getAllowedNextChars(prefix: String) -> Set<Character> { return trie.getAllowedNextChars(for: prefix.lowercased()) }
    public func getTrie() -> VocabularyTrie { return trie }

    public func findCandidates(anchors: String, keyPath: String, prevWord: String = "") -> [(String, Float)] {
        if !isLoaded || anchors.isEmpty { return [] }

        var candidates = [String: Float]()
        let query = anchors.lowercased()
        let path = keyPath.isEmpty ? query : keyPath.lowercased()

        // 1. Exact Match
        if trie.containsWord(query) {
            candidates[query] = DictionaryManager.SCORE_EXACT_MATCH
        }

        // 2. Fuzzy Matching
        let maxFuzzyResults = path.isEmpty ? 5 : 250
        let maxFuzzyDist = query.count <= 3 ? 1 : (query.count <= 6 ? 2 : 3)
        
        let fuzzy = trie.findSimilarWords(query: query, maxDist: maxFuzzyDist, maxResults: maxFuzzyResults)
        for result in fuzzy {
            let score: Float
            if result.distance == 0 { score = DictionaryManager.SCORE_EXACT_MATCH }
            else if result.distance == 1 { score = DictionaryManager.SCORE_EDIT_DIST_1_BASE - Float(result.distance) * DictionaryManager.PENALTY_PER_EDIT_DIST_1 }
            else { score = DictionaryManager.SCORE_EDIT_DIST_2_BASE - Float(result.distance) * DictionaryManager.PENALTY_PER_EDIT_DIST_2 }
            mergeScore(in: &candidates, word: result.word, newScore: score)
        }

        // 3. Prefix Matching
        if candidates.count < maxFuzzyResults {
            let prefixLen = max(1, min(query.count / 2, 3))
            let prefix = String(query.prefix(prefixLen))
            let prefixWords = trie.wordsWithPrefix(prefix, maxResults: 10)
            for word in prefixWords {
                if candidates[word] != nil { continue }
                let dist = trie.editDistance(query, word)
                let score = DictionaryManager.SCORE_PREFIX_MATCH_BASE - Float(dist) * DictionaryManager.PENALTY_PER_EDIT_PREFIX
                mergeScore(in: &candidates, word: word, newScore: score)
            }
        }

        // 4. Subsequence Matching
        if path.count >= 2 {
            let isTap = query == path
            let subseqWords = trie.findSubsequenceMatches(sequence: path, minLength: 2, maxLength: query.count + 4, maxResults: isTap ? 10 : 350)
            for word in subseqWords {
                let dist = trie.editDistance(query, word)
                let penalty: Float = isTap ? 3.0 : 1.5
                let score = DictionaryManager.SCORE_SUBSEQ_BASE - min(Float(dist) * penalty, 40.0)
                mergeScore(in: &candidates, word: word, newScore: score)
            }
        }

        applyBonuses(&candidates, anchors: query, keyPath: path, prevWord: prevWord)

        return candidates.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }.prefix(40).map { $0 }
    }

    private func applyBonuses(_ candidates: inout [String: Float], anchors: String, keyPath: String, prevWord: String) {
        if candidates.isEmpty { return }
        let anchorSkeleton = consonantSkeleton(anchors)
        let prevWordLower = prevWord.lowercased()
        let pathLower = keyPath.lowercased()

        for (word, score) in candidates {
            var adjustedScore = score

            if trie.containsWord(word) { adjustedScore += DictionaryManager.BONUS_DICT_WORD }

            if !keyPath.isEmpty && trie.isSubsequenceOf(word: word, sequence: keyPath) {
                adjustedScore += DictionaryManager.BONUS_SUBSEQUENCE
            }

            let lengthDiff = abs(word.count - anchors.count)
            if lengthDiff == 0 { adjustedScore += DictionaryManager.BONUS_LENGTH_MATCH }
            else if lengthDiff == 1 { adjustedScore += DictionaryManager.BONUS_LENGTH_MATCH * 0.7 }
            else if lengthDiff == 2 { adjustedScore += DictionaryManager.BONUS_LENGTH_MATCH * 0.4 }
            else if lengthDiff >= 4 { adjustedScore -= DictionaryManager.PENALTY_WEAK_LENGTH_MISMATCH }

            if !word.isEmpty && !anchors.isEmpty {
                let firstMatch = word.first == anchors.first
                let lastMatch = word.last == anchors.last
                if firstMatch && lastMatch { adjustedScore += DictionaryManager.BONUS_FIRST_LAST_MATCH }
                else if firstMatch || lastMatch { adjustedScore += DictionaryManager.BONUS_FIRST_LAST_MATCH * 0.6 }
            }

            if trie.isSubsequenceOf(word: anchors, sequence: word) || trie.isSubsequenceOf(word: word, sequence: anchors) {
                adjustedScore += DictionaryManager.BONUS_ANCHOR_SUBSEQ
            }

            let directSim = normalizedSimilarity(anchors, word)
            adjustedScore += directSim * DictionaryManager.BONUS_DIRECT_SIMILARITY_SCALE

            let wordSkeleton = consonantSkeleton(word)
            if !anchorSkeleton.isEmpty && !wordSkeleton.isEmpty {
                let skeletonSim = normalizedSimilarity(anchorSkeleton, wordSkeleton)
                adjustedScore += skeletonSim * DictionaryManager.BONUS_SKELETON_MATCH
            }

            if !keyPath.isEmpty {
                let pathSet = Set(keyPath)
                let wordPathChars = String(word.filter { pathSet.contains($0) })
                let anchorPathChars = String(anchors.filter { pathSet.contains($0) })
                let pathSim = normalizedSimilarity(anchorPathChars, wordPathChars)
                adjustedScore += pathSim * 6.0
            }

            if !prevWordLower.isEmpty {
                let lmScore = kenlm?.getBigramScore(prevWord: prevWordLower, currentWord: word) ?? -100.0
                if lmScore > -50.0 {
                    adjustedScore += DictionaryManager.BONUS_BIGRAM_MATCH + (lmScore * 20.0)
                }
            }

            if pathLower.count > 5 {
                let wordChars = Set(word.lowercased())
                var coveredCount = 0
                for char in pathLower { if wordChars.contains(char) { coveredCount += 1 } }
                let coverageRatio = Float(coveredCount) / Float(pathLower.count)
                
                if coverageRatio > 0.7 { adjustedScore += 40.0 }
                if word.count < 5 && coverageRatio < 0.3 && pathLower.count > 15 {
                    adjustedScore -= 180.0
                }
            }

            let lenDiff = abs(word.count - pathLower.count)
            if lenDiff > 10 && pathLower.count > 15 {
                adjustedScore -= Float(lenDiff) * 15.0
            }

            if !word.isEmpty && !anchors.isEmpty {
                if word.first?.lowercased() == anchors.first?.lowercased() {
                    adjustedScore += 80.0
                } else {
                    adjustedScore -= 120.0
                }
            }

            if anchors.count >= 2 && word.count > anchors.count + 2 && word.hasPrefix(String(anchors.prefix(2))) {
                adjustedScore += 40.0
            }

            let unigramFreq = wordFrequencies[word] ?? 1.0
            let freqBoost = 0.0 // Currently disabled
            adjustedScore += Float(freqBoost)

            candidates[word] = adjustedScore
        }
    }

    public func getHighConfidenceMatch(candidates: [(String, Float)]) -> String? {
        if candidates.isEmpty { return nil }
        let top = candidates[0]
        if top.1 < DictionaryManager.HIGH_CONFIDENCE_THRESHOLD { return nil }
        if candidates.count >= 2 {
            let gap = top.1 - candidates[1].1
            if gap < 20.0 { return nil }
        }
        return top.0
    }

    public func pickBestResult(anchors: String, keyPath: String, vocabCandidates: [(String, Float)], modelCandidates: [(String, Float)]) -> String {
        var scored = [String: Float]()
        for (word, vocabScore) in vocabCandidates { scored[word] = vocabScore }

        let anchorLower = anchors.lowercased()
        let pathLower = keyPath.lowercased()

        for (modelWord, neuralLogit) in modelCandidates {
            let normalizedModel = modelWord.lowercased()
            let isValidWord = isCompleteWord(normalizedModel)
            let simToAnchors = anchors.isEmpty ? 1.0 : normalizedSimilarity(anchorLower, normalizedModel)
            let simToPath = normalizedSimilarity(pathLower, normalizedModel)

            let exactAnchorBonus = (normalizedModel == anchorLower) ? DictionaryManager.BONUS_EXACT_ANCHOR_MODEL : 0.0
            let exactPathBonus = (normalizedModel == pathLower) ? DictionaryManager.BONUS_EXACT_PATH_MODEL : 0.0

            let weightedNeural = neuralLogit * KeyboardConstants.NEURAL_SCORE_WEIGHT
            var modelScore: Float = 0
            if isValidWord && scored[normalizedModel] != nil {
                modelScore = scored[normalizedModel]! + weightedNeural + 35.0 + exactAnchorBonus + exactPathBonus
            } else if isValidWord {
                modelScore = weightedNeural + 210.0 + simToAnchors * 40.0 + simToPath * 45.0 + DictionaryManager.BONUS_VALID_MODEL_WORD + exactAnchorBonus + exactPathBonus
            } else {
                modelScore = weightedNeural + 180.0 + simToAnchors * 45.0 + simToPath * 50.0 + exactAnchorBonus + exactPathBonus - DictionaryManager.PENALTY_WEAK_LENGTH_MISMATCH
            }

            if !normalizedModel.isEmpty && !pathLower.isEmpty {
                if normalizedModel.last != pathLower.last {
                    modelScore -= DictionaryManager.PENALTY_LAST_KEY_MISMATCH
                }
            }

            let frequency = wordFrequencies[normalizedModel] ?? 1.0
            if frequency > 7000.0 { modelScore += 60.0 }
            else if frequency > 3000.0 { modelScore += 30.0 }

            scored[normalizedModel] = modelScore
        }

        if !anchorLower.isEmpty && isCompleteWord(anchorLower) {
            scored[anchorLower] = (scored[anchorLower] ?? 0.0) + DictionaryManager.BONUS_VALID_MODEL_WORD
        }

        if let neuralFirstChar = anchorLower.first {
            for (word, score) in scored {
                if !word.isEmpty && word.first == neuralFirstChar {
                    scored[word] = score + DictionaryManager.BONUS_EXACT_ANCHOR_MODEL
                }
            }
        }

        if !keyPath.isEmpty {
            for (word, score) in scored {
                if trie.isSubsequenceOf(word: word, sequence: keyPath) {
                    scored[word] = score + DictionaryManager.BONUS_KEYPATH_SUBSEQ_EXTRA
                } else {
                    let softPenalty: Float
                    if normalizedSimilarity(word, keyPath) >= 0.6 { softPenalty = DictionaryManager.PENALTY_NOT_IN_KEYPATH / 4.0 }
                    else if normalizedSimilarity(anchorLower, word) >= 0.75 { softPenalty = DictionaryManager.PENALTY_NOT_IN_KEYPATH / 5.0 }
                    else { softPenalty = DictionaryManager.PENALTY_NOT_IN_KEYPATH / 3.0 }
                    scored[word] = score - softPenalty
                }
            }
        }

        let topVocabScore = vocabCandidates.max(by: { $0.1 < $1.1 })?.1 ?? 0.0
        if !modelCandidates.isEmpty && topVocabScore < 95.0 {
            let topModelWord = modelCandidates[0].0.lowercased()
            if scored[topModelWord] != nil {
                scored[topModelWord]! += DictionaryManager.BONUS_WEAK_VOCAB_MODEL
            }
        }

        if !anchorLower.isEmpty {
            for (word, score) in scored {
                var updated = score
                if !word.isEmpty {
                    if word.first == anchorLower.first { updated += 6.0 }
                    if word.last == anchorLower.last { updated += 6.0 }
                }
                scored[word] = updated
            }
        }

        return scored.max(by: { $0.value < $1.value })?.key ?? anchors
    }

    public func finalizeSwipeResult(keyPath: String, modelCandidates: [(String, Float)], isHindiMode: Bool, prevWord: String = "") -> String {
        guard let anchors = modelCandidates.first?.0 else { return "" }
        let vocabCandidates = findCandidates(anchors: anchors, keyPath: keyPath, prevWord: prevWord)
        
        let bestWord = pickBestResult(anchors: anchors, keyPath: keyPath, vocabCandidates: vocabCandidates, modelCandidates: modelCandidates)
        
        print("\(DictionaryManager.TAG): finalizeSwipeResult: Hybrid Output: '\(bestWord)' (Neural Top: '\(anchors)', Path: '\(keyPath)')")
        return bestWord
    }

    public func getStats() -> [String: Any] {
        return [
            "isLoaded": isLoaded,
            "wordCount": trie.wordCount
        ]
    }

    public var ready: Bool { return isLoaded }
}

import Foundation

/// Trie data structure with fuzzy search capabilities for swipe keyboard.
///
/// Supports:
/// - Exact word lookup: O(word_length)
/// - Prefix lookup: O(prefix_length)
/// - Edit distance search: O(|alphabet| * |query| * nodes_within_distance) using Levenshtein automaton
/// - Subsequence matching: O(word_length * sequence_length)
class VocabularyTrie {
    
    private static let TAG = "VocabularyTrie"
    private static let MAX_FUZZY_RESULTS = 30
    private static let MAX_WORD_LENGTH = 25
    
    // =====================================================
    // TRIE NODE
    // =====================================================
    
    private class TrieNode {
        var children: [Character: TrieNode] = [:]
        var isWord = false
    }
    
    // =====================================================
    // STATE
    // =====================================================
    
    private let root = TrieNode()
    private(set) var wordCount = 0
    
    // Secondary index: words grouped by length for fast length-filtered searches
    private var wordsByLength: [Int: [String]] = [:]
    
    // Cache for frequently accessed words
    private var wordCache: Set<String> = []
    
    // =====================================================
    // LOADING
    // =====================================================
    
    /// Load vocabulary from an array of strings.
    /// Words are converted to lowercase and filtered to a-z only.
    func loadFromLines(_ lines: [String]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        var totalLines = 0
        var validWords = 0
        
        for line in lines {
            totalLines += 1
            let word = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            
            // Validate: non-empty, reasonable length, only a-z
            if !word.isEmpty && word.count <= VocabularyTrie.MAX_WORD_LENGTH && word.allSatisfy({ $0 >= "a" && $0 <= "z" }) {
                if insert(word) {
                    validWords += 1
                }
            }
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("\(VocabularyTrie.TAG): Loaded \(wordCount) unique words from \(totalLines) lines (\(validWords) valid) in \(String(format: "%.0f", elapsed))ms")
    }
    
    @discardableResult
    private func insert(_ word: String) -> Bool {
        var node = root
        for char in word {
            if node.children[char] == nil {
                node.children[char] = TrieNode()
            }
            node = node.children[char]!
        }
        
        if !node.isWord {
            node.isWord = true
            wordCount += 1
            
            let len = word.count
            wordsByLength[len, default: []].append(word)
            wordCache.insert(word)
            
            return true
        }
        return false
    }
    
    @discardableResult
    func addWord(_ word: String) -> Bool {
        let w = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if w.isEmpty || w.count > VocabularyTrie.MAX_WORD_LENGTH || !w.allSatisfy({ $0 >= "a" && $0 <= "z" }) {
            return false
        }
        return insert(w)
    }
    
    // =====================================================
    // BASIC LOOKUPS
    // =====================================================
    
    func hasPrefix(_ prefix: String) -> Bool {
        var node = root
        for char in prefix.lowercased() {
            guard let child = node.children[char] else { return false }
            node = child
        }
        return true
    }
    
    func containsWord(_ word: String) -> Bool {
        let w = word.lowercased()
        
        if wordCache.contains(w) {
            return true
        }
        
        var node = root
        for char in w {
            guard let child = node.children[char] else { return false }
            node = child
        }
        return node.isWord
    }
    
    func getAllowedNextChars(for prefix: String) -> Set<Character> {
        var node = root
        for char in prefix.lowercased() {
            guard let child = node.children[char] else { return [] }
            node = child
        }
        return Set(node.children.keys)
    }
    
    var isEmpty: Bool { wordCount == 0 }
    
    // =====================================================
    // PREFIX SEARCH
    // =====================================================
    
    func wordsWithPrefix(_ prefix: String, maxResults: Int = 20) -> [String] {
        var results: [String] = []
        let p = prefix.lowercased()
        
        var node = root
        for char in p {
            guard let child = node.children[char] else { return results }
            node = child
        }
        
        var currentStr = p
        collectWords(node: node, current: &currentStr, results: &results, maxResults: maxResults)
        return results
    }
    
    private func collectWords(node: TrieNode, current: inout String, results: inout [String], maxResults: Int) {
        if results.count >= maxResults { return }
        
        if node.isWord {
            results.append(current)
            if results.count >= maxResults { return }
        }
        
        for char in node.children.keys.sorted() {
            current.append(char)
            collectWords(node: node.children[char]!, current: &current, results: &results, maxResults: maxResults)
            current.removeLast()
            
            if results.count >= maxResults { return }
        }
    }
    
    // =====================================================
    // EDIT DISTANCE (LEVENSHTEIN)
    // =====================================================
    
    func editDistance(_ a: String, _ b: String) -> Int {
        let s = Array(a.lowercased())
        let t = Array(b.lowercased())
        
        if s.count > t.count {
            return editDistance(b, a)
        }
        
        let m = s.count
        let n = t.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var prevRow = Array(0...m)
        var currRow = Array(repeating: 0, count: m + 1)
        
        for j in 1...n {
            currRow[0] = j
            for i in 1...m {
                let cost = (s[i - 1] == t[j - 1]) ? 0 : 1
                currRow[i] = min(
                    currRow[i - 1] + 1,
                    prevRow[i] + 1,
                    prevRow[i - 1] + cost
                )
            }
            prevRow = currRow
        }
        return prevRow[m]
    }
    
    // =====================================================
    // FUZZY SEARCH
    // =====================================================
    
    struct FuzzyResult {
        let word: String
        let distance: Int
    }
    
    func findSimilarWords(query: String, maxDist: Int = 1, maxResults: Int = MAX_FUZZY_RESULTS) -> [FuzzyResult] {
        let q = Array(query.lowercased())
        if q.isEmpty { return [] }
        
        var results: [FuzzyResult] = []
        let initialRow = Array(0...q.count)
        
        var currentWord = ""
        findSimilarDFS(
            node: root,
            query: q,
            previousRow: initialRow,
            currentWord: &currentWord,
            results: &results,
            maxDist: maxDist,
            maxResults: maxResults
        )
        
        results.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            return $0.word < $1.word
        }
        return Array(results.prefix(maxResults))
    }
    
    private func findSimilarDFS(
        node: TrieNode,
        query: [Character],
        previousRow: [Int],
        currentWord: inout String,
        results: inout [FuzzyResult],
        maxDist: Int,
        maxResults: Int
    ) {
        if results.count >= maxResults { return }
        let columns = query.count + 1
        
        if node.isWord && !currentWord.isEmpty {
            let distance = previousRow[columns - 1]
            if distance <= maxDist {
                results.append(FuzzyResult(word: currentWord, distance: distance))
                if results.count >= maxResults { return }
            }
        }
        
        for (char, child) in node.children {
            var currentRow = Array(repeating: 0, count: columns)
            currentRow[0] = previousRow[0] + 1
            var rowMin = currentRow[0]
            
            for col in 1..<columns {
                let insertCost = currentRow[col - 1] + 1
                let deleteCost = previousRow[col] + 1
                let replaceCost = previousRow[col - 1] + (query[col - 1] == char ? 0 : 1)
                
                currentRow[col] = min(insertCost, deleteCost, replaceCost)
                if currentRow[col] < rowMin {
                    rowMin = currentRow[col]
                }
            }
            
            if rowMin <= maxDist {
                currentWord.append(char)
                findSimilarDFS(
                    node: child,
                    query: query,
                    previousRow: currentRow,
                    currentWord: &currentWord,
                    results: &results,
                    maxDist: maxDist,
                    maxResults: maxResults
                )
                currentWord.removeLast()
            }
            if results.count >= maxResults { return }
        }
    }
    
    // =====================================================
    // SUBSEQUENCE MATCHING
    // =====================================================
    
    func isSubsequenceOf(word: String, sequence: String) -> Bool {
        let w = Array(word.lowercased())
        let s = Array(sequence.lowercased())
        
        if w.isEmpty { return true }
        if s.isEmpty { return false }
        
        var wordIdx = 0
        var seqIdx = 0
        
        while wordIdx < w.count && seqIdx < s.count {
            if w[wordIdx] == s[seqIdx] {
                let currentChar = w[wordIdx]
                wordIdx += 1
                if wordIdx < w.count && w[wordIdx] == currentChar {
                    continue
                }
                seqIdx += 1
            } else {
                seqIdx += 1
            }
        }
        return wordIdx == w.count
    }
    
    func findSubsequenceMatches(
        sequence: String,
        minLength: Int = 2,
        maxLength: Int = 15,
        maxResults: Int = MAX_FUZZY_RESULTS
    ) -> [String] {
        let s = Array(sequence.lowercased())
        var results: [String] = []
        if s.isEmpty { return results }
        
        var currentWord = ""
        findSubsequenceDFS(
            node: root,
            sequence: s,
            seqStartIdx: 0,
            currentWord: &currentWord,
            results: &results,
            minLength: minLength,
            maxLength: maxLength,
            maxResults: maxResults
        )
        return results
    }
    
    private func findSubsequenceDFS(
        node: TrieNode,
        sequence: [Character],
        seqStartIdx: Int,
        currentWord: inout String,
        results: inout [String],
        minLength: Int,
        maxLength: Int,
        maxResults: Int
    ) {
        if results.count >= maxResults { return }
        if currentWord.count > maxLength { return }
        
        if node.isWord && currentWord.count >= minLength {
            results.append(currentWord)
            if results.count >= maxResults { return }
        }
        
        if seqStartIdx >= sequence.count { return }
        
        for (char, child) in node.children {
            if let offset = sequence[seqStartIdx...].firstIndex(of: char) {
                currentWord.append(char)
                findSubsequenceDFS(
                    node: child,
                    sequence: sequence,
                    seqStartIdx: offset + 1,
                    currentWord: &currentWord,
                    results: &results,
                    minLength: minLength,
                    maxLength: maxLength,
                    maxResults: maxResults
                )
                currentWord.removeLast()
                if results.count >= maxResults { return }
            }
            
            if seqStartIdx > 0 && sequence[seqStartIdx - 1] == char {
                currentWord.append(char)
                findSubsequenceDFS(
                    node: child,
                    sequence: sequence,
                    seqStartIdx: seqStartIdx,
                    currentWord: &currentWord,
                    results: &results,
                    minLength: minLength,
                    maxLength: maxLength,
                    maxResults: maxResults
                )
                currentWord.removeLast()
                if results.count >= maxResults { return }
            }
        }
    }
    
    func getSimilarLengthWords(query: String, maxResults: Int = 10) -> [FuzzyResult] {
        let q = query.lowercased()
        let qLen = q.count
        var results: [FuzzyResult] = []
        
        let startLen = max(1, qLen - 1)
        let endLen = min(VocabularyTrie.MAX_WORD_LENGTH, qLen + 1)
        
        for len in startLen...endLen {
            guard let words = wordsByLength[len] else { continue }
            
            for word in words {
                let dist = editDistance(q, word)
                if dist <= 2 {
                    results.append(FuzzyResult(word: word, distance: dist))
                }
                if results.count >= maxResults * 3 { break }
            }
        }
        
        results.sort { $0.distance < $1.distance }
        return Array(results.prefix(maxResults))
    }
    
    func exactMatch(query: String) -> [String] {
        let q = query.lowercased()
        return containsWord(q) ? [q] : []
    }
    
    func clear() {
        root.children.removeAll()
        wordCount = 0
        wordsByLength.removeAll()
        wordCache.removeAll()
    }
}

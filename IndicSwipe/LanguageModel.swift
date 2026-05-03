import Foundation

/// A wrapper for Language Modeling.
/// Note: The original Android app used a JNI wrapper for KenLM (kenlm-jni). 
/// For a full 1:1 port on iOS, you will need to compile KenLM in C++ for iOS and bridge it here.
/// Currently, this acts as a stub to allow compilation and basic functionality without crashing.
public class LanguageModel {
    private let assetPath: String
    private let modelName: String

    private static let TAG = "LanguageModel"

    public init(assetPath: String, modelName: String) {
        self.assetPath = assetPath
        self.modelName = modelName
    }

    public func `init`() {
        // TODO: Load KenLM model here via C++ bridging header.
        print("\(LanguageModel.TAG): Stub initialized for model: \(modelName)")
    }

    public func reset() {
        // TODO: Reset KenLM state
    }

    public func getBigramScore(prevWord: String, currentWord: String) -> Float {
        // Return a neutral score since KenLM is not fully bridged yet.
        return -100.0
    }

    public func close() {
        // TODO: Free KenLM state
    }
}

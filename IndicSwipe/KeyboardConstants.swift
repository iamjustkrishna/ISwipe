import Foundation
import CoreGraphics

public struct KeyboardConstants {
    public static let TAG = "IndicSwipeIME"

    // ════════════════════════════════════════════
    // TRAINING REFERENCE (MUST MATCH PYTHON EXACTLY)
    // ════════════════════════════════════════════
    public static let TRAIN_WIDTH: Float = 360.0
    public static let TRAIN_HEIGHT: Float = 220.0
    public static let SAMPLING_CADENCE_MS: Float = 30.0
    public static let TRAIN_ALPHABET_AREA_HEIGHT: Float = 220.0

    // ════════════════════════════════════════════
    // TIMEOUTS & DELAYS
    // ════════════════════════════════════════════
    public static let SWIPE_DECODE_TIMEOUT_MS: TimeInterval = 5.0 // seconds
    public static let XLIT_DECODE_TIMEOUT_MS: TimeInterval = 1.8
    public static let TRANSLITERATION_DELAY_MS: TimeInterval = 0.06
    public static let BACKSPACE_INITIAL_DELAY_MS: TimeInterval = 0.3
    public static let BACKSPACE_REPEAT_INTERVAL_INITIAL_MS: TimeInterval = 0.08
    public static let BACKSPACE_REPEAT_INTERVAL_FAST_MS: TimeInterval = 0.04
    public static let BACKSPACE_ACCELERATION_THRESHOLD: Int = 5
    public static let SPACE_LONG_PRESS_MS: TimeInterval = 0.25
    public static let LANGUAGE_FLASH_DURATION_MS: TimeInterval = 0.6

    // ════════════════════════════════════════════
    // SWIPE & FEATURE ENGINEERING (MUST MATCH CLEVERKEYS)
    // ════════════════════════════════════════════
    public static let MIN_SWIPE_DISTANCE_PX: Float = 60.0
    public static let MAX_TRAJ_LEN: Int = 150
    public static let MAX_WORD_LEN_TARGET: Int = 20
    public static let MIN_POINTS_FOR_SWIPE: Int = 5
    public static let TRAIL_FADE_DELAY_MS: TimeInterval = 0.09
    public static let TRAIL_FADE_DURATION_MS: TimeInterval = 0.32

    // Feature Normalization
    public static let VELOCITY_SCALE: Float = 1000.0
    public static let ACCELERATION_SCALE: Float = 500.0
    public static let FEATURE_CLIP_VAL: Float = 10.0

    public static let VEL_CLIP_MIN: Float = -10.0
    public static let VEL_CLIP_MAX: Float = 10.0
    public static let ACCEL_CLIP_MIN: Float = -500.0
    public static let ACCEL_CLIP_MAX: Float = 500.0

    public static let HIGH_VELOCITY_THRESHOLD: Float = 0.65
    public static let LOW_VELOCITY_THRESHOLD: Float = 0.16
    public static let PAUSE_VELOCITY_THRESHOLD: Float = 0.11
    public static let MIN_PAUSE_TIME_MS: TimeInterval = 0.035
    public static let VELOCITY_SQUASH_THRESHOLD: Float = 0.52
    public static let ONE_EURO_MIN_CUTOFF: Float = 1.0
    public static let ONE_EURO_BETA: Float = 0.007
    public static let ONE_EURO_D_CUTOFF: Float = 1.0

    public static let SAMPLE_DIST_HIGH_SPEED_SQ: Float = 64.0
    public static let SAMPLE_DIST_MEDIUM_SPEED_SQ: Float = 36.0
    public static let SAMPLE_DIST_LOW_SPEED_SQ: Float = 25.0
    public static let SAMPLE_DIST_PAUSE_SQ: Float = 16.0

    public static let CORNER_ANGLE_THRESHOLD: Float = 0.58
    public static let MIN_POINT_DISTANCE_TRAIN: Float = 1.8
    public static let MIN_POINTS_BEFORE_SIMPLIFY: Int = 16
    public static let MAX_PATH_WORD_RATIO: Float = 4.5
    public static let BACKTRACK_DETECT_THRESHOLD: Float = -0.28
    public static let MIN_BACKTRACK_DISTANCE_SQ: Float = 2200.0

    public static let ENDPOINT_SNAP_DISTANCE: Float = 14.0
    public static let ENDPOINT_VELOCITY_THRESHOLD: Float = 0.14
    public static let START_STABILIZATION_POINTS: Int = 4
    public static let END_STABILIZATION_POINTS: Int = 6
    public static let TOUCH_SIZE_WEIGHT: Float = 0.35

    public static let SWIPE_MOVE_THRESHOLD_SQ: Float = 324.0
    public static let SWIPE_DELIBERATE_THRESHOLD_SQ: Float = 900.0
    public static let SWIPE_START_THRESHOLD_SQ: Float = 625.0
    public static let SPECIAL_TAP_TOLERANCE: Float = 14.0

    public static let VERTICAL_PENALTY: Float = 1.4
    public static let OUTSIDE_HITBOX_PENALTY: Float = 2.8
    public static let EXTREME_DISTANCE_THRESHOLD_KEYS: Float = 2.2

    // ════════════════════════════════════════════
    // BEAM SEARCH & SCORING
    // ════════════════════════════════════════════
    public static let SWIPE_BEAM_WIDTH: Int = 1
    public static let XLIT_BEAM_WIDTH: Int = 3
    public static let PRUNING_THRESHOLD_LOG: Float = -320.0

    public static let BEAM_EARLY_EXIT_MIN_STEP: Int = 6
    public static let BEAM_EARLY_EXIT_MIN_COMPLETED: Int = 4

    public static let NEURAL_SCORE_WEIGHT: Float = 4.0
    public static let LM_WEIGHT_ALPHA: Float = 0.25
    public static let REPETITION_PENALTY: Float = -10.5
    public static let DECODER_TEMPERATURE: Float = 0.55

    public static let SKELETON_MISMATCH_PENALTY: Float = -5.0
    public static let TRIPLE_CHAR_PENALTY: Float = -15.0
    public static let UNFINISHED_PENALTY: Float = -5.0
    public static let EOS_TERMINATION_PENALTY: Float = -1.5

    public static let SKELETON_REWARD: Float = 12.0
    
    public static let LANGUAGE_TO_SCRIPT: [String: String] = [
        "hindi": "__hi__",
        "tamil": "__ta__",
        "marathi": "__mr__",
        "hinglish": "__hi__",
        "tanglish": "__ta__",
        "marathilish": "__mr__",
        "telugu": "__te__",
        "telugulish": "__te__"
    ]
    
    public static let SKELETON_COVERAGE_REWARD: Float = 15.0
    public static let SKELETON_ENDPOINT_BONUS: Float = 35.0
    public static let DICTIONARY_BONUS: Float = 250.0
    public static let MINIMUM_PATH_COVERAGE: Float = 0.32

    public static let NEURAL_HIGH_CONFIDENCE_THRESHOLD: Float = -11.0
    public static let NEURAL_MEDIUM_CONFIDENCE_THRESHOLD: Float = -14.0
    public static let LEXICON_BIAS_MULTIPLIER_HIGH_CONF: Float = 1.0
    public static let LEXICON_BIAS_MULTIPLIER_MED_CONF: Float = 1.6
    public static let LEXICON_BIAS_MULTIPLIER_LOW_CONF: Float = 2.8

    public static let MAX_TRANSIT_VELOCITY: Float = 2.8
    public static let MAX_KEYPATH_LENGTH: Int = 16

    public static let LENGTH_REWARD_FACTOR: Float = 45.0
    public static let TIE_BREAK_CONFIDENCE_THRESHOLD: Float = 3.5
    public static let PATH_LEN_MISMATCH_PENALTY: Float = -45.0

    public static let RESCUE_BASE_PENALTY: Float = -14.0
    public static let RESCUE_GEOM_THRESHOLD_LOW: Float = 0.48
    public static let RESCUE_GEOM_THRESHOLD_MED: Float = 0.72

    // UI & CURSOR
    public static let CURSOR_START_THRESHOLD_DP: CGFloat = 14.0
    public static let CURSOR_MOVE_THRESHOLD_DP: CGFloat = 10.0
    public static let SOUND_VOLUME: Float = 0.6

    public static let MAX_HINDI_SUGGESTIONS: Int = 6
    public static let MAX_ROMAN_SUGGESTIONS: Int = 2
    
    public static let SUGGESTION_TEXT_SIZE_HINDI: CGFloat = 17.5
    public static let SUGGESTION_TEXT_SIZE_ENGLISH: CGFloat = 14.5
    public static let SUGGESTION_TEXT_SIZE_PRIMARY: CGFloat = 18.5
    public static let SUGGESTION_BAR_HEIGHT_DP: CGFloat = 48
    public static let SUGGESTION_HORIZONTAL_PADDING_DP: CGFloat = 14
    public static let SUGGESTION_VERTICAL_PADDING_DP: CGFloat = 9

    public static let KEY_CORNER_RADIUS_DP: CGFloat = 6.0
    public static let KEY_CORNER_RADIUS_LARGE_DP: CGFloat = 10.0
    public static let SPACE_BAR_CORNER_RADIUS_DP: CGFloat = 10.0
    public static let SPACE_BAR_HEIGHT_DP: CGFloat = 54
    public static let BOTTOM_ROW_HEIGHT_DP: CGFloat = 64
    public static let BOTTOM_ROW_KEY_MARGIN_DP: CGFloat = 4.0

    public static let SYMBOL_KEY_TEXT_SIZE: CGFloat = 18.0
    public static let SYMBOL_SPECIAL_TEXT_SIZE: CGFloat = 16.0
    public static let EMOJI_COLUMNS: Int = 8

    public static let PUNCTUATION_CHARS = [",", "?", "!", ":", ";", "'", "\"", "@", "#", "(", ")", "-", "_", "/", "&", "%"]
    public static let PRIMARY_SYMBOLS = [".", ",", "?", "!"]

    public static let SYMBOL_PAGE_1 = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["@", "#", "$", "_", "&", "-", "+", "(", ")", "/"],
        ["*", "\"", "'", ":", ";", "!", "?"]
    ]

    public static let SYMBOL_PAGE_2 = [
        ["~", "`", "|", "•", "√", "π", "÷", "×", "§", "∆"],
        ["£", "€", "¥", "^", "°", "=", "{", "}", "\\"],
        ["%", "©", "®", "™", "✓", "[", "]"]
    ]

    public static let PLACEHOLDER_HINTS = [
        "Swipe to type • Hold space to switch language",
        "Hold . for punctuation • Double-tap ⇧ for CAPS",
        "Hold ?123 for themes"
    ]

    public struct EmojiCategory {
        public let icon: String
        public let label: String
        public let emojis: [String]
    }

    public static let EMOJI_CATEGORIES = [
        EmojiCategory(icon: "🕒", label: "Recent", emojis: []),
        EmojiCategory(icon: "😀", label: "Smileys & People", emojis: ["😀","😃","😄","😁","😆","😅","😂","🤣","🥲","😊","😇","🙃","😉","😌","😍","🥰","😘","😗","😙","😚","😋","😛","😜","🤪","😝","🤑","🤗","🤭","🫢","😶‍🌫️","😏","🙄","😬","🤥","😪","😴","😷","🤒","🤕","🤢","🤮","🥵","🥶","🥴","😵","🤯","🤠","🥳","😎","🧐","😒","😔","😟","😕","🙁","☹️","😣","😖","😫","😩","🥺","😢","😭","😤","😠","😡","🤬","🤯","😳","🥵","🥶","😱","😨","😰","😥","😓","🤗","🤔","🫣","🤭","🫢","🤫","🤐","🤨","😐","😑","😶","😏","😒","🙄","😬","🤥","😌","😔","😪","😴"]),
        EmojiCategory(icon: "🔥", label: "Popular", emojis: ["🔥","💯","✨","⭐","🌟","💥","⚡","☀️","🌈","🎉","🎊","❤️","💕","💞","💓","💗","💖","💘","💝","🫶","👍","👎","👏","🙌","🙏","👀","😂","😭","🥹","😍"])
    ]

    public static let COLOR_KEYBOARD_BG = "#111111"
    public static let COLOR_KEY_BG = "#1F1F1F"
    public static let COLOR_KEY_PRESSED = "#333333"
    public static let COLOR_SPECIAL_KEY_BG = "#1A1A1A"
    public static let COLOR_KEY_TEXT = "#F5F5F5"
    public static let COLOR_TEXT_SECONDARY = "#999999"
    public static let COLOR_ACCENT = "#FF6D00"
    public static let COLOR_SUGGESTION_BG = "#0D0D0D"
    public static let COLOR_SUGGESTION_CHIP_BG = "#1A1A1A"
    public static let COLOR_DIVIDER = "#242424"
    public static let COLOR_ENTER_BG = "#FF6D00"
    public static let COLOR_ACTION_ICON = "#F5F5F5"

    public static let COLOR_HINDI_ACCENT_FALLBACK = "#FF6D00"
    public static let COLOR_ENGLISH_ACCENT = "#4CAF50"

    public static let DEBUG_DRAW_TRAIL = false
    public static let DEBUG_LOG_DECODE = true

    public struct Language {
        public let id: String
        public let name: String
        public let accentColor: String
        public let isHindiMode: Bool
        public let assetFolder: String
        public let badgeLabel: String?
    }
    
    public static let LANGUAGES = [
        Language(id: "hindi", name: "हिन्दी", accentColor: "#FF6D00", isHindiMode: true, assetFolder: "hindi", badgeLabel: nil),
        Language(id: "hinglish", name: "Hinglish", accentColor: "#80868B", isHindiMode: false, assetFolder: "hindi", badgeLabel: "HI/EN"),
        Language(id: "tamil", name: "தமிழ்", accentColor: "#FFD600", isHindiMode: true, assetFolder: "tamil", badgeLabel: nil),
        Language(id: "tanglish", name: "Tanglish", accentColor: "#80868B", isHindiMode: false, assetFolder: "tamil", badgeLabel: "TAM/EN"),
        Language(id: "marathi", name: "मराठी", accentColor: "#2979FF", isHindiMode: true, assetFolder: "marathi", badgeLabel: nil),
        Language(id: "marathilish", name: "Marathilish", accentColor: "#80868B", isHindiMode: false, assetFolder: "marathi", badgeLabel: "MR/EN"),
        Language(id: "telugu", name: "తెలుగు", accentColor: "#FF1744", isHindiMode: true, assetFolder: "telugu", badgeLabel: nil),
        Language(id: "telugulish", name: "Telugulish", accentColor: "#80868B", isHindiMode: false, assetFolder: "telugu", badgeLabel: "TEL/EN")
    ]

    public static let KEYBOARD_SIDE_MARGIN_RATIO: CGFloat = 0.02
    public static let TRAIL_SMOOTHING_ENABLED = true
    public static let TRAIL_MAX_POINTS = 25
}

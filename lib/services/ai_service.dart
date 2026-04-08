class AIService {

/// ================================
/// 🔥 TONE DETECTION
/// ================================
static bool isHighConflict(String text) {
final lower = text.toLowerCase();

final triggers = [
"always",
"never",
"you did",
"you didn’t",
"ridiculous",
"unbelievable",
"lazy",
"irresponsible",
];

return triggers.any((t) => lower.contains(t));
}

/// ================================
/// ✨ REWRITE SUGGESTION
/// ================================
static String rewrite(String text) {
return "I’d like to discuss this calmly: $text";
}
}

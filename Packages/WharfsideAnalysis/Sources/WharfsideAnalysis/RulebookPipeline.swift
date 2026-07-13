import Foundation
import RulebookCore

/// Loads and evaluates the active rulebook with fail-closed fallback to seed rules.
public struct RulebookPipeline: Sendable {
    public let rulebook: Rulebook
    public let source: RulebookSource

    public enum RulebookSource: String, Sendable, Equatable {
        case bundled
        case fallback
    }

    public init(rulebook: Rulebook, source: RulebookSource) {
        self.rulebook = rulebook
        self.source = source
    }

    /// Bundled bytes from the app, or `nil` to use the compiled seed fallback.
    public static func load(rulebookData: Data?) -> RulebookPipeline {
        if let rulebookData,
           let rulebook = try? RulebookLoader.loadBundled(rulebookData) {
            return RulebookPipeline(rulebook: rulebook, source: .bundled)
        }
        return RulebookPipeline(rulebook: SeedRulebook.make(), source: .fallback)
    }

    public func evaluate(entries: [LogEntry], context: ContainerContext) -> RuleEvaluation {
        let matchContext = MatchContextBuilder.make(entries: entries, context: context)
        return RuleEngine.evaluate(rulebook, context: matchContext)
    }
}

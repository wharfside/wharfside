// AI/RulebookBundleLoader.swift
// Loads the bundled Rulebook.json shipped with the app (B3).

import Foundation
import WharfsideAnalysis

enum RulebookBundleLoader {
    static func bundledData() -> Data? {
        guard let url = Bundle.main.url(forResource: "Rulebook", withExtension: "json") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    static func pipeline() -> RulebookPipeline {
        RulebookPipeline.load(rulebookData: bundledData())
    }
}

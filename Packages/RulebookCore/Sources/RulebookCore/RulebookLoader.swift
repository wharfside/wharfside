import Crypto
import Foundation

public enum RulebookLoader {

    public static func loadBundled(_ data: Data) throws -> Rulebook {
        try JSONDecoder().decode(Rulebook.self, from: data)
    }

    public static func loadVerified(
        document: Data,
        signature: Data,
        publicKey: Curve25519.Signing.PublicKey
    ) throws -> Rulebook {
        guard publicKey.isValidSignature(signature, for: document) else {
            throw RulebookError.invalidSignature
        }
        return try JSONDecoder().decode(Rulebook.self, from: document)
    }

    public static func appVersion(_ appVersion: String, satisfies minimum: String) -> Bool {
        func parts(_ string: String) -> [Int] {
            string.split(separator: ".").map { Int($0) ?? 0 }
        }
        let app = parts(appVersion)
        let minimumParts = parts(minimum)
        for index in 0..<max(app.count, minimumParts.count) {
            let left = index < app.count ? app[index] : 0
            let right = index < minimumParts.count ? minimumParts[index] : 0
            if left != right { return left > right }
        }
        return true
    }
}

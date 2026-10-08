import Foundation
import Security

// Distributed builds explicitly enable Go in Info.plist. A missing key keeps
// compatibility builds on the legacy protocol; network errors never switch it.
enum MobileSessionContract {
    static var enabled: Bool { Bundle.main.object(forInfoDictionaryKey: "GoAPIAuthEnabled") as? Bool ?? false }

    static func usesGoAPI(_ url: URL?, enabled: Bool) -> Bool {
        guard enabled, let url else { return false }
        return url.scheme == "https" && url.host == "api.burkeblack.tv" &&
            (url.port == nil || url.port == 443) && url.path.hasPrefix("/app/")
    }

    static func nonce() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw ContractError.invalidState
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func callback(_ url: URL, nonce: String, started: Date, now: Date = Date()) throws -> [String: String] {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "burkeblackapp", components.host == "auth",
              components.path.isEmpty, components.fragment == nil,
              components.user == nil, components.password == nil, components.port == nil,
              now >= started, now.timeIntervalSince(started) < 600 else { throw ContractError.invalidState }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            guard values[item.name] == nil, let value = item.value else { throw ContractError.invalidState }
            values[item.name] = value
        }
        guard nonce.count == 64, values["state"] == nonce else { throw ContractError.invalidState }
        return values
    }

    enum ContractError: LocalizedError {
        case invalidState
        var errorDescription: String? { "Sign-in expired or could not be verified. Please try again." }
    }
}

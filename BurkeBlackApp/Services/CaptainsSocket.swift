import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum CaptainSocketEvent { case connected, refresh }

enum CaptainsSocketProtocol {
    static func event(_ data: Data) -> CaptainSocketEvent? {
        struct Packet: Decodable { let version: Int; let channel_id: String; let type: String }
        guard let packet = try? JSONDecoder().decode(Packet.self, from: data),
              packet.version == 1, packet.channel_id == CaptainsContract.channelID,
              packet.type.hasPrefix("kraken.captain.") else { return nil }
        return ["token_change", "vote_change", "election_change", "captain_change"]
            .contains(String(packet.type.dropFirst("kraken.captain.".count))) ? .refresh : .connected
    }

    static func identity(_ session: CaptainSession?) throws -> Data {
        var packet: [String: Any] = ["type": "IDENTITY", "data": [
            "identity": session?.userID ?? UUID().uuidString,
            "categories": ["type": "mobile", "platform": "ios"]
        ]]
        if let session { packet["token"] = session.token }
        return try JSONSerialization.data(withJSONObject: packet)
    }
}

protocol CaptainsSocketSource {
    func events(session: CaptainSession?) -> AsyncThrowingStream<CaptainSocketEvent, Error>
}

final class CaptainsSocket: CaptainsSocketSource {
    func events(session: CaptainSession?) -> AsyncThrowingStream<CaptainSocketEvent, Error> {
        AsyncThrowingStream { continuation in
            let socket = URLSession.shared.webSocketTask(with: URL(string:
                "wss://overlays.burkeblack.tv/captain/ws/\(session == nil ? "overlays" : "users")")!)
            let receiver = Task {
                do {
                    socket.resume()
                    let identity = try CaptainsSocketProtocol.identity(session)
                    try await socket.send(.string(String(decoding: identity, as: UTF8.self)))
                    while !Task.isCancelled {
                        let message = try await socket.receive()
                        let data: Data
                        switch message {
                        case .data(let value): data = value
                        case .string(let value): data = Data(value.utf8)
                        @unknown default: continue
                        }
                        if let event = CaptainsSocketProtocol.event(data) { continuation.yield(event) }
                    }
                    continuation.finish()
                } catch { continuation.finish(throwing: error) }
            }
            continuation.onTermination = { _ in
                receiver.cancel()
                socket.cancel(with: .goingAway, reason: nil)
            }
        }
    }
}

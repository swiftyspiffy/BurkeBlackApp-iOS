// The production types use Combine on Apple platforms. This tiny observation
// shim lets Linux exercise the same state logic without pretending to build UI.
#if !canImport(Combine)
protocol ObservableObject: AnyObject {}
struct TestObjectPublisher { func send() {} }
extension ObservableObject { var objectWillChange: TestObjectPublisher { TestObjectPublisher() } }
@propertyWrapper struct Published<Value> {
    var wrappedValue: Value
    init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
}
#endif

#if canImport(FoundationNetworking)
import Foundation
import FoundationNetworking

// swift-corelibs-foundation only exposes the async WebSocket receive API.
extension URLSessionWebSocketTask {
    func receive(completionHandler: @escaping (Result<Message, Error>) -> Void) {
        Task {
            do { completionHandler(.success(try await receive())) }
            catch { completionHandler(.failure(error)) }
        }
    }
}
#endif

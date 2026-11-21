import Foundation

/// The app writes the latest snapshot to the shared App Group so the widget can show it too.
public enum SharedStore {
    public static let groupID = (Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String)
        ?? "io.github.hasirciogluhq.widgetspro"
    private static let key = "lastSnapshot"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    public static func save(_ s: SystemSnapshot) {
        if let d = try? JSONEncoder().encode(s) { defaults?.set(d, forKey: key) }
    }
    public static func load() -> SystemSnapshot? {
        defaults?.data(forKey: key).flatMap { try? JSONDecoder().decode(SystemSnapshot.self, from: $0) }
    }
}

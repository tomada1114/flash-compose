import Foundation

/// The app's custom URL scheme: which links open which screen.
///
/// Parsing lives in Core, not in the view that receives the URL, so every accepted and
/// rejected shape is a unit test. The one shape accepted is `flash-compose://`, which
/// opens the app on its root screen, the drill.
public enum DeepLink {
    /// Where a link the app understands takes it.
    public enum Destination: Equatable, Sendable {
        /// The root screen, the drill: whatever is pushed is popped.
        case drill
    }

    /// The URL scheme the app registers and parses.
    ///
    /// Contract once an app ships: links to it live in messages, notes, and other apps,
    /// and a renamed scheme breaks every one of them. `project.yml` registers the same
    /// string (`CFBundleURLTypes`), and `DeepLinkTests` fails when the two differ.
    /// `scripts/bootstrap.sh` rewrites this placeholder and that registration together,
    /// so keep it one unsplit literal.
    public static let scheme = "flash-compose"

    /// Where `url` takes the app, or `nil` when it is not exactly `flash-compose://`.
    ///
    /// The scheme compares without regard to case, as URL schemes do; a host, a path, a
    /// query, a fragment, a user, or a port rejects the link rather than being ignored, so
    /// a link that says more than this version understands opens nothing instead of
    /// opening something else. A pushed screen's link shape arrives with its ``AppRoute``
    /// case, as a ``Destination`` case of its own.
    public static func destination(for url: URL) -> Destination? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == scheme,
              components.host?.isEmpty == true,
              components.percentEncodedPath.isEmpty,
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil
        else {
            return nil
        }
        return .drill
    }
}

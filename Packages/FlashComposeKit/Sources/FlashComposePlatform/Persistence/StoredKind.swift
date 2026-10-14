import FlashComposeCore

/// How an ``FlashComposeCore/Answer/Kind`` is stored: a fixed name per case, written out
/// here rather than taken from the Swift case, so renaming a case moves nothing on disk.
enum StoredKind {
    private static let firstOfDay = "firstOfDay"
    private static let reAsk = "reAsk"

    static func name(of kind: Answer.Kind) -> String {
        switch kind {
        case .firstOfDay:
            firstOfDay

        case .reAsk:
            reAsk
        }
    }

    static func kind(named name: String) throws(ProgressStoreError) -> Answer.Kind {
        switch name {
        case firstOfDay:
            .firstOfDay

        case reAsk:
            .reAsk

        default:
            throw .corruptedRecord
        }
    }
}

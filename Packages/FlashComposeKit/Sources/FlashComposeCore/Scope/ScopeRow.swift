/// One row of the scope sheet: a topic or a level, whether it is on, and whether a tap
/// can change it.
public struct ScopeRow<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    /// The topic id or level the row toggles.
    public let id: ID
    /// The row's label, shown verbatim: a topic's Japanese name, or `L1`.
    public let title: String
    /// A second label shown verbatim beside the title: a level's TOEIC label; `nil` for a
    /// topic.
    public let detail: String?
    /// Whether the row is checked.
    public let isOn: Bool
    /// Whether the row refuses a tap: it is the last one on in its section.
    public let isDisabled: Bool
}

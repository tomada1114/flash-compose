/// A screen the navigation stack can push, named by the value it shows.
///
/// It has no case: the drill is the root screen and the scope a sheet, so nothing is
/// pushed yet and the path stays empty (`docs/architecture.md` › Navigation). The type
/// stays because the stack binds to ``NavigationModel/path``. The first pushed screen — a
/// card browser, statistics — adds its case here, carrying an identifier rather than the
/// value it shows; its branch in `RootView`'s `navigationDestination(for:)`; and, when the
/// screen needs a view model of its own, an ``AppModel`` factory that builds it.
public enum AppRoute: Hashable, Sendable {}

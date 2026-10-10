import 'package:flutter/foundation.dart';

/// Which games the player has starred, shared by the lobby and the Game
/// Details screen.
///
/// Both screens have to agree: starring a game from its details page
/// pins it in the lobby, and the lobby's own star has to light up the
/// same way when that game is opened again. Keeping the set on one
/// notifier is what makes that true without either screen reaching into
/// the other.
///
/// Held in memory for this run of the app only. There is no per-user
/// storage on the device yet, and a pinned ordering is not worth
/// inventing one for on its own.
class FavouriteGames extends ChangeNotifier {
  /// The single set the whole app reads from.
  static final FavouriteGames instance = FavouriteGames();

  final Set<String> _ids = {};

  bool contains(String gameId) => _ids.contains(gameId);

  /// Stars [gameId] if it was not starred, un-stars it if it was.
  void toggle(String gameId) {
    if (!_ids.remove(gameId)) _ids.add(gameId);
    notifyListeners();
  }

  /// Starred entries first, everything else left in the order given.
  List<T> pinnedFirst<T>(List<T> items, String Function(T) idOf) {
    final starred = <T>[];
    final rest = <T>[];
    for (final item in items) {
      (_ids.contains(idOf(item)) ? starred : rest).add(item);
    }
    return [...starred, ...rest];
  }

  @visibleForTesting
  void clear() {
    if (_ids.isEmpty) return;
    _ids.clear();
    notifyListeners();
  }
}

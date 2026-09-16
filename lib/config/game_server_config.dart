/// Compile-time configuration for the multiplayer game server.
///
/// There is deliberately no default endpoint. A release build must opt in to a
/// server instead of silently trying an unsafe or unusable address.
abstract final class GameServerConfig {
  static const _rawEndpoint = String.fromEnvironment('BINGO_SERVER_URL');

  static String get endpoint => _rawEndpoint.trim();

  /// A valid HTTP(S) endpoint prevents malformed build arguments from opening
  /// a socket that can never connect.
  static Uri? get serverUri {
    final uri = Uri.tryParse(endpoint);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }

  static bool get isConfigured => serverUri != null;

  /// This is deliberately user-facing. Build commands belong in the setup
  /// guide, rather than in an error toast inside the game.
  static String get setupHint => endpoint.isEmpty
      ? 'Multiplayer is not enabled in this app build.'
      : 'The multiplayer server address is not valid for this app build.';
}

class GameServerUnavailableException implements Exception {
  const GameServerUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

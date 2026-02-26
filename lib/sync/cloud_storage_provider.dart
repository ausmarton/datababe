/// Abstract interface for cloud storage providers.
///
/// Implementations handle authentication and file storage for a specific
/// cloud provider (e.g. Google Drive, iCloud, Dropbox).
abstract class CloudStorageProvider {
  /// Human-readable name for display in the UI (e.g. "Google Drive").
  String get displayName;

  /// Whether the user is currently signed in.
  Future<bool> get isSignedIn;

  /// Attempt to sign in silently (using cached credentials).
  /// Returns true if successful.
  Future<bool> signInSilently();

  /// Interactive sign-in flow. Returns true if successful.
  Future<bool> signIn();

  /// Sign out and revoke access.
  Future<void> signOut();

  /// Download the sync file from cloud storage.
  /// Returns the JSON string, or null if no file exists yet.
  Future<String?> download();

  /// Upload [json] as the sync file to cloud storage.
  Future<void> upload(String json);
}

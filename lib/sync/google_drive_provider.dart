import 'dart:convert';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

import 'cloud_storage_provider.dart';

const _fileName = 'filho-sync.json';
const _appDataSpace = 'appDataFolder';

class GoogleDriveProvider implements CloudStorageProvider {
  GoogleDriveProvider();

  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  @override
  String get displayName => 'Google Drive';

  @override
  Future<bool> get isSignedIn async => _googleSignIn.currentUser != null;

  @override
  Future<bool> signInSilently() async {
    final account = await _googleSignIn.signInSilently();
    return account != null;
  }

  @override
  Future<bool> signIn() async {
    final account = await _googleSignIn.signIn();
    return account != null;
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  @override
  Future<String?> download() async {
    final driveApi = await _getDriveApi();
    final fileId = await _findFileId(driveApi);
    if (fileId == null) return null;

    final media = await driveApi.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  @override
  Future<void> upload(String json) async {
    final driveApi = await _getDriveApi();
    final bytes = utf8.encode(json);
    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/json',
    );

    final existingId = await _findFileId(driveApi);
    if (existingId != null) {
      // Update existing file
      await driveApi.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
      );
    } else {
      // Create new file in appDataFolder
      final fileMetadata = drive.File()
        ..name = _fileName
        ..parents = [_appDataSpace];
      await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<drive.DriveApi> _getDriveApi() async {
    final httpClient = await _googleSignIn.authenticatedClient();
    if (httpClient == null) {
      throw StateError('Not signed in to Google');
    }
    return drive.DriveApi(httpClient);
  }

  Future<String?> _findFileId(drive.DriveApi driveApi) async {
    final fileList = await driveApi.files.list(
      spaces: _appDataSpace,
      q: "name = '$_fileName'",
      $fields: 'files(id)',
    );
    final files = fileList.files;
    if (files == null || files.isEmpty) return null;
    return files.first.id;
  }
}

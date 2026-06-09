import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';
import '../models/sftp_entry.dart';
import '../services/sftp_service.dart';

String _humanizeError(Object e, {required String operation}) {
  if (e is SftpStatusError) {
    switch (e.code) {
      case SftpStatusCode.permissionDenied:
        return 'Permission denied: you do not have access to $operation in this directory. Try a different directory or request elevated access.';
      case SftpStatusCode.noSuchFile:
        return 'The file or directory does not exist.';
      case SftpStatusCode.noConnection:
      case SftpStatusCode.connectionLost:
        return 'Connection to the server was lost. Please reconnect and try again.';
      case SftpStatusCode.opUnsupported:
        return 'This operation is not supported by the server.';
      default:
        return '$operation failed. The server reported an error — check your connection and try again.';
    }
  }
  return '$operation failed. Check your connection and try again.';
}

class SftpController {
  final _service = SftpService();

  SftpClient? _sftp;
  SftpClient? get sftp => _sftp;
  bool _disposed = false;

  final entriesNotifier = ValueNotifier<List<SftpEntry>>([]);
  final currentPathNotifier = ValueNotifier<String>('/');
  final loadingNotifier = ValueNotifier<bool>(false);
  final errorNotifier = ValueNotifier<String?>(null);

  String get currentPath => currentPathNotifier.value;

  void _set<T>(ValueNotifier<T> notifier, T value) {
    if (!_disposed) notifier.value = value;
  }

  Future<void> connect(SSHClient client) async {
    _sftp?.close();
    _sftp = null;
    _set(entriesNotifier, <SftpEntry>[]);
    _set(currentPathNotifier, '/');
    _set(errorNotifier, null);

    try {
      _sftp = await _service.open(client);
      await _loadDir('/');
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'open SFTP session'));
    }
  }

  Future<void> navigate(String path) => _loadDir(path);

  Future<void> navigateUp() {
    final parts = currentPath.split('/')..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return Future.value();
    parts.removeLast();
    final parent = parts.isEmpty ? '/' : '/${parts.join('/')}';
    return _loadDir(parent);
  }

  Future<void> refresh() => _loadDir(currentPath);

  Future<void> upload(String remoteName, Uint8List data) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final remotePath =
        currentPath == '/' ? '/$remoteName' : '$currentPath/$remoteName';
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      await _service.upload(sftp, remotePath, data);
      await _loadDir(currentPath);
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'upload'));
      _set(loadingNotifier, false);
    }
  }

  Future<Uint8List?> download(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return null;
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      return await _service.download(sftp, entry.path);
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'download'));
      return null;
    } finally {
      _set(loadingNotifier, false);
    }
  }

  Future<void> rename(SftpEntry entry, String newName) async {
    final sftp = _sftp;
    if (sftp == null) return;
    final dir = currentPath == '/' ? '' : currentPath;
    final newPath = '$dir/$newName';
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      await _service.rename(sftp, entry.path, newPath);
      await _loadDir(currentPath);
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'rename'));
      _set(loadingNotifier, false);
    }
  }

  Future<void> delete(SftpEntry entry) async {
    final sftp = _sftp;
    if (sftp == null) return;
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      await _service.delete(sftp, entry.path, isDirectory: entry.isDirectory);
      await _loadDir(currentPath);
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'delete'));
      _set(loadingNotifier, false);
    }
  }

  Future<void> _loadDir(String path) async {
    final sftp = _sftp;
    if (sftp == null) return;
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      final entries = await _service.listDir(sftp, path);
      _set(currentPathNotifier, path);
      _set(entriesNotifier, entries);
    } catch (e) {
      _set(errorNotifier, _humanizeError(e, operation: 'read directory'));
    } finally {
      _set(loadingNotifier, false);
    }
  }

  void dispose() {
    _disposed = true;
    _sftp?.close();
    entriesNotifier.dispose();
    currentPathNotifier.dispose();
    loadingNotifier.dispose();
    errorNotifier.dispose();
  }
}

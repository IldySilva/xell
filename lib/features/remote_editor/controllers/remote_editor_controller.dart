import 'dart:convert';
import 'package:dartssh2/dartssh2.dart';
import 'package:flutter/foundation.dart';

class RemoteEditorController {
  final SftpClient _sftp;
  final String path;

  final contentNotifier = ValueNotifier<String>('');
  final loadingNotifier = ValueNotifier<bool>(false);
  final savingNotifier = ValueNotifier<bool>(false);
  final errorNotifier = ValueNotifier<String?>(null);
  final dirtyNotifier = ValueNotifier<bool>(false);

  bool _disposed = false;

  RemoteEditorController({required this._sftp, required this.path});

  Future<void> load() async {
    _set(loadingNotifier, true);
    _set(errorNotifier, null);
    try {
      final file = await _sftp.open(path);
      final bytes = await file.readBytes();
      await file.close();
      _set(contentNotifier, utf8.decode(bytes, allowMalformed: true));
      _set(dirtyNotifier, false);
    } catch (e) {
      _set(errorNotifier, 'Could not read file: $e');
    } finally {
      _set(loadingNotifier, false);
    }
  }

  Future<bool> save(String content) async {
    _set(savingNotifier, true);
    _set(errorNotifier, null);
    try {
      final file = await _sftp.open(
        path,
        mode: SftpFileOpenMode.write | SftpFileOpenMode.truncate,
      );
      await file.writeBytes(utf8.encode(content));
      await file.close();
      _set(contentNotifier, content);
      _set(dirtyNotifier, false);
      return true;
    } catch (e) {
      _set(errorNotifier, 'Could not save file: $e');
      return false;
    } finally {
      _set(savingNotifier, false);
    }
  }

  void markDirty() => _set(dirtyNotifier, true);

  void _set<T>(ValueNotifier<T> n, T v) {
    if (!_disposed) n.value = v;
  }

  void dispose() {
    _disposed = true;
    contentNotifier.dispose();
    loadingNotifier.dispose();
    savingNotifier.dispose();
    errorNotifier.dispose();
    dirtyNotifier.dispose();
  }
}

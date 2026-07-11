import 'dart:io';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'music_service.dart';
import 'offline_cache_service.dart';

/// Runs track downloads through Android/iOS's own background download
/// system, so a download keeps going even if you leave the screen,
/// switch tabs, minimize the app, or lock your phone.
///
/// When the raw file finishes downloading, this immediately encrypts it
/// into the app's private offline store (same as before) and deletes
/// the temporary plaintext copy — so nothing readable is left behind.
class BackgroundDownloadService {
  static final BackgroundDownloadService _instance = BackgroundDownloadService._internal();
  factory BackgroundDownloadService() => _instance;
  BackgroundDownloadService._internal();

  final MusicService _musicService = MusicService();
  final OfflineCacheService _offlineCache = OfflineCacheService();

  final Set<String> _activeFilenames = {};
  final Map<String, double> _latestProgress = {};
  final Map<String, List<void Function(double progress)>> _progressListeners = {};
  final Map<String, List<void Function(bool success)>> _completionListeners = {};
  final Map<String, Map<String, String>> _taskMeta = {};

  bool _streamAttached = false;

  void _ensureStreamAttached() {
    if (_streamAttached) return;
    _streamAttached = true;

    FileDownloader().updates.listen((update) async {
      if (update is TaskProgressUpdate) {
        if (update.progress >= 0 && update.progress <= 1) {
          _latestProgress[update.task.taskId] = update.progress;
          for (final cb in List.of(_progressListeners[update.task.taskId] ?? [])) {
            cb(update.progress);
          }
        }
      } else if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          await _finishDownload(update.task, success: true);
        } else if (update.status == TaskStatus.failed ||
            update.status == TaskStatus.canceled ||
            update.status == TaskStatus.notFound) {
          await _finishDownload(update.task, success: false);
        }
      }
    });
  }

  Future<void> _finishDownload(Task task, {required bool success}) async {
    final meta = _taskMeta[task.taskId];
    bool finalSuccess = success;

    if (success && meta != null) {
      try {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/${task.filename}');
        final bytes = await file.readAsBytes();

        await _offlineCache.downloadTrack(
          filename: meta['filename']!,
          plainBytes: bytes,
          title: meta['title']!,
          trackNumber: int.parse(meta['trackNumber']!),
          albumId: meta['albumId']!,
          albumTitle: meta['albumTitle']!,
          coverUrl: meta['coverUrl']!,
        );

        // Only the encrypted copy should remain — remove the plaintext one.
        if (await file.exists()) await file.delete();
      } catch (_) {
        finalSuccess = false;
      }
    }

    for (final cb in List.of(_completionListeners[task.taskId] ?? [])) {
      cb(finalSuccess);
    }

    if (meta != null) _activeFilenames.remove(meta['filename']);
    _progressListeners.remove(task.taskId);
    _completionListeners.remove(task.taskId);
    _taskMeta.remove(task.taskId);
    _latestProgress.remove(task.taskId);
  }

  String _taskIdFor(String filename) => 'track_$filename';

  bool isDownloading(String filename) => _activeFilenames.contains(filename);

  double getProgress(String filename) => _latestProgress[_taskIdFor(filename)] ?? 0.0;

  void addProgressListener(String filename, void Function(double progress) listener) {
    _progressListeners.putIfAbsent(_taskIdFor(filename), () => []).add(listener);
  }

  void removeProgressListener(String filename, void Function(double progress) listener) {
    _progressListeners[_taskIdFor(filename)]?.remove(listener);
  }

  void addCompletionListener(String filename, void Function(bool success) listener) {
    _completionListeners.putIfAbsent(_taskIdFor(filename), () => []).add(listener);
  }

  void removeCompletionListener(String filename, void Function(bool success) listener) {
    _completionListeners[_taskIdFor(filename)]?.remove(listener);
  }

  /// Starts a track downloading in the background. Safe to call from any
  /// screen — the download is tracked centrally here, not by the screen.
  Future<void> startDownload({
    required String filename,
    required String title,
    required int trackNumber,
    required String albumId,
    required String albumTitle,
    required String coverUrl,
  }) async {
    _ensureStreamAttached();
    if (_activeFilenames.contains(filename)) return;

    final headers = await _musicService.getAuthHeaders();
    final url = _musicService.getStreamUrl(filename);
    final taskId = _taskIdFor(filename);

    _activeFilenames.add(filename);
    _taskMeta[taskId] = {
      'filename': filename,
      'title': title,
      'trackNumber': trackNumber.toString(),
      'albumId': albumId,
      'albumTitle': albumTitle,
      'coverUrl': coverUrl,
    };

    final task = DownloadTask(
      taskId: taskId,
      url: url,
      filename: filename,
      headers: headers,
      baseDirectory: BaseDirectory.temporary,
      updates: Updates.statusAndProgress,
      retries: 3,
    );

    await FileDownloader().enqueue(task);
  }
}

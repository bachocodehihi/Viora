import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../../../config/app_colors.dart';
import '../../../config/theme_helper.dart';
import '../../../l10n/language.dart';

/// Waveform bars for recording bar
class VoiceWaveformBars extends StatelessWidget {
  final bool isPaused;
  final Color color;
  final int barCount;
  final List<double>? amplitudes; // Values from 0.0 (silent) to 1.0 (loud)

  const VoiceWaveformBars({
    super.key,
    required this.isPaused,
    this.color = Colors.white,
    this.barCount = 24,
    this.amplitudes,
  });

  @override
  Widget build(BuildContext context) {
    final count = barCount;
    final amps = amplitudes;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(count, (index) {
        // If no amplitudes provided or 0: completely flat and even (4.0.h)
        double amp = 0.0;
        if (amps != null && amps.isNotEmpty) {
          final ampIdx = index < amps.length ? index : (amps.length - 1);
          amp = amps[ampIdx].clamp(0.0, 1.0);
        }

        // Base height when silent is 4.0.h (completely even like Image 2)
        // Rises up to 24.0.h when sound comes in (like Image 3)
        final double h = (4.0 + amp * 20.0).h;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 70),
          curve: Curves.easeOutQuad,
          width: 2.2.w,
          height: h,
          margin: EdgeInsets.symmetric(horizontal: 1.1.w),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2.r),
          ),
        );
      }),
    );
  }
}

/// Static audio waveform with progress fill for chat message bubbles
class AudioWaveform extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color activeColor;
  final Color inactiveColor;
  final int barCount;
  final List<double>? amplitudes;

  const AudioWaveform({
    super.key,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
    this.barCount = 22,
    this.amplitudes,
  });

  @override
  Widget build(BuildContext context) {
    final count = barCount;
    final amps = amplitudes;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(count, (index) {
        final barProgress = (index + 0.5) / count;
        final bool isPlayed = progress >= barProgress;

        double h;
        if (amps != null && amps.isNotEmpty) {
          final ampIdx = index < amps.length ? index : (amps.length - 1);
          final amp = amps[ampIdx].clamp(0.0, 1.0);
          h = (4.0 + amp * 20.0).h;
        } else {
          h = 4.0.h;
        }

        return Container(
          width: 2.2.w,
          height: h,
          margin: EdgeInsets.symmetric(horizontal: 1.1.w),
          decoration: BoxDecoration(
            color: isPlayed ? activeColor : inactiveColor,
            borderRadius: BorderRadius.circular(2.r),
          ),
        );
      }),
    );
  }
}

class ChatAudioBubble extends StatefulWidget {
  final String text;
  final int durationSeconds;
  final bool isMe;
  final bool isPinned;
  final List<double>? amplitudes;
  final String? filePath;
  final String? audioUrl;

  const ChatAudioBubble({
    super.key,
    required this.text,
    this.durationSeconds = 2,
    required this.isMe,
    this.isPinned = false,
    this.amplitudes,
    this.filePath,
    this.audioUrl,
  });

  @override
  State<ChatAudioBubble> createState() => _ChatAudioBubbleState();
}

class _ChatAudioBubbleState extends State<ChatAudioBubble>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _waveformChannel = MethodChannel('viora/audio_waveform');
  static final Map<String, List<double>> _waveformCache = {};
  static final Map<String, Future<List<double>?>> _inflightWaveform = {};
  static final Map<String, String> _downloadedFileCache = {};
  static _ChatAudioBubbleState? _activePlayerState;

  bool _isPlaying = false;
  bool _hasStarted = false;
  bool _isStartingPlay = false;
  bool _isScrubbing = false;
  bool _isSeeking = false;
  double _scrubProgress = 0.0;
  String? _loadedSourceKey;
  double _progress = 0.0;
  final GlobalKey _waveformKey = GlobalKey();
  AnimationController? _animController;
  AudioPlayer? _player;
  StreamSubscription? _posSub;
  StreamSubscription? _completeSub;
  StreamSubscription? _durationSub;
  StreamSubscription<PlayerState>? _stateSub;
  Duration? _audioDuration;
  List<double>? _extractedAmplitudes;

  int get _effectiveDuration {
    if (_audioDuration != null && _audioDuration!.inSeconds > 0) {
      return _audioDuration!.inSeconds;
    }
    if (widget.durationSeconds > 0) return widget.durationSeconds;
    final parts = widget.text.trim().split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]);
      final s = int.tryParse(parts[1]);
      if (m != null && s != null && m >= 0 && s >= 0 && (m * 60 + s) > 0) {
        return m * 60 + s;
      }
    }
    final parsed = int.tryParse(widget.text.replaceAll(RegExp(r'[^0-9]'), ''));
    return (parsed != null && parsed > 0) ? parsed : 2;
  }

  String? _waveformCacheKey() {
    final path = widget.filePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    final url = widget.audioUrl;
    if (url != null && url.isNotEmpty) {
      return url;
    }
    return null;
  }

  void _maybeExtractWaveform() {
    if (widget.amplitudes != null && widget.amplitudes!.isNotEmpty) return;
    final key = _waveformCacheKey();
    if (key == null) return;

    final cached = _waveformCache[key];
    if (cached != null) {
      if (_extractedAmplitudes != cached) {
        _extractedAmplitudes = cached;
      }
      return;
    }

    final future = _inflightWaveform.putIfAbsent(key, () => _extractWaveform(key));
    future.then((amps) {
      _inflightWaveform.remove(key);
      if (amps != null && amps.isNotEmpty) {
        _waveformCache[key] = amps;
        if (mounted) {
          setState(() {
            _extractedAmplitudes = amps;
          });
        }
      }
    });
  }

  Future<List<double>?> _extractWaveform(String sourceKey) async {
    if (!Platform.isAndroid) return null;
    try {
      String? localPath;
      if (!sourceKey.startsWith('http://') && !sourceKey.startsWith('https://')) {
        if (File(sourceKey).existsSync()) {
          localPath = sourceKey;
        }
      } else {
        final existing = _downloadedFileCache[sourceKey];
        if (existing != null && File(existing).existsSync()) {
          localPath = existing;
        } else {
          final tempDir = await getTemporaryDirectory();
          final targetPath = '${tempDir.path}/wf_${sourceKey.hashCode.abs()}.m4a';
          final targetFile = File(targetPath);
          if (targetFile.existsSync() && targetFile.lengthSync() > 0) {
            _downloadedFileCache[sourceKey] = targetPath;
            localPath = targetPath;
          } else {
            final res = await http
                .get(Uri.parse(sourceKey))
                .timeout(const Duration(seconds: 15));
            if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
              await targetFile.writeAsBytes(res.bodyBytes, flush: true);
              _downloadedFileCache[sourceKey] = targetPath;
              localPath = targetPath;
            }
          }
        }
      }

      if (localPath == null || !File(localPath).existsSync()) return null;
      final raw = await _waveformChannel.invokeMethod<List<dynamic>>(
        'extractWaveform',
        {'path': localPath, 'barCount': 20},
      );
      if (raw == null || raw.isEmpty) return null;
      return raw.map((e) => (e as num).toDouble().clamp(0.0, 1.0)).toList();
    } catch (e) {
      debugPrint('Waveform extraction error: $e');
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeExtractWaveform();
    _player = AudioPlayer();
    _posSub = _player!.onPositionChanged.listen((pos) {
      if (!mounted || !_isPlaying || _isScrubbing || _isSeeking) return;
      final totalMs = _totalDurationMs();
      if (totalMs > 0) {
        setState(() {
          _progress = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
        });
      }
    });
    _durationSub = _player!.onDurationChanged.listen((dur) {
      if (!mounted) return;
      setState(() {
        _audioDuration = dur;
      });
    });
    _completeSub = _player!.onPlayerComplete.listen((_) {
      if (!mounted) return;
      if (_activePlayerState == this) {
        _activePlayerState = null;
      }
      setState(() {
        _isPlaying = false;
        _hasStarted = false;
        _progress = 0.0;
      });
    });
    _stateSub = _player!.onPlayerStateChanged.listen((state) {
      if (!mounted || _isStartingPlay) return;
      if (state == PlayerState.paused || state == PlayerState.stopped) {
        if (_isPlaying) {
          setState(() {
            _isPlaying = false;
          });
        }
      }
    });
  }

  int _totalDurationMs() {
    final durMs = _audioDuration?.inMilliseconds ?? 0;
    if (durMs > 0) return durMs;
    return (_effectiveDuration * 1000).clamp(1000, 3600000);
  }

  double _fractionFromLocalDx(double localDx) {
    final renderBox = _waveformKey.currentContext?.findRenderObject() as RenderBox?;
    final width = (renderBox != null && renderBox.hasSize && renderBox.size.width > 0)
        ? renderBox.size.width
        : (20 * 4.4).w;
    return (localDx / width).clamp(0.0, 1.0);
  }

  Future<bool> _playSourceFromPosition(Duration? startPosition) async {
    final path = widget.filePath;
    final url = widget.audioUrl;
    final sourceKey = _waveformCacheKey() ?? '';
    bool played = false;

    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      try {
        await _player?.play(
          DeviceFileSource(path),
          position: (startPosition != null && startPosition > Duration.zero) ? startPosition : null,
        );
        played = true;
      } catch (e) {
        debugPrint('Play local audio error: $e');
      }
    } else if (url != null && url.isNotEmpty) {
      final cachedLocal = _downloadedFileCache[url];
      if (cachedLocal != null && File(cachedLocal).existsSync()) {
        try {
          await _player?.play(
            DeviceFileSource(cachedLocal),
            position: (startPosition != null && startPosition > Duration.zero) ? startPosition : null,
          );
          played = true;
        } catch (_) {}
      }
      if (!played) {
        try {
          await _player?.play(
            UrlSource(url),
            position: (startPosition != null && startPosition > Duration.zero) ? startPosition : null,
          );
          played = true;
        } catch (e) {
          debugPrint('Play remote audio error: $e');
        }
      }
    }

    if (played) {
      _hasStarted = true;
      _loadedSourceKey = sourceKey;
    }
    return played;
  }

  Future<void> _seekToFraction(double fraction, {required bool autoPlayIfNotStarted}) async {
    final clamped = fraction.clamp(0.0, 1.0);
    final totalMs = _totalDurationMs();
    final maxSeekMs = totalMs > 150 ? totalMs - 120 : totalMs;
    final targetMs = (clamped * totalMs).round().clamp(0, maxSeekMs);
    final targetDuration = Duration(milliseconds: targetMs);

    if (mounted) {
      setState(() {
        _progress = clamped;
        _isScrubbing = false;
      });
    }

    if (_animController != null) {
      _animController!.value = clamped;
      if (_isPlaying) {
        _animController!.forward(from: clamped);
      }
      return;
    }

    final sourceKey = _waveformCacheKey() ?? '';
    if (_hasStarted && _loadedSourceKey == sourceKey && _player != null) {
      _isSeeking = true;
      try {
        await _player!.seek(targetDuration);
      } catch (e) {
        debugPrint('Seek audio error: $e');
      } finally {
        _isSeeking = false;
      }
      return;
    }

    if (!autoPlayIfNotStarted || _isStartingPlay || !mounted) return;

    _isStartingPlay = true;
    try {
      if (_activePlayerState != null && _activePlayerState != this) {
        await _activePlayerState!._pausePlayback();
      }
      _activePlayerState = this;

      final played = await _playSourceFromPosition(targetDuration);
      if (mounted) {
        setState(() {
          _isPlaying = true;
          _progress = clamped;
        });
      }
      if (!played) {
        _startFallbackAnimation(fromFraction: clamped);
      }
    } finally {
      _isStartingPlay = false;
    }
  }

  void _startFallbackAnimation({double fromFraction = 0.0}) {
    final total = _effectiveDuration;
    _animController?.dispose();
    _animController = AnimationController(
      vsync: this,
      duration: Duration(seconds: total),
    );
    _animController!.addListener(() {
      if (mounted && !_isScrubbing) {
        setState(() {
          _progress = _animController!.value;
        });
      }
    });
    _animController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        if (_activePlayerState == this) {
          _activePlayerState = null;
        }
        setState(() {
          _isPlaying = false;
          _hasStarted = false;
          _progress = 0.0;
        });
      }
    });
    _animController!.forward(from: fromFraction >= 1.0 ? 0.0 : fromFraction);
  }

  void _handleWaveformTap(TapUpDetails details) {
    final fraction = _fractionFromLocalDx(details.localPosition.dx);
    HapticFeedback.selectionClick();
    _seekToFraction(fraction, autoPlayIfNotStarted: true);
  }

  void _handleScrubStart(DragStartDetails details) {
    final fraction = _fractionFromLocalDx(details.localPosition.dx);
    HapticFeedback.selectionClick();
    setState(() {
      _isScrubbing = true;
      _scrubProgress = fraction;
    });
  }

  void _handleScrubUpdate(DragUpdateDetails details) {
    if (!_isScrubbing) return;
    final fraction = _fractionFromLocalDx(details.localPosition.dx);
    setState(() {
      _scrubProgress = fraction;
    });
  }

  void _handleScrubEnd() {
    if (!_isScrubbing) return;
    final target = _scrubProgress;
    _seekToFraction(target, autoPlayIfNotStarted: true);
  }

  void _handleScrubCancel() {
    if (!_isScrubbing) return;
    setState(() {
      _isScrubbing = false;
    });
  }

  Future<void> _pausePlayback() async {
    try {
      await _player?.pause();
    } catch (_) {}
    _animController?.stop();
    if (_activePlayerState == this) {
      _activePlayerState = null;
    }
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _togglePlay() async {
    if (_isStartingPlay) return;
    if (_isPlaying) {
      await _pausePlayback();
      return;
    }

    _isStartingPlay = true;
    try {
      if (_activePlayerState != null && _activePlayerState != this) {
        await _activePlayerState!._pausePlayback();
      }
      _activePlayerState = this;

      final sourceKey = _waveformCacheKey() ?? '';
      bool played = false;

      if (_hasStarted &&
          _loadedSourceKey == sourceKey &&
          _progress > 0.0 &&
          _progress < 1.0 &&
          _animController == null) {
        try {
          await _player?.resume();
          played = true;
        } catch (e) {
          debugPrint('Resume audio error: $e');
        }
      }

      if (!played) {
        final resumePos = (_progress > 0.0 && _progress < 0.99)
            ? Duration(milliseconds: (_progress * _totalDurationMs()).round())
            : null;
        played = await _playSourceFromPosition(resumePos);
      }

      if (mounted) {
        setState(() {
          _isPlaying = true;
        });
      }

      if (!played) {
        _startFallbackAnimation(fromFraction: _progress);
      }
    } finally {
      _isStartingPlay = false;
    }
  }

  @override
  void didUpdateWidget(covariant ChatAudioBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitudes != widget.amplitudes ||
        oldWidget.filePath != widget.filePath ||
        oldWidget.audioUrl != widget.audioUrl) {
      if (widget.amplitudes != null && widget.amplitudes!.isNotEmpty) {
        _extractedAmplitudes = null;
      } else {
        _maybeExtractWaveform();
      }
    }
  }

  @override
  void dispose() {
    if (_activePlayerState == this) {
      _activePlayerState = null;
    }
    _posSub?.cancel();
    _completeSub?.cancel();
    _durationSub?.cancel();
    _stateSub?.cancel();
    _player?.dispose();
    _animController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = _effectiveDuration;
    final displayProgress = (_isScrubbing ? _scrubProgress : _progress).clamp(0.0, 1.0);
    final currentSec = (displayProgress * total).round().clamp(0, total);
    final displaySec = (_isPlaying || _isScrubbing || _progress > 0.0) ? currentSec : total;
    final durationStr = '${displaySec ~/ 60}:${(displaySec % 60).toString().padLeft(2, '0')}';
    final double waveformWidth = (20 * 4.4).w;
    final bool showThumb = _isPlaying || _isScrubbing || _progress > 0.0;
    final double thumbSize = _isScrubbing ? 11.r : 8.r;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 32.r,
                  height: 32.r,
                  decoration: BoxDecoration(
                    color: widget.isMe ? Colors.white : AppColors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: widget.isMe ? const Color(0xFF0010B4) : Colors.white,
                    size: 20.r,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: _handleWaveformTap,
                onHorizontalDragStart: _handleScrubStart,
                onHorizontalDragUpdate: _handleScrubUpdate,
                onHorizontalDragEnd: (_) => _handleScrubEnd(),
                onHorizontalDragCancel: _handleScrubCancel,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: 32.r),
                  child: Center(
                    widthFactor: 1.0,
                    child: Stack(
                      key: _waveformKey,
                      alignment: Alignment.centerLeft,
                      clipBehavior: Clip.none,
                      children: [
                        AudioWaveform(
                          progress: displayProgress,
                          barCount: 20,
                          amplitudes: (widget.amplitudes != null && widget.amplitudes!.isNotEmpty)
                              ? widget.amplitudes
                              : _extractedAmplitudes,
                          activeColor: widget.isMe ? Colors.white : AppColors.blue,
                          inactiveColor: widget.isMe
                              ? Colors.white.withValues(alpha: 0.38)
                              : (context.isDark ? Colors.white24 : Colors.grey.withValues(alpha: 0.35)),
                        ),
                        if (showThumb)
                          Positioned(
                            left: (displayProgress * waveformWidth - thumbSize / 2)
                                .clamp(-2.0, waveformWidth - thumbSize + 2.0),
                            child: Container(
                              width: thumbSize,
                              height: thumbSize,
                              decoration: BoxDecoration(
                                color: widget.isMe ? Colors.white : AppColors.blue,
                                shape: BoxShape.circle,
                                border: _isScrubbing
                                    ? Border.all(
                                        color: (widget.isMe ? Colors.white : AppColors.blue)
                                            .withValues(alpha: 0.4),
                                        width: 2.5,
                                        strokeAlign: BorderSide.strokeAlignOutside,
                                      )
                                    : null,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                durationStr,
                style: TextStyle(
                  color: widget.isMe ? Colors.white : context.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (widget.isPinned)
            Padding(
              padding: EdgeInsets.only(top: 4.h),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.push_pin_rounded,
                    size: 11.r,
                    color: widget.isMe ? Colors.white70 : AppColors.blue,
                  ),
                  SizedBox(width: 3.w),
                  Text(
                    l10n.pinned,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.isMe ? Colors.white70 : AppColors.blue,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

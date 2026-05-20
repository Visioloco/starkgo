import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '/flutter_flow/flutter_flow_util.dart' show routeObserver;

const kYoutubeAspectRatio = 16 / 9;
final _youtubeFullScreenControllerMap = <String, YoutubePlayerController>{};

class FlutterFlowYoutubePlayer extends StatefulWidget {
  const FlutterFlowYoutubePlayer({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.autoPlay = false,
    this.mute = false,
    this.looping = false,
    this.showControls = true,
    this.showFullScreen = false,
    this.pauseOnNavigate = true,
    this.strictRelatedVideos = false,
  });

  final String url;
  final double? width;
  final double? height;
  final bool autoPlay;
  final bool mute;
  final bool looping;
  final bool showControls;
  final bool showFullScreen;
  final bool pauseOnNavigate;
  final bool strictRelatedVideos;

  @override
  State<FlutterFlowYoutubePlayer> createState() => _FlutterFlowYoutubePlayerState();
}

class _FlutterFlowYoutubePlayerState extends State<FlutterFlowYoutubePlayer> with RouteAware {
  late YoutubePlayerController _controller;
  String? _videoId;
  bool _subscribedRoute = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    if (_subscribedRoute) {
      routeObserver.unsubscribe(this);
    }
    _controller.close();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pauseOnNavigate && ModalRoute.of(context) is PageRoute) {
      _subscribedRoute = true;
      routeObserver.subscribe(this, ModalRoute.of(context)!);
    }
  }

  @override
  void didPushNext() {
    if (widget.pauseOnNavigate) {
      _controller.pauseVideo();
    }
  }

  double get _width => widget.width == null || widget.width! >= double.infinity ? MediaQuery.sizeOf(context).width : widget.width!;

  double get _height => widget.height == null || widget.height! >= double.infinity ? _width / kYoutubeAspectRatio : widget.height!;

  void _initializePlayer() {
    final videoId = _convertUrlToId(widget.url);
    if (videoId == null) return;
    _videoId = videoId;

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: widget.autoPlay,
      params: YoutubePlayerParams(
        mute: widget.mute,
        loop: widget.looping,
        showControls: widget.showControls,
        showFullscreenButton: widget.showFullScreen,
        strictRelatedVideos: widget.strictRelatedVideos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _width,
        height: _height,
        child: YoutubePlayer(controller: _controller),
      );
}

class YoutubeFullScreenWrapper extends StatefulWidget {
  const YoutubeFullScreenWrapper({super.key, required this.child});

  final Widget child;

  static _YoutubeFullScreenWrapperState? of(BuildContext context) => context.findAncestorStateOfType<_YoutubeFullScreenWrapperState>();

  @override
  State<YoutubeFullScreenWrapper> createState() => _YoutubeFullScreenWrapperState();
}

class _YoutubeFullScreenWrapperState extends State<YoutubeFullScreenWrapper> {
  @override
  Widget build(BuildContext context) => widget.child;
}

String? _convertUrlToId(String url, {bool trimWhitespaces = true}) {
  assert(url.isNotEmpty, 'Url cannot be empty');
  if (!url.contains("http") && (url.length == 11)) return url;
  if (trimWhitespaces) url = url.trim();
  for (final regex in [
    RegExp(r"^https:\/\/(?:www\.|m\.)?youtube\.com\/watch\?v=([_\-a-zA-Z0-9]{11}).*$"),
    RegExp(r"^https:\/\/(?:www\.|m\.)?youtube(?:-nocookie)?\.com\/embed\/([_\-a-zA-Z0-9]{11}).*$"),
    RegExp(r"^https:\/\/youtu\.be\/([_\-a-zA-Z0-9]{11}).*$"),
  ]) {
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) return match.group(1);
  }
  return null;
}

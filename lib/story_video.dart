import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'story_view.dart';
import 'package:video_player/video_player.dart';

import 'utils.dart';

class VideoLoader {
  String url;

  File videoFile;

  Map<String, dynamic> requestHeaders;

  LoadState state = LoadState.loading;

  Function(LoadState) onVideoLoaded;

  VideoLoader(this.url, {this.requestHeaders, this.onVideoLoaded});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
      this.onVideoLoaded(this.state);
    }

    final fileStream = DefaultCacheManager().getFile(this.url, headers: this.requestHeaders);

    fileStream.listen((fileInfo) {
      if (this.videoFile == null) {
        this.state = LoadState.success;
        this.videoFile = fileInfo.file;
        onComplete();
        this.onVideoLoaded(this.state);
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController storyController;
  final VideoLoader videoLoader;

  StoryVideo(this.videoLoader, {this.storyController, Key key}) : super(key: key ?? UniqueKey());

  static StoryVideo url(
    String url, {
    StoryController controller,
    Map<String, dynamic> requestHeaders,
    Key key,
    Function(LoadState) onVideoLoaded,
  }) {
    return StoryVideo(
      VideoLoader(
        url,
        requestHeaders: requestHeaders,
        onVideoLoaded: (state) => onVideoLoaded(state),
      ),
      storyController: controller,
      key: key,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void> playerLoader;

  StreamSubscription _streamSubscription;

  VideoPlayerController playerController;

  @override
  void initState() {
    super.initState();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        this.playerController = VideoPlayerController.file(widget.videoLoader.videoFile);

        playerController.initialize().then((v) {
          log("initialize");
          setState(() {});
          widget.storyController.play();
        });

        if (widget.storyController != null) {
          _streamSubscription = widget.storyController.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              log("pause video");
              playerController.pause();
            } else {
              if (!playerController.value.isPlaying) {
                log("play video");
                playerController.play();
              }
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success && playerController.value.initialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: playerController.value.aspectRatio,
          child: VideoPlayer(playerController),
        ),
      );
    }

    return widget.videoLoader.state == LoadState.loading
        ? Center(
            child: Container(
              width: 70,
              height: 70,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ),
          )
        : Center(
            child: Text(
              "Media failed to load.",
              style: TextStyle(
                color: Colors.white,
              ),
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      height: double.infinity,
      width: double.infinity,
      child: getContentView(),
    );
  }

  @override
  void dispose() {
    print("dispose");
    playerController.pause();
    playerController.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}

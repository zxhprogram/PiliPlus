import 'dart:async';
import 'dart:ui';

import 'package:PiliPlus/common/widgets/pair.dart';
import 'package:PiliPlus/common/widgets/progress_bar/segment_progress_bar.dart';
import 'package:PiliPlus/grpc/bilibili/app/listener/v1.pbenum.dart'
    show PlaylistSource;
import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/http/fav.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/user.dart';
import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/main.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/sponsor_block/action_type.dart';
import 'package:PiliPlus/models/common/sponsor_block/post_segment_model.dart';
import 'package:PiliPlus/models/common/sponsor_block/segment_model.dart';
import 'package:PiliPlus/models/common/sponsor_block/segment_type.dart';
import 'package:PiliPlus/models/common/sponsor_block/skip_type.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/source_type.dart';
import 'package:PiliPlus/models/common/video/subtitle_pref_type.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/models/common/video/video_type.dart';
import 'package:PiliPlus/models/video/play/url.dart';
import 'package:PiliPlus/models_new/media_list/data.dart';
import 'package:PiliPlus/models_new/media_list/media_list.dart';
import 'package:PiliPlus/models_new/sponsor_block/segment_item.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';
import 'package:PiliPlus/models_new/video/video_pbp/data.dart';
import 'package:PiliPlus/models_new/video/video_play_info/data.dart';
import 'package:PiliPlus/models_new/video/video_play_info/subtitle.dart';
import 'package:PiliPlus/models_new/video/video_stein_edgeinfo/data.dart';
import 'package:PiliPlus/pages/audio/view.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/medialist/view.dart';
import 'package:PiliPlus/pages/video/note/view.dart';
import 'package:PiliPlus/pages/video/post_panel/view.dart';
import 'package:PiliPlus/pages/video/send_danmaku/view.dart';
import 'package:PiliPlus/pages/video/widgets/header_control.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/plugin/pl_player/models/data_source.dart';
import 'package:PiliPlus/plugin/pl_player/models/heart_beat_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/play_status.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:dio/dio.dart' show Options;
import 'package:easy_debounce/easy_throttle.dart';
import 'package:extended_nested_scroll_view/extended_nested_scroll_view.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import 'package:get/get_navigation/src/dialog/dialog_route.dart';
import 'package:hive/hive.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:media_kit/media_kit.dart';

class VideoDetailController extends GetxController
    with GetTickerProviderStateMixin {
  /// 路由传参
  late final Map args;
  late String bvid;
  late int aid;
  late final RxInt cid;
  int? epId;
  int? seasonId;
  int? pgcType;
  late final String heroTag;
  late final RxString cover;

  // 视频类型 默认投稿视频
  late final VideoType videoType;
  late final isUgc = videoType == VideoType.ugc;
  VideoType? _actualVideoType;

  // 页面来源 稍后再看 收藏夹
  late bool isPlayAll;
  late SourceType sourceType;
  late bool _mediaDesc = false;
  late final RxList<MediaListItemModel> mediaList = <MediaListItemModel>[].obs;
  late String watchLaterTitle;

  /// tabs相关配置
  late TabController tabCtr;

  // 请求返回的视频信息
  late PlayUrlModel data;
  final Rx<LoadingState> videoState = LoadingState.loading().obs;

  /// 播放器配置 画质 音质 解码格式
  late Rx<VideoQuality> currentVideoQa;
  AudioQuality? currentAudioQa;
  late VideoDecodeFormatType currentDecodeFormats;

  // 是否开始自动播放 存在多p的情况下，第二p需要为true
  final RxBool autoPlay = true.obs;

  final childKey = GlobalKey<ScaffoldState>();

  PlPlayerController plPlayerController = PlPlayerController.getInstance()
    ..setCurrBrightness(-1.0);

  late VideoItem firstVideo;
  late AudioItem firstAudio;
  String? videoUrl;
  String? audioUrl;
  Duration? defaultST;
  Duration? playedTime;

  // 亮度
  double? brightness;

  late final headerCtrKey = GlobalKey<HeaderControlState>();

  Box setting = GStorage.setting;

  late String cacheDecode;
  late String cacheSecondDecode;

  bool get showReply => isUgc
      ? plPlayerController.showVideoReply
      : plPlayerController.showBangumiReply;

  int? seasonCid;
  late final RxInt seasonIndex = 0.obs;

  PlayerStatus? playerStatus;
  StreamSubscription<Duration>? positionSubscription;

  late final scrollKey = GlobalKey<ExtendedNestedScrollViewState>();
  late final RxBool isVertical = false.obs;
  late final RxDouble scrollRatio = 0.0.obs;
  late final ScrollController scrollCtr = ScrollController()
    ..addListener(scrollListener);
  late bool isExpanding = false;
  late bool isCollapsing = false;
  AnimationController? animController;

  AnimationController get animationController =>
      animController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 200),
      );
  late double minVideoHeight;
  late double maxVideoHeight;
  late double videoHeight;

  void animToTop() {
    final outerController = scrollKey.currentState!.outerController;
    if (outerController.hasClients) {
      outerController.animateTo(
        outerController.offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  void setVideoHeight() {
    final isVertical = firstVideo.width != null && firstVideo.height != null
        ? firstVideo.width! < firstVideo.height!
        : false;
    if (!scrollCtr.hasClients) {
      videoHeight = isVertical ? maxVideoHeight : minVideoHeight;
      this.isVertical.value = isVertical;
      return;
    }
    if (this.isVertical.value != isVertical) {
      this.isVertical.value = isVertical;
      double videoHeight = isVertical ? maxVideoHeight : minVideoHeight;
      if (this.videoHeight != videoHeight) {
        if (videoHeight > this.videoHeight) {
          // current minVideoHeight
          isExpanding = true;
          animationController.forward(
            from: (minVideoHeight - scrollCtr.offset) / maxVideoHeight,
          );
          this.videoHeight = maxVideoHeight;
        } else {
          // current maxVideoHeight
          final currentHeight = (maxVideoHeight - scrollCtr.offset).toPrecision(
            2,
          );
          double minVideoHeightPrecise = minVideoHeight.toPrecision(2);
          if (currentHeight == minVideoHeightPrecise) {
            isExpanding = true;
            this.videoHeight = minVideoHeight;
            animationController.forward(from: 1);
          } else if (currentHeight < minVideoHeightPrecise) {
            // expande
            isExpanding = true;
            animationController.forward(from: currentHeight / minVideoHeight);
            this.videoHeight = minVideoHeight;
          } else {
            // collapse
            isCollapsing = true;
            animationController.forward(
              from: scrollCtr.offset / (maxVideoHeight - minVideoHeight),
            );
            this.videoHeight = minVideoHeight;
          }
        }
      }
    } else {
      if (scrollCtr.offset != 0) {
        isExpanding = true;
        animationController.forward(from: 1 - scrollCtr.offset / videoHeight);
      }
    }
  }

  void scrollListener() {
    if (scrollCtr.hasClients) {
      if (scrollCtr.offset == 0) {
        scrollRatio.value = 0;
      } else {
        double offset = scrollCtr.offset - (videoHeight - minVideoHeight);
        if (offset > 0) {
          scrollRatio.value = clampDouble(
            offset.toPrecision(2) /
                (minVideoHeight - kToolbarHeight).toPrecision(2),
            0.0,
            1.0,
          );
        } else {
          scrollRatio.value = 0;
        }
      }
    }
  }

  bool imageStatus = false;

  void onViewImage() {
    imageStatus = true;
  }

  void onDismissed(int _) {
    imageStatus = false;
  }

  final isLoginVideo = Accounts.get(AccountType.video).isLogin;

  @override
  void onInit() {
    super.onInit();
    args = Get.arguments;
    videoType = args['videoType'];
    if (videoType == VideoType.pgc) {
      if (!isLoginVideo) {
        _actualVideoType = VideoType.ugc;
      }
    } else if (args['pgcApi'] == true) {
      _actualVideoType = VideoType.pgc;
    }

    bvid = args['bvid'];
    aid = args['aid'];
    cid = RxInt(args['cid']);
    epId = args['epId'];
    seasonId = args['seasonId'];
    pgcType = args['pgcType'];
    heroTag = args['heroTag'];
    cover = RxString(args['cover'] ?? '');

    sourceType = args['sourceType'] ?? SourceType.normal;
    isPlayAll = sourceType != SourceType.normal;
    if (isPlayAll) {
      watchLaterTitle = args['favTitle'];
      _mediaDesc = args['desc'];
      getMediaList();
    }

    tabCtr = TabController(
      length: 2,
      vsync: this,
      initialIndex: Pref.defaultShowComment ? 1 : 0,
    );

    autoPlay.value = Pref.autoPlayEnable;

    // 预设的解码格式
    cacheDecode = Pref.defaultDecode;
    cacheSecondDecode = Pref.secondDecode;
  }

  Future<void> getMediaList({
    bool isReverse = false,
    bool isLoadPrevious = false,
  }) async {
    final count = args['count'];
    if (!isReverse && count != null && mediaList.length >= count) {
      return;
    }
    var res = await UserHttp.getMediaList(
      type: args['mediaType'] ?? sourceType.mediaType,
      bizId: args['mediaId'] ?? -1,
      ps: 20,
      direction: isLoadPrevious ? true : false,
      oid: isReverse
          ? null
          : mediaList.isEmpty
          ? args['isContinuePlaying'] == true
                ? args['oid']
                : null
          : isLoadPrevious
          ? mediaList.first.aid
          : mediaList.last.aid,
      otype: isReverse
          ? null
          : mediaList.isEmpty
          ? null
          : isLoadPrevious
          ? mediaList.first.type
          : mediaList.last.type,
      desc: _mediaDesc,
      sortField: args['sortField'] ?? 1,
      withCurrent: mediaList.isEmpty && args['isContinuePlaying'] == true
          ? true
          : false,
    );
    if (res['status']) {
      MediaListData data = res['data'];
      if (data.mediaList.isNotEmpty) {
        if (isReverse) {
          mediaList.value = data.mediaList;
          for (var item in mediaList) {
            if (item.cid != null) {
              try {
                Get.find<UgcIntroController>(
                  tag: heroTag,
                ).onChangeEpisode(item);
              } catch (_) {}
              break;
            }
          }
        } else if (isLoadPrevious) {
          mediaList.insertAll(0, data.mediaList);
        } else {
          mediaList.addAll(data.mediaList);
        }
      }
    } else {
      SmartDialog.showToast(res['msg']);
    }
  }

  // 稍后再看面板展开
  void showMediaListPanel(BuildContext context) {
    if (mediaList.isNotEmpty) {
      Widget panel() => MediaListPanel(
        mediaList: mediaList,
        onChangeEpisode: (episode) {
          try {
            Get.find<UgcIntroController>(tag: heroTag).onChangeEpisode(episode);
          } catch (_) {}
        },
        panelTitle: watchLaterTitle,
        bvid: bvid,
        count: args['count'],
        loadMoreMedia: getMediaList,
        desc: _mediaDesc,
        onReverse: () {
          _mediaDesc = !_mediaDesc;
          getMediaList(isReverse: true);
        },
        loadPrevious: args['isContinuePlaying'] == true
            ? () => getMediaList(isLoadPrevious: true)
            : null,
        onDelete:
            sourceType == SourceType.watchLater ||
                (sourceType == SourceType.fav && args['isOwner'] == true)
            ? (item, index) async {
                if (sourceType == SourceType.watchLater) {
                  var res = await UserHttp.toViewDel(
                    aids: item.aid.toString(),
                  );
                  if (res['status']) {
                    mediaList.removeAt(index);
                  }
                  SmartDialog.showToast(res['msg']);
                } else {
                  var res = await FavHttp.favVideo(
                    resources: '${item.aid}:${item.type}',
                    delIds: '${args['mediaId']}',
                  );
                  if (res['status']) {
                    mediaList.removeAt(index);
                    SmartDialog.showToast('取消收藏');
                  } else {
                    SmartDialog.showToast(res['msg']);
                  }
                }
              }
            : null,
      );
      if (plPlayerController.isFullScreen.value || showVideoSheet) {
        PageUtils.showVideoBottomSheet(
          context,
          child: plPlayerController.darkVideoPage && MyApp.darkThemeData != null
              ? Theme(
                  data: MyApp.darkThemeData!,
                  child: panel(),
                )
              : panel(),
          isFullScreen: () => plPlayerController.isFullScreen.value,
        );
      } else {
        childKey.currentState?.showBottomSheet(
          backgroundColor: Colors.transparent,
          constraints: const BoxConstraints(),
          (context) => panel(),
        );
      }
    } else {
      getMediaList();
    }
  }

  bool isPortrait = true;

  bool get horizontalScreen => plPlayerController.horizontalScreen;

  bool get showVideoSheet =>
      (!horizontalScreen && !isPortrait) || plPlayerController.isDesktopPip;

  late final _isBlock = isUgc || !plPlayerController.enablePgcSkip;
  int? _lastPos;
  late final List<PostSegmentModel> postList = [];
  late final List<SegmentModel> segmentList = <SegmentModel>[];
  late final RxList<Segment> segmentProgressList = <Segment>[].obs;

  Color _getColor(SegmentType segment) =>
      plPlayerController.blockColor[segment.index];
  late RxString videoLabel = ''.obs;

  String get blockServer => plPlayerController.blockServer;

  Timer? skipTimer;
  late final listKey = GlobalKey<AnimatedListState>();
  late final List listData = [];

  void _vote(String uuid, int type) {
    Request()
        .post(
          '$blockServer/api/voteOnSponsorTime',
          queryParameters: {
            'UUID': uuid,
            'userID': Pref.blockUserID,
            'type': type,
          },
        )
        .then((res) {
          SmartDialog.showToast(res.statusCode == 200 ? '投票成功' : '投票失败');
        });
  }

  void _showCategoryDialog(BuildContext context, SegmentModel segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: SegmentType.values
                .map(
                  (item) => ListTile(
                    dense: true,
                    onTap: () {
                      Get.back();
                      Request()
                          .post(
                            '$blockServer/api/voteOnSponsorTime',
                            queryParameters: {
                              'UUID': segment.UUID,
                              'userID': Pref.blockUserID,
                              'category': item.name,
                            },
                          )
                          .then((res) {
                            SmartDialog.showToast(
                              '类别更改${res.statusCode == 200 ? '成功' : '失败'}',
                            );
                          });
                    },
                    title: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getColor(item),
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, height: 1),
                          ),
                          TextSpan(
                            text: ' ${item.title}',
                            style: const TextStyle(fontSize: 14, height: 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showVoteDialog(BuildContext context, SegmentModel segment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                dense: true,
                title: const Text(
                  '赞成票',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _vote(segment.UUID, 1);
                },
              ),
              ListTile(
                dense: true,
                title: const Text(
                  '反对票',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _vote(segment.UUID, 0);
                },
              ),
              ListTile(
                dense: true,
                title: const Text(
                  '更改类别',
                  style: TextStyle(fontSize: 14),
                ),
                onTap: () {
                  Get.back();
                  _showCategoryDialog(context, segment);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showSBDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        clipBehavior: Clip.hardEdge,
        contentPadding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: segmentList
                .map(
                  (item) => ListTile(
                    onTap: () {
                      Get.back();
                      if (_isBlock) {
                        _showVoteDialog(context, item);
                      }
                    },
                    dense: true,
                    title: Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Container(
                              height: 10,
                              width: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _getColor(item.segmentType),
                              ),
                            ),
                            style: const TextStyle(fontSize: 14, height: 1),
                          ),
                          TextSpan(
                            text: ' ${item.segmentType.title}',
                            style: const TextStyle(fontSize: 14, height: 1),
                          ),
                        ],
                      ),
                    ),
                    contentPadding: const EdgeInsets.only(left: 16, right: 8),
                    subtitle: Text(
                      '${DurationUtils.formatDuration(item.segment.first / 1000)} 至 ${DurationUtils.formatDuration(item.segment.second / 1000)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.skipType.title,
                          style: const TextStyle(fontSize: 13),
                        ),
                        if (item.segment.second != 0)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: IconButton(
                              tooltip: item.skipType == SkipType.showOnly
                                  ? '跳至此片段'
                                  : '跳过此片段',
                              onPressed: () {
                                Get.back();
                                onSkip(
                                  item,
                                  isSkip: item.skipType != SkipType.showOnly,
                                  isSeek: false,
                                );
                              },
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: Icon(
                                item.skipType == SkipType.showOnly
                                    ? Icons.my_location
                                    : MdiIcons.debugStepOver,
                                size: 18,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 10),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showBlockToast(String msg) {
    SmartDialog.showToast(
      msg,
      alignment: plPlayerController.isFullScreen.value
          ? const Alignment(0, 0.7)
          : null,
    );
  }

  Future<void> _querySponsorBlock() async {
    positionSubscription?.cancel();
    positionSubscription = null;
    videoLabel.value = '';
    segmentList.clear();
    segmentProgressList.clear();
    final result = await Request().get(
      '$blockServer/api/skipSegments',
      queryParameters: {
        'videoID': bvid,
        'cid': cid.value,
      },
      options: Options(validateStatus: (status) => true),
    );
    if (result.statusCode == 200) {
      if (result.data case List list) {
        handleSBData(list.map((e) => SegmentItemModel.fromJson(e)).toList());
      }
    }
  }

  Future<void> handleSBData(List<SegmentItemModel> list) async {
    if (list.isNotEmpty) {
      try {
        Completer? completer;
        final duration = list.first.videoDuration ?? data.timeLength!;
        // segmentList
        segmentList.addAll(
          list
              .where(
                (item) =>
                    plPlayerController.enableList.contains(item.category) &&
                    item.segment[1] >= item.segment[0],
              )
              .map(
                (item) {
                  final segmentType = SegmentType.values.byName(item.category);
                  if (item.segment[0] == 0 && item.segment[1] == 0) {
                    videoLabel.value +=
                        '${videoLabel.value.isNotEmpty ? '/' : ''}${segmentType.title}';
                  }
                  SkipType skipType;
                  if (_isBlock) {
                    skipType = plPlayerController
                        .blockSettings[segmentType.index]
                        .second;
                    if (skipType != SkipType.showOnly) {
                      if (item.segment[1] == item.segment[0] ||
                          item.segment[1] - item.segment[0] <
                              plPlayerController.blockLimit) {
                        skipType = SkipType.showOnly;
                      }
                    }
                  } else {
                    skipType = Pref.pgcSkipType;
                  }

                  final segmentModel = SegmentModel(
                    UUID: item.uuid,
                    segmentType: segmentType,
                    segment: Pair(
                      first: item.segment[0],
                      second: item.segment[1],
                    ),
                    skipType: skipType,
                  );

                  if (positionSubscription == null &&
                      autoPlay.value &&
                      plPlayerController.videoPlayerController != null) {
                    final currPost =
                        defaultST?.inMilliseconds ??
                        plPlayerController.position.value.inMilliseconds;

                    if (currPost >= segmentModel.segment.first &&
                        currPost < segmentModel.segment.second) {
                      _lastPos = currPost;

                      switch (segmentModel.skipType) {
                        case SkipType.alwaysSkip:
                        case SkipType.skipOnce:
                          segmentModel.hasSkipped = true;
                          completer = Completer();
                          final videoPlayerController =
                              plPlayerController.videoPlayerController!;
                          if (videoPlayerController.state.playing) {
                            onSkip(
                              segmentModel,
                            ).whenComplete(completer!.complete);
                          } else {
                            videoPlayerController.stream.playing.firstWhere((
                              e,
                            ) {
                              if (e) {
                                onSkip(
                                  segmentModel,
                                ).whenComplete(completer!.complete);
                                return true;
                              }
                              return false;
                            });
                          }

                          break;
                        case SkipType.skipManually:
                          onAddItem(segmentModel);
                          break;
                        default:
                          break;
                      }
                    }
                  }

                  return segmentModel;
                },
              ),
        );

        // _segmentProgressList
        segmentProgressList.addAll(
          segmentList.map((e) {
            double start = (e.segment.first / duration).clamp(0.0, 1.0);
            double end = (e.segment.second / duration).clamp(0.0, 1.0);
            return Segment(start, end, _getColor(e.segmentType));
          }),
        );

        if (positionSubscription == null &&
            (autoPlay.value || plPlayerController.preInitPlayer)) {
          await completer?.future;
          initSkip();
        }
      } catch (e) {
        if (kDebugMode) debugPrint('failed to parse sponsorblock: $e');
      }
    }
  }

  void initSkip() {
    if (segmentList.isNotEmpty) {
      positionSubscription?.cancel();
      positionSubscription = plPlayerController
          .videoPlayerController
          ?.stream
          .position
          .listen((position) {
            int currentPos = position.inSeconds;
            if (currentPos != _lastPos) {
              _lastPos = currentPos;
              final msPos = currentPos * 1000;
              for (SegmentModel item in segmentList) {
                // if (kDebugMode) {
                //   debugPrint(
                //       '${position.inSeconds},,${item.segment.first},,${item.segment.second},,${item.skipType.name},,${item.hasSkipped}');
                // }
                if (msPos <= item.segment.first &&
                    item.segment.first <= msPos + 1000) {
                  switch (item.skipType) {
                    case SkipType.alwaysSkip:
                      onSkip(item, isSeek: false);
                      break;
                    case SkipType.skipOnce:
                      if (!item.hasSkipped) {
                        item.hasSkipped = true;
                        onSkip(item, isSeek: false);
                      }
                      break;
                    case SkipType.skipManually:
                      onAddItem(item);
                      break;
                    default:
                      break;
                  }
                  break;
                }
              }
            }
          });
    }
  }

  void onAddItem(dynamic item) {
    if (listData.contains(item)) return;
    listData.insert(0, item);
    listKey.currentState?.insertItem(0);
    skipTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
      if (listData.isNotEmpty) {
        onRemoveItem(listData.length - 1, listData.last);
      }
    });
  }

  void cancelSkipTimer() {
    skipTimer?.cancel();
    skipTimer = null;
  }

  void onRemoveItem(int index, item) {
    EasyThrottle.throttle(
      'onRemoveItem',
      const Duration(milliseconds: 500),
      () {
        try {
          listData.removeAt(index);
          if (listData.isEmpty) {
            cancelSkipTimer();
          }
          listKey.currentState?.removeItem(
            index,
            (context, animation) => buildItem(item, animation),
          );
        } catch (_) {}
      },
    );
  }

  Widget buildItem(dynamic item, Animation<double> animation) {
    final theme = Get.theme;
    return Align(
      alignment: Alignment.centerLeft,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(-1, 0),
          end: Offset.zero,
        ).animate(animation),
        child: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: GestureDetector(
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              if (details.delta.dx < 0) {
                onRemoveItem(listData.indexOf(item), item);
              }
            },
            child: SearchText(
              bgColor: theme.colorScheme.secondaryContainer.withValues(
                alpha: 0.8,
              ),
              textColor: theme.colorScheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              fontSize: 14,
              text: item is SegmentModel
                  ? '跳过: ${item.segmentType.shortTitle}'
                  : '上次看到第${item + 1}P，点击跳转',
              onTap: (_) {
                if (item is int) {
                  try {
                    UgcIntroController ugcIntroController =
                        Get.find<UgcIntroController>(tag: heroTag);
                    Part part =
                        ugcIntroController.videoDetail.value.pages![item];
                    ugcIntroController.onChangeEpisode(part);
                    SmartDialog.showToast('已跳至第${item + 1}P');
                  } catch (e) {
                    if (kDebugMode) debugPrint('$e');
                    SmartDialog.showToast('跳转失败');
                  }
                  onRemoveItem(listData.indexOf(item), item);
                } else if (item is SegmentModel) {
                  onSkip(item, isSeek: false);
                  onRemoveItem(listData.indexOf(item), item);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> onSkip(
    SegmentModel item, {
    bool isSkip = true,
    bool isSeek = true,
  }) async {
    try {
      await plPlayerController.seekTo(
        Duration(milliseconds: item.segment.second),
        isSeek: isSeek,
      );
      if (isSkip) {
        if (autoPlay.value && Pref.blockToast) {
          _showBlockToast('已跳过${item.segmentType.shortTitle}片段');
        }
        if (_isBlock && Pref.blockTrack) {
          Request().post(
            '$blockServer/api/viewedVideoSponsorTime',
            queryParameters: {'UUID': item.UUID},
          );
        }
      } else {
        _showBlockToast('已跳至${item.segmentType.shortTitle}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('failed to skip: $e');
      if (isSkip) {
        _showBlockToast('${item.segmentType.shortTitle}片段跳过失败');
      } else {
        _showBlockToast('跳转失败');
      }
    }
  }

  ({int mode, int fontsize, Color color})? dmConfig;
  String? savedDanmaku;

  /// 发送弹幕
  Future<void> showShootDanmakuSheet() async {
    if (plPlayerController.dmState.contains(cid.value)) {
      SmartDialog.showToast('UP主已关闭弹幕');
      return;
    }
    bool isPlaying =
        plPlayerController.playerStatus.status.value == PlayerStatus.playing;
    if (isPlaying) {
      await plPlayerController.pause();
    }
    await Navigator.of(Get.context!).push(
      GetDialogRoute(
        pageBuilder: (buildContext, animation, secondaryAnimation) {
          return SendDanmakuPanel(
            cid: cid.value,
            bvid: bvid,
            progress: plPlayerController.position.value.inMilliseconds,
            initialValue: savedDanmaku,
            onSave: (danmaku) => savedDanmaku = danmaku,
            callback: (danmakuModel) {
              savedDanmaku = null;
              plPlayerController.danmakuController?.addDanmaku(danmakuModel);
            },
            darkVideoPage: plPlayerController.darkVideoPage,
            dmConfig: dmConfig,
            onSaveDmConfig: (dmConfig) => this.dmConfig = dmConfig,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: animation.drive(
              Tween(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.linear)),
            ),
            child: child,
          );
        },
      ),
    );
    if (isPlaying) {
      plPlayerController.play();
    }
  }

  VideoItem findVideoByQa(int qa) {
    /// 根据currentVideoQa和currentDecodeFormats 重新设置videoUrl
    final videoList = data.dash!.video!.where((i) => i.id == qa).toList();

    final currentDecodeFormats = this.currentDecodeFormats.codes;
    final defaultDecodeFormats = VideoDecodeFormatType.fromString(
      cacheDecode,
    ).codes;
    final secondDecodeFormats = VideoDecodeFormatType.fromString(
      cacheSecondDecode,
    ).codes;

    VideoItem? video;
    for (var i in videoList) {
      final codec = i.codecs!;
      if (currentDecodeFormats.any(codec.startsWith)) {
        video = i;
        break;
      } else if (defaultDecodeFormats.any(codec.startsWith)) {
        video = i;
      } else if (video == null && secondDecodeFormats.any(codec.startsWith)) {
        video = i;
      }
    }
    return video ?? videoList.first;
  }

  /// 更新画质、音质
  void updatePlayer() {
    autoPlay.value = true;
    playedTime = plPlayerController.position.value;
    plPlayerController
      ..removeListeners()
      ..isBuffering.value = false
      ..buffered.value = Duration.zero;

    final video = findVideoByQa(currentVideoQa.value.code);
    if (firstVideo.codecs != video.codecs) {
      currentDecodeFormats = VideoDecodeFormatType.fromString(video.codecs!);
    }
    firstVideo = video;
    videoUrl = video.baseUrl!;

    /// 根据currentAudioQa 重新设置audioUrl
    if (currentAudioQa != null) {
      final firstAudio = data.dash!.audio!.firstWhere(
        (i) => i.id == currentAudioQa!.code,
        orElse: () => data.dash!.audio!.first,
      );
      audioUrl = firstAudio.baseUrl ?? '';
    }

    playerInit();
  }

  Future<void> playerInit({
    String? video,
    String? audio,
    Duration? seekToTime,
    Duration? duration,
    bool? autoplay,
    Volume? volume,
  }) async {
    await plPlayerController.setDataSource(
      DataSource(
        videoSource: plPlayerController.onlyPlayAudio.value
            ? audio ?? audioUrl
            : video ?? videoUrl,
        audioSource: plPlayerController.onlyPlayAudio.value
            ? ''
            : audio ?? audioUrl,
        type: DataSourceType.network,
        httpHeaders: {
          'user-agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.36',
          'referer': HttpString.baseUrl,
        },
      ),
      seekTo: seekToTime ?? defaultST ?? playedTime,
      duration:
          duration ??
          (data.timeLength == null
              ? null
              : Duration(milliseconds: data.timeLength!)),
      isVertical: isVertical.value,
      aid: aid,
      bvid: bvid,
      cid: cid.value,
      autoplay: autoplay ?? autoPlay.value,
      epid: isUgc ? null : epId,
      seasonId: isUgc ? null : seasonId,
      pgcType: isUgc ? null : pgcType,
      videoType: videoType,
      callback: () {
        if (videoState.value is! Success) {
          videoState.value = const Success(null);
        }
        setSubtitle(vttSubtitlesIndex.value);
      },
      width: firstVideo.width,
      height: firstVideo.height,
      volume: volume ?? this.volume,
    );

    if (plPlayerController.enableSponsorBlock) {
      initSkip();
    }

    if (vttSubtitlesIndex.value == -1) {
      _queryPlayInfo();
    }

    if (plPlayerController.showDmChart && dmTrend.value == null) {
      _getDmTrend();
    }

    defaultST = null;
  }

  bool isQuerying = false;

  final Rx<List<LanguageItem>?> languages = Rx<List<LanguageItem>?>(null);
  final Rx<String?> currLang = Rx<String?>(null);
  void setLanguage(String language) {
    if (!isLoginVideo) {
      SmartDialog.showToast('账号未登录');
      return;
    }
    currLang.value = language;
    queryVideoUrl(defaultST: playedTime);
  }

  Volume? volume;

  // 视频链接
  Future<void> queryVideoUrl({
    Duration? defaultST,
    bool fromReset = false,
  }) async {
    if (isQuerying) {
      return;
    }
    isQuerying = true;
    if (plPlayerController.enableSponsorBlock && _isBlock && !fromReset) {
      _querySponsorBlock();
    }
    if (plPlayerController.cacheVideoQa == null) {
      final isWiFi = await Utils.isWiFi;
      plPlayerController
        ..cacheVideoQa = isWiFi
            ? Pref.defaultVideoQa
            : Pref.defaultVideoQaCellular
        ..cacheAudioQa = isWiFi
            ? Pref.defaultAudioQa
            : Pref.defaultAudioQaCellular;
    }

    var result = await VideoHttp.videoUrl(
      cid: cid.value,
      bvid: bvid,
      epid: epId,
      seasonId: seasonId,
      tryLook: plPlayerController.tryLook,
      videoType: _actualVideoType ?? videoType,
      language: currLang.value,
    );

    if (result.isSuccess) {
      data = result.data;

      languages.value = data.language?.items;
      currLang.value = data.curLanguage;

      volume = data.volume;

      final progress = args['progress'];
      if (progress != null) {
        this.defaultST = Duration(milliseconds: progress);
        args['progress'] = null;
      } else {
        this.defaultST =
            defaultST ??
            (data.lastPlayTime == null
                ? Duration.zero
                : Duration(milliseconds: data.lastPlayTime!));
      }

      if (!isUgc && !fromReset && plPlayerController.enablePgcSkip) {
        if (data.clipInfoList case final clipInfoList?) {
          positionSubscription?.cancel();
          positionSubscription = null;
          handleSBData(clipInfoList);
        }
      }

      if (data.acceptDesc?.contains('试看') == true) {
        SmartDialog.showToast(
          '该视频为专属视频，仅提供试看',
          displayTime: const Duration(seconds: 3),
        );
      }
      if (data.dash == null && data.durl != null) {
        videoUrl = data.durl!.first.url!;
        audioUrl = '';

        // 实际为FLV/MP4格式，但已被淘汰，这里仅做兜底处理
        firstVideo = VideoItem(
          id: data.quality!,
          baseUrl: videoUrl,
          codecs: 'avc1',
          quality: VideoQuality.fromCode(data.quality!),
        );
        setVideoHeight();
        currentDecodeFormats = VideoDecodeFormatType.fromString('avc1');
        currentVideoQa = Rx(VideoQuality.fromCode(data.quality!));
        if (autoPlay.value || plPlayerController.preInitPlayer) {
          await playerInit();
        }
        isQuerying = false;
        return;
      }
      if (data.dash == null) {
        SmartDialog.showToast('视频资源不存在');
        autoPlay.value = false;
        videoState.value = const Error('视频资源不存在');
        if (plPlayerController.isFullScreen.value) {
          plPlayerController.toggleFullScreen(false);
        }
        isQuerying = false;
        return;
      }
      final List<VideoItem> allVideosList = data.dash!.video!;
      // if (kDebugMode) debugPrint("allVideosList:${allVideosList}");
      // 当前可播放的最高质量视频
      int currentHighVideoQa = allVideosList.first.quality.code;
      // 预设的画质为null，则当前可用的最高质量
      int resVideoQa = currentHighVideoQa;
      if (data.acceptQuality?.isNotEmpty == true &&
          plPlayerController.cacheVideoQa! <= currentHighVideoQa) {
        // 如果预设的画质低于当前最高
        final List<int> numbers = data.acceptQuality!
            .where((e) => e <= currentHighVideoQa)
            .toList();
        resVideoQa = Utils.findClosestNumber(
          plPlayerController.cacheVideoQa!,
          numbers,
        );
      }
      currentVideoQa = Rx(VideoQuality.fromCode(resVideoQa));

      /// 取出符合当前画质的videoList
      final List<VideoItem> videosList = allVideosList
          .where((e) => e.quality.code == resVideoQa)
          .toList();

      /// 优先顺序 设置中指定解码格式 -> 当前可选的首个解码格式
      final List<FormatItem> supportFormats = data.supportFormats!;
      // 根据画质选编码格式
      final List<String> supportDecodeFormats = supportFormats
          .firstWhere(
            (e) => e.quality == resVideoQa,
            orElse: () => supportFormats.first,
          )
          .codecs!;
      // 默认从设置中取AV1
      currentDecodeFormats = VideoDecodeFormatType.fromString(cacheDecode);
      VideoDecodeFormatType secondDecodeFormats =
          VideoDecodeFormatType.fromString(cacheSecondDecode);
      // 当前视频没有对应格式返回第一个
      int flag = 0;
      for (var i in supportDecodeFormats) {
        if (currentDecodeFormats.codes.any(i.startsWith)) {
          flag = 1;
          break;
        } else if (secondDecodeFormats.codes.any(i.startsWith)) {
          flag = 2;
        }
      }
      if (flag == 2) {
        currentDecodeFormats = secondDecodeFormats;
      } else if (flag == 0) {
        currentDecodeFormats = VideoDecodeFormatType.fromString(
          supportDecodeFormats.first,
        );
      }

      /// 取出符合当前解码格式的videoItem
      firstVideo = videosList.firstWhere(
        (e) => currentDecodeFormats.codes.any(e.codecs!.startsWith),
        orElse: () => videosList.first,
      );
      setVideoHeight();

      videoUrl = VideoUtils.getCdnUrl(firstVideo);

      /// 优先顺序 设置中指定质量 -> 当前可选的最高质量
      AudioItem? firstAudio;
      final audiosList = data.dash?.audio;
      if (audiosList != null && audiosList.isNotEmpty) {
        final List<int> numbers = audiosList.map((map) => map.id!).toList();
        int closestNumber = Utils.findClosestNumber(
          plPlayerController.cacheAudioQa,
          numbers,
        );
        if (!numbers.contains(plPlayerController.cacheAudioQa) &&
            numbers.any((e) => e > plPlayerController.cacheAudioQa)) {
          closestNumber = 30280;
        }
        firstAudio = audiosList.firstWhere(
          (e) => e.id == closestNumber,
          orElse: () => audiosList.first,
        );
        audioUrl = VideoUtils.getCdnUrl(firstAudio);
        if (firstAudio.id != null) {
          currentAudioQa = AudioQuality.fromCode(firstAudio.id!);
        }
      } else {
        firstAudio = AudioItem();
        audioUrl = '';
      }
      if (autoPlay.value || plPlayerController.preInitPlayer) {
        await playerInit();
      }
    } else {
      autoPlay.value = false;
      videoState.value = result..toast();
      if (plPlayerController.isFullScreen.value) {
        plPlayerController.toggleFullScreen(false);
      }
    }
    isQuerying = false;
  }

  void onBlock(BuildContext context) {
    if (postList.isEmpty) {
      postList.add(
        PostSegmentModel(
          segment: Pair(
            first: 0,
            second: plPlayerController.position.value.inMilliseconds / 1000,
          ),
          category: SegmentType.sponsor,
          actionType: ActionType.skip,
        ),
      );
    }
    if (plPlayerController.isFullScreen.value || showVideoSheet) {
      PageUtils.showVideoBottomSheet(
        context,
        child: plPlayerController.darkVideoPage && MyApp.darkThemeData != null
            ? Theme(
                data: MyApp.darkThemeData!,
                child: PostPanel(
                  enableSlide: false,
                  videoDetailController: this,
                  plPlayerController: plPlayerController,
                ),
              )
            : PostPanel(
                enableSlide: false,
                videoDetailController: this,
                plPlayerController: plPlayerController,
              ),
        isFullScreen: () => plPlayerController.isFullScreen.value,
      );
    } else {
      childKey.currentState?.showBottomSheet(
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(),
        (context) => PostPanel(
          videoDetailController: this,
          plPlayerController: plPlayerController,
        ),
      );
    }
  }

  RxList<Subtitle> subtitles = RxList<Subtitle>();
  late final Map<int, String> _vttSubtitles = {};
  late final RxInt vttSubtitlesIndex = (-1).obs;
  late final RxBool showVP = true.obs;
  late final RxList<Segment> viewPointList = <Segment>[].obs;

  // 设定字幕轨道
  Future<void> setSubtitle(int index) async {
    if (index <= 0) {
      plPlayerController.videoPlayerController?.setSubtitleTrack(
        SubtitleTrack.no(),
      );
      vttSubtitlesIndex.value = index;
      return;
    }

    void setSub(String subtitle) {
      plPlayerController.videoPlayerController?.setSubtitleTrack(
        SubtitleTrack.data(
          subtitle,
          title: subtitles[index - 1].lanDoc,
          language: subtitles[index - 1].lan,
        ),
      );
      vttSubtitlesIndex.value = index;
    }

    String? subtitle = _vttSubtitles[index - 1];
    if (subtitle != null) {
      setSub(subtitle);
    } else {
      var result = await VideoHttp.vttSubtitles(
        subtitles[index - 1].subtitleUrl!,
      );
      if (result != null) {
        _vttSubtitles[index - 1] = result;
        setSub(result);
      }
    }
  }

  // interactive video
  int? graphVersion;
  EdgeInfoData? steinEdgeInfo;
  late final RxBool showSteinEdgeInfo = false.obs;

  Future<void> getSteinEdgeInfo([int? edgeId]) async {
    steinEdgeInfo = null;
    try {
      var res = await Request().get(
        '/x/stein/edgeinfo_v2',
        queryParameters: {
          'bvid': bvid,
          'graph_version': graphVersion,
          'edge_id': ?edgeId,
        },
      );
      if (res.data['code'] == 0) {
        steinEdgeInfo = EdgeInfoData.fromJson(res.data['data']);
      } else {
        if (kDebugMode) {
          debugPrint('getSteinEdgeInfo error: ${res.data['message']}');
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('getSteinEdgeInfo: $e');
    }
  }

  late bool continuePlayingPart = Pref.continuePlayingPart;

  Future<void> _queryPlayInfo() async {
    _vttSubtitles.clear();
    vttSubtitlesIndex.value = 0;
    if (plPlayerController.showViewPoints) {
      viewPointList.clear();
    }
    var res = await VideoHttp.playInfo(bvid: bvid, cid: cid.value);
    if (res['status']) {
      PlayInfoData playInfo = res['data'];
      // interactive video
      if (isUgc && graphVersion == null) {
        try {
          final introCtr = Get.find<UgcIntroController>(tag: heroTag);
          if (introCtr.videoDetail.value.rights?.isSteinGate == 1) {
            graphVersion = playInfo.interaction?.graphVersion;
            getSteinEdgeInfo();
          }
        } catch (e) {
          if (kDebugMode) debugPrint('handle stein: $e');
        }
      }

      if (isUgc && continuePlayingPart) {
        continuePlayingPart = false;
        try {
          UgcIntroController ugcIntroController = Get.find<UgcIntroController>(
            tag: heroTag,
          );
          if ((ugcIntroController.videoDetail.value.pages?.length ?? 0) > 1 &&
              playInfo.lastPlayCid != null &&
              playInfo.lastPlayCid != 0) {
            if (playInfo.lastPlayCid != cid.value) {
              int index = ugcIntroController.videoDetail.value.pages!
                  .indexWhere((item) => item.cid == playInfo.lastPlayCid);
              if (index != -1) {
                onAddItem(index);
              }
            }
          }
        } catch (_) {}
      }

      if (plPlayerController.showViewPoints &&
          playInfo.viewPoints?.firstOrNull?.type == 2) {
        try {
          viewPointList.value = playInfo.viewPoints!.map((item) {
            double start = (item.to! / (data.timeLength! / 1000)).clamp(
              0.0,
              1.0,
            );
            return Segment(
              start,
              start,
              Colors.black.withValues(alpha: 0.5),
              item.content,
              item.imgUrl,
              item.from,
              item.to,
            );
          }).toList();
        } catch (_) {}
      }

      if (playInfo.subtitle?.subtitles?.isNotEmpty == true) {
        subtitles.value = playInfo.subtitle!.subtitles!;

        final idx = switch (SubtitlePrefType.values[Pref
            .subtitlePreferenceV2]) {
          SubtitlePrefType.off => 0,
          SubtitlePrefType.on => 1,
          SubtitlePrefType.withoutAi =>
            subtitles.first.lan.startsWith('ai') ? 0 : 1,
          SubtitlePrefType.auto =>
            !subtitles.first.lan.startsWith('ai') ||
                    (Utils.isMobile &&
                        (await FlutterVolumeController.getVolume() ?? 0.0) <=
                            0.0)
                ? 1
                : 0,
        };
        setSubtitle(idx);
      }
    }
  }

  void updateMediaListHistory(int aid) {
    if (args['sortField'] != null) {
      VideoHttp.medialistHistory(
        desc: _mediaDesc ? 1 : 0,
        oid: aid,
        upperMid: args['mediaId'],
      );
    }
  }

  void makeHeartBeat() {
    if (plPlayerController.enableHeart &&
        plPlayerController.playerStatus.status.value !=
            PlayerStatus.completed &&
        playedTime != null) {
      try {
        plPlayerController.makeHeartBeat(
          data.timeLength != null
              ? (data.timeLength! - playedTime!.inMilliseconds).abs() <= 1000
                    ? -1
                    : playedTime!.inSeconds
              : playedTime!.inSeconds,
          type: HeartBeatType.status,
          isManual: true,
          aid: aid,
          bvid: bvid,
          cid: cid.value,
          epid: isUgc ? null : epId,
          seasonId: isUgc ? null : seasonId,
          pgcType: isUgc ? null : pgcType,
          videoType: videoType,
        );
      } catch (_) {}
    }
  }

  @override
  void onClose() {
    tabCtr.dispose();
    scrollCtr
      ..removeListener(scrollListener)
      ..dispose();
    animController?.dispose();
    super.onClose();
  }

  void onReset({bool isStein = false}) {
    playedTime = null;
    defaultST = null;
    videoUrl = null;
    audioUrl = null;

    // language
    languages.value = null;
    currLang.value = null;

    if (scrollRatio.value != 0) {
      scrollRatio.refresh();
    }

    // dm trend
    if (plPlayerController.showDmChart) {
      dmTrend.value = null;
    }

    // danmaku
    savedDanmaku = null;

    // subtitle
    subtitles.clear();
    vttSubtitlesIndex.value = -1;
    _vttSubtitles.clear();

    // view point
    if (plPlayerController.showViewPoints) {
      viewPointList.clear();
    }

    // sponsor block
    if (plPlayerController.enableSponsorBlock) {
      _lastPos = null;
      positionSubscription?.cancel();
      positionSubscription = null;
      videoLabel.value = '';
      segmentList.clear();
      segmentProgressList.clear();
    }

    // interactive video
    if (isStein != true) {
      graphVersion = null;
    }
    steinEdgeInfo = null;
    showSteinEdgeInfo.value = false;
  }

  late final Rx<LoadingState<List<double>>?> dmTrend =
      Rx<LoadingState<List<double>>?>(null);
  late final RxBool showDmTreandChart = true.obs;

  Future<void> _getDmTrend() async {
    dmTrend.value = LoadingState<List<double>>.loading();
    try {
      var res = await Request().get(
        'https://bvc.bilivideo.com/pbp/data',
        queryParameters: {
          'bvid': bvid,
          'cid': cid.value,
        },
      );
      PbpData data = PbpData.fromJson(res.data);
      int stepSec = data.stepSec ?? 0;
      if (stepSec != 0 && data.events?.eDefault?.isNotEmpty == true) {
        dmTrend.value = Success(data.events!.eDefault!);
        return;
      }
      dmTrend.value = const Error(null);
    } catch (e) {
      dmTrend.value = const Error(null);
      if (kDebugMode) debugPrint('_getDmTrend: $e');
    }
  }

  void showNoteList(BuildContext context) {
    String? title;
    try {
      title = Get.find<UgcIntroController>(
        tag: heroTag,
      ).videoDetail.value.title;
    } catch (_) {}
    if (plPlayerController.isFullScreen.value || showVideoSheet) {
      PageUtils.showVideoBottomSheet(
        context,
        child: plPlayerController.darkVideoPage && MyApp.darkThemeData != null
            ? Theme(
                data: MyApp.darkThemeData!,
                child: NoteListPage(
                  oid: aid,
                  enableSlide: false,
                  heroTag: heroTag,
                  isStein: graphVersion != null,
                  title: title,
                ),
              )
            : NoteListPage(
                oid: aid,
                enableSlide: false,
                heroTag: heroTag,
                isStein: graphVersion != null,
                title: title,
              ),
        isFullScreen: () => plPlayerController.isFullScreen.value,
      );
    } else {
      childKey.currentState?.showBottomSheet(
        backgroundColor: Colors.transparent,
        constraints: const BoxConstraints(),
        (context) => NoteListPage(
          oid: aid,
          heroTag: heroTag,
          isStein: graphVersion != null,
          title: title,
        ),
      );
    }
  }

  bool onSkipSegment() {
    try {
      if (plPlayerController.enableSponsorBlock) {
        if (listData.lastOrNull case SegmentModel item) {
          onSkip(item, isSeek: false);
          onRemoveItem(listData.indexOf(item), item);
          return true;
        }
      }
    } catch (_) {
      if (kDebugMode) rethrow;
    }
    return false;
  }

  void toAudioPage() {
    int? id;
    int? extraId;
    PlaylistSource from = PlaylistSource.UP_ARCHIVE;
    if (isPlayAll) {
      id = args['mediaId'];
      extraId = sourceType.extraId;
      from = sourceType.playlistSource;
    } else if (isUgc) {
      try {
        final ctr = Get.find<UgcIntroController>(tag: heroTag);
        id = ctr.videoDetail.value.ugcSeason?.id;
        if (id != null) {
          extraId = 8;
          from = PlaylistSource.MEDIA_LIST;
        }
      } catch (_) {}
    }
    AudioPage.toAudioPage(
      itemType: 1,
      id: id,
      oid: aid,
      subId: [cid.value],
      from: from,
      heroTag: autoPlay.value ? heroTag : null,
      start: playedTime,
      audioUrl: audioUrl,
      extraId: extraId,
    );
  }
}

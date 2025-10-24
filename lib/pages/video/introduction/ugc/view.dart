import 'dart:io';
import 'package:PiliPlus/services/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/common/widgets/pendant_avatar.dart';
import 'package:PiliPlus/common/widgets/scroll_physics.dart';
import 'package:PiliPlus/common/widgets/stat/stat.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:PiliPlus/models/common/stat_type.dart';
import 'package:PiliPlus/models_new/video/video_detail/data.dart';
import 'package:PiliPlus/models_new/video/video_detail/staff.dart';
import 'package:PiliPlus/models_new/video/video_tag/data.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/search/widgets/search_text.dart';
import 'package:PiliPlus/pages/video/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/controller.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/action_item.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/page.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/season.dart';
import 'package:PiliPlus/pages/video/introduction/ugc/widgets/selectable_text.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/extension.dart';
import 'package:PiliPlus/utils/feed_back.dart';
import 'package:PiliPlus/utils/id_utils.dart';
import 'package:PiliPlus/utils/num_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/request_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:expandable/expandable.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart' hide ContextExtensionss;
import 'package:logger/logger.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class UgcIntroPanel extends StatefulWidget {
  const UgcIntroPanel({
    super.key,
    required this.heroTag,
    required this.showAiBottomSheet,
    required this.showEpisodes,
    required this.onShowMemberPage,
    required this.isPortrait,
    required this.isHorizontal,
  });

  final String heroTag;
  final Function showAiBottomSheet;
  final Function showEpisodes;
  final ValueChanged<int?> onShowMemberPage;
  final bool isPortrait;
  final bool isHorizontal;

  @override
  State<UgcIntroPanel> createState() => _UgcIntroPanelState();
}

class _UgcIntroPanelState extends State<UgcIntroPanel> {
  late final UgcIntroController introController;
  late final VideoDetailController videoDetailCtr =
      Get.find<VideoDetailController>(tag: widget.heroTag);

  @override
  void initState() {
    super.initState();
    introController = Get.putOrFind(
      UgcIntroController.new,
      tag: widget.heroTag,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const expandTheme = ExpandableThemeData(
      animationDuration: Duration(milliseconds: 300),
      scrollAnimationDuration: Duration(milliseconds: 300),
      crossFadePoint: 0,
      fadeCurve: Curves.ease,
      sizeCurve: Curves.linear,
    );
    final isPortrait = widget.isPortrait;
    final isHorizontal = !isPortrait && widget.isHorizontal;
    return SliverPadding(
      padding: const EdgeInsets.only(
        left: StyleString.safeSpace,
        right: StyleString.safeSpace,
        top: 10,
      ),
      sliver: Obx(
        () {
          VideoDetailData videoDetail = introController.videoDetail.value;
          bool isLoading = videoDetail.bvid == null;
          int? mid = videoDetail.owner?.mid;
          return SliverToBoxAdapter(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isLoading) {
                  return;
                }
                feedBack();
                introController.expandableCtr.toggle();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Row(
                      children: [
                        if (videoDetail.staff.isNullOrEmpty) ...[
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildAvatar(
                                theme,
                                () {
                                  if (mid != null) {
                                    feedBack();
                                    if (!isPortrait &&
                                        introController.horizontalMemberPage) {
                                      widget.onShowMemberPage(mid);
                                    } else {
                                      Get.toNamed(
                                        '/member?mid=$mid&from_view_aid=${videoDetailCtr.aid}',
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                          followButton(context, theme),
                        ] else
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: ReloadScrollPhysics(
                                controller: introController,
                              ),
                              child: Row(
                                spacing: 25,
                                children: videoDetail.staff!
                                    .map(
                                      (e) => _buildStaff(
                                        theme,
                                        isPortrait,
                                        mid,
                                        e,
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (isHorizontal) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: actionGrid(
                              context,
                              isLoading,
                              videoDetail,
                              introController,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (isLoading)
                    _buildVideoTitle(theme, videoDetail)
                  else if (isHorizontal && Utils.isDesktop)
                    SelectionArea(
                      child: _buildVideoTitle(
                        theme,
                        videoDetail,
                        isExpand: true,
                      ),
                    )
                  else
                    ExpandablePanel(
                      controller: introController.expandableCtr,
                      collapsed: _buildTitle(theme, videoDetail),
                      expanded: _buildTitle(theme, videoDetail, isExpand: true),
                      theme: expandTheme,
                    ),
                  const SizedBox(height: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildInfo(theme, videoDetail),
                      if (introController.enableAi) _aiBtn,
                    ],
                  ),
                  if (introController.showArgueMsg &&
                      videoDetail.argueInfo?.argueMsg?.isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(
                              size: 13,
                              Icons.error_outline,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const WidgetSpan(child: SizedBox(width: 2)),
                          TextSpan(
                            text: '${videoDetail.argueInfo!.argueMsg}',
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                  if (isHorizontal && Utils.isDesktop)
                    ..._infos(theme, videoDetail)
                  else
                    ExpandablePanel(
                      controller: introController.expandableCtr,
                      collapsed: const SizedBox.shrink(),
                      expanded: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _infos(theme, videoDetail),
                      ),
                      theme: expandTheme,
                    ),
                  Obx(
                    () => introController.status.value
                        ? const SizedBox.shrink()
                        : Center(
                            child: TextButton.icon(
                              icon: const Icon(Icons.refresh),
                              onPressed: () {
                                introController
                                  ..status.value = true
                                  ..queryVideoIntro();
                                if (videoDetailCtr.videoUrl.isNullOrEmpty &&
                                    !videoDetailCtr.isQuerying) {
                                  videoDetailCtr.queryVideoUrl();
                                }
                              },
                              label: const Text("点此重新加载"),
                            ),
                          ),
                  ),
                  // 点赞收藏转发 布局样式2
                  if (!isHorizontal) ...[
                    const SizedBox(height: 8),
                    actionGrid(
                      context,
                      isLoading,
                      videoDetail,
                      introController,
                    ),
                  ],
                  // 合集
                  if (!isLoading &&
                      videoDetail.ugcSeason != null &&
                      (isPortrait ||
                          !videoDetailCtr
                              .plPlayerController
                              .horizontalSeasonPanel))
                    Obx(
                      () => SeasonPanel(
                        key: ValueKey(introController.videoDetail.value),
                        heroTag: widget.heroTag,
                        showEpisodes: widget.showEpisodes,
                        ugcIntroController: introController,
                      ),
                    ),
                  if (!isLoading &&
                      videoDetail.pages != null &&
                      videoDetail.pages!.length > 1 &&
                      (isPortrait ||
                          !videoDetailCtr
                              .plPlayerController
                              .horizontalSeasonPanel))
                    Obx(
                      () => PagesPanel(
                        key: ValueKey(introController.videoDetail.value),
                        heroTag: widget.heroTag,
                        ugcIntroController: introController,
                        bvid: introController.bvid,
                        showEpisodes: widget.showEpisodes,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTitle(
    ThemeData theme,
    VideoDetailData videoDetail, {
    bool isExpand = false,
  }) => GestureDetector(
    onLongPress: () {
      Feedback.forLongPress(context);
      Utils.copyText(videoDetail.title ?? '');
    },
    child: _buildVideoTitle(
      theme,
      videoDetail,
      isExpand: isExpand,
    ),
  );

  List<Widget> _infos(ThemeData theme, VideoDetailData videoDetail) => [
    const SizedBox(height: 8),
    GestureDetector(
      onTap: () => Utils.copyText('${videoDetail.bvid}'),
      child: Text(
        videoDetail.bvid ?? '',
        style: TextStyle(
          fontSize: 14,
          color: theme.colorScheme.secondary,
        ),
      ),
    ),
    if (videoDetail.descV2?.isNotEmpty == true) ...[
      const SizedBox(height: 8),
      selectableRichText(
        style: const TextStyle(height: 1.4),
        buildContent(theme, videoDetail),
      ),
    ],
    Obx(() {
      final videoTags = introController.videoTags.value;
      if (videoTags.isNullOrEmpty) {
        return const SizedBox.shrink();
      }
      return _buildTags(videoTags!);
    }),
  ];

  WidgetSpan _labelWidget(String text, Color bgColor, Color textColor) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        child: Text(
          text,
          textScaler: TextScaler.noScaling,
          strutStyle: const StrutStyle(
            leading: 0,
            height: 1,
            fontSize: 12,
          ),
          style: TextStyle(
            height: 1,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoTitle(
    ThemeData theme,
    VideoDetailData videoDetail, {
    bool isExpand = false,
  }) {
    late final isDark = theme.brightness == Brightness.dark;
    Widget child() {
      final videoLabel = videoDetailCtr.videoLabel.value;
      return Text.rich(
        TextSpan(
          children: [
            if (videoLabel.isNotEmpty) ...[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                          Icon(
                            Icons.play_arrow_rounded,
                            size: 12,
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ),
                      Text(
                        videoLabel,
                        textScaler: TextScaler.noScaling,
                        strutStyle: const StrutStyle(
                          leading: 0,
                          height: 1,
                          fontSize: 13,
                        ),
                        style: TextStyle(
                          height: 1,
                          fontSize: 13,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const TextSpan(text: ' '),
            ],
            if (videoDetail.isUpowerExclusive == true) ...[
              _labelWidget(
                '充电专属',
                isDark
                    ? theme.colorScheme.error
                    : theme.colorScheme.errorContainer,
                isDark
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onErrorContainer,
              ),
              const TextSpan(text: ' '),
            ] else if (videoDetail.rights?.isSteinGate == 1) ...[
              _labelWidget(
                '互动视频',
                theme.colorScheme.secondaryContainer,
                theme.colorScheme.onSecondaryContainer,
              ),
              const TextSpan(text: ' '),
            ],
            TextSpan(text: videoDetail.title ?? ''),
          ],
        ),
        maxLines: isExpand ? null : 2,
        overflow: isExpand ? null : TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 16),
      );
    }

    if (videoDetailCtr.plPlayerController.enableSponsorBlock) {
      return Obx(child);
    }
    return child();
  }

  Widget followButton(BuildContext context, ThemeData t) {
    return Obx(
      () {
        int attr = introController.followStatus['attribute'] ?? 0;
        return TextButton(
          onPressed: () => introController.actionRelationMod(context),
          style: TextButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: const VisualDensity(vertical: -2.8),
            foregroundColor: attr != 0
                ? t.colorScheme.outline
                : t.colorScheme.onSecondaryContainer,
            backgroundColor: attr != 0
                ? t.colorScheme.onInverseSurface
                : t.colorScheme.secondaryContainer,
          ),
          child: Text(
            switch (attr) {
              1 => '悄悄关注',
              2 => '已关注',
              4 || 6 => '已互关',
              128 => '已拉黑',
              -10 => '特别关注',
              _ => ' 关注 ',
            },
            style: const TextStyle(fontSize: 13),
          ),
        );
      },
    );
  }

  Future<bool> mergeVideoAndAudio({required String videoPath,required String audioPath,
    required String outputPath}) async {
    String ffmpegPath = await loadExePath('ffmpeg.exe');
    await loadExePath('avcodec-61.dll');
    await loadExePath('avdevice-61.dll');
    await loadExePath('avfilter-10.dll');
    await loadExePath('avformat-61.dll');
    await loadExePath('avutil-59.dll');
    await loadExePath('swresample-5.dll');
    await loadExePath('swscale-8.dll');

    // 构建命令行参数
    final arguments = [
      '-i', videoPath, // 输入视频
      '-i', audioPath, // 输入音频
      '-c:v', 'copy', // 直接复制视频流，不重新编码
      '-c:a', 'copy', // 直接复制音频流，不重新编码
      outputPath, // 输出文件
      '-y', // 如果输出文件已存在，直接覆盖
    ];

    logger.log(Level.error, '正在执行命令: $ffmpegPath ${arguments.join(' ')}');

    try {
      // 运行 ffmpeg 进程并等待它完成
      final result = await Process.run(ffmpegPath, arguments);

      // 检查退出码。0 表示成功。
      if (result.exitCode == 0) {
        logger.log(Level.error, '合并成功！输出文件: $outputPath');
        return true;
      } else {
        // 如果失败，打印 ffmpeg 的错误输出
        logger..log(Level.error, '合并失败。FFmpeg 退出码: ${result.exitCode}')
          ..log(Level.error, 'FFmpeg 错误日志 (stderr): ${result.stderr}');
        return false;
      }
    } catch (e) {
      logger..log(Level.error, '执行 ffmpeg 命令时发生异常: $e')
        ..log(Level.error, '请确保 ffmpeg 已经安装并添加到了系统的 PATH 环境变量中。');
      return false;
    }
  }

  Future<String> loadExePath(String file) async {
    final Directory appSupportDir = await getApplicationSupportDirectory();
    final String ffmpegPath = path.join(appSupportDir.path, file);
    final File ffmpegFile = File(ffmpegPath);

    if (!ffmpegFile.existsSync()) {
      final ByteData byteData = await rootBundle.load('assets/ffmpeg/$file');
      final List<int> bytes = byteData.buffer.asUint8List();
      await ffmpegFile.writeAsBytes(bytes, flush: true);
    }
    return ffmpegPath;
  }

  Widget actionGrid(
    BuildContext context,
    bool isLoading,
    VideoDetailData videoDetail,
    UgcIntroController introController,
  ) {
    return SizedBox(
      height: 48,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.thumbsUp),
              selectIcon: const Icon(FontAwesomeIcons.solidThumbsUp),
              selectStatus: introController.hasLike.value,
              semanticsLabel: '点赞',
              text: !isLoading
                  ? NumUtils.numFormat(videoDetail.stat!.like)
                  : null,
              onStartTriple: introController.onStartTriple,
              onCancelTriple: introController.onCancelTriple,
            ),
          ),
          Obx(
            () => ActionItem(
              icon: const Icon(FontAwesomeIcons.thumbsDown),
              selectIcon: const Icon(FontAwesomeIcons.solidThumbsDown),
              onTap: () => introController.handleAction(
                introController.actionDislikeVideo,
              ),
              selectStatus: introController.hasDislike.value,
              semanticsLabel: '点踩',
              text: "点踩",
            ),
          ),
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.b),
              selectIcon: const Icon(FontAwesomeIcons.b),
              onTap: introController.actionCoinVideo,
              selectStatus: introController.hasCoin,
              semanticsLabel: '投币',
              text: !isLoading
                  ? NumUtils.numFormat(videoDetail.stat!.coin)
                  : null,
            ),
          ),
          Obx(
            () => ActionItem(
              animation: introController.tripleAnimation,
              icon: const Icon(FontAwesomeIcons.star),
              selectIcon: const Icon(FontAwesomeIcons.solidStar),
              onTap: () => introController.showFavBottomSheet(context),
              onLongPress: () => introController.showFavBottomSheet(
                context,
                isLongPress: true,
              ),
              selectStatus: introController.hasFav.value,
              semanticsLabel: '收藏',
              text: !isLoading
                  ? NumUtils.numFormat(videoDetail.stat!.favorite)
                  : null,
            ),
          ),
          Obx(
            () => ActionItem(
              icon: const Icon(FontAwesomeIcons.clock),
              selectIcon: const Icon(FontAwesomeIcons.solidClock),
              onTap: () =>
                  introController.handleAction(introController.viewLater),
              selectStatus: introController.hasLater.value,
              semanticsLabel: '再看',
              text: '再看',
            ),
          ),
          ActionItem(
            icon: const Icon(FontAwesomeIcons.download),
            onTap: () async {
              var videoUrl = videoDetailCtr.videoUrl!;
              var audioUrl = videoDetailCtr.audioUrl!;
              print(
                'videoUrl = $videoUrl, audioUrl = $audioUrl, args = ${videoDetailCtr.args}',
              );
              var name = videoDetailCtr.args['title']! as String;
              String? path = await FilePicker.platform.getDirectoryPath();
              if(path==null){
                return;
              }

              SmartDialog.showToast('下载中');
              final headers = {
                'origin': 'https://www.bilibili.com',
                'range': 'bytes=0-',
                'referer':
                'https://www.bilibili.com/video/${videoDetailCtr.args['bvid']!}',
                'sec-fetch-mode': 'cors',
                'user-agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36 Edg/141.0.0.0',
              };

              // 3. 定义本地保存路径和文件名
              final savePathVideo = '$path/$name-video';
              final savePathAudio = '$path/$name-audio';

              File logFile = await LoggerUtils.getLogsPath();
              print(logFile.path);
              logger.log(Level.error,'hhhh');
              // 4. 执行下载函数
              await downloadFileWithHeaders(videoUrl, savePathVideo, headers);
              await downloadFileWithHeaders(audioUrl, savePathAudio, headers);
              SmartDialog.showToast('下载完成文件合成中');
              await mergeVideoAndAudio(videoPath: savePathVideo, audioPath: savePathAudio, outputPath: '$path/$name.mp4');
              await File(savePathAudio).delete();
              await File(savePathVideo).delete();
              SmartDialog.showToast('文件保存完成');
            },
            selectStatus: false,
            semanticsLabel: '下载',
            text: '下载',
          ),
          ActionItem(
            icon: const Icon(FontAwesomeIcons.shareFromSquare),
            onTap: () => introController.actionShareVideo(context),
            selectStatus: false,
            semanticsLabel: '分享',
            text: !isLoading
                ? NumUtils.numFormat(videoDetail.stat!.share!)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> downloadFileWithHeaders(
      String url,
      String savePath,
      Map<String, String> headers,
      ) async {
    var httpClient = http.Client();
    try {
      // 创建一个请求对象
      var request = http.Request('GET', Uri.parse(url));

      // 将所有 headers 添加到请求中
      request.headers.addAll(headers);

      // 发送请求并获取流式响应
      var response = await httpClient.send(request);

      // 检查响应状态码。由于这是一个范围请求 (range header),
      // 成功的响应码通常是 206 (Partial Content)。
      if (response.statusCode == 206 || response.statusCode == 200) {
        // 打开一个文件用于写入
        var file = File(savePath);
        var sink = file.openWrite();

        // 将响应流通过管道直接写入文件
        await response.stream.pipe(sink);

        // 关闭文件流
        await sink.close();

        print('文件片段下载成功，并保存至: $savePath');
        print('服务器响应状态码: ${response.statusCode}');
      } else {
        print('下载失败，服务器返回状态码: ${response.statusCode}');
        // 如果需要，可以打印响应内容以进行调试
        // print('错误响应: ${await response.stream.bytesToString()}');
      }
    } catch (e) {
      print('下载过程中发生错误: $e');
    } finally {
      // 确保 HTTP 客户端被关闭
      httpClient.close();
    }
  }

  static final RegExp urlRegExp = RegExp(
    Constants.urlRegex.pattern + r'|av\d+|bv[a-z\d]{10}|(?:\d+[:：])?\d+[:：]\d+',
    caseSensitive: false,
  );

  TextSpan buildContent(ThemeData theme, VideoDetailData content) {
    if (content.descV2.isNullOrEmpty) {
      return const TextSpan();
    }
    // type
    // 1 普通文本
    // 2 @用户
    final List<TextSpan> spanChildren = content.descV2!.map((currentDesc) {
      switch (currentDesc.type) {
        case 1:
          final List<InlineSpan> spanChildren = <InlineSpan>[];
          currentDesc.rawText?.splitMapJoin(
            urlRegExp,
            onMatch: (Match match) {
              final matchStr = match[0]!;
              final matchStrLowerCase = matchStr.toLowerCase();
              if (matchStrLowerCase.startsWith('http')) {
                spanChildren.add(
                  TextSpan(
                    text: matchStr,
                    style: TextStyle(color: theme.colorScheme.primary),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        try {
                          PageUtils.handleWebview(matchStr);
                        } catch (err) {
                          SmartDialog.showToast(err.toString());
                        }
                      },
                  ),
                );
              } else if (matchStrLowerCase.startsWith('av')) {
                try {
                  int aid = int.parse(matchStr.substring(2));
                  IdUtils.av2bv(aid);
                  spanChildren.add(
                    TextSpan(
                      text: matchStr,
                      style: TextStyle(color: theme.colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => PiliScheme.videoPush(aid, null),
                    ),
                  );
                } catch (e) {
                  spanChildren.add(TextSpan(text: matchStr));
                }
              } else if (matchStrLowerCase.startsWith('bv')) {
                try {
                  IdUtils.bv2av(matchStr);
                  spanChildren.add(
                    TextSpan(
                      text: matchStr,
                      style: TextStyle(color: theme.colorScheme.primary),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => PiliScheme.videoPush(null, matchStr),
                    ),
                  );
                } catch (e) {
                  spanChildren.add(TextSpan(text: matchStr));
                }
              } else {
                spanChildren.add(
                  TextSpan(
                    text: matchStr,
                    style: TextStyle(color: theme.colorScheme.primary),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () {
                        try {
                          Get.find<VideoDetailController>(
                            tag: widget.heroTag,
                          ).plPlayerController.seekTo(
                            Duration(
                              seconds: DurationUtils.parseDuration(matchStr),
                            ),
                            isSeek: false,
                          );
                        } catch (_) {}
                      },
                  ),
                );
              }
              return '';
            },
            onNonMatch: (String nonMatchStr) {
              spanChildren.add(TextSpan(text: nonMatchStr));
              return '';
            },
          );
          return TextSpan(children: spanChildren);
        case 2:
          final Color colorSchemePrimary = theme.colorScheme.primary;
          return TextSpan(
            text: '@${currentDesc.rawText}',
            style: TextStyle(color: colorSchemePrimary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => Get.toNamed('/member?mid=${currentDesc.bizId}'),
          );
        default:
          return const TextSpan();
      }
    }).toList();
    return TextSpan(children: spanChildren);
  }

  Widget _buildStaff(
    ThemeData theme,
    bool isPortrait,
    int? ownerMid,
    Staff item,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (item.mid == ownerMid &&
            !isPortrait &&
            introController.horizontalMemberPage) {
          widget.onShowMemberPage(ownerMid);
        } else {
          Get.toNamed(
            '/member?mid=${item.mid}&from_view_aid=${videoDetailCtr.aid}',
          );
        }
      },
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              NetworkImgLayer(
                type: ImageType.avatar,
                src: item.face,
                width: 35,
                height: 35,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
              ),
              if ((item.official?.type ?? -1) != -1)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.surface,
                    ),
                    child: Icon(
                      Icons.offline_bolt,
                      color: item.official?.type == 0
                          ? const Color(0xFFFFCC00)
                          : Colors.lightBlueAccent,
                      size: 14,
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                right: -6,
                child: Obx(
                  () =>
                      introController.staffRelations['status'] == true &&
                          introController.staffRelations['${item.mid}'] == null
                      ? Material(
                          type: MaterialType.transparency,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => RequestUtils.actionRelationMod(
                              context: context,
                              mid: item.mid,
                              isFollow: false,
                              callback: (val) {
                                introController.staffRelations['${item.mid}'] =
                                    true;
                              },
                            ),
                            child: Ink(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                MdiIcons.plus,
                                size: 16,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: (item.vip?.status ?? 0) > 0 && item.vip?.type == 2
                      ? theme.colorScheme.vipColor
                      : null,
                ),
              ),
              Text(
                item.title!,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(
    ThemeData theme,
    VoidCallback onPushMember,
  ) => GestureDetector(
    onTap: onPushMember,
    behavior: HitTestBehavior.opaque,
    child: Obx(
      () {
        final userStat = introController.userStat.value;
        final isVip = (userStat.card?.vip?.status ?? 0) > 0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PendantAvatar(
              avatar: userStat.card?.face,
              size: 35,
              badgeSize: 14,
              isVip: isVip,
              officialType: userStat.card?.official?.type,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userStat.card?.name ?? "",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isVip && userStat.card?.vip?.type == 2
                        ? theme.colorScheme.vipColor
                        : null,
                  ),
                ),
                const SizedBox(height: 0),
                Text(
                  '${NumUtils.numFormat(userStat.follower)}粉丝    ${'${NumUtils.numFormat(userStat.archiveCount)}视频'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _buildInfo(ThemeData theme, VideoDetailData videoDetail) => Row(
    spacing: 10,
    children: [
      StatWidget(
        type: StatType.play,
        value: videoDetail.stat?.view,
        color: theme.colorScheme.outline,
      ),
      StatWidget(
        type: StatType.danmaku,
        value: videoDetail.stat?.danmaku,
        color: theme.colorScheme.outline,
      ),
      Text(
        DateFormatUtils.format(videoDetail.pubdate),
        style: TextStyle(
          fontSize: 12,
          color: theme.colorScheme.outline,
        ),
      ),
      if (MineController.anonymity.value)
        Icon(
          MdiIcons.incognito,
          size: 15,
          color: theme.colorScheme.outline,
          semanticLabel: '无痕',
        ),
      if (introController.isShowOnlineTotal)
        Obx(
          () => Text(
            '${introController.total.value}人在看',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.outline,
            ),
          ),
        ),
    ],
  );

  Widget get _aiBtn => Positioned(
    right: 8,
    child: Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (introController.aiConclusionResult == null) {
            await introController.aiConclusion();
          }
          if (introController.aiConclusionResult case final res?) {
            if (res.summary?.isNotEmpty == true ||
                res.outline?.isNotEmpty == true) {
              widget.showAiBottomSheet();
            } else {
              SmartDialog.showToast("当前视频不支持AI视频总结");
            }
          }
        },
        child: Image.asset(
          semanticLabel: 'AI总结',
          'assets/images/ai.png',
          height: 18,
          width: 18,
        ),
      ),
    ),
  );

  Widget _buildTags(List<VideoTagItem> tags) {
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags
              .map(
                (item) => SearchText(
                  fontSize: 13,
                  text: switch (item.tagType) {
                    'bgm' => item.tagName!.replaceFirst('发现', '\u{1f3b5}BGM：'),
                    'topic' => '#${item.tagName}',
                    _ => item.tagName!,
                  },
                  onTap: switch (item.tagType) {
                    'bgm' => (_) => Get.toNamed(
                      '/musicDetail',
                      parameters: {'musicId': item.musicId!},
                    ),
                    'topic' => (_) => Get.toNamed(
                      '/dynTopic',
                      parameters: {'id': item.tagId!.toString()},
                    ),
                    _ => (tagName) => Get.toNamed(
                      '/searchResult',
                      parameters: {'keyword': tagName},
                    ),
                  },
                  onLongPress: Utils.copyText,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

// Panel Component
Item {
  id: root

  property var pluginApi: null
  readonly property var runtime: pluginApi?.mainInstance
  readonly property var snapshot: runtime?.activeWindowSnapshot || ({})
  readonly property var mediaSnapshot: runtime?.activeMediaSnapshot || ({})
  readonly property bool hasActiveMediaSnapshot: runtime?.hasActiveMediaSnapshot === true
  readonly property bool showPluginInfo: (pluginApi?.pluginSettings?.showPluginInfo ?? pluginApi?.manifest?.metadata?.defaultSettings?.showPluginInfo ?? false)
  readonly property bool scheduledRefreshEnabled: runtime?.scheduledRefreshEnabled === true
  readonly property int scheduledRefreshIntervalMs: runtime?.scheduledRefreshIntervalMs || 5000
  property double nextScheduledRefreshEpochMs: 0
  property int scheduledRefreshCountdownSec: 0
  property string debugPayloadEdit: ""
  property bool debugPayloadDirty: false
  property bool hydratingDebugPayload: false
  property string debugTestState: "idle"
  property int debugTestHttpStatus: 0

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 440 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.max(220 * Style.uiScaleRatio, mainColumn.implicitHeight + Style.marginL * 2)

  readonly property bool allowAttach: true

  anchors.fill: parent

  function triggerManualRefresh() {
    if (!runtime?.manualRefreshAndUpload) {
      Logger.w("ActiveUpload", "Cannot refresh: main instance unavailable");
      return;
    }
    runtime.manualRefreshAndUpload();
    ToastService.showNotice("Process Reporter", pluginApi?.tr("panel.refresh-triggered") || "已请求刷新并上传");
  }

  function openPluginSettings() {
    if (!pluginApi?.manifest) {
      Logger.w("ActiveUpload", "Cannot open settings: manifest missing");
      return;
    }

    var panelScreen = pluginApi?.panelOpenScreen;
    if (panelScreen) {
      Logger.i("ActiveUpload", "Opening plugin settings from panelOpenScreen:", panelScreen.name);
      BarService.openPluginSettings(panelScreen, pluginApi.manifest);
      return;
    }

    Logger.w("ActiveUpload", "panelOpenScreen missing, fallback to withCurrentScreen");
    pluginApi.withCurrentScreen(screen => {
      if (!screen) {
        Logger.e("ActiveUpload", "Cannot open settings: no current screen");
        return;
      }
      Logger.i("ActiveUpload", "Opening plugin settings from current screen:", screen.name);
      BarService.openPluginSettings(screen, pluginApi.manifest);
    });
  }

  function resetScheduledCountdown() {
    if (!scheduledRefreshEnabled) {
      nextScheduledRefreshEpochMs = 0;
      scheduledRefreshCountdownSec = 0;
      return;
    }

    var baseEpoch = runtime?.lastUpdatedEpochMs || Date.now();
    nextScheduledRefreshEpochMs = baseEpoch + scheduledRefreshIntervalMs;
    updateScheduledCountdown();
  }

  function updateScheduledCountdown() {
    if (!scheduledRefreshEnabled || nextScheduledRefreshEpochMs <= 0) {
      scheduledRefreshCountdownSec = 0;
      return;
    }

    var remainMs = nextScheduledRefreshEpochMs - Date.now();
    if (remainMs < 0) {
      remainMs = 0;
    }
    scheduledRefreshCountdownSec = Math.ceil(remainMs / 1000);
  }

  function copyRawAppIdToClipboard() {
    var rawId = String(snapshot.rawAppId || "").trim();
    if (!rawId) {
      ToastService.showNotice("Process Reporter", pluginApi?.tr("panel.copy-empty") || "当前无可复制的原始 App ID");
      return;
    }

    var escaped = rawId.replace(/'/g, "'\\''");
    var command = "printf %s '" + escaped + "' | wl-copy --type text/plain";
    copyTextProcess.exec({
      command: ["sh", "-c", command]
    });
  }

  function resetDebugPayloadDraft(forceReset) {
    if (!forceReset && root.debugPayloadDirty) {
      return;
    }

    var nextText = runtime?.buildDebugPayloadJson ? runtime.buildDebugPayloadJson("panel-preview") : "{}";
    root.hydratingDebugPayload = true;
    root.debugPayloadEdit = nextText;
    if (payloadEditor) {
      payloadEditor.text = nextText;
    }
    root.hydratingDebugPayload = false;
    root.debugPayloadDirty = false;
    root.debugTestState = "idle";
    root.debugTestHttpStatus = 0;
  }

  function runDebugUploadTest() {
    if (!runtime?.testUploadPayload) {
      root.debugTestState = "failed";
      root.debugTestHttpStatus = 0;
      return;
    }

    root.debugTestState = "uploading";
    root.debugTestHttpStatus = 0;

    runtime.testUploadPayload(root.debugPayloadEdit, function(ok, statusCode, reason) {
      root.debugTestState = reason || (ok ? "success" : "failed");
      root.debugTestHttpStatus = statusCode || 0;
    });
  }

  function toggleUploadPause() {
    if (!runtime?.setUploadPaused) {
      return;
    }

    var nextPaused = !(runtime?.uploadPaused === true);
    runtime.setUploadPaused(nextPaused);
    ToastService.showNotice(
      "Process Reporter",
      nextPaused
        ? (pluginApi?.tr("panel.debug.pause-enabled") || "已暂时暂停自动上报")
        : (pluginApi?.tr("panel.debug.pause-disabled") || "已恢复自动上报")
    );
  }

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("ActiveWindowUpload", "Panel initialized");
    }
    resetScheduledCountdown();
    resetDebugPayloadDraft(true);
  }

  Connections {
    target: runtime

    function onLastUpdatedEpochMsChanged() {
      root.resetScheduledCountdown();
    }

    function onScheduledRefreshEnabledChanged() {
      root.resetScheduledCountdown();
    }

    function onScheduledRefreshIntervalMsChanged() {
      root.resetScheduledCountdown();
    }

    function onActiveWindowSnapshotChanged() {
      root.resetDebugPayloadDraft(false);
    }

    function onActiveMediaSnapshotChanged() {
      root.resetDebugPayloadDraft(false);
    }

    function onHasActiveMediaSnapshotChanged() {
      root.resetDebugPayloadDraft(false);
    }
  }

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      root.resetDebugPayloadDraft(false);
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.scheduledRefreshEnabled
    onTriggered: root.updateScheduledCountdown()
  }

  Process {
    id: copyTextProcess

    onExited: function(exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice("Process Reporter", pluginApi?.tr("panel.copy-success") || "原始 App ID 已复制");
      } else {
        ToastService.showNotice("Process Reporter", pluginApi?.tr("panel.copy-failed") || "复制失败，请确认 wl-copy 可用");
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: mainColumn
      anchors {
        fill: parent
        margins: Style.marginL
      }
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: topCardContent.implicitHeight + Style.marginL * 2
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          id: topCardContent
          anchors.fill: parent
          anchors.margins: Style.marginL
          spacing: Style.marginM

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS

            Rectangle {
              Layout.preferredWidth: 28 * Style.uiScaleRatio
              Layout.preferredHeight: 28 * Style.uiScaleRatio
              radius: Style.radiusS
              color: Color.mPrimaryContainer

              NIcon {
                anchors.centerIn: parent
                icon: "settings-about"
                pointSize: Style.fontSizeM * Style.uiScaleRatio
                color: Color.mOnPrimaryContainer
              }
            }

            NText {
              text: pluginApi?.tr("panel.title") || "Process Reporter"
              font.weight: Font.Bold
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginS
            z: 20

            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS

              NText {
                text: (pluginApi?.tr("panel.last-updated") || "最近更新时间") + ": " + (runtime?.lastUpdatedAt || "-")
                font.pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              NText {
                visible: root.scheduledRefreshEnabled
                text: (pluginApi?.tr("panel.next-refresh") || "下次刷新") + ": " + root.scheduledRefreshCountdownSec + (pluginApi?.tr("panel.seconds-later") || " 秒后")
                font.pointSize: Style.fontSizeS
                color: Color.mPrimary
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }

            Rectangle {
              id: refreshBtn
              Layout.preferredWidth: 34 * Style.uiScaleRatio
              Layout.preferredHeight: 34 * Style.uiScaleRatio
              radius: width / 2
              color: refreshMouse.containsMouse ? Color.mPrimaryContainer : "transparent"
              border.color: Color.mOutline
              border.width: 1
              scale: refreshMouse.containsMouse ? 1.08 : 1.0

              Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              Behavior on color {
                ColorAnimation { duration: 140 }
              }

              NIcon {
                anchors.centerIn: parent
                icon: "refresh"
                pointSize: Style.fontSizeM * Style.uiScaleRatio
                color: refreshMouse.containsMouse ? Color.mOnPrimaryContainer : Color.mOnSurface
              }

              MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerManualRefresh()
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                radius: Style.radiusS
                color: Color.mInverseSurface
                opacity: refreshMouse.containsMouse ? 1 : 0
                visible: opacity > 0
                width: refreshTip.implicitWidth + 16
                height: refreshTip.implicitHeight + 8
                z: 40

                Behavior on opacity {
                  NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }

                NText {
                  id: refreshTip
                  anchors.centerIn: parent
                  text: pluginApi?.tr("panel.refresh-now") || "手动刷新并上传"
                  font.pointSize: Style.fontSizeXS
                  color: Color.mOnInverseSurface
                }
              }
            }

            Rectangle {
              id: settingsBtn
              Layout.preferredWidth: 34 * Style.uiScaleRatio
              Layout.preferredHeight: 34 * Style.uiScaleRatio
              radius: width / 2
              color: settingsMouse.containsMouse ? Color.mSecondaryContainer : "transparent"
              border.color: Color.mOutline
              border.width: 1
              scale: settingsMouse.containsMouse ? 1.08 : 1.0

              Behavior on scale {
                NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
              }

              Behavior on color {
                ColorAnimation { duration: 140 }
              }

              NIcon {
                anchors.centerIn: parent
                icon: "settings"
                pointSize: Style.fontSizeM * Style.uiScaleRatio
                color: settingsMouse.containsMouse ? Color.mOnSecondaryContainer : Color.mPrimary
              }

              MouseArea {
                id: settingsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openPluginSettings()
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.bottom
                anchors.topMargin: 8
                radius: Style.radiusS
                color: Color.mInverseSurface
                opacity: settingsMouse.containsMouse ? 1 : 0
                visible: opacity > 0
                width: settingsTip.implicitWidth + 16
                height: settingsTip.implicitHeight + 8
                z: 40

                Behavior on opacity {
                  NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                }

                NText {
                  id: settingsTip
                  anchors.centerIn: parent
                  text: pluginApi?.tr("panel.open-settings") || "打开插件设置"
                  font.pointSize: Style.fontSizeXS
                  color: Color.mOnInverseSurface
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: titleInfo.implicitHeight + Style.marginM * 2
            color: Color.mSurface
            radius: Style.radiusM

            ColumnLayout {
              id: titleInfo
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginXS

              NText {
                text: pluginApi?.tr("panel.window.title") || "Window title"
                font.weight: Font.Medium
                color: Color.mOnSurfaceVariant
              }

              NText {
                text: snapshot.title || "Unknown Window"
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: appInfo.implicitHeight + Style.marginM * 2
            color: Color.mSurface
            radius: Style.radiusM

            ColumnLayout {
              id: appInfo
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginXS

              NText {
                text: pluginApi?.tr("panel.window.app") || "App ID"
                font.weight: Font.Medium
                color: Color.mOnSurfaceVariant
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NImageRounded {
                  Layout.preferredWidth: 18 * Style.uiScaleRatio
                  Layout.preferredHeight: 18 * Style.uiScaleRatio
                  imagePath: ThemeIcons.iconForAppId(snapshot.rawAppId || snapshot.appId, "application-x-executable")
                  fallbackIcon: "apps"
                  borderWidth: 0
                }

                NText {
                  text: snapshot.appId || "-"
                  font.family: Settings.data.ui.fontFixed
                  Layout.fillWidth: true
                  wrapMode: Text.WrapAnywhere
                }
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NText {
                  text: pluginApi?.tr("panel.window.raw-app") || "原始 App ID"
                  font.weight: Font.Medium
                  color: Color.mOnSurfaceVariant
                }

                NText {
                  text: snapshot.rawAppId || "-"
                  font.family: Settings.data.ui.fontFixed
                  Layout.fillWidth: true
                  wrapMode: Text.WrapAnywhere
                }

                Rectangle {
                  Layout.preferredWidth: 62 * Style.uiScaleRatio
                  Layout.preferredHeight: 26 * Style.uiScaleRatio
                  radius: Style.radiusS
                  color: copyRawMouse.containsMouse ? Color.mPrimaryContainer : "transparent"
                  border.color: Color.mOutline
                  border.width: 1

                  NText {
                    anchors.centerIn: parent
                    text: pluginApi?.tr("panel.copy") || "复制"
                    font.pointSize: Style.fontSizeXS
                    color: copyRawMouse.containsMouse ? Color.mOnPrimaryContainer : Color.mOnSurface
                  }

                  MouseArea {
                    id: copyRawMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.copyRawAppIdToClipboard()
                  }
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: mediaInfo.implicitHeight + Style.marginM * 2
            color: Color.mPrimaryContainer
            radius: Style.radiusM

            ColumnLayout {
              id: mediaInfo
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginS

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.marginS

                NIcon {
                  icon: "music"
                  pointSize: Style.fontSizeM * Style.uiScaleRatio
                  color: Color.mOnPrimaryContainer
                }

                NText {
                  text: pluginApi?.tr("panel.media.title") || "媒体信息"
                  font.weight: Font.Bold
                  color: Color.mOnPrimaryContainer
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                  radius: Style.radiusS
                  color: "transparent"
                  border.color: root.hasActiveMediaSnapshot
                    ? (mediaSnapshot.isPlaying ? Color.mPrimary : Color.mSecondary)
                    : Color.mOutline
                  border.width: 1
                  Layout.preferredHeight: 24 * Style.uiScaleRatio
                  Layout.preferredWidth: mediaStateLabel.implicitWidth + Style.marginM * 1.6

                  NText {
                    id: mediaStateLabel
                    anchors.centerIn: parent
                    text: !root.hasActiveMediaSnapshot
                      ? (pluginApi?.tr("panel.media.no-active") || "当前无活跃媒体")
                      : (mediaSnapshot.isPlaying
                        ? (pluginApi?.tr("panel.media.playing") || "播放中")
                        : (pluginApi?.tr("panel.media.paused") || "已暂停"))
                    font.pointSize: Style.fontSizeXS
                    color: root.hasActiveMediaSnapshot
                      ? (mediaSnapshot.isPlaying ? Color.mPrimary : Color.mSecondary)
                      : Color.mOnSurfaceVariant
                  }
                }
              }

              NText {
                visible: !root.hasActiveMediaSnapshot
                text: pluginApi?.tr("panel.media.no-active") || "当前无活跃媒体"
                color: Color.mOnPrimaryContainer
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              RowLayout {
                visible: root.hasActiveMediaSnapshot
                Layout.fillWidth: true
                spacing: Style.marginS

                NImageRounded {
                  Layout.preferredWidth: 48 * Style.uiScaleRatio
                  Layout.preferredHeight: 48 * Style.uiScaleRatio
                  radius: Style.radiusS
                  imagePath: mediaSnapshot.trackArtUrl || ""
                  fallbackIcon: "music"
                  borderWidth: 0
                  imageFillMode: Image.PreserveAspectCrop
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.marginXS

                  NText {
                    text: mediaSnapshot.trackTitle || "-"
                    font.weight: Font.Bold
                    color: Color.mOnPrimaryContainer
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }

                  NText {
                    text: (pluginApi?.tr("panel.media.player") || "播放器") + ": " + (mediaSnapshot.playerIdentity || "-")
                    font.pointSize: Style.fontSizeXS
                    color: Color.mOnPrimaryContainer
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                  }
                }
              }

              NText {
                visible: root.hasActiveMediaSnapshot
                text: (pluginApi?.tr("panel.media.artist") || "艺术家") + ": " + (mediaSnapshot.trackArtist || "-")
                color: Color.mOnPrimaryContainer
                Layout.fillWidth: true
                elide: Text.ElideRight
              }

              NText {
                visible: root.hasActiveMediaSnapshot
                text: (pluginApi?.tr("panel.media.album") || "专辑") + ": " + (mediaSnapshot.trackAlbum || "-")
                color: Color.mOnPrimaryContainer
                Layout.fillWidth: true
                elide: Text.ElideRight
              }
            }
          }
        }
      }

      ColumnLayout {
        visible: root.showPluginInfo
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("panel.debug.title") || "调试与测试"
          font.pointSize: Style.fontSizeM * Style.uiScaleRatio
          font.weight: Font.Medium
          color: Color.mOnSurface
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: payloadColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: payloadColumn
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            NText {
              text: pluginApi?.tr("panel.debug.payload-label") || "云函数上报原文（可编辑）"
              font.pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }

            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: 220 * Style.uiScaleRatio
              color: Color.mSurface
              radius: Style.radiusS
              border.color: Color.mOutline
              border.width: 1
              clip: true

              Flickable {
                id: payloadFlick
                anchors.fill: parent
                anchors.margins: Style.marginS
                contentWidth: Math.max(width, payloadEditor.paintedWidth + Style.marginM)
                contentHeight: Math.max(height, payloadEditor.paintedHeight + Style.marginM)
                clip: true

                TextEdit {
                  id: payloadEditor
                  width: payloadFlick.width
                  height: Math.max(implicitHeight, payloadFlick.height)
                  text: ""
                  wrapMode: TextEdit.NoWrap
                  color: Color.mOnSurface
                  font.family: Settings.data.ui.fontFixed
                  font.pointSize: Style.fontSizeS
                  selectByMouse: true
                  persistentSelection: true

                  Component.onCompleted: {
                    text = root.debugPayloadEdit;
                  }

                  onTextChanged: {
                    root.debugPayloadEdit = text;
                    if (!root.hydratingDebugPayload) {
                      root.debugPayloadDirty = true;
                      if (root.debugTestState !== "uploading") {
                        root.debugTestState = "idle";
                        root.debugTestHttpStatus = 0;
                      }
                    }
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginS

              Rectangle {
                Layout.preferredWidth: 118 * Style.uiScaleRatio
                Layout.preferredHeight: 30 * Style.uiScaleRatio
                radius: Style.radiusS
                color: pauseUploadMouse.containsMouse
                  ? ((runtime?.uploadPaused === true) ? Color.mSecondaryContainer : Color.mErrorContainer)
                  : "transparent"
                border.color: (runtime?.uploadPaused === true) ? Color.mPrimary : Color.mError
                border.width: 1

                NText {
                  anchors.centerIn: parent
                  text: runtime?.uploadPaused === true
                    ? (pluginApi?.tr("panel.debug.resume-upload") || "恢复上报")
                    : (pluginApi?.tr("panel.debug.pause-upload") || "暂停上报")
                  font.pointSize: Style.fontSizeXS
                  color: pauseUploadMouse.containsMouse
                    ? ((runtime?.uploadPaused === true) ? Color.mOnSecondaryContainer : Color.mOnErrorContainer)
                    : ((runtime?.uploadPaused === true) ? Color.mPrimary : Color.mError)
                }

                MouseArea {
                  id: pauseUploadMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggleUploadPause()
                }
              }

              Rectangle {
                Layout.preferredWidth: 138 * Style.uiScaleRatio
                Layout.preferredHeight: 30 * Style.uiScaleRatio
                radius: Style.radiusS
                color: resetPayloadMouse.containsMouse ? Color.mSecondaryContainer : "transparent"
                border.color: Color.mOutline
                border.width: 1

                NText {
                  anchors.centerIn: parent
                  text: pluginApi?.tr("panel.debug.reset") || "重置为当前快照"
                  font.pointSize: Style.fontSizeXS
                  color: resetPayloadMouse.containsMouse ? Color.mOnSecondaryContainer : Color.mOnSurface
                }

                MouseArea {
                  id: resetPayloadMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.resetDebugPayloadDraft(true)
                }
              }

              Rectangle {
                Layout.preferredWidth: 112 * Style.uiScaleRatio
                Layout.preferredHeight: 30 * Style.uiScaleRatio
                radius: Style.radiusS
                color: testUploadMouse.containsMouse ? Color.mPrimaryContainer : "transparent"
                border.color: Color.mOutline
                border.width: 1

                NText {
                  anchors.centerIn: parent
                  text: pluginApi?.tr("panel.debug.test-upload") || "测试上报"
                  font.pointSize: Style.fontSizeXS
                  color: testUploadMouse.containsMouse ? Color.mOnPrimaryContainer : Color.mOnSurface
                }

                MouseArea {
                  id: testUploadMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runDebugUploadTest()
                }
              }

              Item { Layout.fillWidth: true }
            }

            NText {
              Layout.fillWidth: true
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: (runtime?.uploadPaused === true || root.debugTestState === "success") ? Color.mPrimary : Color.mOnSurface
              text: {
                if (runtime?.uploadPaused === true) {
                  return pluginApi?.tr("panel.upload-paused") || "已暂时暂停自动上报";
                }
                if (root.debugTestState === "uploading") {
                  return pluginApi?.tr("panel.upload-uploading") || "上传中";
                }
                if (root.debugTestState === "invalid-json") {
                  return pluginApi?.tr("panel.debug.invalid-json") || "JSON 无效，无法发送";
                }
                if (root.debugTestState === "no-endpoint") {
                  return pluginApi?.tr("panel.upload-no-endpoint") || "未配置上传地址";
                }
                if (root.debugTestState === "no-token") {
                  return pluginApi?.tr("panel.upload-no-token") || "未配置上传令牌";
                }
                if (root.debugTestState === "success") {
                  return (pluginApi?.tr("panel.debug.test-success") || "测试上报成功") + (root.debugTestHttpStatus > 0 ? (" (HTTP " + root.debugTestHttpStatus + ")") : "");
                }
                if (root.debugTestState === "failed") {
                  return (pluginApi?.tr("panel.debug.test-failed") || "测试上报失败") + (root.debugTestHttpStatus > 0 ? (" (HTTP " + root.debugTestHttpStatus + ")") : "");
                }
                return pluginApi?.tr("panel.debug.test-idle") || "可编辑上方 JSON 后点击“测试上报”";
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: statusColumn.implicitHeight + Style.marginM * 2
          color: Color.mSurfaceVariant
          radius: Style.radiusM

          ColumnLayout {
            id: statusColumn
            anchors {
              fill: parent
              margins: Style.marginM
            }
            spacing: Style.marginS

            NText {
              text: (pluginApi?.tr("panel.last-updated") || "Last updated") + ": " + (runtime?.lastUpdatedAt || "-")
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: (pluginApi?.tr("panel.upload-state") || "Upload status") + ": " + (pluginApi?.tr("panel.upload-" + (runtime?.uploadState || "disabled")) || (runtime?.uploadState || "disabled"))
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: (pluginApi?.tr("panel.media-upload-state") || "Media upload status") + ": " + (pluginApi?.tr("panel.upload-" + (runtime?.mediaUploadState || "media-disabled")) || (runtime?.mediaUploadState || "media-disabled"))
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NText {
              text: (pluginApi?.tr("panel.media-last-updated") || "Media last updated") + ": " + (runtime?.lastMediaUpdatedAt || "-")
              font.pointSize: Style.fontSizeS
              font.family: Settings.data.ui.fontFixed
              color: Color.mOnSurface
              Layout.fillWidth: true
            }
          }
        }
      }
    }
  }
}

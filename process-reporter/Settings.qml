import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property bool valueUploadEnabled: cfg.uploadEnabled ?? defaults.uploadEnabled ?? false
  property bool valueUploadThrottleEnabled: cfg.uploadThrottleEnabled ?? defaults.uploadThrottleEnabled ?? true
  property bool valueUploadMediaEnabled: cfg.uploadMediaEnabled ?? defaults.uploadMediaEnabled ?? false
  property bool valueUploadWindowTitle: cfg.uploadWindowTitle ?? defaults.uploadWindowTitle ?? false
  property bool valueScheduledUploadEnabled: cfg.scheduledUploadEnabled ?? defaults.scheduledUploadEnabled ?? false
  property bool valueShowPluginInfo: cfg.showPluginInfo ?? defaults.showPluginInfo ?? false
  property int valueScheduledUploadIntervalMs: cfg.scheduledUploadIntervalMs ?? defaults.scheduledUploadIntervalMs ?? 5000
  property string valueUploadEndpoint: cfg.uploadEndpoint ?? defaults.uploadEndpoint ?? ""
  property string valueUploadToken: cfg.uploadToken ?? defaults.uploadToken ?? ""
  property int valueUploadThrottleMs: cfg.uploadThrottleMs ?? defaults.uploadThrottleMs ?? 15000
  property string endpointEdit: ""
  property string tokenEdit: ""
  property string scheduledIntervalEdit: ""
  property string throttleEdit: ""
  property bool isHydrating: true

  spacing: Style.marginL

  Component.onCompleted: {
    Logger.d("ActiveWindowUpload", "Settings UI loaded");
    hydrateFromSettings();
    root.isHydrating = false;
  }

  Component.onDestruction: {
    root.saveSettings();
  }

  Timer {
    id: autosaveTimer
    interval: 350
    repeat: false
    onTriggered: root.saveSettings()
  }

  function queueAutosave() {
    if (root.isHydrating) {
      return;
    }
    autosaveTimer.restart();
  }

  function hydrateFromSettings() {
    root.valueUploadEnabled = cfg.uploadEnabled ?? defaults.uploadEnabled ?? false;
    root.valueUploadThrottleEnabled = cfg.uploadThrottleEnabled ?? defaults.uploadThrottleEnabled ?? true;
    root.valueUploadMediaEnabled = cfg.uploadMediaEnabled ?? defaults.uploadMediaEnabled ?? false;
    root.valueUploadWindowTitle = cfg.uploadWindowTitle ?? defaults.uploadWindowTitle ?? false;
    root.valueScheduledUploadEnabled = cfg.scheduledUploadEnabled ?? defaults.scheduledUploadEnabled ?? false;
    root.valueShowPluginInfo = cfg.showPluginInfo ?? defaults.showPluginInfo ?? false;
    root.valueScheduledUploadIntervalMs = cfg.scheduledUploadIntervalMs ?? defaults.scheduledUploadIntervalMs ?? 5000;
    root.valueUploadEndpoint = cfg.uploadEndpoint ?? defaults.uploadEndpoint ?? "";
    root.valueUploadToken = cfg.uploadToken ?? defaults.uploadToken ?? "";
    root.valueUploadThrottleMs = cfg.uploadThrottleMs ?? defaults.uploadThrottleMs ?? 15000;

    endpointEdit = valueUploadEndpoint;
    tokenEdit = valueUploadToken;
    scheduledIntervalEdit = String(valueScheduledUploadIntervalMs);
    throttleEdit = String(valueUploadThrottleMs);
  }

  function hasAnyEditingFocus() {
    return intervalInput.activeFocus || endpointInput.activeFocus || tokenInput.activeFocus || throttleInput.activeFocus;
  }

  function commitScheduledInterval() {
    var clamped = clampInt(scheduledIntervalEdit, valueScheduledUploadIntervalMs, 1000, 60000);
    valueScheduledUploadIntervalMs = clamped;
    scheduledIntervalEdit = String(clamped);
    saveSettings();
  }

  function commitEndpoint() {
    valueUploadEndpoint = String(endpointEdit || "").trim();
    endpointEdit = valueUploadEndpoint;
    saveSettings();
  }

  function commitToken() {
    valueUploadToken = String(tokenEdit || "").trim();
    tokenEdit = valueUploadToken;
    saveSettings();
  }

  function commitThrottle() {
    var clamped = clampInt(throttleEdit, valueUploadThrottleMs, 1000, 3600000);
    valueUploadThrottleMs = clamped;
    throttleEdit = String(clamped);
    saveSettings();
  }

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      if (root.hasAnyEditingFocus()) {
        return;
      }
      root.isHydrating = true;
      hydrateFromSettings();
      root.isHydrating = false;
    }
  }

  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: basicSection.implicitHeight + Style.marginM * 2
      color: Color.mSurfaceVariant
      radius: Style.radiusL

      ColumnLayout {
        id: basicSection
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NIcon {
            icon: "settings-general"
            pointSize: Style.fontSizeM * Style.uiScaleRatio
            color: Color.mPrimary
          }

          NText {
            text: pluginApi?.tr("settings.sections.basic") || "基础功能"
            font.weight: Font.Bold
            color: Color.mOnSurface
          }
        }

        NToggle {
          label: pluginApi?.tr("settings.upload.media-enabled.label") || "启用媒体信息上报"
          description: pluginApi?.tr("settings.upload.media-enabled.desc") || "监听 MediaService 并上报播放器、曲目和播放状态"
          checked: root.valueUploadMediaEnabled
          onToggled: c => {
            root.valueUploadMediaEnabled = c;
            root.queueAutosave();
          }
          defaultValue: defaults.uploadMediaEnabled ?? false
        }

        NToggle {
          label: pluginApi?.tr("settings.upload.window-title.label") || "上报窗口标题（高隐私风险）"
          description: pluginApi?.tr("settings.upload.window-title.desc") || "可能包含聊天、文档、网页等敏感信息，仅在你明确知情时开启"
          checked: root.valueUploadWindowTitle
          onToggled: c => {
            root.valueUploadWindowTitle = c;
            root.queueAutosave();
          }
          defaultValue: defaults.uploadWindowTitle ?? false
        }

        NToggle {
          label: pluginApi?.tr("settings.upload.scheduled.label") || "Enable scheduled upload"
          description: pluginApi?.tr("settings.upload.scheduled.desc") || "Upload heartbeat with timer"
          checked: root.valueScheduledUploadEnabled
          onToggled: c => {
            root.valueScheduledUploadEnabled = c;
            root.queueAutosave();
          }
          defaultValue: defaults.scheduledUploadEnabled ?? false
        }

        NTextInput {
          id: intervalInput
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.upload.scheduled-interval.label") || "Scheduled upload interval (ms)"
          description: pluginApi?.tr("settings.upload.scheduled-interval.desc") || "Minimum 1000 ms"
          placeholderText: "5000"
          text: root.scheduledIntervalEdit
          inputMethodHints: Qt.ImhDigitsOnly
          onTextChanged: root.scheduledIntervalEdit = text
          onEditingFinished: root.commitScheduledInterval()
        }
      }
    }

    Rectangle {
      Layout.fillWidth: true
      Layout.preferredHeight: uploadSection.implicitHeight + Style.marginM * 2
      color: Color.mSurfaceVariant
      radius: Style.radiusL

      ColumnLayout {
        id: uploadSection
        anchors.fill: parent
        anchors.margins: Style.marginM
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NIcon {
            icon: "download"
            pointSize: Style.fontSizeM * Style.uiScaleRatio
            color: Color.mPrimary
          }

          NText {
            text: pluginApi?.tr("settings.sections.upload") || "上报与调试"
            font.weight: Font.Bold
            color: Color.mOnSurface
          }
        }

        NToggle {
          label: pluginApi?.tr("settings.upload.enabled.label") || "Enable upload extension"
          description: pluginApi?.tr("settings.upload.enabled.desc") || "Enable cloud upload (no window title)"
          checked: root.valueUploadEnabled
          onToggled: c => {
            root.valueUploadEnabled = c;
            root.queueAutosave();
          }
          defaultValue: defaults.uploadEnabled ?? false
        }

        NToggle {
          label: pluginApi?.tr("settings.upload.throttle-enabled.label") || "启用上传节流"
          description: pluginApi?.tr("settings.upload.throttle-enabled.desc") || "开启后按最小时间间隔限制重复上报"
          checked: root.valueUploadThrottleEnabled
          onToggled: c => {
            root.valueUploadThrottleEnabled = c;
            root.queueAutosave();
          }
          defaultValue: defaults.uploadThrottleEnabled ?? true
        }

        NTextInput {
          id: endpointInput
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.upload.endpoint.label") || "Upload endpoint"
          description: pluginApi?.tr("settings.upload.endpoint.desc") || "Cloud function URL (POST JSON)"
          placeholderText: "https://example.com/function"
          text: root.endpointEdit
          onTextChanged: root.endpointEdit = text
          onEditingFinished: root.commitEndpoint()
        }

        NTextInput {
          id: tokenInput
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.upload.token.label") || "Upload token"
          description: pluginApi?.tr("settings.upload.token.desc") || "Bearer token for cloud function authentication"
          placeholderText: "your-secret-token"
          text: root.tokenEdit
          onTextChanged: root.tokenEdit = text
          onEditingFinished: root.commitToken()
        }

        NTextInput {
          id: throttleInput
          Layout.fillWidth: true
          label: pluginApi?.tr("settings.upload.throttle.label") || "Upload throttle (ms)"
          description: pluginApi?.tr("settings.upload.throttle.desc") || "Minimum 1000 ms"
          placeholderText: "15000"
          text: root.throttleEdit
          enabled: root.valueUploadThrottleEnabled
          inputMethodHints: Qt.ImhDigitsOnly
          onTextChanged: root.throttleEdit = text
          onEditingFinished: root.commitThrottle()
        }

        NToggle {
          label: pluginApi?.tr("settings.debug.show-plugin-info.label") || "显示调试功能"
          description: pluginApi?.tr("settings.debug.show-plugin-info.desc") || "在 Panel 中显示调试区（上报原文编辑与测试）"
          checked: root.valueShowPluginInfo
          onToggled: c => {
            root.valueShowPluginInfo = c;
            root.queueAutosave();
          }
          defaultValue: defaults.showPluginInfo ?? false
        }
      }
    }
  }

  function clampInt(value, fallback, minValue, maxValue) {
    var parsed = parseInt(value);
    if (isNaN(parsed)) {
      parsed = fallback;
    }
    if (parsed < minValue) {
      parsed = minValue;
    }
    if (parsed > maxValue) {
      parsed = maxValue;
    }
    return parsed;
  }

  function syncEditBuffers() {
    // Persist in-progress text edits even when the settings view closes before focus changes.
    root.valueUploadEndpoint = String(root.endpointEdit || "").trim();
    root.endpointEdit = root.valueUploadEndpoint;
    root.valueUploadToken = String(root.tokenEdit || "").trim();
    root.tokenEdit = root.valueUploadToken;
    root.valueScheduledUploadIntervalMs = clampInt(root.scheduledIntervalEdit, root.valueScheduledUploadIntervalMs, 1000, 60000);
    root.scheduledIntervalEdit = String(root.valueScheduledUploadIntervalMs);
    root.valueUploadThrottleMs = clampInt(root.throttleEdit, root.valueUploadThrottleMs, 1000, 3600000);
    root.throttleEdit = String(root.valueUploadThrottleMs);
  }

  function saveSettings() {
    if (!pluginApi) {
      Logger.e("ActiveWindowUpload", "Cannot save settings: pluginApi is null");
      return;
    }

    syncEditBuffers();

    pluginApi.pluginSettings.uploadEnabled = root.valueUploadEnabled;
    pluginApi.pluginSettings.uploadThrottleEnabled = root.valueUploadThrottleEnabled;
    pluginApi.pluginSettings.uploadMediaEnabled = root.valueUploadMediaEnabled;
    pluginApi.pluginSettings.uploadWindowTitle = root.valueUploadWindowTitle;
    pluginApi.pluginSettings.scheduledUploadEnabled = root.valueScheduledUploadEnabled;
    pluginApi.pluginSettings.showPluginInfo = root.valueShowPluginInfo;
    pluginApi.pluginSettings.scheduledUploadIntervalMs = clampInt(root.valueScheduledUploadIntervalMs, 5000, 1000, 60000);
    pluginApi.pluginSettings.uploadEndpoint = root.valueUploadEndpoint;
    pluginApi.pluginSettings.uploadToken = root.valueUploadToken;
    pluginApi.pluginSettings.uploadThrottleMs = clampInt(root.valueUploadThrottleMs, 15000, 1000, 3600000);
    pluginApi.saveSettings();

    Logger.d("ActiveWindowUpload", "Settings saved successfully");
  }
}

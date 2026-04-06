import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.Media
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null
  property var activeWindowSnapshot: ({
    windowId: "",
    title: "Unknown Window",
    appId: "",
    rawAppId: "",
    appName: "Unknown",
    isFocused: false,
  })
  property string lastUpdatedAt: "-"
  property double lastUpdatedEpochMs: 0
  property string uploadState: "disabled"
  property double lastUploadEpochMs: 0
  property var activeMediaSnapshot: ({
    playerIdentity: "",
    trackTitle: "",
    trackArtist: "",
    trackAlbum: "",
    trackArtUrl: "",
    isPlaying: false,
  })
  property bool hasActiveMediaSnapshot: false
  property string mediaUploadState: "media-disabled"
  property string lastMediaUpdatedAt: "-"
  property double lastMediaUpdatedEpochMs: 0
  property string lastCombinedSnapshotKey: ""
  property bool scheduledRefreshEnabled: false
  property int scheduledRefreshIntervalMs: 5000
  property bool uploadPaused: false

  Component.onCompleted: {
    Logger.i("ActiveUpload", "Main initialized", "pluginId=", pluginApi?.pluginId || "unknown");
    refreshSnapshot("startup");
    refreshMediaSnapshot("startup");
    applyTimerConfig();
  }

  Connections {
    target: pluginApi

    function onPluginSettingsChanged() {
      Logger.d("ActiveUpload", "Plugin settings changed");
      applyTimerConfig();
      refreshSnapshot("settings");
      refreshMediaSnapshot("settings");
      maybeUploadCombined(true, "settings-changed");
    }
  }

  Connections {
    target: typeof CompositorService !== "undefined" ? CompositorService : null

    function onActiveWindowChanged() {
      Logger.d("ActiveUpload", "Active window changed event received");
      refreshSnapshot("event");
      maybeUploadCombined(false, "window-event");
    }

    function onWindowListChanged() {
      refreshSnapshot("window-list");
      maybeUploadCombined(false, "window-list");
    }
  }

  Connections {
    target: typeof MediaService !== "undefined" ? MediaService : null

    function onIsPlayingChanged() {
      Logger.d("ActiveUpload", "Media playback state changed");
      refreshMediaSnapshot("media-is-playing");
      maybeUploadCombined(false, "media-is-playing");
    }

    function onTrackTitleChanged() {
      Logger.d("ActiveUpload", "Media track title changed");
      refreshMediaSnapshot("media-track-title");
      maybeUploadCombined(false, "media-track-title");
    }

    function onPlayerIdentityChanged() {
      Logger.d("ActiveUpload", "Media player identity changed");
      refreshMediaSnapshot("media-player-identity");
      maybeUploadCombined(false, "media-player-identity");
    }
  }

  Timer {
    id: scheduledUploadTimer
    interval: 5000
    repeat: true
    running: false

    onTriggered: {
      Logger.d("ActiveUpload", "Scheduled upload timer triggered");
      refreshSnapshot("scheduled");
      refreshMediaSnapshot("scheduled");
      maybeUploadCombined(false, "scheduled");
    }
  }

  function getSettingInt(key, fallback, minValue, maxValue) {
    var value = pluginApi?.pluginSettings?.[key];
    if (value === undefined || value === null || value === "") {
      value = fallback;
    }
    value = parseInt(value);
    if (isNaN(value)) {
      value = fallback;
    }
    if (minValue !== undefined && value < minValue) {
      value = minValue;
    }
    if (maxValue !== undefined && value > maxValue) {
      value = maxValue;
    }
    return value;
  }

  function getSettingBool(key, fallback) {
    var value = pluginApi?.pluginSettings?.[key];
    if (value === undefined || value === null) {
      return fallback;
    }
    return value === true || value === "true" || value === 1;
  }

  function getFocusedWindowSnapshot() {
    var focused = null;
    if (typeof CompositorService !== "undefined" && CompositorService.getFocusedWindow) {
      focused = CompositorService.getFocusedWindow();
    }

    var rawAppId = focused?.appId ? String(focused.appId) : "";
    var appId = rawAppId;
    var title = focused?.title ? String(focused.title).replace(/(\r\n|\n|\r)/g, " ").trim() : "";
    var appName = "Unknown";
    if (typeof CompositorService !== "undefined" && CompositorService.getCleanAppName) {
      appName = CompositorService.getCleanAppName(appId, title);
    } else if (appId) {
      appName = appId.split(".").pop();
    }
    if (!title) {
      title = appName || "Unknown Window";
    }

    return {
      // Use compositor-provided unified fields for cross-backend compatibility.
      windowId: focused?.windowId ? String(focused.windowId)
        : (focused?.id ? String(focused.id)
        : (focused?.address ? String(focused.address)
        : "")),
      title: title,
      appId: appId,
      rawAppId: rawAppId,
      appName: appName || "Unknown",
      isFocused: focused?.isFocused === true,
    };
  }

  function hasMeaningfulWindowSnapshot(snapshot) {
    if (!snapshot) {
      return false;
    }
    return (snapshot.windowId && snapshot.windowId.length > 0)
      || (snapshot.appId && snapshot.appId.length > 0);
  }

  function postUpload(payload, endpoint, token, onResult) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", endpoint);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.setRequestHeader("Authorization", "Bearer " + token);
    xhr.timeout = 8000;

    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) {
        return;
      }
      if (xhr.status >= 200 && xhr.status < 300) {
        if (onResult) {
          onResult(true, xhr.status);
        }
        return;
      }
      if (onResult) {
        onResult(false, xhr.status);
      }
      Logger.w("ActiveUpload", "Upload failed with status", xhr.status);
    };

    xhr.onerror = function() {
      if (onResult) {
        onResult(false, 0);
      }
      Logger.w("ActiveUpload", "Upload request error");
    };

    xhr.ontimeout = function() {
      if (onResult) {
        onResult(false, 0);
      }
      Logger.w("ActiveUpload", "Upload request timeout");
    };

    xhr.send(JSON.stringify(payload));
  }

  function getActiveMediaSnapshot() {
    if (typeof MediaService === "undefined") {
      return null;
    }

    var trackTitle = String(MediaService.trackTitle || "").trim();
    if (!trackTitle) {
      return null;
    }

    return {
      playerIdentity: String(MediaService.playerIdentity || "").trim(),
      trackTitle: trackTitle,
      trackArtist: String(MediaService.trackArtist || "").trim(),
      trackAlbum: String(MediaService.trackAlbum || "").trim(),
      trackArtUrl: String(MediaService.trackArtUrl || "").trim(),
      isPlaying: MediaService.isPlaying === true,
    };
  }

  function getMediaSnapshotKey(snapshot) {
    if (!snapshot) {
      return "";
    }
    return [
      snapshot.playerIdentity,
      snapshot.trackTitle,
      snapshot.trackArtist,
      snapshot.trackAlbum,
      snapshot.trackArtUrl,
      snapshot.isPlaying ? "1" : "0",
    ].join("|");
  }

  function getWindowSnapshotKey(snapshot, includeTitle) {
    if (!snapshot) {
      return "";
    }
    return [
      snapshot.windowId,
      snapshot.appId,
      snapshot.appName,
      includeTitle ? String(snapshot.title || "") : "",
    ].join("|");
  }

  function buildCombinedPayload(triggerReason, includeMediaOverride) {
    var includeWindowTitle = getSettingBool("uploadWindowTitle", false);
    var windowSnapshot = activeWindowSnapshot;
    var hasWindow = !!(windowSnapshot && windowSnapshot.windowId);

    var includeMedia = includeMediaOverride;
    if (includeMedia === undefined || includeMedia === null) {
      includeMedia = getSettingBool("uploadMediaEnabled", false);
    }
    var mediaSnapshot = includeMedia ? getActiveMediaSnapshot() : null;

    var payload = {
      timestamp: Date.now(),
      event: triggerReason || "unknown",
      window: hasWindow ? {
        windowId: windowSnapshot.windowId,
        appId: windowSnapshot.appId,
        appName: windowSnapshot.appName,
      } : null,
      media: mediaSnapshot ? {
        playerIdentity: mediaSnapshot.playerIdentity,
        trackTitle: mediaSnapshot.trackTitle,
        trackArtist: mediaSnapshot.trackArtist,
        trackAlbum: mediaSnapshot.trackAlbum,
        trackArtUrl: mediaSnapshot.trackArtUrl,
        isPlaying: mediaSnapshot.isPlaying,
      } : null,
    };

    if (hasWindow && includeWindowTitle && windowSnapshot.title) {
      payload.window.windowTitle = String(windowSnapshot.title);
    }

    return {
      payload: payload,
      hasWindow: hasWindow,
      mediaSnapshot: mediaSnapshot,
      includeMedia: includeMedia,
      includeWindowTitle: includeWindowTitle,
      windowSnapshot: windowSnapshot,
    };
  }

  function buildDebugPayloadJson(triggerReason) {
    var built = buildCombinedPayload(triggerReason || "panel-debug", true);
    return JSON.stringify(built.payload, null, 2);
  }

  function testUploadPayload(payloadText, onResult) {
    var endpoint = String(pluginApi?.pluginSettings?.uploadEndpoint || "").trim();
    if (!endpoint) {
      if (onResult) {
        onResult(false, 0, "no-endpoint");
      }
      return;
    }

    var token = String(pluginApi?.pluginSettings?.uploadToken || "").trim();
    if (!token) {
      if (onResult) {
        onResult(false, 0, "no-token");
      }
      return;
    }

    var parsedPayload = null;
    try {
      parsedPayload = JSON.parse(String(payloadText || ""));
    } catch (err) {
      Logger.w("ActiveUpload", "Debug payload parse failed", String(err));
      if (onResult) {
        onResult(false, 0, "invalid-json");
      }
      return;
    }

    postUpload(parsedPayload, endpoint, token, function(ok, statusCode) {
      if (onResult) {
        onResult(ok, statusCode, ok ? "success" : "failed");
      }
    });
  }

  function setUploadPaused(paused) {
    uploadPaused = paused === true;
    if (uploadPaused) {
      uploadState = "paused";
      mediaUploadState = getSettingBool("uploadMediaEnabled", false) ? "paused" : "media-disabled";
    } else {
      refreshSnapshot("resume");
      refreshMediaSnapshot("resume");
      maybeUploadCombined(false, "resume");
    }
    Logger.i("ActiveUpload", "Upload pause state changed", "paused=", uploadPaused);
  }

  function maybeUploadCombined(forceUpload, triggerReason) {
    if (forceUpload === undefined) {
      forceUpload = false;
    }
    if (triggerReason === undefined) {
      triggerReason = "unknown";
    }

    var enabled = getSettingBool("uploadEnabled", false);
    if (!enabled) {
      uploadState = "disabled";
      mediaUploadState = getSettingBool("uploadMediaEnabled", false) ? "disabled" : "media-disabled";
      return;
    }

    if (uploadPaused) {
      uploadState = "paused";
      mediaUploadState = getSettingBool("uploadMediaEnabled", false) ? "paused" : "media-disabled";
      return;
    }

    var endpoint = String(pluginApi?.pluginSettings?.uploadEndpoint || "").trim();
    if (!endpoint) {
      uploadState = "no-endpoint";
      mediaUploadState = getSettingBool("uploadMediaEnabled", false) ? "no-endpoint" : "media-disabled";
      Logger.w("ActiveUpload", "Combined upload skipped: uploadEndpoint is empty");
      return;
    }

    var token = String(pluginApi?.pluginSettings?.uploadToken || "").trim();
    if (!token) {
      uploadState = "no-token";
      mediaUploadState = getSettingBool("uploadMediaEnabled", false) ? "no-token" : "media-disabled";
      Logger.w("ActiveUpload", "Combined upload skipped: uploadToken is empty");
      return;
    }

    var built = buildCombinedPayload(triggerReason);
    var includeMedia = built.includeMedia;
    var mediaSnapshot = built.mediaSnapshot;
    var windowSnapshot = built.windowSnapshot;
    var hasWindow = built.hasWindow;
    var includeWindowTitle = built.includeWindowTitle;
    if (!includeMedia) {
      mediaUploadState = "media-disabled";
    } else if (!mediaSnapshot) {
      mediaUploadState = "no-media";
    }

    if (!hasWindow && !mediaSnapshot) {
      uploadState = "no-window";
      return;
    }

    var now = Date.now();
    var nextCombinedKey = [
      getWindowSnapshotKey(windowSnapshot, includeWindowTitle),
      getMediaSnapshotKey(mediaSnapshot),
      includeMedia ? "media-on" : "media-off",
    ].join("||");

    if (!forceUpload && nextCombinedKey === lastCombinedSnapshotKey) {
      uploadState = "throttled";
      if (includeMedia && mediaSnapshot) {
        mediaUploadState = "throttled";
      }
      Logger.d("ActiveUpload", "Combined upload skipped: duplicate snapshot", "trigger=", triggerReason);
      return;
    }

    var throttleEnabled = getSettingBool("uploadThrottleEnabled", true);
    if (!forceUpload && throttleEnabled) {
      var throttleMs = getSettingInt("uploadThrottleMs", 15000, 1000, 3600000);
      if (now - lastUploadEpochMs < throttleMs) {
        uploadState = "throttled";
        if (includeMedia && mediaSnapshot) {
          mediaUploadState = "throttled";
        }
        Logger.d("ActiveUpload", "Combined upload throttled", "remainingMs=", throttleMs - (now - lastUploadEpochMs));
        return;
      }
    }

    var payload = built.payload;
    payload.timestamp = now;
    payload.event = triggerReason;

    lastUploadEpochMs = now;
    uploadState = "uploading";
    if (includeMedia) {
      mediaUploadState = mediaSnapshot ? "uploading" : "no-media";
    }
    Logger.i("ActiveUpload", "Uploading combined payload", "trigger=", triggerReason, "hasWindow=", hasWindow, "hasMedia=", !!mediaSnapshot);
    postUpload(payload, endpoint, token, function(ok) {
      if (ok) {
        lastCombinedSnapshotKey = nextCombinedKey;
      }
      uploadState = ok ? "success" : "failed";
      if (includeMedia) {
        mediaUploadState = mediaSnapshot ? (ok ? "success" : "failed") : "no-media";
      }
    });
  }

  function refreshSnapshot(reason) {
    void reason;
    var nextSnapshot = getFocusedWindowSnapshot();
    var preservedPrevious = false;
    if (hasMeaningfulWindowSnapshot(activeWindowSnapshot) && !hasMeaningfulWindowSnapshot(nextSnapshot)) {
      preservedPrevious = true;
      Logger.d("ActiveUpload", "Preserved previous focused snapshot", "reason=", reason, "prevWindowId=", activeWindowSnapshot.windowId);
    } else {
      activeWindowSnapshot = nextSnapshot;
    }
    lastUpdatedEpochMs = Date.now();
    lastUpdatedAt = Qt.formatDateTime(new Date(lastUpdatedEpochMs), "yyyy-MM-dd hh:mm:ss");
    Logger.d("ActiveUpload", "Snapshot refreshed", "reason=", reason, "windowId=", activeWindowSnapshot.windowId, "appId=", activeWindowSnapshot.appId);
    if (preservedPrevious) {
      Logger.d("ActiveUpload", "Upload skipped for preserved snapshot", "reason=", reason);
    }
  }

  function refreshMediaSnapshot(reason) {
    void reason;

    var snapshot = getActiveMediaSnapshot();
    if (snapshot) {
      activeMediaSnapshot = snapshot;
      hasActiveMediaSnapshot = true;
    } else {
      activeMediaSnapshot = {
        playerIdentity: "",
        trackTitle: "",
        trackArtist: "",
        trackAlbum: "",
        trackArtUrl: "",
        isPlaying: false,
      };
      hasActiveMediaSnapshot = false;
    }

    lastMediaUpdatedEpochMs = Date.now();
    lastMediaUpdatedAt = Qt.formatDateTime(new Date(lastMediaUpdatedEpochMs), "yyyy-MM-dd hh:mm:ss");
  }

  function manualRefreshAndUpload() {
    Logger.i("ActiveUpload", "Manual refresh requested");
    refreshSnapshot("manual");
    refreshMediaSnapshot("manual");
    maybeUploadCombined(true, "manual");
  }

  function applyTimerConfig() {
    scheduledUploadTimer.interval = getSettingInt("scheduledUploadIntervalMs", 5000, 1000, 60000);
    scheduledRefreshIntervalMs = scheduledUploadTimer.interval;
    var enabled = getSettingBool("scheduledUploadEnabled", false);
    scheduledUploadTimer.running = enabled;
    scheduledRefreshEnabled = enabled;
    Logger.d("ActiveUpload", "Timer config applied", "running=", enabled, "intervalMs=", scheduledUploadTimer.interval);
  }

  IpcHandler {
    // Use runtime plugin id so source-prefixed installs expose a valid IPC target.
    target: "plugin:" + (pluginApi?.pluginId || "active-upload")

    Component.onCompleted: {
      Logger.i("ActiveUpload", "IPC handler registered", "target=", target);
    }

    function toggle() {
      if (pluginApi) {
        Logger.i("ActiveUpload", "IPC toggle called");
        pluginApi.withCurrentScreen(screen => {
          pluginApi.openPanel(screen);
        });
      }
    }

    function refreshNow() {
      Logger.i("ActiveUpload", "IPC refreshNow called");
      manualRefreshAndUpload();
      ToastService.showNotice("Process Reporter", "Snapshot refreshed and upload requested");
    }
  }
}
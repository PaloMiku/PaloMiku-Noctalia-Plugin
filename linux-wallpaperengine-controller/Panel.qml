import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import Quickshell
import Quickshell.Io

import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property var cfg: pluginApi?.pluginSettings || ({})
  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property var geometryPlaceholder: panelContainer

  property real contentPreferredWidth: 1480 * Style.uiScaleRatio
  property real contentPreferredHeight: 860 * Style.uiScaleRatio

  readonly property bool allowAttach: true
  readonly property bool panelAnchorHorizontalCenter: false
  readonly property bool panelAnchorVerticalCenter: false

  readonly property string wallpapersFolder: cfg.wallpapersFolder ?? defaults.wallpapersFolder ?? ""
  readonly property string resolvedWallpapersFolder: Settings.preprocessPath(wallpapersFolder)
  property string selectedScreenName: pluginApi?.panelOpenScreen?.name ?? ""
  property string selectedPath: ""
  property string pendingPath: ""
  property string selectedScaling: "fill"
  property int selectedVolume: 100
  property bool selectedMuted: true
  property bool selectedAudioReactiveEffects: true
  property bool selectedDisableMouse: false
  property bool selectedDisableParallax: false
  property bool scanningWallpapers: false
  property bool folderAccessible: true

  property string searchText: ""
  property string selectedType: "all"
  property string selectedResolution: "all"
  property string sortMode: "name"
  property bool sortAscending: true
  readonly property bool singleScreenMode: Quickshell.screens.length <= 1
  property bool applyAllDisplays: !singleScreenMode && root._applyAllDisplays
  property bool _applyAllDisplays: true
  property bool applyTargetExpanded: false
  property bool filterDropdownOpen: false
  property bool resolutionDropdownOpen: false
  property bool sortDropdownOpen: false
  property bool errorDetailsExpanded: false
  property real filterDropdownX: 0
  property real filterDropdownY: 0
  property real filterDropdownWidth: 220 * Style.uiScaleRatio
  property real resolutionDropdownX: 0
  property real resolutionDropdownY: 0
  property real resolutionDropdownWidth: 220 * Style.uiScaleRatio
  property real sortDropdownX: 0
  property real sortDropdownY: 0
  property real sortDropdownWidth: 220 * Style.uiScaleRatio

  property var screenModel: []
  property var wallpaperItems: []
  property var visibleWallpapers: []
  readonly property bool hasRuntimeError: !!(mainInstance?.lastError && mainInstance.lastError.length > 0)
  readonly property var selectedWallpaperData: {
    const target = String(pendingPath || "");
    if (target.length === 0) {
      return null;
    }
    for (const item of wallpaperItems) {
      if (String(item.path || "") === target) {
        return item;
      }
    }
    return null;
  }

  function basename(path) {
    const parts = String(path || "").split("/");
    return parts.length > 0 ? parts[parts.length - 1] : "";
  }

  function fileExt(path) {
    const raw = basename(path);
    const idx = raw.lastIndexOf(".");
    return idx >= 0 ? raw.substring(idx + 1).toLowerCase() : "";
  }

  function isVideoMotion(path) {
    const ext = fileExt(path);
    return ext === "mp4" || ext === "webm" || ext === "mov" || ext === "mkv";
  }

  function typeLabel(value) {
    const key = String(value || "all").toLowerCase();
    if (key === "scene") return pluginApi?.tr("panel.typeScene");
    if (key === "video") return pluginApi?.tr("panel.typeVideo");
    if (key === "web") return pluginApi?.tr("panel.typeWeb");
    if (key === "application") return pluginApi?.tr("panel.typeApplication");
    return pluginApi?.tr("panel.filterAll");
  }

  function scalingLabel(value) {
    const key = String(value || "fill").toLowerCase();
    if (key === "fit") return pluginApi?.tr("panel.scalingFit");
    if (key === "stretch") return pluginApi?.tr("panel.scalingStretch");
    if (key === "default") return pluginApi?.tr("panel.scalingDefault");
    return pluginApi?.tr("panel.scalingFill");
  }

  function formatBytes(bytesValue) {
    const size = Number(bytesValue || 0);
    if (isNaN(size) || size <= 0) {
      return "0 B";
    }

    if (size < 1024) {
      return Math.floor(size) + " B";
    }

    if (size < 1024 * 1024) {
      return (size / 1024).toFixed(1) + " KB";
    }

    if (size < 1024 * 1024 * 1024) {
      return (size / (1024 * 1024)).toFixed(1) + " MB";
    }

    return (size / (1024 * 1024 * 1024)).toFixed(1) + " GB";
  }

  function sortLabel(value) {
    if (value === "date") return pluginApi?.tr("panel.sortDateAdded");
    if (value === "size") return pluginApi?.tr("panel.sortSize");
    if (value === "recent") return pluginApi?.tr("panel.sortRecent");
    return pluginApi?.tr("panel.sortName");
  }

  function resolutionBadgeIcon(value) {
    const resolution = String(value || "").toLowerCase().trim();
    if (resolution.length === 0 || resolution === "unknown") {
      return "";
    }

    const match = resolution.match(/(\d+)\s*[x×]\s*(\d+)/);
    if (!match) {
      return "";
    }

    const width = Number(match[1]);
    const height = Number(match[2]);
    if (isNaN(width) || isNaN(height)) {
      return "";
    }

    const longestEdge = Math.max(width, height);
    if (longestEdge >= 7680) {
      return "badge-8k";
    }
    if (longestEdge >= 3840) {
      return "badge-4k";
    }
    return "";
  }

  function resolutionBadgeLabel(value) {
    const icon = resolutionBadgeIcon(value);
    if (icon === "badge-8k") {
      return "8K";
    }
    if (icon === "badge-4k") {
      return "4K";
    }
    return "";
  }

  function resolutionFilterKey(value) {
    const resolution = String(value || "").toLowerCase().trim();
    if (resolution.length === 0 || resolution === "unknown") {
      return "unknown";
    }

    const match = resolution.match(/(\d+)\s*[x×]\s*(\d+)/);
    if (!match) {
      return "unknown";
    }

    const width = Number(match[1]);
    const height = Number(match[2]);
    if (isNaN(width) || isNaN(height)) {
      return "unknown";
    }

    const longestEdge = Math.max(width, height);
    if (longestEdge >= 7680) {
      return "8k";
    }
    if (longestEdge >= 3840) {
      return "4k";
    }
    return "other";
  }

  function resolutionFilterLabel(value) {
    if (value === "8k") return pluginApi?.tr("panel.filterRes8k");
    if (value === "4k") return pluginApi?.tr("panel.filterRes4k");
    if (value === "unknown") return pluginApi?.tr("panel.filterResUnknown");
    return pluginApi?.tr("panel.filterResAll");
  }

  function closeDropdowns() {
    filterDropdownOpen = false;
    resolutionDropdownOpen = false;
    sortDropdownOpen = false;
  }

  function openFilterDropdown() {
    const pos = filterButton.mapToItem(root, 0, filterButton.height + Style.marginXS);
    filterDropdownX = pos.x;
    filterDropdownY = pos.y;
    filterDropdownWidth = filterButton.width;
    resolutionDropdownOpen = false;
    sortDropdownOpen = false;
    filterDropdownOpen = true;
  }

  function openSortDropdown() {
    const pos = sortButton.mapToItem(root, 0, sortButton.height + Style.marginXS);
    sortDropdownX = pos.x;
    sortDropdownY = pos.y;
    sortDropdownWidth = sortButton.width;
    filterDropdownOpen = false;
    resolutionDropdownOpen = false;
    sortDropdownOpen = true;
  }

  function openResolutionDropdown() {
    const pos = resolutionButton.mapToItem(root, 0, resolutionButton.height + Style.marginXS);
    resolutionDropdownX = pos.x;
    resolutionDropdownY = pos.y;
    resolutionDropdownWidth = resolutionButton.width;
    filterDropdownOpen = false;
    sortDropdownOpen = false;
    resolutionDropdownOpen = true;
  }

  function applyFilterAction(action) {
    if (String(action).indexOf("type:") === 0) {
      selectedType = String(action).substring(5);
    }
    closeDropdowns();
  }

  function applyResolutionFilterAction(action) {
    if (String(action).indexOf("res:") === 0) {
      selectedResolution = String(action).substring(4);
    }
    closeDropdowns();
  }

  function applySortAction(action) {
    if (action === "sort:toggleAscending") {
      sortAscending = !sortAscending;
    } else if (String(action).indexOf("sort:") === 0) {
      sortMode = String(action).substring(5);
    }
    closeDropdowns();
  }

  function loadPanelMemory() {
    if (!pluginApi) {
      return;
    }

    const remembered = String(pluginApi?.pluginSettings?.panelLastSelectedPath || "").trim();
    if (remembered.length > 0) {
      pendingPath = remembered;
    }
  }

  function persistPanelMemory(flushToDisk = false) {
    if (!pluginApi) {
      return;
    }

    const current = String(pluginApi?.pluginSettings?.panelLastSelectedPath || "");
    const next = String(pendingPath || "");
    if (current === next) {
      return;
    }

    pluginApi.pluginSettings.panelLastSelectedPath = next;
    if (flushToDisk) {
      pluginApi.saveSettings();
    }
  }

  function resetPendingToGlobalDefaults() {
    selectedScaling = String(defaults.defaultScaling || "fill");
    selectedVolume = Math.max(0, Math.min(100, Number(defaults.defaultVolume ?? 100)));
    selectedMuted = !!(defaults.defaultMuted ?? true);
    selectedAudioReactiveEffects = !!(defaults.defaultAudioReactiveEffects ?? true);
    selectedDisableMouse = !!(defaults.defaultDisableMouse ?? false);
    selectedDisableParallax = !!(defaults.defaultDisableParallax ?? false);
  }

  function syncSelectionOptionsFromScreen() {
    if (root.singleScreenMode) {
      resetPendingToGlobalDefaults();
      return;
    }

    const screenCfg = mainInstance?.getScreenConfig(selectedScreenName);
    if (!screenCfg) {
      resetPendingToGlobalDefaults();
      return;
    }

    selectedScaling = String(screenCfg.scaling || defaults.defaultScaling || "fill");
    selectedVolume = Math.max(0, Math.min(100, Number(screenCfg.volume ?? defaults.defaultVolume ?? 100)));
    selectedMuted = !!(screenCfg.muted ?? defaults.defaultMuted ?? true);
    selectedAudioReactiveEffects = !!(screenCfg.audioReactiveEffects ?? defaults.defaultAudioReactiveEffects ?? true);
    selectedDisableMouse = !!(screenCfg.disableMouse ?? defaults.defaultDisableMouse ?? false);
    selectedDisableParallax = !!(screenCfg.disableParallax ?? defaults.defaultDisableParallax ?? false);
  }

  function applyPendingSelection() {
    const path = String(pendingPath || "").trim();
    if (path.length === 0) {
      return;
    }

    const options = { "scaling": selectedScaling };
    options.volume = selectedVolume;
    options.muted = selectedMuted;
    options.audioReactiveEffects = selectedAudioReactiveEffects;
    options.disableMouse = selectedDisableMouse;
    options.disableParallax = selectedDisableParallax;
    selectedPath = path;

    if (applyAllDisplays) {
      Logger.i("LWEController", "Confirm apply to all displays", path, JSON.stringify(options));
      mainInstance?.setAllScreensWallpaperWithOptions(path, options);
      pendingPath = "";
      return;
    }

    if (!root.singleScreenMode && selectedScreenName.length === 0) {
      Logger.w("LWEController", "Confirm apply skipped due to empty selected screen", path);
      return;
    }

    const targetScreen = root.singleScreenMode ? (Quickshell.screens[0]?.name || "") : selectedScreenName;
    Logger.i("LWEController", "Confirm apply to screen", targetScreen, path, JSON.stringify(options));
    mainInstance?.setScreenWallpaperWithOptions(targetScreen, path, options);
    pendingPath = "";
  }

  function refreshVisibleWallpapers() {
    const query = String(searchText || "").trim().toLowerCase();
    let items = wallpaperItems.slice();

    if (selectedType !== "all") {
      items = items.filter(item => String(item.type || "unknown").toLowerCase() === selectedType);
    }

    if (selectedResolution !== "all") {
      items = items.filter(item => resolutionFilterKey(item.resolution) === selectedResolution);
    }

    if (query.length > 0) {
      items = items.filter(item => {
        return String(item.name || "").toLowerCase().indexOf(query) >= 0
          || String(item.id || "").toLowerCase().indexOf(query) >= 0;
      });
    }

    if (sortMode === "date") {
      items.sort((a, b) => Number(a.mtime || 0) - Number(b.mtime || 0));
    } else if (sortMode === "size") {
      items.sort((a, b) => Number(a.bytes || 0) - Number(b.bytes || 0));
    } else if (sortMode === "recent") {
      items.sort((a, b) => Number(b.mtime || 0) - Number(a.mtime || 0));
    } else {
      items.sort((a, b) => String(a.name || "").localeCompare(String(b.name || "")));
    }

    if (!sortAscending) {
      items.reverse();
    }

    visibleWallpapers = items;
    Logger.d("LWEController", "Visible wallpapers refreshed", "count=", visibleWallpapers.length, "type=", selectedType, "resolution=", selectedResolution, "sort=", sortMode, "ascending=", sortAscending, "query=", query);
  }

  function reconcilePendingSelection() {
    const current = String(pendingPath || "");
    if (current.length === 0) {
      return;
    }

    let exists = false;
    for (const item of wallpaperItems) {
      if (String(item.path || "") === current) {
        exists = true;
        break;
      }
    }

    if (!exists) {
      pendingPath = "";
    }
  }

  function scanWallpapers() {
    const folderPath = String(resolvedWallpapersFolder || "").trim();
    wallpaperItems = [];
    visibleWallpapers = [];

    if (folderPath.length === 0) {
      scanningWallpapers = false;
      folderAccessible = false;
      Logger.w("LWEController", "Scan skipped: wallpapers folder is empty");
      return;
    }

    Logger.i("LWEController", "Scanning wallpapers", folderPath);

    const pluginDir = pluginApi?.pluginDir || "";
    const scriptPath = pluginDir + "/scripts/scan-wallpapers.sh";

    scanningWallpapers = true;
    scanProcess.command = ["sh", scriptPath, folderPath];
    scanProcess.running = true;
  }

  function rebuildScreenModel() {
    const model = [];
    for (const screen of Quickshell.screens) {
      model.push({ key: screen.name, name: screen.name });
    }

    screenModel = model;

    if (!root.singleScreenMode && selectedScreenName.length === 0 && model.length > 0) {
      selectedScreenName = model[0].key;
    }
  }

  function applyPath(path) {
    if (!path || path.length === 0) {
      Logger.w("LWEController", "Apply skipped due to invalid path", path);
      return;
    }
    pendingPath = path;
  }

  onWallpaperItemsChanged: {
    refreshVisibleWallpapers();
    reconcilePendingSelection();
  }
  onSearchTextChanged: refreshVisibleWallpapers()
  onSelectedTypeChanged: refreshVisibleWallpapers()
  onSelectedResolutionChanged: refreshVisibleWallpapers()
  onSortModeChanged: refreshVisibleWallpapers()
  onSortAscendingChanged: refreshVisibleWallpapers()
  onSelectedScreenNameChanged: syncSelectionOptionsFromScreen()
  onWallpapersFolderChanged: {
    if (!root.pluginApi) {
      return;
    }
    scanWallpapers();
  }

  Component.onCompleted: {
    Logger.i("LWEController", "Panel opened", "screen=", selectedScreenName);
    rebuildScreenModel();
    loadPanelMemory();
    syncSelectionOptionsFromScreen();
    scanWallpapers();
  }

  Component.onDestruction: {
    persistPanelMemory(true);
  }

  onWidthChanged: {
    if (filterDropdownOpen) {
      openFilterDropdown();
    }
    if (resolutionDropdownOpen) {
      openResolutionDropdown();
    }
    if (sortDropdownOpen) {
      openSortDropdown();
    }
  }

  Connections {
    target: mainInstance

    function onLastErrorChanged() {
      root.errorDetailsExpanded = false;
    }
  }

  anchors.fill: parent

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 56 * Style.uiScaleRatio + 48 * Style.uiScaleRatio + Style.marginS * 4
        Layout.minimumHeight: Layout.preferredHeight
        radius: Style.radiusL
        color: Color.mSurface
        border.width: Style.borderS
        border.color: Qt.alpha(Color.mOutline, 0.22)

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginS
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true

            NIcon {
              icon: "wallpaper-selector"
              pointSize: Style.fontSizeL
              color: Color.mOnSurface
            }

            NText {
              text: pluginApi?.tr("panel.title")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Bold
              color: Color.mOnSurface
            }

            Item { Layout.fillWidth: true }

            NIconButton {
              enabled: mainInstance?.engineAvailable ?? false
              icon: "refresh"
              tooltipText: pluginApi?.tr("panel.reload")
              onClicked: {
                root.scanWallpapers();
                if (mainInstance?.hasAnyConfiguredWallpaper()) {
                  mainInstance?.reload(true);
                } else {
                  mainInstance.lastError = "";
                }
              }
            }

            NIconButton {
              enabled: mainInstance?.engineAvailable ?? false
              icon: "player-stop"
              tooltipText: pluginApi?.tr("panel.stop")
              onClicked: mainInstance?.stopAll(true)
            }

            NIconButton {
              icon: "settings"
              tooltipText: pluginApi?.tr("menu.settings")
              onClicked: {
                const screen = pluginApi?.panelOpenScreen;
                BarService.openPluginSettings(screen, pluginApi?.manifest);
                if (pluginApi) {
                  pluginApi.togglePanel(screen);
                }
              }
            }

            NIconButton {
              icon: "x"
              tooltipText: pluginApi?.tr("panel.closePanel")
              onClicked: {
                const screen = pluginApi?.panelOpenScreen;
                if (pluginApi) {
                  pluginApi.togglePanel(screen);
                }
              }
            }
          }

          RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 48 * Style.uiScaleRatio

            NTextInput {
              id: searchInput
              Layout.fillWidth: true
              placeholderText: pluginApi?.tr("panel.searchPlaceholder")
              text: root.searchText
              onTextChanged: root.searchText = text
            }

            NIconButton {
              Layout.alignment: Qt.AlignVCenter
              visible: root.searchText.length > 0
              icon: "x"
              tooltipText: pluginApi?.tr("panel.searchClear")
              onClicked: root.searchText = ""
            }

            Rectangle {
              id: resolutionButton
              Layout.preferredWidth: 172 * Style.uiScaleRatio
              Layout.maximumWidth: 184 * Style.uiScaleRatio
              Layout.preferredHeight: 42 * Style.uiScaleRatio
              radius: Style.radiusL
              color: Qt.alpha(Color.mSurfaceVariant, 0.42)
              border.width: Style.borderS
              border.color: Qt.alpha(Color.mOutline, 0.45)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXXS

                NIcon {
                  icon: "badge-hd"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurface
                }

                NText {
                  Layout.fillWidth: true
                  text: root.resolutionFilterLabel(root.selectedResolution)
                  color: Color.mOnSurface
                  elide: Text.ElideRight
                }

                NIcon {
                  icon: "chevron-down"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (resolutionDropdownOpen) {
                    root.closeDropdowns();
                  } else {
                    root.openResolutionDropdown();
                  }
                }
              }
            }

            Rectangle {
              id: filterButton
              Layout.preferredWidth: 172 * Style.uiScaleRatio
              Layout.maximumWidth: 184 * Style.uiScaleRatio
              Layout.preferredHeight: 42 * Style.uiScaleRatio
              radius: Style.radiusL
              color: Qt.alpha(Color.mSurfaceVariant, 0.42)
              border.width: Style.borderS
              border.color: Qt.alpha(Color.mOutline, 0.45)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXXS

                NIcon {
                  icon: "adjustments-horizontal"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurface
                }

                NText {
                  Layout.fillWidth: true
                  text: pluginApi?.tr("panel.filterButtonSummary", { type: root.typeLabel(root.selectedType) })
                  color: Color.mOnSurface
                  elide: Text.ElideRight
                }

                NIcon {
                  icon: "chevron-down"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (filterDropdownOpen) {
                    root.closeDropdowns();
                  } else {
                    root.openFilterDropdown();
                  }
                }
              }
            }

            Rectangle {
              id: sortButton
              Layout.preferredWidth: 172 * Style.uiScaleRatio
              Layout.maximumWidth: 184 * Style.uiScaleRatio
              Layout.preferredHeight: 42 * Style.uiScaleRatio
              radius: Style.radiusL
              color: Qt.alpha(Color.mSurfaceVariant, 0.42)
              border.width: Style.borderS
              border.color: Qt.alpha(Color.mOutline, 0.45)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.marginS
                anchors.rightMargin: Style.marginS
                spacing: Style.marginXXS

                NIcon {
                  icon: "arrows-sort"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurface
                }

                NText {
                  Layout.fillWidth: true
                  text: pluginApi?.tr("panel.sortButtonSummary", {
                    direction: root.sortAscending ? "\u2191" : "\u2193",
                    sort: root.sortLabel(root.sortMode)
                  })
                  color: Color.mOnSurface
                  elide: Text.ElideRight
                }

                NIcon {
                  icon: "chevron-down"
                  pointSize: Style.fontSizeM
                  color: Color.mOnSurfaceVariant
                }
              }

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  if (sortDropdownOpen) {
                    root.closeDropdowns();
                  } else {
                    root.openSortDropdown();
                  }
                }
              }
            }
            }
          }
        }

        Rectangle {
          id: runtimeErrorBanner
          visible: root.hasRuntimeError
          Layout.fillWidth: true
          implicitHeight: errorBannerContent.implicitHeight + Style.marginS * 2
          Layout.preferredHeight: implicitHeight
          radius: Style.radiusM
          color: Color.mSurface
          border.width: Style.borderS
          border.color: Qt.alpha(Color.mOutline, 0.2)

          ColumnLayout {
            id: errorBannerContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Style.marginS
            anchors.rightMargin: Style.marginS
            anchors.topMargin: Style.marginS
            spacing: Style.marginXS

            RowLayout {
              Layout.fillWidth: true

              NIcon {
                icon: "alert-triangle"
                pointSize: Style.fontSizeL
                color: Color.mError
              }

              NText {
                text: pluginApi?.tr("panel.errorBannerTitle")
                color: Color.mOnSurface
                font.weight: Font.Bold
              }

              Item {
                Layout.fillWidth: true
              }

              NButton {
                text: root.errorDetailsExpanded
                  ? pluginApi?.tr("panel.errorHideDetails")
                  : pluginApi?.tr("panel.errorShowDetails")
                icon: root.errorDetailsExpanded ? "chevron-up" : "chevron-down"
                onClicked: root.errorDetailsExpanded = !root.errorDetailsExpanded
              }

              NIconButton {
                icon: "x"
                tooltipText: pluginApi?.tr("panel.errorDismiss")
                onClicked: {
                  if (mainInstance) {
                    mainInstance.lastError = "";
                    mainInstance.lastErrorDetails = "";
                  }
                }
              }
            }

            NText {
              Layout.fillWidth: true
              text: mainInstance?.lastError ?? ""
              color: Color.mOnSurface
              wrapMode: Text.WordWrap
              maximumLineCount: 2
              elide: Text.ElideRight
            }

            Rectangle {
              visible: root.errorDetailsExpanded && (mainInstance?.lastErrorDetails ?? "").length > 0
              Layout.fillWidth: true
              Layout.preferredHeight: 136 * Style.uiScaleRatio
              radius: Style.radiusS
              color: Qt.alpha(Color.mSurfaceVariant, 0.35)
              border.width: Style.borderS
              border.color: Qt.alpha(Color.mOutline, 0.25)

              NScrollView {
                anchors.fill: parent
                anchors.margins: Style.marginXS
                showScrollbarWhenScrollable: true
                gradientColor: "transparent"

                NText {
                  width: parent.width
                  text: mainInstance?.lastErrorDetails ?? ""
                  color: Color.mOnSurface
                  wrapMode: Text.WrapAnywhere
                }
              }
            }
          }
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          radius: Style.radiusL
          color: Color.mSurface
          border.width: Style.borderS
          border.color: Qt.alpha(Color.mOutline, 0.2)

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginM
            spacing: Style.marginS

            RowLayout {
              Layout.fillWidth: true
              Layout.fillHeight: true
              Layout.topMargin: Style.marginXS
              spacing: Style.marginM

              GridView {
                id: gridView
                Layout.fillWidth: true
                Layout.fillHeight: true
                property real minCardWidth: 244 * Style.uiScaleRatio
                property real cardGap: Style.marginS
                property int columnCount: Math.max(1, Math.floor((width + cardGap) / (minCardWidth + cardGap)))
                cellWidth: (width - ((columnCount - 1) * cardGap)) / columnCount
                cellHeight: 208 * Style.uiScaleRatio
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                model: root.visibleWallpapers

                delegate: Rectangle {
                  id: tileCard
                  required property var modelData
                  width: gridView.cellWidth
                  height: gridView.cellHeight
                  radius: Style.radiusL
                  color: Qt.alpha(Color.mSurface, 0.82)
                  border.width: root.pendingPath === modelData.path ? 2 : (root.selectedPath === modelData.path ? 1 : 0)
                  border.color: root.pendingPath === modelData.path ? Color.mPrimary : Qt.alpha(Color.mOutline, 0.45)
                  clip: true

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.marginS
                    spacing: Style.marginXS

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 136 * Style.uiScaleRatio
                      radius: Style.radiusM
                      color: Color.mSurfaceVariant
                      clip: true

                      Image {
                        anchors.fill: parent
                        visible: modelData.thumb && modelData.thumb.length > 0
                        source: visible ? ("file://" + modelData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                      }

                      Loader {
                        anchors.fill: parent
                        active: modelData.motionPreview && modelData.motionPreview.length > 0
                        sourceComponent: root.isVideoMotion(modelData.motionPreview) ? motionVideoComponent : motionAnimatedComponent
                      }

                      Component {
                        id: motionAnimatedComponent

                        AnimatedImage {
                          anchors.fill: parent
                          source: "file://" + modelData.motionPreview
                          fillMode: Image.PreserveAspectCrop
                          cache: false
                          playing: true
                        }
                      }

                      Component {
                        id: motionVideoComponent

                        Video {
                          anchors.fill: parent
                          autoPlay: true
                          loops: MediaPlayer.Infinite
                          muted: true
                          fillMode: VideoOutput.PreserveAspectCrop
                          source: "file://" + modelData.motionPreview

                          onErrorOccurred: (error, errorString) => {
                            Logger.e("LWEController", "Video preview error", errorString, modelData.motionPreview);
                          }
                        }
                      }

                      NIcon {
                        anchors.centerIn: parent
                        visible: (!modelData.thumb || modelData.thumb.length === 0) && (!modelData.motionPreview || modelData.motionPreview.length === 0)
                        icon: "photo"
                        pointSize: Style.fontSizeXL
                        color: Color.mOnSurfaceVariant
                      }
                    }

                     RowLayout {
                       Layout.fillWidth: true
                       spacing: Style.marginXS

                       NText {
                         Layout.fillWidth: true
                         text: modelData.name
                         color: Color.mOnSurface
                         elide: Text.ElideRight
                         font.weight: Font.Medium
                       }

                    NIcon {
                      visible: root.selectedPath === modelData.path
                      icon: "check"
                      pointSize: Style.fontSizeL
                      color: Color.mPrimary
                    }
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginXS

                    Rectangle {
                      color: Qt.alpha(Color.mPrimary, 0.14)
                      radius: Style.radiusXS
                      implicitWidth: idBadgeText.implicitWidth + Style.marginS * 2
                      implicitHeight: idBadgeText.implicitHeight + Style.marginXS * 2

                      NText {
                        id: idBadgeText
                        anchors.centerIn: parent
                        text: modelData.id
                        color: Color.mPrimary
                        elide: Text.ElideMiddle
                        font.pointSize: Style.fontSizeXS
                        font.weight: Font.Medium
                      }
                    }

                    Item { Layout.fillWidth: true }

                    Rectangle {
                      visible: root.resolutionBadgeIcon(modelData.resolution).length > 0
                      color: Qt.alpha(Color.mSurfaceVariant, 0.24)
                      radius: Style.radiusXS
                      implicitWidth: resolutionBadgeRow.implicitWidth + Style.marginS * 2
                      implicitHeight: resolutionBadgeRow.implicitHeight + Style.marginXS * 2

                      RowLayout {
                        id: resolutionBadgeRow
                        anchors.centerIn: parent
                        spacing: Style.marginXS

                        NIcon {
                          id: resolutionBadgeIconItem
                          icon: root.resolutionBadgeIcon(modelData.resolution)
                          pointSize: Style.fontSizeM
                          color: Color.mOnSurfaceVariant
                        }

                        NText {
                          text: root.resolutionBadgeLabel(modelData.resolution)
                          color: Color.mOnSurfaceVariant
                          font.pointSize: Style.fontSizeXS
                          font.weight: Font.Medium
                        }
                      }
                    }

                    Rectangle {
                      color: Qt.alpha(Color.mSecondary, 0.18)
                      radius: Style.radiusXS
                      implicitWidth: typeBadgeText.implicitWidth + Style.marginS * 2
                      implicitHeight: typeBadgeText.implicitHeight + Style.marginXS * 2

                      NText {
                        id: typeBadgeText
                        anchors.centerIn: parent
                        text: root.typeLabel(modelData.type)
                        color: Color.mSecondary
                        font.pointSize: Style.fontSizeXS
                        font.weight: Font.Medium
                      }
                    }

                    Rectangle {
                      color: modelData.dynamic ? Qt.alpha(Color.mTertiary, 0.18) : Qt.alpha(Color.mOutline, 0.18)
                      radius: Style.radiusXS
                      implicitWidth: motionBadgeText.implicitWidth + Style.marginS * 2
                      implicitHeight: motionBadgeText.implicitHeight + Style.marginXS * 2

                      NText {
                        id: motionBadgeText
                        anchors.centerIn: parent
                        text: modelData.dynamic
                          ? pluginApi?.tr("panel.dynamicBadge")
                          : pluginApi?.tr("panel.staticBadge")
                        color: modelData.dynamic ? Color.mTertiary : Color.mOnSurfaceVariant
                        font.pointSize: Style.fontSizeXS
                        font.weight: Font.Medium
                      }
                    }
                  }
                  }

                  MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    enabled: mainInstance?.engineAvailable ?? false
                    hoverEnabled: true
                    onClicked: root.applyPath(modelData.path)
                  }
                }

                Rectangle {
                  visible: root.visibleWallpapers.length === 0 && !root.scanningWallpapers
                  anchors.centerIn: parent
                  color: "transparent"
                  width: 300 * Style.uiScaleRatio
                  height: 140 * Style.uiScaleRatio

                  ColumnLayout {
                    anchors.centerIn: parent
                    spacing: Style.marginS

                    NIcon {
                      Layout.alignment: Qt.AlignHCenter
                      icon: "photo"
                      pointSize: Style.fontSizeXL
                      color: Color.mOnSurfaceVariant
                    }

                    NText {
                      text: root.wallpaperItems.length === 0
                        ? pluginApi?.tr("panel.emptyAll")
                        : pluginApi?.tr("panel.emptyFiltered")
                      color: Color.mOnSurfaceVariant
                    }
                  }
                }
              }

              Rectangle {
                Layout.preferredWidth: 340 * Style.uiScaleRatio
                Layout.fillHeight: true
                visible: root.selectedWallpaperData !== null
                radius: Style.radiusL
                color: Qt.alpha(Color.mSurfaceVariant, 0.35)
                border.width: Style.borderS
                border.color: Qt.alpha(Color.mOutline, 0.35)
                clip: true

                NScrollView {
                  id: sidebarScrollView
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  showScrollbarWhenScrollable: true
                  gradientColor: "transparent"

                  ColumnLayout {
                    width: sidebarScrollView.availableWidth
                    spacing: Style.marginS

                    Rectangle {
                      Layout.fillWidth: true
                      Layout.preferredHeight: 180 * Style.uiScaleRatio
                      radius: Style.radiusM
                      color: Color.mSurfaceVariant
                      clip: true

                      Image {
                        anchors.fill: parent
                        visible: root.selectedWallpaperData && (!root.selectedWallpaperData.motionPreview || root.selectedWallpaperData.motionPreview.length === 0) && root.selectedWallpaperData.thumb && root.selectedWallpaperData.thumb.length > 0
                        source: visible ? ("file://" + root.selectedWallpaperData.thumb) : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                      }

                      AnimatedImage {
                        anchors.fill: parent
                        visible: root.selectedWallpaperData && root.selectedWallpaperData.motionPreview && root.selectedWallpaperData.motionPreview.length > 0 && !root.isVideoMotion(root.selectedWallpaperData.motionPreview)
                        source: visible ? ("file://" + root.selectedWallpaperData.motionPreview) : ""
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        playing: visible
                      }

                      Video {
                        anchors.fill: parent
                        visible: root.selectedWallpaperData && root.selectedWallpaperData.motionPreview && root.selectedWallpaperData.motionPreview.length > 0 && root.isVideoMotion(root.selectedWallpaperData.motionPreview)
                        autoPlay: true
                        loops: MediaPlayer.Infinite
                        muted: true
                        fillMode: VideoOutput.PreserveAspectCrop
                        source: visible ? ("file://" + root.selectedWallpaperData.motionPreview) : ""
                      }
                    }

                    NText {
                      Layout.fillWidth: true
                      text: root.selectedWallpaperData ? root.selectedWallpaperData.name : ""
                      color: Color.mOnSurface
                      font.weight: Font.Bold
                      elide: Text.ElideRight
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginXS

                      Rectangle {
                        color: Qt.alpha(Color.mPrimary, 0.14)
                        radius: Style.radiusXS
                        implicitWidth: sidebarIdBadgeText.implicitWidth + Style.marginS * 2
                        implicitHeight: sidebarIdBadgeText.implicitHeight + Style.marginXS * 2

                        NText {
                          id: sidebarIdBadgeText
                          anchors.centerIn: parent
                          text: root.selectedWallpaperData ? root.selectedWallpaperData.id : ""
                          color: Color.mPrimary
                          font.pointSize: Style.fontSizeXS
                          font.weight: Font.Medium
                        }
                      }

                      Item { Layout.fillWidth: true }

                      Rectangle {
                        visible: root.selectedWallpaperData && root.resolutionBadgeLabel(root.selectedWallpaperData.resolution).length > 0
                        color: Qt.alpha(Color.mSurfaceVariant, 0.24)
                        radius: Style.radiusXS
                        implicitWidth: sidebarResolutionBadgeRow.implicitWidth + Style.marginS * 2
                        implicitHeight: sidebarResolutionBadgeRow.implicitHeight + Style.marginXS * 2

                        RowLayout {
                          id: sidebarResolutionBadgeRow
                          anchors.centerIn: parent
                          spacing: Style.marginXS

                          NIcon {
                            icon: root.selectedWallpaperData ? root.resolutionBadgeIcon(root.selectedWallpaperData.resolution) : ""
                            pointSize: Style.fontSizeM
                            color: Color.mOnSurfaceVariant
                          }

                          NText {
                            id: sidebarResolutionBadgeText
                            text: root.selectedWallpaperData ? root.resolutionBadgeLabel(root.selectedWallpaperData.resolution) : ""
                            color: Color.mOnSurfaceVariant
                            font.pointSize: Style.fontSizeXS
                            font.weight: Font.Medium
                          }
                        }
                      }

                      Rectangle {
                        color: Qt.alpha(Color.mSecondary, 0.18)
                        radius: Style.radiusXS
                        implicitWidth: sidebarTypeBadgeText.implicitWidth + Style.marginS * 2
                        implicitHeight: sidebarTypeBadgeText.implicitHeight + Style.marginXS * 2

                        NText {
                          id: sidebarTypeBadgeText
                          anchors.centerIn: parent
                          text: root.selectedWallpaperData ? root.typeLabel(root.selectedWallpaperData.type) : ""
                          color: Color.mSecondary
                          font.pointSize: Style.fontSizeXS
                          font.weight: Font.Medium
                        }
                      }

                      Rectangle {
                        color: root.selectedWallpaperData && root.selectedWallpaperData.dynamic
                          ? Qt.alpha(Color.mTertiary, 0.18)
                          : Qt.alpha(Color.mOutline, 0.18)
                        radius: Style.radiusXS
                        implicitWidth: sidebarMotionBadgeText.implicitWidth + Style.marginS * 2
                        implicitHeight: sidebarMotionBadgeText.implicitHeight + Style.marginXS * 2

                        NText {
                          id: sidebarMotionBadgeText
                          anchors.centerIn: parent
                          text: root.selectedWallpaperData
                            ? (root.selectedWallpaperData.dynamic
                              ? pluginApi?.tr("panel.dynamicBadge")
                              : pluginApi?.tr("panel.staticBadge"))
                            : ""
                          color: root.selectedWallpaperData && root.selectedWallpaperData.dynamic ? Color.mTertiary : Color.mOnSurfaceVariant
                          font.pointSize: Style.fontSizeXS
                          font.weight: Font.Medium
                        }
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      Layout.topMargin: Style.marginM

                      NText {
                        text: pluginApi?.tr("panel.infoType")
                        color: Color.mOnSurfaceVariant
                      }

                      Item { Layout.fillWidth: true }

                      NText {
                        text: root.selectedWallpaperData ? root.typeLabel(root.selectedWallpaperData.type) : ""
                        color: Color.mOnSurface
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true

                      NText {
                        text: pluginApi?.tr("panel.infoId")
                        color: Color.mOnSurfaceVariant
                      }

                      Item { Layout.fillWidth: true }

                      NText {
                        text: root.selectedWallpaperData ? root.selectedWallpaperData.id : ""
                        color: Color.mOnSurface
                        elide: Text.ElideMiddle
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true

                      NText {
                        text: pluginApi?.tr("panel.infoResolution")
                        color: Color.mOnSurfaceVariant
                      }

                      Item { Layout.fillWidth: true }

                      NText {
                        text: root.selectedWallpaperData
                          ? (String(root.selectedWallpaperData.resolution || "unknown") === "unknown"
                            ? pluginApi?.tr("panel.resolutionUnknown")
                            : root.selectedWallpaperData.resolution)
                          : ""
                        color: Color.mOnSurface
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true

                      NText {
                        text: pluginApi?.tr("panel.infoSize")
                        color: Color.mOnSurfaceVariant
                      }

                      Item { Layout.fillWidth: true }

                      NText {
                        text: root.selectedWallpaperData ? root.formatBytes(root.selectedWallpaperData.bytes) : ""
                        color: Color.mOnSurface
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginS

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: Style.marginS

                        NButton {
                          Layout.fillWidth: true
                          text: pluginApi?.tr("panel.confirmApply")
                          icon: "check"
                          enabled: (mainInstance?.engineAvailable ?? false) && root.pendingPath.length > 0
                          onClicked: root.applyPendingSelection()
                        }

                        NIconButton {
                          Layout.preferredWidth: 42 * Style.uiScaleRatio
                          Layout.preferredHeight: 42 * Style.uiScaleRatio
                          visible: !root.singleScreenMode
                          enabled: mainInstance?.engineAvailable ?? false
                          icon: "device-desktop"
                          tooltipText: root.applyAllDisplays
                            ? pluginApi?.tr("panel.targetAllDisplays")
                            : pluginApi?.tr("panel.targetSingleDisplay", { screen: root.selectedScreenName })
                          onClicked: root.applyTargetExpanded = !root.applyTargetExpanded
                        }
                      }

                      NBox {
                        Layout.fillWidth: true
                        visible: !root.singleScreenMode && root.applyTargetExpanded
                        Layout.preferredHeight: targetScreenColumn.implicitHeight + Style.marginL * 2

                        ButtonGroup {
                          id: targetScreenGroup
                        }

                        ColumnLayout {
                          id: targetScreenColumn
                          anchors.fill: parent
                          anchors.margins: Style.marginL
                          spacing: Style.marginS

                          NRadioButton {
                            ButtonGroup.group: targetScreenGroup
                            Layout.fillWidth: true
                            enabled: mainInstance?.engineAvailable ?? false
                            text: pluginApi?.tr("panel.applyAllDisplays")
                            checked: root.applyAllDisplays
                            onClicked: {
                              root._applyAllDisplays = true;
                              root.applyTargetExpanded = false;
                            }
                          }

                          Repeater {
                            model: root.screenModel

                            NRadioButton {
                              ButtonGroup.group: targetScreenGroup
                              required property var modelData
                              Layout.fillWidth: true
                              enabled: mainInstance?.engineAvailable ?? false
                              text: pluginApi?.tr("panel.applySingleDisplay", { screen: modelData.name })
                              checked: !root.applyAllDisplays && root.selectedScreenName === modelData.key
                              onClicked: {
                                root._applyAllDisplays = false;
                                root.selectedScreenName = modelData.key;
                                root.applyTargetExpanded = false;
                              }
                            }
                          }
                        }
                      }

                      NDivider {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.marginM
                        Layout.bottomMargin: Style.marginM
                      }

                      NText {
                        text: pluginApi?.tr("panel.sectionAudio")
                        color: Color.mOnSurface
                        font.weight: Font.Bold
                        font.pointSize: Style.fontSizeM
                      }

                      NComboBox {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperScaling")
                        model: [
                          { "key": "fill", "name": pluginApi?.tr("panel.scalingFill") },
                          { "key": "fit", "name": pluginApi?.tr("panel.scalingFit") },
                          { "key": "stretch", "name": pluginApi?.tr("panel.scalingStretch") },
                          { "key": "default", "name": pluginApi?.tr("panel.scalingDefault") }
                        ]
                        currentKey: root.selectedScaling
                        onSelected: key => root.selectedScaling = key
                      }

                      NSpinBox {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperVolume")
                        from: 0
                        to: 100
                        suffix: pluginApi?.tr("settings.units.percent")
                        value: root.selectedVolume
                        enabled: !root.selectedMuted
                        onValueChanged: root.selectedVolume = value
                      }

                      NToggle {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperMuted")
                        checked: root.selectedMuted
                        onToggled: checked => root.selectedMuted = checked
                      }

                      NDivider {
                        Layout.fillWidth: true
                        Layout.topMargin: Style.marginM
                        Layout.bottomMargin: Style.marginM
                      }

                      NText {
                        text: pluginApi?.tr("panel.sectionFeatures")
                        color: Color.mOnSurface
                        font.weight: Font.Bold
                        font.pointSize: Style.fontSizeM
                      }

                      NToggle {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperAudioReactive")
                        checked: root.selectedAudioReactiveEffects
                        onToggled: checked => root.selectedAudioReactiveEffects = checked
                      }

                      NToggle {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperDisableMouse")
                        checked: root.selectedDisableMouse
                        onToggled: checked => root.selectedDisableMouse = checked
                      }

                      NToggle {
                        Layout.fillWidth: true
                        label: pluginApi?.tr("panel.wallpaperDisableParallax")
                        checked: root.selectedDisableParallax
                        onToggled: checked => root.selectedDisableParallax = checked
                      }
                    }
                  }
                }
              }
            }
          }
        }

        NText {
          visible: !(mainInstance?.engineAvailable ?? false)
          text: pluginApi?.tr("panel.installHint")
          color: Color.mOnSurfaceVariant
          wrapMode: Text.Wrap
        }

        NText {
          visible: !root.folderAccessible
          text: pluginApi?.tr("panel.folderInvalid")
          color: Color.mError
          wrapMode: Text.WrapAnywhere
        }

        NText {
          visible: root.scanningWallpapers
          text: pluginApi?.tr("panel.scanning")
          color: Color.mOnSurfaceVariant
        }
      }

  }

  MouseArea {
    anchors.fill: parent
    visible: root.filterDropdownOpen || root.resolutionDropdownOpen || root.sortDropdownOpen
    z: 900
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: root.closeDropdowns()
  }

  Rectangle {
    visible: root.resolutionDropdownOpen
    x: root.resolutionDropdownX
    y: root.resolutionDropdownY
    width: root.resolutionDropdownWidth
    height: Math.min(210 * Style.uiScaleRatio, resolutionList.contentHeight + 2 * Style.marginS)
    radius: Style.radiusL
    color: Qt.alpha(Color.mSurface, 0.96)
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOutline, 0.45)
    z: 901

    NListView {
      id: resolutionList
      anchors.fill: parent
      anchors.margins: Style.marginS
      clip: true
      spacing: Style.marginXS
      model: [
        { "label": pluginApi?.tr("panel.filterResAll"), "action": "res:all", "selected": root.selectedResolution === "all" },
        { "label": pluginApi?.tr("panel.filterRes4k"), "action": "res:4k", "selected": root.selectedResolution === "4k" },
        { "label": pluginApi?.tr("panel.filterRes8k"), "action": "res:8k", "selected": root.selectedResolution === "8k" },
        { "label": pluginApi?.tr("panel.filterResUnknown"), "action": "res:unknown", "selected": root.selectedResolution === "unknown" }
      ]

      delegate: Rectangle {
        required property var modelData
        width: resolutionList.availableWidth
        height: 34 * Style.uiScaleRatio
        radius: Style.radiusM
        color: modelData.selected ? Qt.alpha(Color.mPrimary, 0.22) : "transparent"
        border.width: modelData.selected ? 1 : 0
        border.color: Qt.alpha(Color.mPrimary, 0.45)

        NText {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.marginS
          text: modelData.label
          color: modelData.selected ? Color.mPrimary : Color.mOnSurface
          font.weight: modelData.selected ? Font.Medium : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.applyResolutionFilterAction(modelData.action)
        }
      }
    }
  }

  Rectangle {
    visible: root.filterDropdownOpen
    x: root.filterDropdownX
    y: root.filterDropdownY
    width: root.filterDropdownWidth
    height: Math.min(244 * Style.uiScaleRatio, filterList.contentHeight + 2 * Style.marginS)
    radius: Style.radiusL
    color: Qt.alpha(Color.mSurface, 0.96)
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOutline, 0.45)
    z: 901

    NListView {
      id: filterList
      anchors.fill: parent
      anchors.margins: Style.marginS
      clip: true
      spacing: Style.marginXS
      model: [
        { "label": pluginApi?.tr("panel.filterTypeAll"), "action": "type:all", "selected": root.selectedType === "all" },
        { "label": pluginApi?.tr("panel.filterTypeScene"), "action": "type:scene", "selected": root.selectedType === "scene" },
        { "label": pluginApi?.tr("panel.filterTypeVideo"), "action": "type:video", "selected": root.selectedType === "video" },
        { "label": pluginApi?.tr("panel.filterTypeWeb"), "action": "type:web", "selected": root.selectedType === "web" },
        { "label": pluginApi?.tr("panel.filterTypeApplication"), "action": "type:application", "selected": root.selectedType === "application" }
      ]

      delegate: Rectangle {
        required property var modelData
        width: filterList.availableWidth
        height: 34 * Style.uiScaleRatio
        radius: Style.radiusM
        color: modelData.selected ? Qt.alpha(Color.mPrimary, 0.22) : "transparent"
        border.width: modelData.selected ? 1 : 0
        border.color: Qt.alpha(Color.mPrimary, 0.45)

        NText {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.marginS
          text: modelData.label
          color: modelData.selected ? Color.mPrimary : Color.mOnSurface
          font.weight: modelData.selected ? Font.Medium : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.applyFilterAction(modelData.action)
        }
      }
    }
  }

  Rectangle {
    visible: root.sortDropdownOpen
    x: root.sortDropdownX
    y: root.sortDropdownY
    width: root.sortDropdownWidth
    height: Math.min(244 * Style.uiScaleRatio, sortList.contentHeight + 2 * Style.marginS)
    radius: Style.radiusL
    color: Qt.alpha(Color.mSurface, 0.96)
    border.width: Style.borderS
    border.color: Qt.alpha(Color.mOutline, 0.45)
    z: 901

    NListView {
      id: sortList
      anchors.fill: parent
      anchors.margins: Style.marginS
      clip: true
      spacing: Style.marginXS
      model: [
        { "label": pluginApi?.tr("panel.sortName"), "action": "sort:name", "selected": root.sortMode === "name" },
        { "label": pluginApi?.tr("panel.sortDateAdded"), "action": "sort:date", "selected": root.sortMode === "date" },
        { "label": pluginApi?.tr("panel.sortSize"), "action": "sort:size", "selected": root.sortMode === "size" },
        { "label": pluginApi?.tr("panel.sortRecent"), "action": "sort:recent", "selected": root.sortMode === "recent" },
        {
          "label": pluginApi?.tr("panel.sortAscendingToggleWithDirection", {
            direction: root.sortAscending ? "\u2191" : "\u2193"
          }),
          "action": "sort:toggleAscending",
          "selected": false
        }
      ]

      delegate: Rectangle {
        required property var modelData
        width: sortList.availableWidth
        height: 34 * Style.uiScaleRatio
        radius: Style.radiusM
        color: modelData.selected ? Qt.alpha(Color.mPrimary, 0.22) : "transparent"
        border.width: modelData.selected ? 1 : 0
        border.color: Qt.alpha(Color.mPrimary, 0.45)

        NText {
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.leftMargin: Style.marginS
          text: modelData.label
          color: modelData.selected ? Color.mPrimary : Color.mOnSurface
          font.weight: modelData.selected ? Font.Medium : Font.Normal
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.applySortAction(modelData.action)
        }
      }
    }
  }

  Process {
    id: scanProcess

    onExited: function (exitCode) {
      const parsed = [];
      const lines = String(stdout.text || "").split("\n");
      const stderrText = String(stderr.text || "").trim();

      root.folderAccessible = (exitCode === 0);

      for (let i = 0; i < lines.length; i++) {
        const line = lines[i].trim();
        if (line.length === 0) {
          continue;
        }

        const parts = line.split("\t");
        const path = parts.length > 0 ? parts[0] : "";
        const name = parts.length > 1 && parts[1].length > 0 ? parts[1] : basename(path);
        const thumb = parts.length > 2 ? parts[2] : "";
        const motionPreview = parts.length > 3 ? parts[3] : "";
        const dynamic = parts.length > 4 ? parts[4] === "1" : false;
        const id = parts.length > 5 ? parts[5] : basename(path);
        const type = parts.length > 6 ? parts[6] : "unknown";
        const resolution = parts.length > 7 ? parts[7] : "unknown";
        const sizeMtime = parts.length > 8 ? parts[8] : "0:0";
        const sizeParts = String(sizeMtime).split(":");
        const bytes = sizeParts.length > 0 ? Number(sizeParts[0]) : 0;
        const mtime = sizeParts.length > 1 ? Number(sizeParts[1]) : 0;

        if (path.length > 0) {
          parsed.push({
            path: path,
            name: name,
            thumb: thumb,
            motionPreview: motionPreview,
            dynamic: dynamic,
            id: id,
            type: type,
            resolution: resolution,
            bytes: bytes,
            mtime: mtime
          });
        }
      }

      root.wallpaperItems = parsed;
      root.scanningWallpapers = false;

      if (!root.folderAccessible) {
        if (stderrText.length > 0) {
          Logger.e("LWEController", "Wallpaper scan failed", "folder=", root.resolvedWallpapersFolder, "exitCode=", exitCode, "stderr=", stderrText);
        } else {
          Logger.e("LWEController", "Wallpaper scan failed", "folder=", root.resolvedWallpapersFolder, "exitCode=", exitCode);
        }
      }

      Logger.i("LWEController", "Scan completed", "count=", parsed.length, "exitCode=", exitCode);
    }

    stdout: StdioCollector {}
    stderr: StdioCollector {}
  }
}

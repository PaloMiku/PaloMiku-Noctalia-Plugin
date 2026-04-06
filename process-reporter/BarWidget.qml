import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  readonly property var runtime: pluginApi?.mainInstance
  readonly property string currentWindowTitle: runtime?.activeWindowSnapshot?.title || "Unknown Window"

  icon: "world"
  tooltipText: pluginApi?.tr("widget.tooltip", {
    "title": currentWindowTitle,
  }) || ("窗口: " + currentWindowTitle)
  tooltipDirection: BarService.getTooltipDirection(screen?.name)
  baseSize: Style.getCapsuleHeightForScreen(screen?.name)
  applyUiScale: false
  customRadius: Style.radiusL
  colorBg: Style.capsuleColor
  colorFg: Color.mPrimary

  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      Logger.i("ActiveUpload", "Bar widget clicked", "pluginId=", pluginApi?.pluginId || "unknown");
      pluginApi.withCurrentScreen(screen => {
        Logger.d("ActiveUpload", "Opening panel from bar", "screen=", screen?.name || "unknown");
        pluginApi.openPanel(screen, this);
      });
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": pluginApi?.tr("menu.settings"),
        "action": "settings",
        "icon": "settings"
      },
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        pluginApi.withCurrentScreen(currentScreen => {
          if (!currentScreen || !pluginApi?.manifest) {
            Logger.w("ActiveUpload", "Cannot open settings from bar menu: missing screen or manifest");
            return;
          }
          BarService.openPluginSettings(currentScreen, pluginApi.manifest);
        });
      }
    }
  }

  onRightClicked: {
    Logger.d("ActiveUpload", "Bar widget right-clicked");
    PanelService.showContextMenu(contextMenu, root, screen);
  }
}

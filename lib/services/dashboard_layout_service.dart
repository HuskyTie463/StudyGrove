import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_layout.dart';

class DashboardLayoutService {
  static const _phoneKey = 'dashboard_layout_phone_v2';
  static const _desktopKey = 'dashboard_layout_desktop_v1';
  static const _legacyPhoneKey = 'dashboard_layout_phone_v1';
  static const _widgetDefaultsMigrationKey =
      'dashboard_layout_widget_defaults_v3';

  Future<DashboardLayoutConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    var phoneRaw = prefs.getString(_phoneKey);
    phoneRaw ??= prefs.getString(_legacyPhoneKey);
    final desktopRaw = prefs.getString(_desktopKey);

    if (phoneRaw == null && desktopRaw == null) {
      await prefs.setBool(_widgetDefaultsMigrationKey, true);
      return DashboardLayoutConfig.defaults();
    }

    final defaults = DashboardLayoutConfig.defaults();
    final fromPhone = phoneRaw != null
        ? DashboardLayoutConfig.decode(phoneRaw)
        : defaults;
    final fromDesktop = desktopRaw != null
        ? DashboardLayoutConfig.decode(desktopRaw)
        : defaults;

    final phoneRects = phoneRaw != null
        ? (fromPhone.phoneRects.isEmpty
            ? defaults.phoneRects
            : fromPhone.phoneRects)
        : defaults.phoneRects;
    final desktopRects = desktopRaw != null
        ? fromDesktop.desktopRects
        : defaults.desktopRects;

    final config = DashboardLayoutConfig(
      phoneRects: phoneRects,
      desktopRects: desktopRects,
    );
    final migrated = prefs.getBool(_widgetDefaultsMigrationKey) ?? false;
    if (!migrated) {
      _applyV3WidgetDefaults(config);
      await prefs.setBool(_widgetDefaultsMigrationKey, true);
      await save(config);
    }
    return config;
  }

  /// One-time: drop auto Gap session / phone queue, compact phone Today.
  void _applyV3WidgetDefaults(DashboardLayoutConfig config) {
    config.phoneRects.remove(DashboardWidgetType.gapSession);
    config.phoneRects.remove(DashboardWidgetType.tasks);
    config.phoneRects[DashboardWidgetType.todayEvents] =
        DashboardLayoutConfig.suggestedPhoneRects()[
            DashboardWidgetType.todayEvents]!;

    config.desktopRects.remove(DashboardWidgetType.gapSession);
    const oldDesktopTasks = DesktopRect(
      col: 0,
      row: 2,
      colSpan: 5,
      rowSpan: 6,
    );
    final tasks = config.desktopRects[DashboardWidgetType.tasks];
    if (tasks == oldDesktopTasks) {
      config.desktopRects[DashboardWidgetType.tasks] =
          DashboardLayoutConfig.suggestedDesktopRects()[
              DashboardWidgetType.tasks]!;
    }
  }

  Future<void> save(DashboardLayoutConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    final phoneOnly = DashboardLayoutConfig(
      phoneRects: config.phoneRects,
      desktopRects: const {},
    );
    final desktopOnly = DashboardLayoutConfig(
      phoneRects: const {},
      desktopRects: config.desktopRects,
    );
    await prefs.setString(_phoneKey, phoneOnly.encode());
    await prefs.setString(_desktopKey, desktopOnly.encode());
  }
}

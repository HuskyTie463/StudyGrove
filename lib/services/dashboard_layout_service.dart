import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_layout.dart';

class DashboardLayoutService {
  static const _phoneKey = 'dashboard_layout_phone_v2';
  static const _desktopKey = 'dashboard_layout_desktop_v1';
  static const _legacyPhoneKey = 'dashboard_layout_phone_v1';

  Future<DashboardLayoutConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    var phoneRaw = prefs.getString(_phoneKey);
    phoneRaw ??= prefs.getString(_legacyPhoneKey);
    final desktopRaw = prefs.getString(_desktopKey);

    if (phoneRaw == null && desktopRaw == null) {
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
    _ensureGapSession(config);
    return config;
  }

  void _ensureGapSession(DashboardLayoutConfig config) {
    if (!config.phoneRects.containsKey(DashboardWidgetType.gapSession)) {
      final rect = config.firstFreeRect(
            config.phoneRects,
            colSpan: 12,
            rowSpan: 2,
          ) ??
          const DesktopRect(col: 0, row: 0, colSpan: 12, rowSpan: 2);
      config.phoneRects[DashboardWidgetType.gapSession] = rect;
    }
    if (!config.desktopRects.containsKey(DashboardWidgetType.gapSession)) {
      final rect = config.firstFreeRect(
            config.desktopRects,
            colSpan: 5,
            rowSpan: 2,
          ) ??
          const DesktopRect(col: 0, row: 0, colSpan: 5, rowSpan: 2);
      config.desktopRects[DashboardWidgetType.gapSession] = rect;
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

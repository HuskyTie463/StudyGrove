import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../config/background_assets.dart';
import '../main.dart';
import '../theme/app_visual_mode.dart';
import '../theme/design_tokens.dart';
import '../theme/style_family.dart';
import '../ui/shared_ui.dart';

class BackgroundsPage extends StatelessWidget {
  const BackgroundsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final t = context.tokens;
        return SafeArea(
          child: ListView(
            padding: EdgeInsets.all(t.gap(2)),
            children: [
              FrostPanel(
                // Opaque enough that the shell wallpaper does not show through
                // as a second copy behind the thumbnail grid.
                opacity: 0.88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              SegmentedButton<ThemeBrightnessPref>(
                segments: const [
                  ButtonSegment(
                    value: ThemeBrightnessPref.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeBrightnessPref.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeBrightnessPref.system,
                    label: Text('System'),
                    icon: Icon(Icons.brightness_auto),
                  ),
                ],
                selected: {themeController.brightnessPref},
                onSelectionChanged: (v) {
                  themeController.setBrightnessPref(v.first);
                },
              ),
              SizedBox(height: t.gap(1.5)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reduced motion'),
                value: themeController.reducedMotion,
                onChanged: themeController.setReducedMotion,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Increased contrast'),
                value: themeController.contrast == ContrastLevel.increased,
                onChanged: (v) => themeController.setContrast(
                  v ? ContrastLevel.increased : ContrastLevel.normal,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Spacing'),
                trailing: SegmentedButton<SpacingDensity>(
                  segments: const [
                    ButtonSegment(
                      value: SpacingDensity.comfortable,
                      label: Text('Comfy'),
                    ),
                    ButtonSegment(
                      value: SpacingDensity.compact,
                      label: Text('Compact'),
                    ),
                  ],
                  selected: {themeController.spacing},
                  onSelectionChanged: (v) =>
                      themeController.setSpacing(v.first),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Blend colours from background'),
                value: themeController.useBackgroundBlend,
                onChanged: themeController.setUseBackgroundBlend,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Panel opacity'),
                subtitle: Text(
                  themeController.mode == AppVisualMode.blend
                      ? 'Frost over the wallpaper'
                      : 'How solid the panels feel',
                ),
                trailing: SizedBox(
                  width: 180,
                  child: Slider(
                    value: themeController.panelOpacity.clamp(0.20, 0.85),
                    min: 0.20,
                    max: 0.85,
                    onChanged: themeController.setPanelOpacity,
                  ),
                ),
              ),
              SizedBox(height: t.gap(2)),
              Text('Wallpaper', style: Theme.of(context).textTheme.titleMedium),
              SizedBox(height: t.gap(1)),
              Text(
                'Upload a photo or pick a scene. Yours stay on this device.',
                style: TextStyle(color: t.textMuted, fontSize: 13),
              ),
              SizedBox(height: t.gap(1)),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: 1 +
                    themeController.customBackgrounds.length +
                    dashboardBackgroundAssets.length,
                itemBuilder: (_, i) {
                  if (i == 0) {
                    return _UploadWallpaperTile(
                      onTap: () => _uploadWallpaper(context),
                    );
                  }
                  final customCount = themeController.customBackgrounds.length;
                  final customIndex = i - 1;
                  if (customIndex < customCount) {
                    final path = themeController.customBackgrounds[customIndex];
                    return _WallpaperTile(
                      asset: path,
                      selected: path == themeController.backgroundAsset,
                      onTap: () => themeController.setBackground(path),
                    );
                  }
                  final asset = dashboardBackgroundAssets[customIndex - customCount];
                  return _WallpaperTile(
                    asset: asset,
                    selected: asset == themeController.backgroundAsset,
                    onTap: () => themeController.setBackground(asset),
                  );
                },
              ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _uploadWallpaper(BuildContext context) async {
  final picked = await FilePicker.platform.pickFiles(
    type: FileType.image,
    allowMultiple: false,
  );
  final path = picked?.files.single.path;
  if (path == null || path.isEmpty) return;
  final ok = await themeController.importCustomBackground(path);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        ok ? 'Wallpaper saved on this device.' : "Couldn't use that photo.",
      ),
    ),
  );
}

class _UploadWallpaperTile extends StatelessWidget {
  const _UploadWallpaperTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined, color: t.textMuted),
            const SizedBox(height: 6),
            Text(
              'Upload',
              style: TextStyle(fontSize: 12, color: t.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  final String asset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? t.primaryAction : t.border,
            width: selected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GroveWallpaper(asset: asset),
            if (selected)
              Positioned(
                bottom: 6,
                right: 6,
                child: Icon(
                  Icons.check_circle,
                  color: t.primaryAction,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

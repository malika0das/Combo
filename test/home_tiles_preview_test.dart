import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:combo_universal/models/catalog.dart';
import 'package:combo_universal/theme.dart';
import 'package:combo_universal/widgets/stat_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders the home page's tile blocks to a PNG so the redesign can be reviewed
/// without installing a build on a phone.
///
/// Writing is opt-in, because a test that mutates the working tree by default is
/// a nuisance in CI:
///
///     flutter test test/home_tiles_preview_test.dart \
///       --dart-define=write_preview=true
///
/// Output: `build/previews/home_tiles.png`.
const _writePreview = bool.fromEnvironment('write_preview');
const _previewKey = ValueKey('home_tiles_preview');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('home tiles preview renders with the real catalog',
      (tester) async {
    final catalog = Catalog.fromJson(
      jsonDecode(File('assets/data/catalog.json').readAsStringSync())
          as Map<String, dynamic>,
    );

    // A phone-width, tall viewport: 360 x 900 logical pixels.
    tester.view.physicalSize = const Size(1080, 2700);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      RepaintBoundary(
        key: _previewKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          // Frozen animation so the capture shows settled numbers rather than
          // counters part-way up.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: true),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(body: _Preview(catalog: catalog)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The real bundled numbers, formatted: proof we captured real data.
    expect(find.text('5,977'), findsOneWidget);
    expect(find.text('1,420'), findsOneWidget);

    if (!_writePreview) return;

    final bytes = await tester.runAsync(() async {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(_previewKey),
      );
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    if (bytes == null) return;

    final file = File('build/previews/home_tiles.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes);

    // ignore: avoid_print
    print('Wrote ${file.absolute.path} (${bytes.length} bytes)');
  });
}

/// A static reconstruction of the home page's two tile blocks, wired to the
/// real catalog so the numbers in the image are the numbers users see.
class _Preview extends StatelessWidget {
  const _Preview({required this.catalog});

  final Catalog catalog;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lists = catalog.categories.fold<int>(0, (a, c) => a + c.groupCount);
    final models = catalog.categories.fold<int>(0, (a, c) => a + c.modelCount);
    final height = statTileExtent(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: StatTile(
                      eyebrow: 'Models',
                      value: models,
                      caption: 'ready offline',
                      tint: brandSeed,
                      icon: Icons.inventory_2_outlined,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: height,
                    child: StatTile(
                      eyebrow: 'Lists',
                      value: lists,
                      caption: 'in ${catalog.categories.length} part types',
                      tint: const Color(0xFF9B5DE5),
                      icon: Icons.format_list_bulleted_rounded,
                      phase: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            Text('Browse by part', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: catalog.categories.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                mainAxisExtent: height,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, i) {
                final category = catalog.categories[i];
                return StatTile(
                  eyebrow: category.name,
                  value: category.modelCount,
                  caption: '${category.groupCount} lists',
                  tint: accentFor(category.icon, scheme),
                  icon: iconFor(category.icon),
                  phase: (i * 0.37) % 1,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

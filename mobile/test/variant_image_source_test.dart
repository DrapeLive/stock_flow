import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

import 'package:stock_flow_admin/features/items/item_edit_screen.dart';
import 'package:stock_flow_admin/features/items/variant_form.dart';

import 'helpers.dart';

/// The channel image_picker's default (method-channel) platform impl talks to.
/// Intercepting `pickImage` lets a test assert which [ImageSource] each
/// option was wired to without pulling in the platform interface package.
const _imagePickerChannel = MethodChannel('plugins.flutter.io/image_picker');

/// 1x1 transparent PNG. The picked path must point at a real, decodable file
/// because the callers render it via `Image.file` straight away.
final _pixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Records the [ImageSource] of every `pickImage` call the app makes, and
/// returns a real image file so the downstream "image set" flow still runs.
void _mockImagePicker(List<ImageSource> recorded, Directory dir) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_imagePickerChannel, (call) async {
    if (call.method != 'pickImage') return null;
    final args = Map<Object?, Object?>.from(call.arguments as Map);
    recorded.add(ImageSource.values[args['source'] as int]);
    final file = File('${dir.path}/picked-${recorded.length}.png')
      ..writeAsBytesSync(_pixelPng);
    return file.path;
  });
}

void main() {
  late ProviderContainer container;
  late List<ImageSource> pickedSources;
  late Directory pickedDir;

  setUp(() async {
    await resetTestInfra();
    container = makeTestContainer();
    addTearDown(container.dispose);
    pickedSources = [];
    pickedDir = Directory.systemTemp.createTempSync('sf_image_picker_test_');
    addTearDown(() => pickedDir.deleteSync(recursive: true));
    _mockImagePicker(pickedSources, pickedDir);
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_imagePickerChannel, null);
    });
  });

  Future<void> pumpVariantEditor(WidgetTester tester) async {
    useTallSurface(tester);
    await pumpScreen(
      tester,
      VariantEditorScreen(
        commonName: 'ITEM-A',
        commonPrice: '500',
        commonType: 'gents',
        itemSizes: const ['S,M,L,XL'],
        initial: ColorVariantDraft(),
        isEdit: false,
        variantIndex: 1,
        onSave: (_) {},
        onBack: () {},
      ),
      container,
    );
    await tester.pumpAndSettle();
  }

  /// Opens the chooser from the create-flow image area.
  Future<void> openChooserFromVariantEditor(WidgetTester tester) async {
    await tester.tap(find.text('Tap to upload & crop'));
    await tester.pumpAndSettle();
  }

  group('create flow variant image', () {
    testWidgets('offers both Take Photo and Choose from Gallery',
        (tester) async {
      await pumpVariantEditor(tester);
      await openChooserFromVariantEditor(tester);

      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
      // Nothing is picked until the admin actually chooses.
      expect(pickedSources, isEmpty);
    });

    testWidgets('Take Photo picks with ImageSource.camera', (tester) async {
      await pumpVariantEditor(tester);
      await openChooserFromVariantEditor(tester);

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(pickedSources, [ImageSource.camera]);
      // Same downstream flow as a gallery pick: the image is set on the variant,
      // so the Change/Remove actions appear.
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('Choose from Gallery keeps ImageSource.gallery',
        (tester) async {
      await pumpVariantEditor(tester);
      await openChooserFromVariantEditor(tester);

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(pickedSources, [ImageSource.gallery]);
      expect(find.text('Change'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('dismissing the chooser picks nothing', (tester) async {
      await pumpVariantEditor(tester);
      await openChooserFromVariantEditor(tester);

      // Tap the barrier above the sheet to dismiss without choosing.
      await tester.tapAt(const Offset(300, 60));
      await tester.pumpAndSettle();

      expect(find.text('Take Photo'), findsNothing);
      expect(pickedSources, isEmpty);
      expect(find.text('Tap to upload & crop'), findsOneWidget);
    });
  });

  group('edit flow inline variant thumbnail', () {
    Future<void> pumpEditScreen(WidgetTester tester) async {
      useTallSurface(tester);
      seedAdminSession(business: 'gents');
      mockGet('/api/items/size-ranges', body: sizeRangesJson());
      mockGet('/api/items/1/', body: {
        'id': 1,
        'name': 'Edit Item',
        'type': 'gents',
        'price': '500',
        'description': 'Test item',
        'variants': [
          {
            'id': 100,
            'qr_code': 'QRONE',
            'image': null,
            'display_order': null,
            'sizes': [
              {'id': 1, 'size': 'S', 'stock': 5},
            ],
          },
        ],
      });
      await pumpScreen(tester, const ItemEditScreen(itemId: 1), container);
      await tester.pumpAndSettle();
    }

    /// The edit screen has its own picker instance on the variant thumbnail.
    Future<void> openChooserFromThumbnail(WidgetTester tester) async {
      await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Take Photo'), findsOneWidget);
      expect(find.text('Choose from Gallery'), findsOneWidget);
    }

    testWidgets('Take Photo picks with ImageSource.camera', (tester) async {
      await pumpEditScreen(tester);
      await openChooserFromThumbnail(tester);

      await tester.tap(find.text('Take Photo'));
      await tester.pumpAndSettle();

      expect(pickedSources, [ImageSource.camera]);
    });

    testWidgets('Choose from Gallery picks with ImageSource.gallery',
        (tester) async {
      await pumpEditScreen(tester);
      await openChooserFromThumbnail(tester);

      await tester.tap(find.text('Choose from Gallery'));
      await tester.pumpAndSettle();

      expect(pickedSources, [ImageSource.gallery]);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

import 'package:stock_flow_admin/features/items/item_sync_service.dart';
import 'package:stock_flow_admin/data/item_store.dart';
import 'package:stock_flow_admin/core/cache/app_cache.dart';

import 'helpers.dart';

void main() {
  setUp(() async {
    await resetTestInfra();
  });

  test('service completes a bootstrap+verify round in real async', () async {
    seedAdminSession();
    seedItemStore([stockEntryJson()]);
    mockItemSync(items: [stockEntryJson()]);

    await ItemSyncService.instance.trigger().timeout(const Duration(seconds: 10));

    expect(ItemSyncService.instance.lastError.value, isNull);
    expect(ItemSyncService.instance.syncing.value, isFalse);
    expect(ItemStore.instance.hasBootstrapped, isTrue);
    expect(ItemStore.instance.entries(), hasLength(1));
    expect(ItemStore.instance.entries().first.name, 'ITEM-A');
    // boxes are a side effect of seeding; assert via store instead
    expect(AppCache.itemSyncBox.isNotEmpty, isTrue);
  });
}
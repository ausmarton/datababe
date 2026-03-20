import 'package:sembast/sembast.dart';

/// Centralized Sembast store references for all entity types.
class StoreRefs {
  StoreRefs._();

  static final activities = stringMapStoreFactory.store('activities');
  static final ingredients = stringMapStoreFactory.store('ingredients');
  static final recipes = stringMapStoreFactory.store('recipes');
  static final targets = stringMapStoreFactory.store('targets');
  static final families = stringMapStoreFactory.store('families');
  static final children = stringMapStoreFactory.store('children');
  static final carers = stringMapStoreFactory.store('carers');

  // Sync infrastructure
  static final syncQueue = stringMapStoreFactory.store('sync_queue');
  static final syncMeta = stringMapStoreFactory.store('sync_meta');
  static final syncDeadLetter = stringMapStoreFactory.store('sync_dead_letter');

  // User preferences (local-only, per device)
  static final settings = stringMapStoreFactory.store('settings');
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/snippets/snippet_store.dart';

/// Global snippet store instance.
final snippetStoreProvider = Provider<SnippetStore>((ref) {
  final store = SnippetStore();
  store.load();
  ref.onDispose(() => store.dispose());
  return store;
});

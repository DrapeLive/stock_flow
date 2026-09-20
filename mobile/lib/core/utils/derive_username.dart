/// Mirrors `frontend/lib/utils/deriveUsername.ts`.
String deriveUsername(String displayName, {Set<String>? existingUsernames}) {
  var base = displayName
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^\w]'), '')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');

  if (existingUsernames == null) return base;

  var username = base;
  var counter = 1;
  while (existingUsernames.contains(username)) {
    username = '${base}_$counter';
    counter++;
  }
  return username;
}
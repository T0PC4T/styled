/// Applies a JSON merge patch (RFC 7386) to [target]: objects merge key by
/// key, a null value removes a key, and anything else replaces.
Object? mergePatch(Object? target, Object? patch) {
  if (patch is! Map<String, Object?>) return patch;
  final result = <String, Object?>{if (target is Map<String, Object?>) ...target};
  for (final MapEntry(:key, :value) in patch.entries) {
    if (value == null) {
      result.remove(key);
    } else {
      result[key] = mergePatch(result[key], value);
    }
  }
  return result;
}

/// Writes a `///` doc comment, one trimmed line at a time.
void writeDocComment(StringBuffer buffer, String? docComment, {String indent = '  '}) {
  if (docComment == null) return;
  for (final line in docComment.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) buffer.writeln('$indent$trimmed');
  }
}

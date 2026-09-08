/// Resolves `redirect.html` against the origin/directory the web app is
/// actually served from, so it tracks --web-port / a real deployment host
/// without needing to be told either.
Uri resolveWebRedirectUri(Uri base) {
  final origin = Uri.parse(base.origin);
  final basePath = base.path;
  final directoryPath = basePath.endsWith('/')
      ? basePath
      : basePath.substring(0, basePath.lastIndexOf('/') + 1);
  return origin.replace(path: '${directoryPath}redirect.html');
}

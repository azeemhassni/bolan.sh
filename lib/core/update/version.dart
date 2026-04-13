/// Simple semver version for comparing release tags.
class Version implements Comparable<Version> {
  final int major;
  final int minor;
  final int patch;

  const Version(this.major, this.minor, this.patch);

  /// Parses `"0.3.3"` or `"v0.3.3"`.
  factory Version.parse(String input) {
    final s = input.startsWith('v') ? input.substring(1) : input;
    final parts = s.split('.');
    if (parts.length != 3) {
      throw FormatException('Invalid version: $input');
    }
    return Version(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Returns `true` if parsing succeeds.
  static bool isValid(String input) {
    try {
      Version.parse(input);
      return true;
    } on FormatException {
      return false;
    }
  }

  bool operator >(Version other) => compareTo(other) > 0;
  bool operator <(Version other) => compareTo(other) < 0;
  bool operator >=(Version other) => compareTo(other) >= 0;
  bool operator <=(Version other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is Version &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  int compareTo(Version other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

/// A saved command template that can be quickly inserted into the prompt.
class Snippet {
  final String id;
  final String name;
  final String command;
  final String description;
  final List<String> tags;

  const Snippet({
    required this.id,
    required this.name,
    required this.command,
    this.description = '',
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'command': command,
        'description': description,
        'tags': tags,
      };

  factory Snippet.fromJson(Map<String, dynamic> json) {
    return Snippet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      command: json['command'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

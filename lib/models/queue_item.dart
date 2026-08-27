class QueueItem {
  final String id;
  final String videoId;
  final String title;
  final String addedBy;
  final int addedAt;

  QueueItem({
    required this.id,
    required this.videoId,
    required this.title,
    required this.addedBy,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'videoId': videoId,
        'title': title,
        'addedBy': addedBy,
        'addedAt': addedAt,
      };

  factory QueueItem.fromMap(String id, Map<dynamic, dynamic> map) => QueueItem(
        id: id,
        videoId: map['videoId']?.toString() ?? '',
        title: map['title']?.toString() ?? '',
        addedBy: map['addedBy']?.toString() ?? '',
        addedAt: (map['addedAt'] as num?)?.toInt() ?? 0,
      );
}

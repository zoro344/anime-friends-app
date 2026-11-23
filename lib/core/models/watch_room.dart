class WatchRoom {
  final String id;
  final String name;
  final String code;
  final String hostId;
  final int memberCount;
  final bool isPrivate;
  final String watchiumCode;
  final String anymexDeepLink;

  const WatchRoom({
    required this.id,
    required this.name,
    this.code = '',
    this.hostId = '',
    this.memberCount = 1,
    this.isPrivate = false,
    this.watchiumCode = '',
    this.anymexDeepLink = '',
  });

  factory WatchRoom.fromJson(Map<String, dynamic> json) => WatchRoom(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? 'Watch Room'}',
        code: '${json['code'] ?? ''}',
        hostId: '${json['hostId'] ?? ''}',
        memberCount: (json['memberCount'] as num?)?.toInt() ?? 1,
        isPrivate: json['isPrivate'] == true,
        watchiumCode: '${json['watchiumCode'] ?? ''}',
        anymexDeepLink: '${json['anymexDeepLink'] ?? ''}',
      );
}

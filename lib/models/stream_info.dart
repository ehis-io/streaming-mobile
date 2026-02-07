import 'package:json_annotation/json_annotation.dart';

part 'stream_info.g.dart';

@JsonSerializable()
class StreamInfo {
  final String url;
  final String quality;
  final bool? isM3U8;
  final String? provider;
  final Map<String, String>? headers;

  StreamInfo({
    required this.url,
    required this.quality,
    this.isM3U8,
    this.provider,
    this.headers,
  });

  factory StreamInfo.fromJson(Map<String, dynamic> json) => _$StreamInfoFromJson(json);
  Map<String, dynamic> toJson() => _$StreamInfoToJson(this);
  bool get isEmbed {
    // Check for explicit flag or common embed patterns
    if (isM3U8 == false) return true;
    if (url.contains('/embed')) return true;
    if (!url.endsWith('.m3u8') && !url.endsWith('.mp4')) return true;
    return false;
  }
}

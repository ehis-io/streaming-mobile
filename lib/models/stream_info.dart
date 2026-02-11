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
    if (isM3U8 == true) return false;
    if (url.contains('.m3u8') || url.contains('.mp4')) return false;
    if (url.contains('/embed')) return true;
    return true;
  }
}

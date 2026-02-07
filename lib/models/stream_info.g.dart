// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stream_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StreamInfo _$StreamInfoFromJson(Map<String, dynamic> json) => StreamInfo(
  url: json['url'] as String,
  quality: json['quality'] as String,
  isM3U8: json['isM3U8'] as bool?,
  provider: json['provider'] as String?,
  headers: (json['headers'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
);

Map<String, dynamic> _$StreamInfoToJson(StreamInfo instance) =>
    <String, dynamic>{
      'url': instance.url,
      'quality': instance.quality,
      'isM3U8': instance.isM3U8,
      'provider': instance.provider,
      'headers': instance.headers,
    };

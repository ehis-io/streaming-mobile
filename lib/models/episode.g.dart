// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Episode _$EpisodeFromJson(Map<String, dynamic> json) => Episode(
  episodeNumber: (json['episode_number'] as num).toInt(),
  name: json['name'] as String?,
  overview: json['overview'] as String?,
  airDate: json['air_date'] as String?,
  stillPath: json['still_path'] as String?,
  voteAverage: (json['vote_average'] as num?)?.toDouble(),
);

Map<String, dynamic> _$EpisodeToJson(Episode instance) => <String, dynamic>{
  'episode_number': instance.episodeNumber,
  'name': instance.name,
  'overview': instance.overview,
  'air_date': instance.airDate,
  'still_path': instance.stillPath,
  'vote_average': instance.voteAverage,
};

// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Season _$SeasonFromJson(Map<String, dynamic> json) => Season(
  seasonNumber: (json['season_number'] as num).toInt(),
  episodeCount: (json['episode_count'] as num).toInt(),
  name: json['name'] as String?,
  overview: json['overview'] as String?,
  posterPath: json['poster_path'] as String?,
  airDate: json['air_date'] as String?,
);

Map<String, dynamic> _$SeasonToJson(Season instance) => <String, dynamic>{
  'season_number': instance.seasonNumber,
  'episode_count': instance.episodeCount,
  'name': instance.name,
  'overview': instance.overview,
  'poster_path': instance.posterPath,
  'air_date': instance.airDate,
};

Media _$MediaFromJson(Map<String, dynamic> json) => Media(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String?,
  name: json['name'] as String?,
  overview: json['overview'] as String?,
  posterPath: json['poster_path'] as String?,
  backdropPath: json['backdrop_path'] as String?,
  voteAverage: (json['vote_average'] as num?)?.toDouble(),
  releaseDate: json['release_date'] as String?,
  firstAirDate: json['first_air_date'] as String?,
  mediaType: $enumDecodeNullable(_$MediaTypeEnumMap, json['media_type']),
  seasons: (json['seasons'] as List<dynamic>?)
      ?.map((e) => Season.fromJson(e as Map<String, dynamic>))
      .toList(),
  numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
);

Map<String, dynamic> _$MediaToJson(Media instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'name': instance.name,
  'overview': instance.overview,
  'poster_path': instance.posterPath,
  'backdrop_path': instance.backdropPath,
  'vote_average': instance.voteAverage,
  'release_date': instance.releaseDate,
  'first_air_date': instance.firstAirDate,
  'media_type': _$MediaTypeEnumMap[instance.mediaType],
  'seasons': instance.seasons,
  'number_of_seasons': instance.numberOfSeasons,
};

const _$MediaTypeEnumMap = {
  MediaType.movie: 'movie',
  MediaType.tv: 'tv',
  MediaType.anime: 'anime',
};

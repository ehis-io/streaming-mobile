// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'media.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

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
};

const _$MediaTypeEnumMap = {MediaType.movie: 'movie', MediaType.tv: 'tv'};

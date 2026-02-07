import 'package:json_annotation/json_annotation.dart';

part 'media.g.dart';

enum MediaType {
  @JsonValue('movie')
  movie,
  @JsonValue('tv')
  tv,
  @JsonValue('anime')
  anime,
}

@JsonSerializable()
class Media {
  final int id;
  final String? title;
  final String? name;
  final String? overview;
  @JsonKey(name: 'poster_path')
  final String? posterPath;
  @JsonKey(name: 'backdrop_path')
  final String? backdropPath;
  @JsonKey(name: 'vote_average')
  final double? voteAverage;
  @JsonKey(name: 'release_date')
  final String? releaseDate;
  @JsonKey(name: 'first_air_date')
  final String? firstAirDate;
  @JsonKey(name: 'media_type')
  final MediaType? mediaType;

  Media({
    required this.id,
    this.title,
    this.name,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.releaseDate,
    this.firstAirDate,
    this.mediaType,
  });

  String get displayTitle => title ?? name ?? 'Unknown';
  String get displayDate => releaseDate ?? firstAirDate ?? '';
  String get posterUrl {
    if (posterPath == null) return 'https://via.placeholder.com/500x750?text=No+Image';
    if (posterPath!.startsWith('http')) return posterPath!;
    return 'https://image.tmdb.org/t/p/w500$posterPath';
  }
  String get backdropUrl {
    if (backdropPath == null) return 'https://via.placeholder.com/1280x720?text=No+Image';
    if (backdropPath!.startsWith('http')) return backdropPath!;
    return 'https://image.tmdb.org/t/p/w1280$backdropPath';
  }

  factory Media.fromJson(Map<String, dynamic> json) => _$MediaFromJson(json);
  Map<String, dynamic> toJson() => _$MediaToJson(this);

  Media copyWith({
    int? id,
    String? title,
    String? name,
    String? overview,
    String? posterPath,
    String? backdropPath,
    double? voteAverage,
    String? releaseDate,
    String? firstAirDate,
    MediaType? mediaType,
  }) {
    return Media(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      overview: overview ?? this.overview,
      posterPath: posterPath ?? this.posterPath,
      backdropPath: backdropPath ?? this.backdropPath,
      voteAverage: voteAverage ?? this.voteAverage,
      releaseDate: releaseDate ?? this.releaseDate,
      firstAirDate: firstAirDate ?? this.firstAirDate,
      mediaType: mediaType ?? this.mediaType,
    );
  }
}

import 'package:json_annotation/json_annotation.dart';

part 'episode.g.dart';

@JsonSerializable()
class Episode {
  @JsonKey(name: 'episode_number')
  final int episodeNumber;
  final String? name;
  final String? overview;
  @JsonKey(name: 'air_date')
  final String? airDate;
  @JsonKey(name: 'still_path')
  final String? stillPath;
  @JsonKey(name: 'vote_average')
  final double? voteAverage;

  Episode({
    required this.episodeNumber,
    this.name,
    this.overview,
    this.airDate,
    this.stillPath,
    this.voteAverage,
  });

  String get stillUrl {
    if (stillPath == null) return 'https://via.placeholder.com/500x281?text=No+Image';
    if (stillPath!.startsWith('http')) return stillPath!;
    return 'https://image.tmdb.org/t/p/w500$stillPath';
  }

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);
  Map<String, dynamic> toJson() => _$EpisodeToJson(this);
}

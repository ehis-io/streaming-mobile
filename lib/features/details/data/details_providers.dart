import '../../../models/media.dart';
import '../../../models/stream_info.dart';
import '../../../models/episode.dart';
import '../../../core/network/api_client.dart';

final tvDetailsProvider = FutureProvider.family<Media, int>((ref, id) async {
  final client = ref.watch(apiClientProvider);
  return client.getTvDetails(id);
});

final seasonDetailsProvider = FutureProvider.family<List<Episode>, ({int id, int season})>((ref, args) async {
  final client = ref.watch(apiClientProvider);
  return client.getSeasonDetails(args.id, args.season);
});

final streamsProvider = FutureProvider.family<List<StreamInfo>, ({Media media, int? season, int? episode})>((ref, args) async {
  final client = ref.watch(apiClientProvider);
  return client.getStreams(
    args.media.id.toString(),
    mediaType: args.media.mediaType?.name ?? (args.media.title != null ? 'movie' : 'tv'),
    season: args.season,
    episode: args.episode,
  );
});

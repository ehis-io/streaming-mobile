import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/media.dart';
import '../../../models/stream_info.dart';
import '../../../core/network/api_client.dart';

final streamsProvider = FutureProvider.family<List<StreamInfo>, Media>((ref, media) async {
  final client = ref.watch(apiClientProvider);
  return client.getStreams(
    media.id.toString(),
    mediaType: media.mediaType?.name ?? (media.title != null ? 'movie' : 'tv'),
    // For now we just fetch for movie or season 1 ep 1 for tv/anime
    season: media.mediaType == MediaType.movie ? null : 1,
    episode: media.mediaType == MediaType.movie ? null : 1,
  );
});

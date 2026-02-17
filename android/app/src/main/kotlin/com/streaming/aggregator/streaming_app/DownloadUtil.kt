package com.streaming.aggregator.streaming_app

import android.content.Context
import androidx.media3.common.util.UnstableApi
import androidx.media3.database.DatabaseProvider
import androidx.media3.database.StandaloneDatabaseProvider
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.datasource.cache.Cache
import androidx.media3.datasource.cache.CacheDataSource
import androidx.media3.datasource.cache.NoOpCacheEvictor
import androidx.media3.datasource.cache.SimpleCache
import androidx.media3.exoplayer.offline.DownloadManager
import java.io.File
import java.util.concurrent.Executors

@UnstableApi
object DownloadUtil {
    private const val DOWNLOAD_CONTENT_DIRECTORY = "downloads"
    
    private var databaseProvider: DatabaseProvider? = null
    private var downloadCache: Cache? = null
    private var downloadManager: DownloadManager? = null
    private val urlHeaders = java.util.concurrent.ConcurrentHashMap<String, Map<String, String>>()

    fun setHeadersForUrl(urlPart: String, headers: Map<String, String>) {
        urlHeaders[urlPart] = headers
    }

    fun removeHeadersForUrl(urlPart: String) {
        urlHeaders.remove(urlPart)
    }

    @Synchronized
    fun getDatabaseProvider(context: Context): DatabaseProvider {
        if (databaseProvider == null) {
            databaseProvider = StandaloneDatabaseProvider(context)
        }
        return databaseProvider!!
    }

    @Synchronized
    fun getDownloadCache(context: Context): Cache {
        if (downloadCache == null) {
            val downloadContentDirectory = File(context.getExternalFilesDir(null), DOWNLOAD_CONTENT_DIRECTORY)
            downloadCache = SimpleCache(downloadContentDirectory, NoOpCacheEvictor(), getDatabaseProvider(context))
        }
        return downloadCache!!
    }

    @Synchronized
    fun getDownloadManager(context: Context): DownloadManager {
        if (downloadManager == null) {
            val upstreamFactory = DataSource.Factory {
                val baseDataSource = DefaultHttpDataSource.Factory()
                    .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
                    .setAllowCrossProtocolRedirects(true)
                    .createDataSource()
                
                object : DataSource by baseDataSource {
                    override fun open(dataSpec: androidx.media3.datasource.DataSpec): Long {
                        val uriString = dataSpec.uri.toString()
                        for ((part, headers) in urlHeaders) {
                            if (uriString.contains(part)) {
                                // We need to add headers to the baseDataSource
                                // Since we can't easily modify the already created DataSource's properties,
                                // We use a fresh one for this request if we have headers
                                val factoryWithHeaders = DefaultHttpDataSource.Factory()
                                    .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
                                    .setAllowCrossProtocolRedirects(true)
                                    .setDefaultRequestProperties(headers)
                                val dsWithHeaders = factoryWithHeaders.createDataSource()
                                return dsWithHeaders.open(dataSpec)
                            }
                        }
                        return baseDataSource.open(dataSpec)
                    }
                }
            }

            downloadManager = DownloadManager(
                context,
                getDatabaseProvider(context),
                getDownloadCache(context),
                upstreamFactory,
                Executors.newFixedThreadPool(6)
            )
        }
        return downloadManager!!
    }

    fun getHttpDataSourceFactory(context: Context, headers: Map<String, String>? = null): DataSource.Factory {
        val factory = DefaultHttpDataSource.Factory()
            .setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
            .setAllowCrossProtocolRedirects(true)
        
        headers?.let {
            factory.setDefaultRequestProperties(it)
        }
        
        return factory
    }

    fun getReadOnlyDataSourceFactory(context: Context): DataSource.Factory {
        return CacheDataSource.Factory()
            .setCache(getDownloadCache(context))
            .setUpstreamDataSourceFactory(getHttpDataSourceFactory(context))
            .setCacheWriteDataSinkFactory(null) // Read only
    }
}

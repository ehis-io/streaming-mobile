package com.streaming.aggregator.streaming_app

import android.os.Bundle
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.exoplayer.offline.DownloadService
import androidx.media3.exoplayer.offline.Download
import androidx.media3.exoplayer.offline.DownloadManager
import androidx.media3.exoplayer.offline.DownloadRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

@UnstableApi
class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.streaming.aggregator/hls_download"
    private var downloadManager: DownloadManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        downloadManager = DownloadUtil.getDownloadManager(this)
        
        // Setup listener for progress updates
        downloadManager?.addListener(object : DownloadManager.Listener {
            override fun onDownloadChanged(downloadManager: DownloadManager, download: Download, finalException: Exception?) {
                val status = when (download.state) {
                    Download.STATE_DOWNLOADING -> "DOWNLOADING"
                    Download.STATE_COMPLETED -> "COMPLETED"
                    Download.STATE_FAILED -> "FAILED"
                    Download.STATE_STOPPED -> "PAUSED"
                    Download.STATE_QUEUED -> "QUEUED"
                    Download.STATE_REMOVING -> "REMOVING"
                    Download.STATE_RESTARTING -> "RESTARTING"
                    else -> "IDLE"
                }

                val data = mutableMapOf(
                    "id" to download.request.id,
                    "status" to status,
                    "progress" to if (download.percentDownloaded == androidx.media3.common.C.PERCENTAGE_UNSET.toFloat()) 0 else download.percentDownloaded.toInt()
                )
                
                // Try to get title from data
                download.request.data?.let {
                    data["fileName"] = String(it, Charsets.UTF_8).split("|").lastOrNull() ?: "HLS Download"
                }

                if (download.state == Download.STATE_COMPLETED || download.state == Download.STATE_FAILED || download.state == Download.STATE_REMOVING) {
                    val urlPart = download.request.uri.toString().substringBefore("?")
                    DownloadUtil.removeHeadersForUrl(urlPart)
                }
                
                flutterEngine?.dartExecutor?.binaryMessenger?.let {
                    MethodChannel(it, CHANNEL).invokeMethod("onDownloadUpdate", data)
                }
            }
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    val id = call.argument<String>("id") ?: url.hashCode().toString()
                    val fileName = call.argument<String>("fileName") ?: "HLS Download"
                    val referer = call.argument<String>("referer")
                    
                    if (url != null) {
                        try {
                            if (referer != null) {
                                DownloadUtil.setHeadersForUrl(url.substringBefore("?"), mapOf("Referer" to referer))
                            }
                            
                            // Store referer and filename in data: "referer|filename"
                            val metaData = "${referer ?: ""}|$fileName".toByteArray(Charsets.UTF_8)
                            
                            val downloadRequest = DownloadRequest.Builder(id, android.net.Uri.parse(url))
                                .setMimeType(MimeTypes.APPLICATION_M3U8)
                                .setData(metaData)
                                .build()
                            
                            DownloadService.sendAddDownload(
                                this,
                                HlsDownloadService::class.java,
                                downloadRequest,
                                false
                            )
                            result.success(id)
                        } catch (e: Exception) {
                            result.error("DOWNLOAD_ERROR", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }
                "pauseDownload" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        DownloadService.sendSetStopReason(
                            this,
                            HlsDownloadService::class.java,
                            id,
                            Download.STOP_REASON_NONE + 1, // Any non-zero value pauses
                            false
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ID", "ID is null", null)
                    }
                }
                "resumeDownload" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        DownloadService.sendSetStopReason(
                            this,
                            HlsDownloadService::class.java,
                            id,
                            Download.STOP_REASON_NONE, // zero resumes
                            false
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ID", "ID is null", null)
                    }
                }
                "cancelDownload" -> {
                    val id = call.argument<String>("id")
                    if (id != null) {
                        DownloadService.sendRemoveDownload(
                            this,
                            HlsDownloadService::class.java,
                            id,
                            false
                        )
                        result.success(true)
                    } else {
                        result.error("INVALID_ID", "ID is null", null)
                    }
                }
                "getTasks" -> {
                    val cursor = downloadManager?.downloadIndex?.getDownloads()
                    val tasks = mutableListOf<Map<String, Any>>()
                    
                    cursor?.use {
                        while (it.moveToNext()) {
                            val download = it.download
                            val status = when (download.state) {
                                Download.STATE_DOWNLOADING -> "DOWNLOADING"
                                Download.STATE_COMPLETED -> "COMPLETED"
                                Download.STATE_FAILED -> "FAILED"
                                Download.STATE_STOPPED -> "PAUSED"
                                Download.STATE_QUEUED -> "QUEUED"
                                else -> "IDLE"
                            }
                            
                            val fileName = download.request.data?.let { data ->
                                String(data, Charsets.UTF_8).split("|").lastOrNull() ?: "HLS Download"
                            } ?: "HLS Download"

                            tasks.add(mapOf(
                                "id" to download.request.id,
                                "progress" to if (download.percentDownloaded == androidx.media3.common.C.PERCENTAGE_UNSET.toFloat()) 0 else download.percentDownloaded.toInt(),
                                "status" to status,
                                "fileName" to fileName
                            ))
                        }
                    }
                    result.success(tasks)
                }
                else -> result.notImplemented()
            }
        }
    }
}

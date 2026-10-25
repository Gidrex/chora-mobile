package dev.gidrex.chora_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import javax.xml.parsers.DocumentBuilderFactory
import javax.xml.transform.TransformerFactory
import javax.xml.transform.dom.DOMSource
import javax.xml.transform.stream.StreamResult
import org.w3c.dom.Element

/** Local Syncthing daemon bound to exactly one folder: the chora storage root. */
class SyncthingService : Service() {

    companion object {
        const val ACTION_START = "dev.gidrex.chora_mobile.syncthing.START"
        const val ACTION_STOP = "dev.gidrex.chora_mobile.syncthing.STOP"
        const val CHANNEL_ID = "chora_sync"
        const val NOTIF_ID = 41

        @Volatile
        private var process: Process? = null

        fun isRunning(): Boolean {
            val proc = process
            return proc != null && proc.isAlive
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                shutdownDaemon(intent.getStringExtra("apiKey") ?: "")
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val choraDir = intent?.getStringExtra("choraDir") ?: return START_NOT_STICKY
                val apiKey = intent.getStringExtra("apiKey") ?: return START_NOT_STICKY
                startForegroundService(choraDir)
                Thread {
                    try {
                        ensureConfig(choraDir, apiKey)
                        launchDaemon()
                    } catch (e: Exception) {
                        e.printStackTrace()
                        stopSelf()
                    }
                }.start()
                return START_STICKY
            }
        }
    }

    private fun startForegroundService(choraDir: String) {
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "Chora Sync", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val notif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("Chora Sync активен")
                .setContentText(choraDir)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("Chora Sync активен")
                .setContentText(choraDir)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .build()
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, notif)
        }
    }

    private fun libPath(): String = "${applicationInfo.nativeLibraryDir}/libsyncthing.so"

    private fun stHome(): File = File(filesDir, "syncthing_home").also { it.mkdirs() }

    private fun ensureConfig(choraDir: String, apiKey: String) {
        val home = stHome()
        val config = File(home, "config.xml")
        if (!config.exists()) {
            ProcessBuilder(libPath(), "-generate=${home.absolutePath}")
                .redirectErrorStream(true)
                .start()
                .waitFor()
        }
        patchConfig(config, choraDir, apiKey)
    }

    /** Point the GUI at 127.0.0.1:8384 and sync exactly one folder. */
    private fun patchConfig(config: File, choraDir: String, apiKey: String) {
        val doc = DocumentBuilderFactory.newInstance().newDocumentBuilder().parse(config)
        doc.documentElement.normalize()

        val gui = doc.getElementsByTagName("gui").item(0) as Element
        gui.setAttribute("enabled", "true")
        setChildText(gui, "address", "127.0.0.1:8384")
        setChildText(gui, "apikey", apiKey)

        // Drop every folder (including the `default` one), keep a single root.
        val folders = doc.getElementsByTagName("folder")
        for (i in folders.length - 1 downTo 0) {
            val node = folders.item(i)
            node.parentNode.removeChild(node)
        }
        val folder = doc.createElement("folder")
        folder.setAttribute("id", "chora-root")
        folder.setAttribute("label", "Chora")
        folder.setAttribute("path", choraDir)
        folder.setAttribute("type", "sendreceive")
        folder.setAttribute("rescanIntervalS", "3600")
        folder.setAttribute("fsWatcherEnabled", "true")
        folder.setAttribute("fsWatcherDelayS", "5")
        doc.documentElement.appendChild(folder)

        TransformerFactory.newInstance().newTransformer().transform(
            DOMSource(doc),
            StreamResult(config)
        )
    }

    private fun setChildText(parent: Element, tag: String, text: String) {
        val nodes = parent.getElementsByTagName(tag)
        val element = if (nodes.length > 0) {
            nodes.item(0) as Element
        } else {
            val created = parent.ownerDocument.createElement(tag)
            parent.appendChild(created)
            created
        }
        element.textContent = text
    }

    private fun launchDaemon() {
        val home = stHome()
        process?.destroy()
        process = ProcessBuilder(
            libPath(),
            "-home=${home.absolutePath}",
            "-no-browser",
            "-no-restart"
        ).redirectErrorStream(true).start()
    }

    private fun shutdownDaemon(apiKey: String) {
        try {
            val url = URL("http://127.0.0.1:8384/rest/system/shutdown")
            val connection = (url.openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("X-API-Key", apiKey)
                connectTimeout = 3000
                readTimeout = 3000
            }
            connection.inputStream.close()
        } catch (_: Exception) {
        }
        process?.destroy()
        process = null
        stopForeground(STOP_FOREGROUND_REMOVE)
    }

    override fun onDestroy() {
        process?.destroy()
        process = null
        super.onDestroy()
    }
}

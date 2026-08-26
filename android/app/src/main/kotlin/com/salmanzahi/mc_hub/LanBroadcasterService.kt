package com.salmanzahi.mc_hub

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.Build
import android.os.IBinder
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.SocketTimeoutException

/**
 * LAN Broadcaster Service
 *
 * Mengumumkan world remote sebagai "world LAN" di jaringan lokal HP pemain.
 * MCBE mendeteksi world LAN lewat UDP broadcast RakNet unconnected pong.
 *
 * Cara kerja:
 * 1. Bind UDP socket ke port 19132 (broadcast)
 * 2. Setiap 500ms kirim fake unconnected pong berisi info world remote
 * 3. Minecraft yang terbuka akan menampilkan world ini di tab LAN/Friends
 */
class LanBroadcasterService : Service() {

    private var socket: DatagramSocket? = null
    private var broadcasterThread: Thread? = null
    private var running = false

    private var worldName = "Remote World"
    private var relayIp = "172.197.221.186"
    private var relayPort = 19132
    private var playerCount = 0

    companion object {
        const val CHANNEL_ID = "mc_hub_lan"
        const val NOTIFICATION_ID = 1001
        const val EXTRA_NAME = "world_name"
        const val EXTRA_IP = "relay_ip"
        const val EXTRA_PORT = "relay_port"
        const val EXTRA_PLAYERS = "player_count"

        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopSelf()
            return START_NOT_STICKY
        }

        worldName = intent?.getStringExtra(EXTRA_NAME) ?: worldName
        relayIp = intent?.getStringExtra(EXTRA_IP) ?: relayIp
        relayPort = intent?.getIntExtra(EXTRA_PORT, 19132) ?: relayPort
        playerCount = intent?.getIntExtra(EXTRA_PLAYERS, 0) ?: playerCount

        startForeground(NOTIFICATION_ID, buildNotification())
        startBroadcasting()
        return START_STICKY
    }

    private fun startBroadcasting() {
        if (running) return
        running = true
        isRunning = true

        broadcasterThread = Thread {
            try {
                socket = DatagramSocket().apply {
                    broadcast = true
                    reuseAddress = true
                }
                val broadcastAddr = InetAddress.getByName("255.255.255.255")

                while (running) {
                    try {
                        val pong = buildRakNetPong()
                        val packet = DatagramPacket(pong, pong.size, broadcastAddr, 19132)
                        socket?.send(packet)
                    } catch (_: Exception) { }
                    Thread.sleep(500)
                }
            } catch (_: Exception) { }
        }
        broadcasterThread?.start()
    }

    /**
     * Membuat paket RakNet Unconnected Pong (0x1c) dengan motd berisi nama world.
     * Format motd MCBE: nama\nprotocol\nversion\nplayers\nmaxPlayers\nserverId\nsubMotd\ngamemode
     */
    private fun buildRakNetPong(): ByteArray {
        val protocol = 618 // MCBE protocol version (approx - compatible with recent versions)
        val version = "1.21.50"
        val motd = "$worldName;$protocol;$version;${playerCount + 1};20;${System.currentTimeMillis()};;Survival"

        // Magic bytes untuk RakNet unconnected pong
        val magic = byteArrayOf(
            0x00, 0xff.toByte(), 0xff.toByte(), 0x00,
            0xfe.toByte(), 0xfe.toByte(), 0xfe.toByte(), 0xfe.toByte(),
            0xfd.toByte(), 0xfd.toByte(), 0xfd.toByte(), 0xfd.toByte(),
            0x12, 0x34, 0x56, 0x78
        )

        val motdBytes = motd.toByteArray(Charsets.UTF_8)

        // Header: packetId(1) + time(8) + magic(16) + guid(8) + motdLenShort(2) + motd
        val buf = java.io.ByteArrayOutputStream()
        buf.write(0x1c) // unconnected pong
        buf.write(System.nanoTime().toInt())
        buf.write((System.nanoTime() shr 32).toInt())
        buf.write(magic)
        // server GUID (random fixed)
        val guid = 123456789L
        for (i in 7 downTo 0) buf.write(((guid shr (i * 8)) and 0xFF).toInt())
        // motd length (short BE)
        buf.write((motdBytes.size shr 8) and 0xFF)
        buf.write(motdBytes.size and 0xFF)
        buf.write(motdBytes)

        return buf.toByteArray()
    }

    private fun buildNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pending = android.app.PendingIntent.getActivity(
            this, 0, intent,
            android.app.PendingIntent.FLAG_IMMUTABLE
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("MC World Hub - Broadcasting")
            .setContentText("$worldName muncul di tab LAN Minecraft")
            .setSmallIcon(android.R.drawable.ic_menu_share)
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "LAN Broadcasting",
                NotificationManager.IMPORTANCE_LOW
            )
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        running = false
        isRunning = false
        broadcasterThread?.interrupt()
        socket?.close()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

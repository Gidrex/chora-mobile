package dev.gidrex.chora_mobile

import android.content.Intent
import android.net.Uri
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "dev.gidrex.chora_mobile/storage"
        const val PICK_DIR_REQUEST = 41
    }

    private var pickResult: MethodChannel.Result? = null

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_DIR_REQUEST) return
        val pending = pickResult
        pickResult = null
        if (pending == null) return
        val tree = if (resultCode == RESULT_OK) data?.data else null
        if (tree == null) {
            pending.success(null)
            return
        }
        pending.success(resolveTree(tree))
    }

    /// `content://.../tree/primary:chora` -> `/storage/emulated/0/chora`.
    /// Only the primary volume resolves to a raw path; else null.
    private fun resolveTree(uri: Uri): String? {
        if (uri.authority != "com.android.externalstorage.documents") return null
        val parts = DocumentsContract.getTreeDocumentId(uri).split(":", limit = 2)
        if (parts.size != 2 || parts[0] != "primary") return null
        return "/storage/emulated/0/" + parts[1].trim('/')
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAllFilesAccess" -> result.success(Environment.isExternalStorageManager())
                "pickDirectory" -> {
                    pickResult = result
                    try {
                        startActivityForResult(
                            Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                addFlags(
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                        Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
                                )
                            },
                            PICK_DIR_REQUEST,
                        )
                    } catch (e: Exception) {
                        pickResult = null
                        result.error("NO_PICKER", e.message, null)
                    }
                }
                "requestAllFilesAccess" -> {
                    try {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                Uri.parse("package:$packageName"),
                            ),
                        )
                    } catch (_: Exception) {
                        startActivity(
                            Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                        )
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}

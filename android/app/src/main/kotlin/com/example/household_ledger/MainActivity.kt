package com.example.household_ledger

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val channelName = "household_ledger/file_save"
    private val createDocumentRequest = 9137
    private var pendingResult: MethodChannel.Result? = null
    private var pendingSourcePath: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(::handleFileSaveCall)
    }

    private fun handleFileSaveCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "saveFile") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("save_in_progress", "Another save request is active.", null)
            return
        }
        val sourcePath = call.argument<String>("sourcePath")
        val suggestedName = call.argument<String>("suggestedName")
        val mimeType = call.argument<String>("mimeType")
        if (sourcePath.isNullOrBlank() || suggestedName.isNullOrBlank() || mimeType.isNullOrBlank()) {
            result.error("invalid_arguments", "Missing file save arguments.", null)
            return
        }
        if (!File(sourcePath).isFile) {
            result.error("source_missing", "The source file does not exist.", null)
            return
        }
        pendingResult = result
        pendingSourcePath = sourcePath
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, suggestedName)
        }
        startActivityForResult(intent, createDocumentRequest)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != createDocumentRequest) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val result = pendingResult
        val sourcePath = pendingSourcePath
        pendingResult = null
        pendingSourcePath = null
        if (result == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }
        val uri: Uri = data.data!!
        try {
            contentResolver.openOutputStream(uri, "w").use { output ->
                requireNotNull(output) { "Could not open destination." }
                FileInputStream(requireNotNull(sourcePath)).use { input -> input.copyTo(output) }
                output.flush()
            }
            result.success(uri.toString())
        } catch (error: Exception) {
            result.error("save_failed", error.message, null)
        }
    }
}

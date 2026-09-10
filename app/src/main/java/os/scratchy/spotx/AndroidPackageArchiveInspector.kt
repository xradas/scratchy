package os.scratchy.spotx

import android.content.ContentResolver
import android.content.pm.PackageManager
import android.os.Build
import os.scratchy.engine.Diagnostic
import os.scratchy.engine.InspectionResult
import os.scratchy.engine.TargetIdentity
import os.scratchy.engine.TargetPolicy
import java.io.File

/** Reads metadata from a disposable cache copy; the user-selected APK is never changed. */
class AndroidPackageArchiveInspector(
    private val contentResolver: ContentResolver,
    private val packageManager: PackageManager,
    private val cacheDirectory: File,
    private val policy: TargetPolicy,
) {
    fun inspect(uri: android.net.Uri): InspectionResult {
        val archive = File.createTempFile("scratchy-inspect-", ".apk", cacheDirectory)
        return try {
            contentResolver.openInputStream(uri)?.use { input -> archive.outputStream().use(input::copyTo) }
                ?: return InspectionResult.Rejected(Diagnostic("unreadable-input", "Scratchy could not open the selected file."))
            val info = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageArchiveInfo(archive.path, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION") packageManager.getPackageArchiveInfo(archive.path, 0)
            } ?: return InspectionResult.Rejected(Diagnostic("invalid-apk", "The selected file is not a readable APK."))
            policy.evaluate(TargetIdentity(info.packageName, info.versionName ?: "unknown", if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()))
        } catch (error: Exception) {
            InspectionResult.Rejected(Diagnostic("inspection-failed", error.message ?: "APK inspection failed."))
        } finally {
            archive.delete()
        }
    }
}

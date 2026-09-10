package os.scratchy.spotx

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.Security
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import os.scratchy.engine.InspectionResult
import os.scratchy.engine.TargetPolicy

private val Ink = Color(0xFF101114)
private val Lime = Color(0xFFCBFF46)
private val Panel = Color(0xFF202329)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ScratchyApp() }
    }
}

@Composable
private fun ScratchyApp() {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var result by remember { mutableStateOf<InspectionResult?>(null) }
    var inspecting by remember { mutableStateOf(false) }
    val picker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        inspecting = true
        scope.launch {
            result = withContext(Dispatchers.IO) {
                AndroidPackageArchiveInspector(
                    context.contentResolver,
                    context.packageManager,
                    context.cacheDir,
                    TargetPolicy(setOf("com.spotify.music")),
                ).inspect(uri)
            }
            inspecting = false
        }
    }
    MaterialTheme(colorScheme = darkColorScheme(primary = Lime, surface = Panel, background = Ink)) {
        Scaffold(containerColor = Ink) { inset ->
            Column(Modifier.fillMaxSize().padding(inset).padding(24.dp), verticalArrangement = Arrangement.spacedBy(18.dp)) {
                Text("scratchy", style = MaterialTheme.typography.displaySmall, fontWeight = FontWeight.Bold, color = Color.White)
                Text("SpotX for Android", color = Lime, style = MaterialTheme.typography.titleMedium)
                Text("Inspect an APK before any transformation. The original file is never changed.", color = Color.LightGray)
                Surface(color = Panel, modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                        Icon(Icons.Default.Security, null, tint = Lime)
                        Text("APK inspection", color = Color.White, fontWeight = FontWeight.SemiBold)
                        when (val current = result) {
                            is InspectionResult.Identified -> Text("Found ${current.target.packageName} ${current.target.versionName} (${current.target.versionCode}). No patches are enabled yet.", color = Lime)
                            is InspectionResult.Rejected -> Text(current.diagnostic.message, color = Color(0xFFFFB4AB))
                            null -> Text("Choose an APK to inspect its package name and version.", color = Color.LightGray)
                        }
                        Button(enabled = !inspecting, onClick = { picker.launch(arrayOf("application/vnd.android.package-archive")) }) {
                            Icon(Icons.Default.FolderOpen, null)
                            Spacer(Modifier.width(8.dp))
                            Text(if (inspecting) "Inspecting…" else "Select APK")
                        }
                    }
                }
                Text("Pipeline", color = Lime, fontWeight = FontWeight.SemiBold)
                listOf("Inspect package and version", "Reject unknown targets", "Evaluate compatible benign patches", "Validate result and report diagnostics").forEachIndexed { index, step ->
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("0${index + 1}", color = Lime, modifier = Modifier.width(42.dp), fontWeight = FontWeight.Bold)
                        Text(step, color = Color.White)
                    }
                }
            }
        }
    }
}

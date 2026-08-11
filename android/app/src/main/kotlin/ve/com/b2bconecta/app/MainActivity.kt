package ve.com.b2bconecta.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    // Con launchMode=singleTop, el intent nuevo debe propagarse al plugin app_links.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
    }
}

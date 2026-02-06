package by.schools.chetverka

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import by.schools.chetverka.ui.AppRoot
import by.schools.chetverka.ui.AppViewModel
import by.schools.chetverka.ui.theme.ChetverkaTheme

class MainActivity : ComponentActivity() {

    private val viewModel: AppViewModel by viewModels {
        AppViewModel.provideFactory(applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            ChetverkaTheme {
                AppRoot(viewModel = viewModel)
            }
        }
    }
}

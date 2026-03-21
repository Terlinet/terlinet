package com.example.terlinet

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.terlinet.api.QueryRequest
import com.example.terlinet.api.TerlineTApi
import kotlinx.coroutines.launch

class MainActivity : ComponentActivity() {
    private val api = TerlineTApi.create()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            TerlineTScreen(api)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TerlineTScreen(api: TerlineTApi) {
    var textInput by remember { mutableStateOf("") }
    var responseText by remember { mutableStateOf("Aguardando sua pergunta...") }
    val scope = rememberCoroutineScope()
    var isLoading by remember { mutableStateOf(false) }

    Scaffold(
        topBar = { TopAppBar(title = { Text("TerlineT") }) }
    ) { padding ->
        Column(
            modifier = Modifier
                .padding(padding)
                .padding(16.dp)
                .fillMaxSize()
        ) {
            TextField(
                value = textInput,
                onValueChange = { textInput = it },
                label = { Text("O que deseja saber?") },
                modifier = Modifier.fillMaxWidth()
            )
            
            Spacer(modifier = Modifier.height(8.dp))
            
            Button(
                onClick = {
                    if (textInput.isNotBlank()) {
                        scope.launch {
                            isLoading = true
                            responseText = "Pensando..."
                            try {
                                val response = api.sendQuery(QueryRequest(textInput))
                                responseText = response
                            } catch (e: Exception) {
                                responseText = "Erro: ${e.message}"
                            } finally {
                                isLoading = false
                            }
                        }
                    }
                },
                enabled = !isLoading,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(if (isLoading) "Enviando..." else "Perguntar")
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Text(
                text = responseText,
                style = MaterialTheme.typography.bodyLarge
            )
        }
    }
}

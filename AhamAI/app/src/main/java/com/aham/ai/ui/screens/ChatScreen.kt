package com.aham.ai.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aham.ai.R
import com.aham.ai.data.FocusMode
import com.aham.ai.data.Message
import com.aham.ai.ui.components.MessageCard
import com.aham.ai.ui.components.SearchBar
import com.aham.ai.ui.components.SourceCard
import com.aham.ai.viewmodel.ChatViewModel
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatScreen(
    viewModel: ChatViewModel
) {
    val currentThread by viewModel.currentThread.collectAsStateWithLifecycle()
    val focusMode by viewModel.focusMode.collectAsStateWithLifecycle()
    val isLoading by viewModel.isLoading.collectAsStateWithLifecycle()
    val searchQuery by viewModel.searchQuery.collectAsStateWithLifecycle()
    
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    
    // Scroll to bottom when new messages are added
    LaunchedEffect(currentThread?.messages?.size) {
        currentThread?.messages?.let {
            if (it.isNotEmpty()) {
                coroutineScope.launch {
                    listState.animateScrollToItem(it.size - 1)
                }
            }
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
    ) {
        // Top Bar
        TopAppBar(
            title = {
                Text(
                    text = "AhamAI",
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
            },
            actions = {
                IconButton(onClick = { viewModel.createNewThread() }) {
                    Icon(
                        imageVector = Icons.Default.Add,
                        contentDescription = stringResource(R.string.new_thread)
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = MaterialTheme.colorScheme.surface
            )
        )

        // Main content
        Box(
            modifier = Modifier
                .fillMaxSize()
                .weight(1f)
        ) {
            if (currentThread == null || currentThread?.messages?.isEmpty() == true) {
                // Empty state with search
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = "Ask anything...",
                        style = MaterialTheme.typography.headlineMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    
                    Spacer(modifier = Modifier.height(32.dp))
                    
                    // Focus mode selector
                    FocusModeSelector(
                        selectedMode = focusMode,
                        onModeSelected = viewModel::setFocusMode
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Search bar
                    SearchBar(
                        query = searchQuery,
                        onQueryChange = viewModel::updateSearchQuery,
                        onSearch = {
                            viewModel.sendMessage(searchQuery)
                            viewModel.updateSearchQuery("")
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                    
                    Spacer(modifier = Modifier.height(24.dp))
                    
                    // Suggested queries
                    SuggestedQueries(
                        onQueryClick = { query ->
                            viewModel.sendMessage(query)
                        }
                    )
                }
            } else {
                // Chat messages
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    items(currentThread?.messages ?: emptyList()) { message ->
                        MessageCard(
                            message = message,
                            onSourceClick = { /* Handle source click */ },
                            onRelatedQuestionClick = { question ->
                                viewModel.sendMessage(question)
                            }
                        )
                    }
                    
                    // Loading indicator
                    if (isLoading) {
                        item {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .padding(vertical = 16.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                }
                
                // Floating search bar at bottom
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .background(
                            MaterialTheme.colorScheme.surface.copy(alpha = 0.95f)
                        )
                        .padding(16.dp)
                ) {
                    SearchBar(
                        query = searchQuery,
                        onQueryChange = viewModel::updateSearchQuery,
                        onSearch = {
                            viewModel.sendMessage(searchQuery)
                            viewModel.updateSearchQuery("")
                        },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }
        }
    }
}

@Composable
fun FocusModeSelector(
    selectedMode: FocusMode,
    onModeSelected: (FocusMode) -> Unit
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(horizontal = 16.dp)
    ) {
        items(FocusMode.values()) { mode ->
            FilterChip(
                selected = selectedMode == mode,
                onClick = { onModeSelected(mode) },
                label = { Text(mode.displayName) },
                leadingIcon = {
                    Icon(
                        imageVector = mode.icon,
                        contentDescription = mode.displayName,
                        modifier = Modifier.size(18.dp)
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                    selectedLeadingIconColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
    }
}

@Composable
fun SuggestedQueries(
    onQueryClick: (String) -> Unit
) {
    val suggestions = listOf(
        "What is Material Design 3?",
        "How to implement navigation in Jetpack Compose?",
        "Best practices for Android development",
        "Explain Kotlin coroutines"
    )
    
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        suggestions.forEach { suggestion ->
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onQueryClick(suggestion) },
                colors = CardDefaults.cardColors(
                    containerColor = MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Text(
                    text = suggestion,
                    modifier = Modifier.padding(16.dp),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}
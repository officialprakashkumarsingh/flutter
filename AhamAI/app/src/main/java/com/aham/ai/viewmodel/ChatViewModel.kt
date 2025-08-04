package com.aham.ai.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aham.ai.data.FocusMode
import com.aham.ai.data.Message
import com.aham.ai.data.Source
import com.aham.ai.data.Thread
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

class ChatViewModel : ViewModel() {
    private val _threads = MutableStateFlow<List<Thread>>(emptyList())
    val threads: StateFlow<List<Thread>> = _threads.asStateFlow()

    private val _currentThread = MutableStateFlow<Thread?>(null)
    val currentThread: StateFlow<Thread?> = _currentThread.asStateFlow()

    private val _focusMode = MutableStateFlow(FocusMode.ALL)
    val focusMode: StateFlow<FocusMode> = _focusMode.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _searchQuery = MutableStateFlow("")
    val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

    init {
        // Initialize with some sample threads
        val sampleThreads = listOf(
            Thread(
                title = "What is Jetpack Compose?",
                messages = listOf(
                    Message(
                        content = "What is Jetpack Compose?",
                        isUser = true
                    ),
                    Message(
                        content = "Jetpack Compose is Android's modern toolkit for building native UI. It simplifies and accelerates UI development on Android with less code, powerful tools, and intuitive Kotlin APIs.",
                        isUser = false,
                        sources = listOf(
                            Source(
                                title = "Android Developers",
                                url = "https://developer.android.com/jetpack/compose",
                                snippet = "Jetpack Compose is Android's recommended modern toolkit for building native UI."
                            )
                        ),
                        relatedQuestions = listOf(
                            "How to get started with Jetpack Compose?",
                            "What are the benefits of Jetpack Compose?",
                            "Jetpack Compose vs XML layouts"
                        )
                    )
                )
            )
        )
        _threads.value = sampleThreads
    }

    fun updateSearchQuery(query: String) {
        _searchQuery.value = query
    }

    fun setFocusMode(mode: FocusMode) {
        _focusMode.value = mode
    }

    fun sendMessage(content: String) {
        if (content.isBlank()) return

        viewModelScope.launch {
            val userMessage = Message(content = content, isUser = true)
            
            // Create new thread if none exists
            if (_currentThread.value == null) {
                val newThread = Thread(
                    title = content.take(50),
                    messages = listOf(userMessage)
                )
                _currentThread.value = newThread
                _threads.value = _threads.value + newThread
            } else {
                // Add message to current thread
                val updatedThread = _currentThread.value!!.copy(
                    messages = _currentThread.value!!.messages + userMessage,
                    updatedAt = System.currentTimeMillis()
                )
                _currentThread.value = updatedThread
                _threads.value = _threads.value.map { 
                    if (it.id == updatedThread.id) updatedThread else it 
                }
            }

            // Simulate AI response
            _isLoading.value = true
            delay(2000) // Simulate network delay

            val aiResponse = generateAIResponse(content)
            val updatedThreadWithResponse = _currentThread.value!!.copy(
                messages = _currentThread.value!!.messages + aiResponse,
                updatedAt = System.currentTimeMillis()
            )
            _currentThread.value = updatedThreadWithResponse
            _threads.value = _threads.value.map { 
                if (it.id == updatedThreadWithResponse.id) updatedThreadWithResponse else it 
            }
            _isLoading.value = false
        }
    }

    fun selectThread(thread: Thread) {
        _currentThread.value = thread
    }

    fun createNewThread() {
        _currentThread.value = null
        _searchQuery.value = ""
    }

    fun deleteThread(threadId: String) {
        _threads.value = _threads.value.filter { it.id != threadId }
        if (_currentThread.value?.id == threadId) {
            _currentThread.value = null
        }
    }

    private fun generateAIResponse(query: String): Message {
        // Simulate different responses based on focus mode
        val response = when (_focusMode.value) {
            FocusMode.ACADEMIC -> "Based on academic research, $query..."
            FocusMode.WRITING -> "From a writing perspective, $query..."
            FocusMode.WOLFRAM -> "According to mathematical analysis, $query..."
            FocusMode.YOUTUBE -> "Based on YouTube content, $query..."
            FocusMode.REDDIT -> "According to Reddit discussions, $query..."
            FocusMode.WIKIPEDIA -> "Wikipedia states that $query..."
            else -> "Here's what I found about $query..."
        }

        return Message(
            content = response,
            isUser = false,
            sources = listOf(
                Source(
                    title = "Example Source 1",
                    url = "https://example.com/1",
                    snippet = "This is a snippet from the source..."
                ),
                Source(
                    title = "Example Source 2",
                    url = "https://example.com/2",
                    snippet = "Another relevant snippet..."
                )
            ),
            relatedQuestions = listOf(
                "Tell me more about $query",
                "What are the alternatives?",
                "How does this compare to other options?"
            )
        )
    }
}
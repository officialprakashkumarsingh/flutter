package com.aham.ai.data

import java.util.UUID

data class Message(
    val id: String = UUID.randomUUID().toString(),
    val content: String,
    val isUser: Boolean,
    val timestamp: Long = System.currentTimeMillis(),
    val sources: List<Source> = emptyList(),
    val relatedQuestions: List<String> = emptyList(),
    val isLoading: Boolean = false
)

data class Source(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val url: String,
    val snippet: String,
    val favicon: String? = null
)
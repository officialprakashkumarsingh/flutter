package com.aham.ai.data

import java.util.UUID

data class Thread(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val messages: List<Message> = emptyList(),
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
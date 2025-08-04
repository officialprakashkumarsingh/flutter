package com.aham.ai.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.aham.ai.data.Message
import com.aham.ai.data.Source

@Composable
fun MessageCard(
    message: Message,
    onSourceClick: (Source) -> Unit,
    onRelatedQuestionClick: (String) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Message content
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = if (message.isUser) Arrangement.End else Arrangement.Start
        ) {
            if (!message.isUser) {
                // AI Avatar
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primaryContainer),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.AutoAwesome,
                        contentDescription = "AI",
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                }
                Spacer(modifier = Modifier.width(8.dp))
            }
            
            Card(
                modifier = Modifier.widthIn(max = 300.dp),
                shape = RoundedCornerShape(
                    topStart = if (message.isUser) 16.dp else 4.dp,
                    topEnd = if (message.isUser) 4.dp else 16.dp,
                    bottomStart = 16.dp,
                    bottomEnd = 16.dp
                ),
                colors = CardDefaults.cardColors(
                    containerColor = if (message.isUser) 
                        MaterialTheme.colorScheme.primary 
                    else 
                        MaterialTheme.colorScheme.surfaceVariant
                )
            ) {
                Text(
                    text = message.content,
                    modifier = Modifier.padding(12.dp),
                    color = if (message.isUser) 
                        MaterialTheme.colorScheme.onPrimary 
                    else 
                        MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            
            if (message.isUser) {
                Spacer(modifier = Modifier.width(8.dp))
                // User Avatar
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.secondaryContainer),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Person,
                        contentDescription = "User",
                        modifier = Modifier.size(20.dp),
                        tint = MaterialTheme.colorScheme.onSecondaryContainer
                    )
                }
            }
        }
        
        // Sources
        if (message.sources.isNotEmpty()) {
            Column(
                modifier = Modifier.padding(start = 40.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "Sources",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(message.sources) { source ->
                        SourceCard(
                            source = source,
                            onClick = { onSourceClick(source) }
                        )
                    }
                }
            }
        }
        
        // Related questions
        if (message.relatedQuestions.isNotEmpty()) {
            Column(
                modifier = Modifier.padding(start = 40.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = "Related",
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                message.relatedQuestions.forEach { question ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onRelatedQuestionClick(question) },
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surface
                        ),
                        border = CardDefaults.outlinedCardBorder()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = question,
                                style = MaterialTheme.typography.bodySmall,
                                modifier = Modifier.weight(1f)
                            )
                            Icon(
                                imageVector = Icons.Default.ArrowForward,
                                contentDescription = "Ask",
                                modifier = Modifier.size(16.dp),
                                tint = MaterialTheme.colorScheme.primary
                            )
                        }
                    }
                }
            }
        }
        
        // Action buttons for AI messages
        if (!message.isUser && !message.isLoading) {
            Row(
                modifier = Modifier.padding(start = 40.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                IconButton(
                    onClick = { /* Copy */ },
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.ContentCopy,
                        contentDescription = "Copy",
                        modifier = Modifier.size(18.dp)
                    )
                }
                IconButton(
                    onClick = { /* Share */ },
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Share,
                        contentDescription = "Share",
                        modifier = Modifier.size(18.dp)
                    )
                }
                IconButton(
                    onClick = { /* Regenerate */ },
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Refresh,
                        contentDescription = "Regenerate",
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}
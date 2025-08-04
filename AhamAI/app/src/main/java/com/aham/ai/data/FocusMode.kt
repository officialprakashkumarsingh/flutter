package com.aham.ai.data

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Calculate
import androidx.compose.material.icons.filled.Create
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.YouTube
import androidx.compose.ui.graphics.vector.ImageVector

enum class FocusMode(
    val displayName: String,
    val icon: ImageVector
) {
    ALL("All", Icons.Default.AllInclusive),
    ACADEMIC("Academic", Icons.Default.School),
    WRITING("Writing", Icons.Default.Create),
    WOLFRAM("Wolfram", Icons.Default.Calculate),
    YOUTUBE("YouTube", Icons.Default.YouTube),
    REDDIT("Reddit", Icons.Default.Forum),
    WIKIPEDIA("Wikipedia", Icons.Default.Book)
}
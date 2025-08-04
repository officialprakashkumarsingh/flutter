package com.aham.ai.navigation

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import com.aham.ai.ui.screens.ChatScreen
import com.aham.ai.ui.screens.DiscoverScreen
import com.aham.ai.ui.screens.LibraryScreen
import com.aham.ai.ui.screens.ProfileScreen
import com.aham.ai.viewmodel.ChatViewModel

sealed class Screen(val route: String) {
    object Chat : Screen("chat")
    object Library : Screen("library")
    object Discover : Screen("discover")
    object Profile : Screen("profile")
}

@Composable
fun AhamAINavHost(
    navController: NavHostController,
    viewModel: ChatViewModel,
    modifier: Modifier = Modifier
) {
    NavHost(
        navController = navController,
        startDestination = Screen.Chat.route,
        modifier = modifier
    ) {
        composable(Screen.Chat.route) {
            ChatScreen(viewModel = viewModel)
        }
        composable(Screen.Library.route) {
            LibraryScreen(
                threads = viewModel.threads.value,
                onThreadClick = { thread ->
                    viewModel.selectThread(thread)
                    navController.navigate(Screen.Chat.route)
                },
                onDeleteThread = { threadId ->
                    viewModel.deleteThread(threadId)
                }
            )
        }
        composable(Screen.Discover.route) {
            DiscoverScreen()
        }
        composable(Screen.Profile.route) {
            ProfileScreen()
        }
    }
}
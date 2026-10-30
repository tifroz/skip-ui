// Copyright 2026 Skip
// SPDX-License-Identifier: MPL-2.0
package skip.ui

import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetState
import androidx.compose.ui.MotionDurationScale
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.withContext

/**
 * Keeps programmatic sheet dismissal visible instead of using Material's fast effects timing.
 * Native SwiftUI's large sheet travels halfway in about 110 ms and 90% in about 240 ms,
 * regardless of the animation passed to withAnimation. Scaling Material's hide spring by
 * 3.5 approximates that travel without accessing its private animation specification.
 */
@OptIn(ExperimentalMaterial3Api::class)
internal suspend fun hideSheetWithTransition(sheetState: SheetState) {
    val inheritedScale = coroutineContext[MotionDurationScale]
    val dismissalScale = object : MotionDurationScale {
        // Read the inherited value throughout the animation, including system animation disablement.
        override val scaleFactor: Float
            get() = (inheritedScale?.scaleFactor ?: 1f) * 3.5f
    }
    withContext(dismissalScale) { sheetState.hide() }
}

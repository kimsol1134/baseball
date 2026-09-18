package com.solkim.baseball.application

/** Replay snapshots are optional; scorecards and career totals are never subject to this budget. */
public object AlbumReplayRetention {
    public const val PITCHES_PER_PAGE: Int = 128
    public const val TOTAL_PITCHES: Int = 512
    public const val TOTAL_TRAJECTORY_VALUES: Int = 65_536

    public fun isFull(pages: List<PlayerAlbumPage>, page: PlayerAlbumPage): Boolean =
        page.pitches.size >= PITCHES_PER_PAGE || pages.sumOf { it.pitches.size } >= TOTAL_PITCHES ||
            pages.sumOf { p -> p.pitches.sumOf { it.trajectory.size.toLong() } } >= TOTAL_TRAJECTORY_VALUES

    internal fun append(pages: List<PlayerAlbumPage>, page: PlayerAlbumPage, pitch: AlbumPitch): List<AlbumPitch> {
        if (page.pitches.any { it.id == pitch.id } || isFull(pages, page)) return page.pitches
        val values = pages.sumOf { p -> p.pitches.sumOf { it.trajectory.size.toLong() } }
        if (values + pitch.trajectory.size > TOTAL_TRAJECTORY_VALUES) return page.pitches
        // Existing replays, including over-budget imported saves, remain replayable unchanged.
        return page.pitches + pitch
    }
}

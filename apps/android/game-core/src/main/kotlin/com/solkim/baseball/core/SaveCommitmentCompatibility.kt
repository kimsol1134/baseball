package com.solkim.baseball.core

/**
 * State commitments are built from `toString()` in places, so a new data-class field would change
 * the hash of every save written before it existed. Fields added after the v9 Android save format
 * are erased from the commitment text while they hold their default value; a save that actually
 * uses them commits the new text. Tokens are long and specific, so player-authored strings
 * (names are capped well below their length) cannot collide with them.
 */
public object SaveCommitmentCompatibility {
    private val DEFAULT_TOKENS = listOf(
        ", regular=false, perfectReleases=0",
        ", perfectReleases=0",
        ", chapterGameClaimed=false",
        ", development=null",
        ", supportQueue=[]",
        ", assignment=null",
        ", trustReward=0",
    )

    public fun stable(text: String): String {
        var result = text
        for (token in DEFAULT_TOKENS) if (token in result) result = result.replace(token, "")
        return result
    }
}

package com.solkim.baseball.core.pro

import kotlin.math.max
import kotlin.math.min

public enum class ProTeamLegacyTier(public val wire: String) {
    NEW_FACE("new_face"),
    SUPPORTING_PILLAR("supporting_pillar"),
    CORE_PLAYER("core_player"),
    CLUB_ACE("club_ace"),
    CLUB_SYMBOL("club_symbol"),
    RETIRED_NUMBER_CANDIDATE("retired_number_candidate"),
}

/** iOS `ProTeamCareerRecordRules` / `ProTeamLegacyRules`. Version 1 is frozen. */
public object ProTeamLegacyRules {
    public fun score(record: ProTeamCareerRecord): Int = score(record, 1)

    public fun score(record: ProTeamCareerRecord, rulesVersion: Int): Int {
        if (rulesVersion >= 2) {
            val tenure = min(20, max(0, record.completedSeasons) * 2)
            val strikeouts = min(30, max(0, record.strikeouts) / 40)
            val workload = min(18, max(0, record.inningsOuts) / 200)
            val awards = min(20, max(0, record.awardCount) * 5)
            val continuity = min(8, max(0, record.consecutiveSeasons))
            val community = min(8, max(0, record.communityPoints))
            return min(100, tenure + strikeouts + workload + awards + continuity + community)
        }
        val tenure = min(40, max(0, record.completedSeasons) * 5)
        val strikeouts = min(25, max(0, record.strikeouts) / 40)
        val workload = min(15, max(0, record.inningsOuts) / 180)
        val awards = min(12, max(0, record.awardCount) * 4)
        val continuity = min(8, max(0, record.consecutiveSeasons))
        val community = min(8, max(0, record.communityPoints))
        return min(100, tenure + strikeouts + workload + awards + continuity + community)
    }

    public fun tier(record: ProTeamCareerRecord, rulesVersion: Int = 1): ProTeamLegacyTier {
        val value = score(record, rulesVersion)
        if (value >= 80 && record.completedSeasons >= 8) return ProTeamLegacyTier.RETIRED_NUMBER_CANDIDATE
        if (value >= 65 && record.completedSeasons >= 6) return ProTeamLegacyTier.CLUB_SYMBOL
        if (value >= 50 && record.completedSeasons >= 4) return ProTeamLegacyTier.CLUB_ACE
        if (value >= 35) return ProTeamLegacyTier.CORE_PLAYER
        if (value >= 15) return ProTeamLegacyTier.SUPPORTING_PILLAR
        return ProTeamLegacyTier.NEW_FACE
    }
}

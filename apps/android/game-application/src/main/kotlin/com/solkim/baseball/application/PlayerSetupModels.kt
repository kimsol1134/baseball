package com.solkim.baseball.application

/** Read-only setup choices exposed through the application boundary. */
public typealias SetupDifficulty = com.solkim.baseball.core.highschool.HighSchoolDifficulty
public typealias SetupSoulDomain = com.solkim.baseball.core.highschool.HighSchoolSoulDomain
public typealias SetupSoulBoost = com.solkim.baseball.core.highschool.HighSchoolSoulBoost
public typealias SetupPitch = com.solkim.baseball.core.pitch.PitchKind

/** iOS PitchLearningRules.recommendedSelection. Explicit player choices override these defaults. */
public object SetupRepertoire {
    public fun primary(preset: String): SetupPitch = when (preset) {
        "precision_commander" -> SetupPitch.CHANGEUP
        "breaking_ball_artist" -> SetupPitch.SLIDER
        else -> SetupPitch.FOUR_SEAM
    }
    public fun learning(preset: String): SetupPitch = when (preset) {
        "breaking_ball_artist" -> SetupPitch.CHANGEUP
        "innings_eater" -> SetupPitch.SLIDER
        else -> SetupPitch.CURVEBALL
    }
}

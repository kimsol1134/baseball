package com.solkim.baseball.application

/** Fictional staff identity is stable for the team and role, including after a restart. */
public object ProPeoplePresentation {
    public fun seed(team: String, role: String): String = "pro-staff:$team:$role"
    public fun styleKey(team: String, role: String): String = "android.pro.personality.$role.${Math.floorMod(team.hashCode(), 2)}"
    public fun name(team: String, role: String): String {
        val names = if (role == "catcher") listOf("배시온", "차이든", "문해솔", "류찬울") else listOf("한도윤", "서재온", "차윤재", "오태린")
        return names[Math.floorMod(team.hashCode(), names.size)]
    }
}

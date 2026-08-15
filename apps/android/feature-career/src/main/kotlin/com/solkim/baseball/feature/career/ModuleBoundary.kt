package com.solkim.baseball.feature.career

/** The Compose contract is fixture-complete; native production cutover remains explicitly off. */
public object CareerModuleBoundary {
    public const val productionEnabled: Boolean = false
    public const val fixtureComplete: Boolean = true
    public val requiredSurfaces: Set<String> = setOf("contract", "settlement", "investment", "retirement")
}

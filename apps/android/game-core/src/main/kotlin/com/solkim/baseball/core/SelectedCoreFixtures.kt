package com.solkim.baseball.core

/**
 * Stable primitive values copied from the checked-in C#/Swift translation fixtures.
 *
 * Pitch behavior is exercised by the complete, metadata-bearing oracle fixture and the
 * production-shaped [com.solkim.baseball.core.pitch.PitchKernel]. Keeping only primitive values
 * here prevents a second, stale 20-row gameplay table from becoming an accidental authority.
 */
public object SelectedCoreFixtures {
    public const val SWIFT_TRANSLATION_SOURCE_COMMIT: String =
        "fe7b585c32f5819dc4cd61dd16b92af46ee22b87"
    public const val PITCH_ORACLE_SOURCE_COMMIT: String =
        "23acbb8ec233836e802009c8852c430e08075d3c"
    public const val PITCH_ORACLE_SOURCE_SET_SHA256: String =
        "bdf4288abbc6dc81e96f8c725202af4e764bb293640e3fb0e3571abef182c76b"

    public val splitMix64: Map<ULong, List<ULong>> = mapOf(
        0UL to listOf(
            16294208416658607535UL,
            7960286522194355700UL,
            487617019471545679UL,
            17909611376780542444UL,
            1961750202426094747UL,
        ),
        1UL to listOf(
            10451216379200822465UL,
            13757245211066428519UL,
            17911839290282890590UL,
            8196980753821780235UL,
            8195237237126968761UL,
        ),
        ULong.MAX_VALUE to listOf(
            16490336266968443936UL,
            16834447057089888969UL,
            4048727598324417001UL,
            7862637804313477842UL,
            13015481187462834606UL,
        ),
    )

    public val stableHash: Map<String, String> = mapOf(
        "" to "cbf29ce484222325",
        "a" to "af63dc4c8601ec8c",
        "FourSeam" to "7303f86d3e687b93",
        "야구" to "e43442a27180caf1",
        "⚾️" to "765e83d3e7e11743",
    )

}

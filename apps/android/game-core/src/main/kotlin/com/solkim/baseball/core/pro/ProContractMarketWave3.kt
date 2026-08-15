package com.solkim.baseball.core.pro

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * Read-only Wave 3 market oracle types. The current Android ProState still has the legacy
 * contract shape, so these types are deliberately not embedded in ProState or Compose
 * projections. They keep the Swift fixture's persisted IDs and offer payload codec-ready for the
 * future Journey state migration.
 */
public enum class ProWave3MarketKind(public val wire: String) {
    RENEWAL("renewal"),
    FREE_AGENCY("free_agency"),
    ;

    public companion object {
        public fun fromWire(value: String): ProWave3MarketKind = entries.firstOrNull { it.wire == value }
            ?: error("pro.wave3.market.kind:$value")
    }
}

public enum class ProWave3ContractKind(public val wire: String) {
    RENEWAL_LONG("renewal_long"),
    PROVE_IT("prove_it"),
    FREE_AGENT("free_agent"),
    ;

    public companion object {
        public fun fromWire(value: String): ProWave3ContractKind = entries.firstOrNull { it.wire == value }
            ?: error("pro.wave3.offer.kind:$value")
    }
}

public data class ProWave3Expectation(
    val kind: String,
    val target: Int,
    val difficulty: String,
)

public data class ProWave3Offer(
    val id: String,
    val teamId: String,
    val years: Int,
    val annualSalary: Int,
    val signingBonus: Int?,
    val contractKind: ProWave3ContractKind,
    val rolePromise: ProRole,
    val outlook: String,
    val expectation: ProWave3Expectation,
    val preservesTeamLegacy: Boolean,
)

public data class ProWave3MarketFixtureRow(
    val seed: String,
    val kind: ProWave3MarketKind,
    val careerId: String,
    val forSeason: Int,
    val generatedAtRevision: ULong,
    val currentTeamId: String,
    val currentRole: ProRole,
    val level: ProLevel,
    val marketScore: Int,
    val serviceYears: Int,
    val age: Int,
    val maximumCareerSeasons: Int,
    val marketId: String,
    val offers: List<ProWave3Offer>,
)

/** Canonical row codec used by the Android fixture test only. */
public object ProContractMarketWave3Codec {
    public fun decodeRow(value: JsonValue.Obj): ProWave3MarketFixtureRow = ProWave3MarketFixtureRow(
        seed = value.string("seed"),
        kind = ProWave3MarketKind.fromWire(value.string("kind")),
        careerId = value.string("careerID"),
        forSeason = value.integer("forSeason"),
        generatedAtRevision = value.ulong("generatedAtRevision"),
        currentTeamId = value.string("currentTeamID"),
        currentRole = role(value.string("currentRole")),
        level = level(value.string("level")),
        marketScore = value.integer("marketScore"),
        serviceYears = value.integer("serviceYears"),
        age = value.integer("age"),
        maximumCareerSeasons = value.integer("maximumCareerSeasons"),
        marketId = value.string("marketID"),
        offers = value.array("offers").values.map { decodeOffer(it as? JsonValue.Obj ?: error("pro.wave3.offer.object")) },
    )

    public fun encodeRow(value: ProWave3MarketFixtureRow): JsonValue.Obj = obj(
        "seed" to JsonValue.Str(value.seed),
        "kind" to JsonValue.Str(value.kind.wire),
        "careerID" to JsonValue.Str(value.careerId),
        "forSeason" to JsonValue.Num(value.forSeason.toString()),
        "generatedAtRevision" to JsonValue.Num(value.generatedAtRevision.toString()),
        "currentTeamID" to JsonValue.Str(value.currentTeamId),
        "currentRole" to JsonValue.Str(value.currentRole.wire),
        "level" to JsonValue.Str(value.level.wire),
        "marketScore" to JsonValue.Num(value.marketScore.toString()),
        "serviceYears" to JsonValue.Num(value.serviceYears.toString()),
        "age" to JsonValue.Num(value.age.toString()),
        "maximumCareerSeasons" to JsonValue.Num(value.maximumCareerSeasons.toString()),
        "marketID" to JsonValue.Str(value.marketId),
        "offers" to JsonValue.Arr(value.offers.map(::encodeOffer)),
    )

    public fun canonicalRow(value: ProWave3MarketFixtureRow): String = StrictJson.canonical(encodeRow(value))

    private fun decodeOffer(value: JsonValue.Obj): ProWave3Offer {
        val expectation = value.obj("expectation")
        return ProWave3Offer(
            id = value.string("id"),
            teamId = value.string("teamID"),
            years = value.integer("years"),
            annualSalary = value.integer("annualSalary"),
            signingBonus = value.nullableInteger("signingBonus"),
            contractKind = ProWave3ContractKind.fromWire(value.string("contractKind")),
            rolePromise = role(value.string("rolePromise")),
            outlook = value.string("outlook"),
            expectation = ProWave3Expectation(
                kind = expectation.string("kind"),
                target = expectation.integer("target"),
                difficulty = expectation.string("difficulty"),
            ),
            preservesTeamLegacy = value.boolean("preservesTeamLegacy"),
        )
    }

    private fun encodeOffer(value: ProWave3Offer): JsonValue.Obj {
        val expectation = obj(
            "kind" to JsonValue.Str(value.expectation.kind),
            "target" to JsonValue.Num(value.expectation.target.toString()),
            "difficulty" to JsonValue.Str(value.expectation.difficulty),
        )
        return obj(
            "id" to JsonValue.Str(value.id),
            "teamID" to JsonValue.Str(value.teamId),
            "years" to JsonValue.Num(value.years.toString()),
            "annualSalary" to JsonValue.Num(value.annualSalary.toString()),
            "signingBonus" to (value.signingBonus?.let { JsonValue.Num(it.toString()) } ?: JsonValue.Null),
            "contractKind" to JsonValue.Str(value.contractKind.wire),
            "rolePromise" to JsonValue.Str(value.rolePromise.wire),
            "outlook" to JsonValue.Str(value.outlook),
            "expectation" to expectation,
            "preservesTeamLegacy" to JsonValue.Bool(value.preservesTeamLegacy),
        )
    }

    private fun role(value: String): ProRole = ProRole.entries.firstOrNull { it.wire == value }
        ?: error("pro.wave3.role:$value")

    private fun level(value: String): ProLevel = ProLevel.entries.firstOrNull { it.wire == value }
        ?: error("pro.wave3.level:$value")

    private fun obj(vararg fields: Pair<String, JsonValue>): JsonValue.Obj = JsonValue.Obj(linkedMapOf(*fields))

    private fun JsonValue.Obj.value(name: String): JsonValue = this[name] ?: error("pro.wave3.field:$name")
    private fun JsonValue.Obj.string(name: String): String = (value(name) as? JsonValue.Str)?.value ?: error("pro.wave3.string:$name")
    private fun JsonValue.Obj.integer(name: String): Int = stringNumber(name).toIntOrNull() ?: error("pro.wave3.integer:$name")
    private fun JsonValue.Obj.ulong(name: String): ULong = stringNumber(name).toULongOrNull() ?: error("pro.wave3.ulong:$name")
    private fun JsonValue.Obj.stringNumber(name: String): String = (value(name) as? JsonValue.Num)?.raw ?: error("pro.wave3.number:$name")
    private fun JsonValue.Obj.boolean(name: String): Boolean = (value(name) as? JsonValue.Bool)?.value ?: error("pro.wave3.boolean:$name")
    private fun JsonValue.Obj.nullableInteger(name: String): Int? = when (val item = value(name)) {
        JsonValue.Null -> null
        is JsonValue.Num -> item.raw.toIntOrNull() ?: error("pro.wave3.integer:$name")
        else -> error("pro.wave3.nullable_integer:$name")
    }
    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj = value(name) as? JsonValue.Obj ?: error("pro.wave3.object:$name")
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = value(name) as? JsonValue.Arr ?: error("pro.wave3.array:$name")
}

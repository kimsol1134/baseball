package com.solkim.baseball.application.fixtures

import com.solkim.baseball.application.CareerBackup
import com.solkim.baseball.model.JsonValue

/** Test-only access to the portable envelope; not part of the application API. */
public fun portableCareerFixture(payload: JsonValue.Obj): ByteArray = CareerBackup.encode(payload)

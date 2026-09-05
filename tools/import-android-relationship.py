#!/usr/bin/env python3
"""Import authored iOS relationship scenes without translating or changing game rules."""
from pathlib import Path
import json
import re
import sys

root = Path(__file__).resolve().parent.parent
source = (root / 'packages/simulation-core/Sources/SimulationCore/RelationshipVoiceCatalog.swift').read_text()
quoted = r'"((?:\\.|[^"\\])*)"'

def decode(value):
    value = re.sub(r'\\u\{([0-9a-fA-F]+)\}', lambda m: chr(int(m[1], 16)), value)
    return json.loads('"' + value + '"')

def kotlin(value):
    return json.dumps(value, ensure_ascii=False).replace('$', '\\$')

entries = []
for match in re.finditer(quoted + r': Scene\(', source):
    start = match.end()
    depth = 1
    i = start
    in_string = False
    while depth:
        c = source[i]
        if in_string and c == '\\':
            i += 2
            continue
        if c == '"': in_string = not in_string
        elif not in_string:
            if c == '(': depth += 1
            elif c == ')': depth -= 1
        i += 1
    body = source[start:i-1]
    speaker = re.search(r'speaker: \.(coach|catcher|rival|named)', body)[1]
    if speaker == 'named': speaker = decode(re.search(r'speaker: \.named\(' + quoted, body)[1])
    flat = re.search(r'quotes: flat\(' + quoted, body)
    quotes = {band: decode(value) for band, value in re.findall(r'\.(low|mid|high): ' + quoted, body)}
    if flat: quotes = dict.fromkeys(('low', 'mid', 'high'), decode(flat[1]))
    choices = re.findall(r'(listen|explain|challenge)\(' + quoted + r',\s*' + quoted + r'\)', body)
    assert len(choices) == 3, match[1]
    entries.append(f'        {kotlin(match[1])} to Scene({kotlin(speaker)}, listOf(' + ', '.join(kotlin(quotes.get(band, '')) for band in ('low', 'mid', 'high')) + '), listOf(\n' +
                   ',\n'.join('            Choice(' + kotlin(decode(title)) + ', ' + kotlin(decode(detail)) + ')' for _, title, detail in choices) + '\n        )),')

result = '''package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.*

/** Generated from RelationshipVoiceCatalog.swift by tools/import-android-relationship.py. */
public object RelationshipNarrative {
    public data class Choice(val title: String, val detail: String)
    public data class Scene(val speaker: String, val quotes: List<String>, val choices: List<Choice>)
    public fun scene(state: HighSchoolState): Scene? = state.currentRelationshipEvent?.let { scenes[it.id] ?: scenes[it.category] }
    public fun line(state: HighSchoolState): String {
        val scene = scene(state) ?: return state.currentRelationshipEvent?.summary.orEmpty()
        val trust = when(scene.speaker) { "coach" -> state.managerTrust; "catcher" -> state.catcherTrust; "rival" -> state.rivalTrust; else -> (state.managerTrust + state.catcherTrust + state.rivalTrust) / 3 }
        return scene.quotes[if (trust < 45) 0 else if (trust < 65) 1 else 2].ifBlank { state.currentRelationshipEvent?.summary.orEmpty() }
    }
    public fun speaker(state: HighSchoolState): String = when(val who = scene(state)?.speaker) {
        "coach" -> state.school?.coachName ?: "감독"
        "catcher" -> state.school?.catcherName ?: "포수"
        "rival" -> state.rival.name
        else -> who ?: "동료"
    }
    public fun choice(state: HighSchoolState, response: HighSchoolRelationshipResponse): Choice? = scene(state)?.choices?.get(response.ordinal)
    private val scenes = mapOf(
''' + '\n'.join(entries) + '\n    )\n}\n'
target = root / 'apps/android/game-application/src/main/kotlin/com/solkim/baseball/application/RelationshipNarrative.kt'
if '--check' in sys.argv:
    assert target.read_text() == result, 'Run tools/import-android-relationship.py'
else:
    target.write_text(result)
print(f'{len(entries)} relationship scenes imported')

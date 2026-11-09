"""Test public settings exports without reading live configuration files."""
import copy
import json
from pathlib import Path
import subprocess
import sys
import unittest

import tomlkit

ROOT = Path(__file__).resolve().parents[2]
BIN = ROOT / 'private_dot_local/bin'
FIXTURE = 'fixture-private-value'


def claude_filter(value):
    script = (BIN / 'executable_claude_settings_export.sh').read_text()
    program = script.split("JQ_PROGRAM='\n", 1)[1].split("\n'", 1)[0]
    result = subprocess.run(
        ['jq', '--arg', 'marker', '.local/bin/agent-hook', '--arg', 'home',
         '/fixture/home', program],
        input=json.dumps(value), text=True, capture_output=True, check=True,
    )
    return json.loads(result.stdout)


def codex_filter(value):
    script = (BIN / 'executable_codex_settings_export.sh').read_text()
    program = script.split("cat <<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
    return subprocess.run([sys.executable, '-c', program], input=value,
                          text=True, capture_output=True)


class ExportSecurityTests(unittest.TestCase):
    def setUp(self):
        self.claude = json.loads((ROOT / '.chezmoitemplates/claude-settings.json').read_text())
        self.codex = (ROOT / '.chezmoitemplates/codex-config.toml').read_text()

    def test_claude_preserves_preferences(self):
        self.assertEqual(claude_filter(self.claude), self.claude)

    def test_claude_omits_credentials(self):
        value = copy.deepcopy(self.claude)
        value['env'].update(ANTHROPIC_API_KEY=FIXTURE, ANTHROPIC_AUTH_TOKEN=FIXTURE)
        value['apiKeyHelper'] = FIXTURE
        value['futureCredentialSetting'] = {'value': FIXTURE}
        value['permissions']['futureCredentialSetting'] = FIXTURE
        value['modelSettings']['claude-sonnet-5']['apiKey'] = FIXTURE
        self.assertEqual(claude_filter(value), self.claude)

    def test_claude_omits_vendor_hooks_and_unknown_hook_fields(self):
        value = copy.deepcopy(self.claude)
        group = value['hooks']['Stop'][0]
        group['env'] = {'SECRET': FIXTURE}
        group['hooks'][0]['env'] = {'SECRET': FIXTURE}
        value['hooks']['Stop'].append({'hooks': [{'command': FIXTURE}]})
        self.assertEqual(claude_filter(value), self.claude)

    def test_codex_preserves_preferences(self):
        result = codex_filter(self.codex)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(tomlkit.parse(result.stdout).unwrap(), tomlkit.parse(self.codex).unwrap())

    def test_codex_omits_credentials_and_comments(self):
        value = tomlkit.parse(self.codex)
        value['model_providers'] = {'audit': {
            'experimental_bearer_token': FIXTURE,
            'http_headers': {'Authorization': FIXTURE},
        }}
        value['futureCredentialSetting'] = FIXTURE
        value['features']['futureCredentialSetting'] = FIXTURE
        next(iter(value['plugins'].values()))['token'] = FIXTURE
        value['desktop']['appearanceLightChromeTheme']['fonts']['apiKey'] = FIXTURE
        result = codex_filter(f'# {FIXTURE}\n' + tomlkit.dumps(value))
        self.assertEqual(result.returncode, 0)
        self.assertNotIn(FIXTURE, result.stdout)
        self.assertEqual(tomlkit.parse(result.stdout).unwrap(), tomlkit.parse(self.codex).unwrap())

    def test_codex_rejects_invalid_preference_types(self):
        value = tomlkit.parse(self.codex)
        value['model'] = {'token': FIXTURE}
        result = codex_filter(tomlkit.dumps(value))
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()

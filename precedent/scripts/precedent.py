#!/usr/bin/env python3
"""Local, dependency-free precedent retrieval. Never executes a recommendation."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import sys

VERSION = '1.0.0'
MAX_LINE = 4 * 1024 * 1024
MAX_TEXT = 4000
IDENTIFIER = re.compile(r'^[A-Za-z][A-Za-z0-9_.-]{0,79}$')
SECRET = re.compile(r'-----BEGIN .*PRIVATE KEY-----|\b(?:gh[pousr]_|github_pat_|sk-)[A-Za-z0-9_-]{12,}|'
                    r'\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b|'
                    r'(?i:\b(?:password|api[_ -]?key|access[_ -]?token|secret|authorization|cookie)\s*[:=]\s*\S+)')
GENERATED = re.compile(r'(?i)(^Task:|Subagent needs attention|Goal mission needs attention|'
                       r'You are reviving a previous subagent|<environment_context>|<permissions instructions>|'
                       r'Ignore (?:all |previous )?instructions|^The conversation history before this point was compacted|'
                       r'^<summary>|^\[Conversation (?:summary|history)\]|^\s*[❯$>]\s|^\s*\{)')
STOP = set('the a an to of in on for and or is are should we i you me my do which what how can use want please'.split())


def digest(text):
    return hashlib.sha256(text.encode('utf-8')).hexdigest()


def epoch(value):
    try:
        if isinstance(value, (int, float)) and not isinstance(value, bool):
            if not math.isfinite(value):
                raise ValueError('Timestamp must be finite')
            return float(value) / 1000 if value > 10**11 else float(value)
        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
        if dt.tzinfo is None:
            raise ValueError('Timestamp requires a timezone')
        return dt.timestamp()
    except (TypeError, AttributeError, OverflowError) as exc:
        raise ValueError('Invalid timestamp') from exc


def normalize_user(text):
    if not isinstance(text, str):
        return None
    # Expanded skill instructions are not the human's new message.
    if '</skill>' in text:
        text = text.rsplit('</skill>', 1)[-1]
    text = text.strip()
    if not text or len(text) > MAX_TEXT or SECRET.search(text) or GENERATED.search(text):
        return None
    return text


def text_content(content):
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ''
    return '\n'.join(b.get('text', '') for b in content if isinstance(b, dict) and b.get('type') in ('text', 'input_text'))


def header_info(provider, header):
    if provider == 'pi' and header.get('type') == 'session':
        if header.get('parentSession'):
            return None
        return {'session': str(header.get('id', '')), 'cwd': header.get('cwd', '')}
    if provider == 'codex' and header.get('type') == 'session_meta':
        p = header.get('payload', {})
        # Codex child origins are objects, rather than a human CLI/app origin.
        if isinstance(p.get('source'), dict) or 'subagent' in str(p.get('source', '')).lower():
            return None
        return {'session': str(p.get('id', '')), 'cwd': p.get('cwd', '')}
    return None


def message_info(provider, entry, line_no):
    if provider == 'pi' and entry.get('type') == 'message':
        msg = entry.get('message', {})
        if msg.get('role') != 'user' or msg.get('source') == 'extension':
            return None
        return str(entry.get('id', line_no)), entry.get('parentId'), entry.get('timestamp'), normalize_user(text_content(msg.get('content')))
    if provider == 'codex' and entry.get('type') == 'response_item':
        msg = entry.get('payload', {})
        if msg.get('type') != 'message' or msg.get('role') != 'user':
            return None
        # Codex entries have no stable message id in some versions; byte position
        # and line number remain part of the exact source reference.
        return str(msg.get('id', f'line-{line_no}')), None, entry.get('timestamp'), normalize_user(text_content(msg.get('content')))
    return None


def repo_name(cwd):
    parts = str(cwd).replace('\\', '/').rstrip('/').split('/')
    return '/'.join(parts[-2:]) if len(parts) >= 3 else ''


def verify_source(row):
    """Re-read one source entry, not the whole transcript, before exposing it."""
    try:
        with Path(row['path']).open('rb') as f:
            first = f.readline(MAX_LINE + 1)
            if digest(first.decode('utf-8')) != row['header_digest']:
                return False
            if not header_info(row['provider'], json.loads(first)):
                return False
            f.seek(row['offset'])
            raw = f.read(row['length'])
        msg = message_info(row['provider'], json.loads(raw), row['line'])
        return bool(msg and msg[3] and msg[0] == row['entry_id'] and msg[1] == row['parent_id']
                    and msg[2] == row['timestamp'] and digest(msg[3]) == row['digest'])
    except (OSError, ValueError, UnicodeError, KeyError):
        return False


class Store:
    def __init__(self, root):
        self.root = Path(root).expanduser().resolve()
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        if os.name != 'nt':
            self.root.chmod(0o700)
        self.db = sqlite3.connect(self.root / 'index.sqlite3', timeout=10)
        self.db.row_factory = sqlite3.Row
        version = self.db.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0, 1):
            self.db.close()
            raise ValueError('Unsupported precedent database version')
        self.db.executescript('''
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS files(path TEXT PRIMARY KEY, provider TEXT, size INTEGER, mtime INTEGER);
            CREATE TABLE IF NOT EXISTS messages(
                id TEXT UNIQUE, provider TEXT, path TEXT, session TEXT, entry_id TEXT, parent_id TEXT,
                repository TEXT, timestamp TEXT, time REAL, text TEXT, digest TEXT, trust TEXT,
                offset INTEGER, length INTEGER, line INTEGER, header_digest TEXT);
            CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(text, content=messages, content_rowid=rowid);
            CREATE TRIGGER IF NOT EXISTS msg_ai AFTER INSERT ON messages BEGIN
                INSERT INTO messages_fts(rowid,text) VALUES(new.rowid,new.text); END;
            CREATE TRIGGER IF NOT EXISTS msg_ad AFTER DELETE ON messages BEGIN
                INSERT INTO messages_fts(messages_fts,rowid,text) VALUES('delete',old.rowid,old.text); END;
            CREATE TABLE IF NOT EXISTS decisions(id TEXT PRIMARY KEY, source_id TEXT, data TEXT);
            CREATE TABLE IF NOT EXISTS observations(id INTEGER PRIMARY KEY, data TEXT);
            PRAGMA user_version=1;
        ''')
        if os.name != 'nt':
            (self.root / 'index.sqlite3').chmod(0o600)

    def close(self):
        self.db.close()

    def counts(self):
        return {name: self.db.execute(f'SELECT count(*) FROM {name}').fetchone()[0]
                for name in ('files', 'messages', 'decisions', 'observations')}

    def curate(self, records):
        """Explicit source review only. Importing transcripts never calls this."""
        if not isinstance(records, list) or len(records) > 200:
            raise ValueError('Expected at most 200 reviewed records')
        if any(not isinstance(r, dict) or not IDENTIFIER.fullmatch(str(r.get('id', ''))) for r in records):
            raise ValueError('Invalid reviewed record or id')
        ids = [r['id'] for r in records]
        if len(set(ids)) != len(ids):
            raise ValueError('Duplicate decision ids')
        prepared = []
        existing = {r['id']: json.loads(r['data']) for r in self.db.execute('SELECT * FROM decisions')}
        incoming = {r['id']: r for r in records}
        for rec in records:
            if not isinstance(rec, dict) or not IDENTIFIER.fullmatch(str(rec.get('id', ''))):
                raise ValueError('Invalid decision id')
            for field in ('topic', 'decision', 'scope', 'source_id', 'source_sha256'):
                if not isinstance(rec.get(field), str) or not 1 <= len(rec[field]) <= 2000:
                    raise ValueError(f'Invalid {field}')
            if rec.get('verification') != 'source-reviewed' or rec.get('kind') not in ('preference', 'instruction', 'task_approval', 'correction'):
                raise ValueError('A record requires explicit source review and a valid kind')
            allowed = {'id', 'source_id', 'source_sha256', 'topic', 'decision', 'scope', 'kind',
                       'verification', 'exclusions', 'supersedes', 'scope_reason', 'outcome', 'reason'}
            if set(rec) - allowed:
                raise ValueError('Unknown reviewed-record field')
            for field in ('scope_reason', 'outcome', 'reason'):
                if field in rec and (not isinstance(rec[field], str) or len(rec[field]) > 2000):
                    raise ValueError(f'Invalid {field}')
            exclusions = rec.get('exclusions', [])
            if not isinstance(exclusions, list) or len(exclusions) > 8 or any(
                    not isinstance(x, str) or len(x) > 500 for x in exclusions):
                raise ValueError('Invalid exclusions')
            if SECRET.search(json.dumps(rec)):
                raise ValueError('Potential secret in reviewed record')
            row = self.db.execute('SELECT * FROM messages WHERE id=?', (rec['source_id'],)).fetchone()
            if not row or row['digest'] != rec['source_sha256'] or not verify_source(row):
                raise ValueError('Source missing, changed, or not an indexed user message')
            old = existing.get(rec['id'])
            if old and old != rec:
                raise ValueError('Decision ids are immutable; add a superseding record')
            supersedes = rec.get('supersedes', [])
            if not isinstance(supersedes, list) or len(supersedes) > 20 or rec['id'] in supersedes or any(
                    not isinstance(x, str) or not IDENTIFIER.fullmatch(x) for x in supersedes):
                raise ValueError('Invalid supersession')
            for id_ in supersedes:
                prior = incoming.get(id_) or existing.get(id_)
                if not prior or prior['scope'] != rec['scope'] or prior['topic'] != rec['topic']:
                    raise ValueError('Supersession must address the same topic and scope')
                prior_row = self.db.execute('SELECT time FROM messages WHERE id=?', (prior['source_id'],)).fetchone()
                if not prior_row or prior_row['time'] >= row['time']:
                    raise ValueError('Supersession must be strictly later')
            prepared.append((rec['id'], rec['source_id'], json.dumps(rec, ensure_ascii=False)))
        with self.db:
            self.db.executemany('INSERT OR IGNORE INTO decisions VALUES(?,?,?)', prepared)
        return {'curated': len(prepared), 'authority': 'not_granted_by_precedent'}


def index_files(store, files):
    result = {'indexed_files': 0, 'unchanged_files': 0, 'indexed_messages': 0,
              'excluded_files': 0, 'partial_files': 0, 'malformed_lines': 0, 'unreadable_files': 0}
    for provider, supplied in files:
        path = Path(supplied).resolve()
        try:
            before = path.stat()
            old = store.db.execute('SELECT * FROM files WHERE path=?', (str(path),)).fetchone()
            if old and old['size'] == before.st_size and old['mtime'] == before.st_mtime_ns:
                result['unchanged_files'] += 1
                continue
            rows = []
            with path.open('rb') as f:
                first = f.readline(MAX_LINE + 1)
                try:
                    header = json.loads(first)
                    info = header_info(provider, header)
                except (ValueError, UnicodeError):
                    info = None
                if not info:
                    result['excluded_files'] += 1
                else:
                    header_digest = digest(first.decode('utf-8'))
                    line_no = 1
                    while True:
                        offset = f.tell()
                        raw = f.readline(MAX_LINE + 1)
                        if not raw:
                            break
                        line_no += 1
                        if len(raw) > MAX_LINE:
                            while raw and not raw.endswith(b'\n'):
                                raw = f.readline(MAX_LINE + 1)
                            result['malformed_lines'] += 1
                            continue
                        if not raw.endswith(b'\n'):
                            result['partial_files'] += 1
                            break
                        try:
                            entry = json.loads(raw)
                            msg = message_info(provider, entry, line_no)
                            if not msg or not msg[3]:
                                continue
                            id_, parent, timestamp, text = msg
                            time = epoch(timestamp)
                        except (ValueError, UnicodeError, TypeError, AttributeError):
                            result['malformed_lines'] += 1
                            continue
                        source_id = provider + ':' + digest(f'{path}:{id_}')[:24]
                        rows.append((source_id, provider, str(path), info['session'], id_, parent,
                                     repo_name(info['cwd']), timestamp, time, text, digest(text), 'candidate',
                                     offset, len(raw), line_no, header_digest))
            after = path.stat()
            # Do not commit a mixed snapshot; a later index pass can retry.
            if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
                result['partial_files'] += 1
                continue
            with store.db:
                store.db.execute('DELETE FROM messages WHERE path=?', (str(path),))
                store.db.executemany('INSERT OR IGNORE INTO messages VALUES(' + ','.join('?' * 16) + ')', rows)
                store.db.execute('INSERT OR REPLACE INTO files VALUES(?,?,?,?)',
                                 (str(path), provider, after.st_size, after.st_mtime_ns))
            result['indexed_files'] += 1
            result['indexed_messages'] += len(rows)
        except OSError:
            result['unreadable_files'] += 1
    return result


def tokens(text):
    return list(dict.fromkeys(t.lower() for t in re.findall(r'[A-Za-z0-9_]{2,40}', text) if t.lower() not in STOP))[:24]


def public_source(row):
    return {k: row[k] for k in ('id', 'provider', 'path', 'session', 'entry_id', 'parent_id',
                                'repository', 'timestamp', 'line', 'digest', 'trust', 'text')}


def validate_request(req):
    if not isinstance(req, dict) or not isinstance(req.get('question'), str) or not 1 <= len(req['question']) <= 2000:
        raise ValueError('Expected a bounded question')
    if SECRET.search(req['question']):
        raise ValueError('Do not submit secrets')
    if req.get('kind') not in ('fact', 'preference', 'design', 'scope', 'authority', 'human_action'):
        raise ValueError('Invalid decision kind')
    options = req.get('options')
    if not isinstance(options, list) or not 2 <= len(options) <= 8:
        raise ValueError('Supply two to eight options')
    ids = []
    for opt in options:
        if not isinstance(opt, dict) or not IDENTIFIER.fullmatch(str(opt.get('id', ''))):
            raise ValueError('Invalid option id')
        if not isinstance(opt.get('text'), str) or not 1 <= len(opt['text']) <= 500:
            raise ValueError('Invalid option text')
        ids.append(opt['id'])
    if len(set(ids)) != len(ids):
        raise ValueError('Duplicate option ids')
    if not isinstance(req.get('repository', ''), str) or len(req.get('repository', '')) > 200:
        raise ValueError('Invalid repository')
    if req.get('before') is not None:
        epoch(req['before'])
    if SECRET.search(json.dumps(req)):
        raise ValueError('Do not submit secrets')
    proposal = req.get('proposal')
    if proposal is not None:
        if not isinstance(proposal, dict) or proposal.get('option_id') not in ids:
            raise ValueError('Proposal must select a supplied option')
        if not isinstance(proposal.get('evidence_ids'), list) or not 1 <= len(proposal['evidence_ids']) <= 5:
            raise ValueError('Proposal requires one to five reviewed evidence ids')
        if not isinstance(proposal.get('rationale'), str) or not 1 <= len(proposal['rationale']) <= 1000:
            raise ValueError('Proposal requires a bounded rationale')


def resolve(store, req):
    validate_request(req)
    cutoff = epoch(req['before']) if req.get('before') else datetime.now(timezone.utc).timestamp()
    repository = req.get('repository', '')
    words = tokens(req['question'] + ' ' + ' '.join(o['text'] for o in req['options']))
    warnings = []
    eligible = []
    for saved in store.db.execute('SELECT * FROM decisions'):
        rec = json.loads(saved['data'])
        row = store.db.execute('SELECT * FROM messages WHERE id=?', (saved['source_id'],)).fetchone()
        if not row or row['digest'] != rec['source_sha256'] or not verify_source(row):
            warnings.append('stale_source')
            continue
        if row['time'] >= cutoff or rec['scope'] not in ('*', repository):
            continue
        score = len(set(words) & set(tokens(rec['topic'] + ' ' + rec['decision'] + ' ' + row['text'])))
        eligible.append((rec, row, score))
    superseded = {id_ for rec, _, _ in eligible for id_ in rec.get('supersedes', [])}
    scoped_topics = {rec['topic'] for rec, _, _ in eligible if repository and rec['scope'] == repository}
    selected = [(rec, row, score) for rec, row, score in eligible if score and rec['id'] not in superseded
                and not (rec['scope'] == '*' and rec['topic'] in scoped_topics)]
    selected.sort(key=lambda x: (-x[2], -x[1]['time'], x[0]['id']))
    selected = selected[:5]
    decisions = [{**rec, 'source': public_source(row)} for rec, row, _ in selected]
    topics = {}
    for rec, _, _ in selected:
        topics.setdefault(rec['topic'], set()).add(rec['decision'])
    conflicts = sorted(topic for topic, values in topics.items() if len(values) > 1)
    candidates = []
    if words:
        query = ' OR '.join('"' + w + '"' for w in words)
        found = store.db.execute('''SELECT m.* FROM messages_fts f JOIN messages m ON m.rowid=f.rowid
            WHERE messages_fts MATCH ? AND m.time < ? AND m.repository IN ('', ?)
            ORDER BY bm25(messages_fts) LIMIT 24''', (query, cutoff, repository))
        seen = set()
        for row in found:
            if row['digest'] in seen or row['repository'] not in ('', repository) or not verify_source(row):
                continue
            seen.add(row['digest'])
            candidates.append(public_source(row))
            if len(candidates) == 5:
                break
    state = {'authority': 'needs_authority', 'human_action': 'needs_human'}.get(req['kind'], 'investigate')
    recommendation = None
    proposal = req.get('proposal')
    eligible_ids = {rec['id'] for rec in decisions if rec['kind'] != 'task_approval'}
    if proposal and req['kind'] in ('preference', 'design', 'scope'):
        if not conflicts and set(proposal['evidence_ids']) <= eligible_ids:
            recommendation = proposal
            state = 'shadow'
        else:
            warnings.append('unsupported_or_conflicting_proposal')
    result = {'version': VERSION, 'mode': 'shadow', 'state': state, 'recommendation': recommendation,
              'authority': 'not_granted_by_precedent', 'execute': False,
              'decisions': decisions, 'candidates': candidates, 'conflicts': conflicts,
              'warnings': sorted(set(warnings)),
              'next': 'Compare quoted evidence with current instructions. A shadow proposal does not change normal approval or decision gates.'}
    # Observations are never imported as human evidence. No private prompt/quote in telemetry.
    observation = {'at': datetime.now(timezone.utc).isoformat(), 'request_hash': digest(json.dumps(req, sort_keys=True)),
                   'state': state, 'option_id': proposal.get('option_id') if recommendation else None,
                   'evidence_ids': proposal.get('evidence_ids', []) if recommendation else [], 'mode': 'shadow'}
    with store.db:
        store.db.execute('INSERT INTO observations(data) VALUES(?)', (json.dumps(observation),))
        store.db.execute('DELETE FROM observations WHERE id NOT IN (SELECT id FROM observations ORDER BY id DESC LIMIT 2000)')
    return result


def discover(home):
    home = Path(home)
    for p in (home / '.pi/agent/sessions').glob('*/*.jsonl'):
        yield 'pi', p
    for root in (home / '.codex/sessions', home / '.codex/archived_sessions'):
        for p in root.rglob('*.jsonl'):
            yield 'codex', p


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state', default=os.environ.get('PRECEDENT_STATE', str(Path.home() / '.agents/precedent')))
    sub = parser.add_subparsers(dest='command', required=True)
    sub.add_parser('status')
    index = sub.add_parser('index')
    index.add_argument('--home', default=str(Path.home()))
    index.add_argument('--rebuild', action='store_true', help='Re-read sources after parser/filter updates; retain reviewed records')
    curate = sub.add_parser('curate')
    curate.add_argument('--file', required=True)
    sub.add_parser('resolve')
    args = parser.parse_args()
    store = Store(args.state)
    try:
        if args.command == 'status':
            output = {'version': VERSION, 'mode': 'shadow', 'state_directory': str(store.root), **store.counts()}
        elif args.command == 'index':
            if args.rebuild:
                with store.db:
                    store.db.execute('DELETE FROM files')
            output = {**index_files(store, discover(args.home)), **store.counts()}
        elif args.command == 'curate':
            output = store.curate(json.loads(Path(args.file).read_text(encoding='utf-8')))
        else:
            raw = sys.stdin.read(16001)
            if len(raw) > 16000:
                raise ValueError('Request exceeds 16000 characters')
            output = resolve(store, json.loads(raw))
        print(json.dumps(output, ensure_ascii=True))
    finally:
        store.close()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, sqlite3.Error) as error:
        # Do not dump requests, file content, or a secret-bearing traceback.
        print(json.dumps({'state': 'unavailable', 'execute': False, 'error': type(error).__name__}), file=sys.stderr)
        sys.exit(1)

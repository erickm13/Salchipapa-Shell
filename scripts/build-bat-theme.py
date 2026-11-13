#!/usr/bin/env python3
"""Build shell/themes/bat/gruvbox-salchipapa.tmTheme for bat (the theme apply-colors.sh uses with gruvbox).

Starts from bat's gruvbox-dark (shell/themes/bat/upstream/, see its README) and recolours its rules by category:
variables pink, symbols (punctuation, operators, brackets) orange, comments gray, keywords red,
command flags blue.
Identifiers without a scope (plain variables in Rust or Python) take the pink of `source`.

Also writes shell/themes/bat/syntaxes/ (bat's Bash syntax with a few more scopes; see build_syntaxes).

Usage: scripts/build-bat-theme.py   (then apply a theme again: apply-colors.sh rebuilds bat's cache)
"""
import plistlib
import re
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / "shell/themes/bat"
UP = DIR / "upstream"
SRC, OUT = UP / "gruvbox-dark.tmTheme", DIR / "gruvbox-salchipapa.tmTheme"
PINK, ORANGE, GRAY, RED, BLUE, GREEN = '#d3869b', '#fe8019', '#928374', '#fb4934', '#83a598', '#b8bb26'
FG, AQUA = '#ebdbb2', '#8ec07c'

def category(sel):
    parts = sel.split()
    last = parts[-1] if parts else ''
    if 'comment' in sel:
        return GRAY
    # command flags (-n, -la, --color) with their dash
    if last.startswith(('variable.parameter.option', 'punctuation.definition.parameter')):
        return BLUE
    if last.startswith('punctuation.definition.variable'):
        return PINK
    if last.startswith('punctuation.definition.string'):
        return GREEN  # as nvim: the quotes are part of the string
    if (last.startswith(('punctuation', 'meta.brace'))
            or (last.startswith('keyword.operator') and not last.startswith(('keyword.operator.word', 'keyword.operator.logical.python')))):
        return ORANGE
    if last.startswith(('keyword', 'storage')):
        return RED
    if (last.startswith(('variable', 'entity.name.variable'))
            and not last.startswith(('variable.function', 'variable.language', 'variable.other.constant', 'variable.import', 'variable.package', 'variable.type', 'variable.other.class'))):
        return PINK
    return None

t = plistlib.load(open(SRC, 'rb'))
t['name'] = 'gruvbox-salchipapa'
t['comment'] = ('gruvbox-dark of bat (github.com/subnut/gruvbox-tmTheme, MIT, (c) 2020 Subhaditya Nath; '
                'based on morhetz/gruvbox) recoloured by Salchipapa-Shell: variables pink, symbols '
                'orange, comments gray, keywords red, flags blue.')
rules = []
for r in t['settings'][1:]:
    sels = [s.strip() for s in r.get('scope', '').replace('\n', ' ').split(',') if s.strip()]
    keep, moved = [], {}
    for s in sels:
        c = category(s)
        (keep.append(s) if c is None or c == r.get('settings', {}).get('foreground') else moved.setdefault(c, []).append(s))
    if keep or not sels:
        rules.append(dict(r, scope=', '.join(keep)) if sels else r)
    for c, ss in moved.items():
        st = dict(r.get('settings', {}), foreground=c)
        if c == GRAY: st['fontStyle'] = 'italic'
        rules.append({'name': f"{r.get('name') or 'rule'} (Salchipapa)", 'scope': ', '.join(ss), 'settings': st})
# fallbacks for scopes the theme never names
for name, scope, c in [
    ('symbols', 'punctuation, meta.brace, keyword.operator', ORANGE),
    ('keywords', 'keyword, storage', RED),
    ('variables', 'variable.other, variable.parameter, entity.name.variable', PINK),
    ('comments', 'comment', GRAY),
    ('flags', 'variable.parameter.option, punctuation.definition.parameter', BLUE),
    ('string quotes', 'string punctuation.definition.string', GREEN),
    # command arguments, as nvim's @variable.parameter (strings and variables inside keep theirs)
    ('command arguments', 'meta.function-call.arguments', BLUE),
]:
    rules.insert(1, {'name': f'Salchipapa fallback: {name}', 'scope': scope, 'settings': {'foreground': c}})
# Shell scripts like nvim's bash treesitter (gruvbox.nvim): at the end so they win the ties.
SHELL = [
    # nvim: `$`/`${` orange; the name pink (as its ALL_CAPS @constant; bat cannot tell the case)
    ('variable expansions ($x, ${x}, $1, $@)',
     'source.shell punctuation.definition.variable, '
     'source.shell punctuation.section.expansion.parameter, '
     'source.shell meta.group.expansion.parameter punctuation.section.expansion', ORANGE),
    # names as nvim: the rest cream, ALL_CAPS pink (@constant), bash's own orange (@variable.builtin)
    ('variable names', 'source.shell variable.other.readwrite, '
     'source.shell meta.group.expansion.parameter variable.other.readwrite', FG),
    ('constants (ALL_CAPS names, $@ $# $? $$ $!)', 'source.shell variable.other.constant, '
     'source.shell variable.other.readwrite variable.other.constant, source.shell variable.language', PINK),
    ('bash variables ($HOME, $PATH)', 'source.shell variable.other.builtin, '
     'source.shell variable.other.readwrite variable.other.builtin', ORANGE),
    ('commands and functions (sudo, mkdir, step)',  # nvim: Function = GruvboxGreenBold
     'source.shell variable.function, source.shell entity.name.function, '
     'source.shell meta.function entity.name.function, '
     'source.shell meta.function-call variable.function', GREEN, 'bold'),
    ('builtins (echo, set, cd, true, [ ])',
     'source.shell support.function, source.shell meta.function-call support.function, '
     'source.shell meta.function-call variable.function support.function', ORANGE, 'bold'),
    ('return, break, continue', 'source.shell keyword.control.flow, '
     'source.shell meta.function-call keyword.control.flow', ORANGE, 'bold'),
    # text inside ${...} that is not the name (the default in ${X:-...}): the string's green, as nvim
    ('${...} text inside strings', 'source.shell string meta.group.expansion.parameter', GREEN),
    # syntaxes/: nvim's @keyword.directive -> PreProc (aqua), still italic as a comment
    ('shebang', 'source.shell comment.line.shebang', AQUA, 'italic'),
    # syntaxes/: the first word of a case pattern list, then the others (s | si | yes)
    ('case patterns', 'source.shell string.unquoted.case.pattern', BLUE),
    ('case pattern, first word', 'source.shell string.unquoted.case.pattern.first', GREEN),
]
for name, scope, c, *style in SHELL:
    st = {'foreground': c, 'fontStyle': style[0] if style else ''}
    rules.append({'name': f'Salchipapa shell: {name}', 'scope': scope, 'settings': st})
t['settings'] = t['settings'][:1] + rules
# Plain text in nvim's cream (fg1 #ebdbb2) instead of the theme's fg0 (#fbf1c7)
for r in t['settings']:
    st = r.get('settings', {})
    for k in ('foreground', 'highlight', 'highlightForeground'):
        if st.get(k, '').lower() == '#fbf1c7':
            st[k] = '#ebdbb2'
t['settings'][0]['settings']['foreground'] = '#ebdbb2'
plistlib.dump(t, open(OUT, 'wb'))


# Bash's own variables, as nvim-treesitter's queries/bash/highlights.scm (@variable.builtin):
# names from the GNU Bash manual (Bourne Shell Variables + Bash Variables).
BASH_BUILTIN_VARS = """
    CDPATH HOME IFS MAIL MAILPATH OPTARG OPTIND PATH PS1 PS2 _ BASH BASHOPTS BASHPID
    BASH_ALIASES BASH_ARGC BASH_ARGV BASH_ARGV0 BASH_CMDS BASH_COMMAND BASH_COMPAT BASH_ENV
    BASH_EXECUTION_STRING BASH_LINENO BASH_LOADABLES_PATH BASH_REMATCH BASH_SOURCE BASH_SUBSHELL
    BASH_VERSINFO BASH_VERSION BASH_XTRACEFD CHILD_MAX COLUMNS COMP_CWORD COMP_LINE COMP_POINT
    COMP_TYPE COMP_KEY COMP_WORDBREAKS COMP_WORDS COMPREPLY COPROC DIRSTACK EMACS ENV
    EPOCHREALTIME EPOCHSECONDS EUID EXECIGNORE FCEDIT FIGNORE FUNCNAME FUNCNEST GLOBIGNORE
    GROUPS histchars HISTCMD HISTCONTROL HISTFILE HISTFILESIZE HISTIGNORE HISTSIZE
    HISTTIMEFORMAT HOSTFILE HOSTNAME HOSTTYPE IGNOREEOF INPUTRC INSIDE_EMACS LANG LC_ALL
    LC_COLLATE LC_CTYPE LC_MESSAGES LC_NUMERIC LC_TIME LINENO LINES MACHTYPE MAILCHECK MAPFILE
    OLDPWD OPTERR OSTYPE PIPESTATUS POSIXLY_CORRECT PPID PROMPT_COMMAND PROMPT_DIRTRIM PS0 PS3
    PS4 PWD RANDOM READLINE_ARGUMENT READLINE_LINE READLINE_MARK READLINE_POINT REPLY SECONDS
    SHELL SHELLOPTS SHLVL SRANDOM TIMEFORMAT TMOUT TMPDIR UID
""".split()


def build_syntaxes():
    """Copies of bat's Bash syntaxes, patched:
    - numbers in command arguments are constant.numeric (return 1, -eq 0, sleep 0.5),
    - true/false are builtins (as `:`),
    - in case patterns the first word is scoped apart from the rest (nvim: green / blue).
    Both get their own scope names (*.salchipapa) so they include each other and not bat's
    built-in copies; the theme matches them through `source.shell`.
    """
    NUM = "'(?<![^\\s=(\\[])-?[0-9]+(?:\\.[0-9]+)?(?=$|[\\s;|&)\\]])'"
    BASH, BUILTIN = 'source.shell.bash', 'commands.builtin.shell.bash'
    NEW_BASH, NEW_BUILTIN = BASH + '.salchipapa', BUILTIN + '.salchipapa'

    s = open(UP / 'Bash.sublime-syntax').read()
    def add(anchor, indent):
        nonlocal s
        assert s.count(anchor) == 1, anchor
        s = s.replace(anchor, anchor + f"{indent}- match: {NUM}\n{indent}  scope: constant.numeric.integer.decimal.shell\n")
    add("  cmd-args-common:\n", "    ")
    add("  cmd-test-double-brace-args:\n    - meta_scope: meta.function-call.arguments.shell\n", "    ")
    add("  cmd-test-double-brace-args-bt:\n    - meta_scope: meta.function-call.arguments.shell\n", "    ")
    # Variable names as nvim (variable_name): bash's own -> builtin, ALL_CAPS -> constant, the rest
    # stays readwrite. In $name, ${name...} and name=.
    builtin = '(?:' + '|'.join(sorted(BASH_BUILTIN_VARS, key=len, reverse=True)) + ')'
    caps = '[A-Z][A-Z_0-9]*'
    end = '(?![[:alnum:]_])'
    # $1, $0: plain names in nvim (@variable); $@ $# $? $$ $! are variable.language (@constant)
    old = "    - match: (\\$)({{identifier}})\n"
    assert s.count(old) == 1
    s = s.replace(old, "".join(
        f"    - match: '(\\$)({pat}){end}'\n      captures:\n        0: meta.group.expansion.parameter.shell\n"
        f"        1: punctuation.definition.variable.shell\n        2: {sc}\n"
        for pat, sc in ((builtin, 'variable.other.builtin.shell'), (caps, 'variable.other.constant.shell'))) + old)
    # ${name...}: the name right after `${`, `${!` or `${#`
    old = "    - include: expansion-parameter-common\n"
    anchor = ("  expansion-parameter-post-first-character:\n    - meta_content_scope:\n"
              "        meta.group.expansion.parameter.shell\n        variable.other.readwrite.shell\n")
    assert s.count(anchor + old) == 1
    # only the name is a variable, not the rest (${X:-$HOME/default} keeps the string colour)
    new_anchor = anchor.replace("        variable.other.readwrite.shell\n", "")
    s = s.replace(anchor + old, new_anchor + "".join(
        f"    - match: '(?<=\\{{|\\{{!|\\{{#){pat}{end}'\n      scope: {sc}\n"
        for pat, sc in ((builtin, 'variable.other.builtin.shell'), (caps, 'variable.other.constant.shell'),
                        ('[[:alpha:]_][[:alnum:]_]*', 'variable.other.readwrite.shell'))) + old)
    # name= (assignments, local/export/declare)
    old = ("        - meta_content_scope: variable.other.readwrite.assignment.shell\n"
           "        - include: line-continuation-or-pop-at-end\n")
    assert s.count(old) == 1
    s = s.replace(old, old + "".join(
        f"        - match: '(?<![[:alnum:]_]){pat}{end}'\n          scope: {sc}\n"
        for pat, sc in ((builtin, 'variable.other.builtin.shell'), (caps, 'variable.other.constant.shell'))))
    # Job specs (%1, %+, %ce) only at the start of a word: `date +%Y%m%d` is an argument, not jobs
    i = s.index("  expansion-job:\n"); j = s.index("\n\n\n", i)
    job = s[i:j]
    assert job.count("    - match: (%)") == 3 and job.count("    - match: '%'") == 1
    job = job.replace("    - match: (%)", "    - match: (?<![^\\s])(%)").replace("    - match: '%'", "    - match: '(?<![^\\s])%'")
    s = s[:i] + job + s[j:]
    # Shebang (#!/usr/bin/env bash) apart from the comments, as nvim (@keyword.directive)
    old = "  prototype:\n    - include: comment\n"
    assert s.count(old) == 1
    s = s.replace(old, "  prototype:\n    - match: '^#![ \\t]*/.*$'\n      scope: comment.line.shebang.shell\n"
                  "    - include: comment\n")
    # case patterns: the first word of each pattern list is scoped apart from the rest (nvim: green / blue)
    FIRST = ("  case-clause-first:\n"
             "    - match: '\\s*([^\\s|()$\"`\\\\*?\\[\\]]+)(?=\\s*[|)])'\n"
             "      captures:\n"
             "        1: string.unquoted.case.pattern.first.shell\n"
             "      pop: true\n"
             "    - match: ''\n"
             "      pop: true\n\n")
    for old, new in [
        ("          set: case-clause-patterns\n", "          set: [case-clause-patterns, case-clause-first]\n"),
        ("    - match: (?=\\S)\n      push: case-clause-patterns\n", "    - match: (?=\\S)\n      push: [case-clause-patterns, case-clause-first]\n"),
        ("  case-clause-patterns-body:\n", FIRST + "  case-clause-patterns-body:\n"),
        ("    - match: \\|\n      scope: keyword.operator.logical.shell\n    - match: \\(\n      scope: punctuation.section.parens.begin.shell\n",
         "    - match: \\|\n      scope: keyword.operator.logical.shell\n"
         "    - match: '[^\\s|()$\"`\\\\*?\\[\\]]+'\n      scope: string.unquoted.case.pattern.shell\n"
         "    - match: \\(\n      scope: punctuation.section.parens.begin.shell\n"),
    ]:
        assert s.count(old) == 1, old
        s = s.replace(old, new)
    assert s.count(f'\nscope: {BASH}\n') == 1
    s = s.replace(f'\nscope: {BASH}\n', f'\nscope: {NEW_BASH}\n')
    s = s.replace(f'scope:{BUILTIN}', f'scope:{NEW_BUILTIN}')
    s = s.replace(f'scope:{BASH}#', f'scope:{NEW_BASH}#')
    s = s.replace('name: Bourne Again Shell (bash)\n',
                  'name: Bourne Again Shell (bash)\n# Salchipapa-Shell: bat\'s Bash + numbers in command arguments\n', 1)
    open(DIR / 'syntaxes/Bash.sublime-syntax', 'w').write(s)

    b = open(UP / 'commands-builtin-shell-bash.sublime-syntax').read()
    assert b.count(f'\nscope: {BUILTIN}\n') == 1
    b = b.replace(f'\nscope: {BUILTIN}\n', f'\nscope: {NEW_BUILTIN}\n').replace(f'scope:{BASH}#', f'scope:{NEW_BASH}#')
    b = b.replace(f'scope:{BUILTIN}#', f'scope:{NEW_BUILTIN}#')
    # true and false as builtins (as `:`), so they take the builtin colour like in nvim
    for suffix in ('', '-bt'):
        old = ("  - match: '{{boundary_begin}}:{{boundary_end}}'\n"
               "    scope: meta.function-call.shell support.function.colon.shell\n"
               f"    set:\n    - scope:{NEW_BASH}#cmd-post\n    - cmd-args-colon{suffix}\n")
        assert b.count(old) == 1, suffix
        new = old + "".join(
            f"  - match: '{{{{boundary_begin}}}}{w}{{{{boundary_end}}}}'\n"
            f"    scope: meta.function-call.shell support.function.{w}.shell\n"
            f"    set:\n    - scope:{NEW_BASH}#cmd-post\n    - cmd-args-colon{suffix}\n" for w in ('true', 'false'))
        b = b.replace(old, new)
    open(DIR / 'syntaxes/commands-builtin-shell-bash.sublime-syntax', 'w').write(b)


build_syntaxes()

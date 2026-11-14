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
SRC = UP / "gruvbox-dark.tmTheme"

# Roles of each theme, as its nvim colorscheme paints them (gruvbox.nvim / solarized-osaka.nvim).
# Optional roles (string, function, type, constant, remap) only exist where the base theme's own
# colours don't fit: remap translates the base's leftover gruvbox colours to the theme.
GRUVBOX = dict(
    name='gruvbox-salchipapa', fg='#ebdbb2', comment='#928374', keyword='#fb4934', keyword_style=None,
    symbol='#fe8019', variable='#d3869b', flag='#83a598', quote='#b8bb26', command='#b8bb26',
    command_style='bold', builtin='#fe8019', flow='#fe8019', flow_style='bold', dollar='#fe8019',
    shell_name='#ebdbb2', shell_constant='#d3869b', shell_builtin_var='#fe8019',
    expansion_string='#b8bb26', shebang='#8ec07c', case_rest='#83a598', case_first='#b8bb26',
    description='variables pink, symbols orange, comments gray, keywords red, flags blue')
SOLARIZED = dict(
    name='solarized-salchipapa', fg='#b6c5c6', comment='#7b99a2', keyword='#a2bb00',
    keyword_style='bold italic', symbol='#a2bb00', variable='#b6c5c6', flag='#fb724a',
    quote='#34c5b9', command='#5aaefa', command_style='', builtin='#fb724a', flow='#fb724a',
    flow_style='', dollar='#fb724a', shell_name='#b6c5c6', shell_constant='#34c5b9',
    shell_builtin_var='#fb724a', shell_special='#fb724a', bracket='#fb724a',
    expansion_string='#34c5b9', shebang='#ff6c6a', case_rest='#fb724a',
    case_first='#34c5b9', string='#34c5b9', function='#5aaefa', type='#dba500', constant='#34c5b9',
    remap={'#b8bb26': '#a2bb00', '#98971a': '#a2bb00', '#fabd2f': '#dba500', '#d79921': '#dba500',
           '#d3869b': '#34c5b9', '#b16286': '#34c5b9', '#83a598': '#5aaefa', '#458588': '#5aaefa',
           '#8ec07c': '#5aaefa', '#689d6a': '#5aaefa', '#fe8019': '#fb724a', '#d65d0e': '#fb724a',
           '#fb4934': '#ff6c6a', '#cc241d': '#ff6c6a', '#fbf1c7': '#c2cdcd', '#ebdbb2': '#b6c5c6',
           '#d5c4a1': '#b6c5c6', '#bdae93': '#a0b4b6', '#a89984': '#a0b4b6', '#928374': '#7b99a2',
           '#7c6f64': '#7b99a2', '#665c54': '#063540', '#504945': '#063540', '#3c3836': '#002c38',
           '#32302f': '#002c38', '#282828': '#001419', '#1d2021': '#001419', '#1b1b1b': '#001419',
           '#3a3a3a': '#002c38'},
    description='as solarized-osaka.nvim (vivid): keywords green, commands blue, strings cyan, '
                'parameters orange, comments gray')

BLUR = dict(
    name='gentleman-kanagawa-blur-salchipapa', fg='#f3f6f9', comment='#8394a3', keyword='#c99ad6',
    keyword_style='', symbol='#deba87', bracket='#8aa6c1', variable='#c4746e', flag='#c7a8df',
    quote='#dfbd76', command='#b99bf2', command_style='', builtin='#8d9ef2', flow='#8d9ef2',
    flow_style='', dollar='#96a2b0', shell_name='#c4746e', shell_constant='#cb7c94',
    shell_builtin_var='#b6a6c8', shell_special='#cb7c94', expansion_string='#dfbd76',
    shebang='#c99ad6', case_rest='#c7a8df', case_first='#dfbd76', string='#dfbd76',
    function='#b99bf2', type='#8fb8dd', constant='#cb7c94',
    test_bracket='#8aa6c1', paren='#96a2b0', separator='#a3b5c1', number='#a4daa7',
    remap={'#b8bb26': '#b7cc85', '#98971a': '#b7cc85', '#fabd2f': '#e0c15a', '#d79921': '#e0c15a',
           '#d3869b': '#cb7c94', '#b16286': '#cb7c94', '#83a598': '#7fb4ca', '#458588': '#7fb4ca',
           '#8ec07c': '#b99bf2', '#689d6a': '#b99bf2', '#fe8019': '#deba87', '#d65d0e': '#deba87',
           '#fb4934': '#c4746e', '#cc241d': '#c4746e', '#fbf1c7': '#f3f6f9', '#ebdbb2': '#f3f6f9',
           '#d5c4a1': '#e0e2ea', '#bdae93': '#a3b5c1', '#a89984': '#a3b5c1', '#928374': '#8394a3',
           '#7c6f64': '#5c6170', '#665c54': '#232a40', '#504945': '#232a36', '#3c3836': '#191e28',
           '#32302f': '#191e28', '#282828': '#06080f', '#1d2021': '#06080f', '#1b1b1b': '#06080f',
           '#3a3a3a': '#191e28'},
    description='as gentleman-kanagawa-blur (nvim): keywords lilac, commands purple, strings gold, '
                'parameters light lilac, comments gray')


def build_theme(P):
    """bat's gruvbox-dark recoloured by role with palette P (see GRUVBOX / SOLARIZED)."""
    def category(sel):
        parts = sel.split()
        last = parts[-1] if parts else ''
        if 'comment' in sel:
            return 'comment'
        # command flags (-n, -la, --color) with their dash
        if last.startswith(('variable.parameter.option', 'punctuation.definition.parameter')):
            return 'flag'
        if last.startswith('punctuation.definition.variable'):
            return 'variable'
        if last.startswith('punctuation.definition.string'):
            return 'quote'  # as nvim: the quotes are part of the string
        if 'bracket' in P and (last.startswith(('meta.brace', 'punctuation.section', 'punctuation.definition.group',
                                                  'punctuation.definition.compound', 'punctuation.definition.array'))):
            return 'bracket'
        if (last.startswith(('punctuation', 'meta.brace'))
                or (last.startswith('keyword.operator') and not last.startswith(('keyword.operator.word', 'keyword.operator.logical.python')))):
            return 'symbol'
        if last.startswith(('keyword', 'storage')):
            return 'keyword'
        if (last.startswith(('variable', 'entity.name.variable'))
                and not last.startswith(('variable.function', 'variable.language', 'variable.other.constant', 'variable.import', 'variable.package', 'variable.type', 'variable.other.class'))):
            return 'variable'
        if 'string' in P and last.startswith('string'):
            return 'string'
        if 'function' in P and last.startswith(('entity.name.function', 'variable.function', 'meta.function-call')):
            return 'function'
        if 'type' in P and last.startswith(('entity.name.type', 'support.type', 'support.class', 'storage.type', 'entity.name.class')):
            return 'type'
        if 'constant' in P and last.startswith('constant'):
            return 'constant'
        return None

    t = plistlib.load(open(SRC, 'rb'))
    t['name'] = P['name']
    t['comment'] = ('gruvbox-dark of bat (github.com/subnut/gruvbox-tmTheme, MIT, (c) 2020 Subhaditya Nath; '
                    f'based on morhetz/gruvbox) recoloured by Salchipapa-Shell: {P["description"]}.')
    rules = []
    for r in t['settings'][1:]:
        sels = [s.strip() for s in r.get('scope', '').replace('\n', ' ').split(',') if s.strip()]
        keep, moved = [], {}
        for s in sels:
            role = category(s)
            c = P[role] if role else None
            (keep.append(s) if c is None or c == r.get('settings', {}).get('foreground') else moved.setdefault(role, []).append(s))
        if keep or not sels:
            rules.append(dict(r, scope=', '.join(keep)) if sels else r)
        for role, ss in moved.items():
            st = dict(r.get('settings', {}), foreground=P[role])
            if role == 'comment': st['fontStyle'] = 'italic'
            if role == 'keyword' and P.get('keyword_style') is not None: st['fontStyle'] = P['keyword_style']
            rules.append({'name': f"{r.get('name') or 'rule'} (Salchipapa)", 'scope': ', '.join(ss), 'settings': st})
    # fallbacks for scopes the theme never names
    for name, scope, role in [
        ('symbols', 'punctuation, meta.brace, keyword.operator', 'symbol'),
        ('keywords', 'keyword, storage', 'keyword'),
        ('variables', 'variable.other, variable.parameter, entity.name.variable', 'variable'),
        ('comments', 'comment', 'comment'),
        ('flags', 'variable.parameter.option, punctuation.definition.parameter', 'flag'),
        ('string quotes', 'string punctuation.definition.string', 'quote'),
        # command arguments, as nvim's @variable.parameter (strings and variables inside keep theirs)
        ('command arguments', 'meta.function-call.arguments', 'flag'),
    ]:
        rules.insert(1, {'name': f'Salchipapa fallback: {name}', 'scope': scope, 'settings': {'foreground': P[role]}})
    # Shell scripts like nvim's bash treesitter: at the end so they win the ties.
    SHELL = [
        # nvim: `$`/`${` Special; the name: ALL_CAPS @constant, bash's own @variable.builtin, the rest @variable
        ('variable expansions ($x, ${x}, $1, $@)',
         'source.shell punctuation.definition.variable, '
         'source.shell punctuation.section.expansion.parameter, '
         'source.shell meta.group.expansion.parameter punctuation.section.expansion', P['dollar']),
        ('variable names', 'source.shell variable.other.readwrite, '
         'source.shell meta.group.expansion.parameter variable.other.readwrite', P['shell_name']),
        ('constants (ALL_CAPS names, $@ $# $? $$ $!)', 'source.shell variable.other.constant, '
         'source.shell variable.other.readwrite variable.other.constant'
         + ('' if 'shell_special' in P else ', source.shell variable.language'), P['shell_constant']),
        *([('special variables ($@ $# $? $$ $!)', 'source.shell variable.language', P['shell_special'])]
          if 'shell_special' in P else []),
        ('bash variables ($HOME, $PATH)', 'source.shell variable.other.builtin, '
         'source.shell variable.other.readwrite variable.other.builtin', P['shell_builtin_var']),
        ('commands and functions (sudo, mkdir, step)',  # nvim: Function
         'source.shell variable.function, source.shell entity.name.function, '
         'source.shell meta.function entity.name.function, '
         'source.shell meta.function-call variable.function', P['command'], P['command_style']),
        ('builtins (echo, set, cd, true, [ ])',
         'source.shell support.function, source.shell meta.function-call support.function, '
         'source.shell meta.function-call variable.function support.function', P['builtin'], 'bold'),
        ('return, break, continue', 'source.shell keyword.control.flow, '
         'source.shell meta.function-call keyword.control.flow', P['flow'], P['flow_style']),
        # text inside ${...} that is not the name (the default in ${X:-...}): the string's colour, as nvim
        ('${...} text inside strings', 'source.shell string meta.group.expansion.parameter', P['expansion_string']),
        # syntaxes/: nvim's @keyword.directive, still italic as a comment
        ('shebang', 'source.shell comment.line.shebang', P['shebang'], 'italic'),
        # syntaxes/: the first word of a case pattern list, then the others (s | si | yes)
        ('case patterns', 'source.shell string.unquoted.case.pattern', P['case_rest']),
        ('case pattern, first word', 'source.shell string.unquoted.case.pattern.first', P['case_first']),
    ]
    # optional roles (only palettes whose nvim tells them apart)
    for role, scope in (('test_bracket', 'source.shell support.function.test, source.shell support.function.double-brace'),
                        ('paren', 'source.shell meta.group.expansion.command punctuation.section'),  # the ( ) of $( )
                        ('separator', 'source.shell keyword.operator.logical.continue, source.shell punctuation.terminator, '
                                      'source.shell keyword.operator.list'),
                        ('number', 'source.shell constant.numeric, source.shell meta.function-call.arguments constant.numeric')):
        if role in P:
            SHELL.append((role, scope, P[role]))
    if 'bracket' in P:
        SHELL.append(('brackets', 'source.shell punctuation.section, source.shell punctuation.definition.compound, '
                      'source.shell punctuation.definition.array, source.shell meta.brace', P['bracket']))
    for name, scope, c, *style in SHELL:
        st = {'foreground': c, 'fontStyle': style[0] if style else ''}
        rules.append({'name': f'Salchipapa shell: {name}', 'scope': scope, 'settings': st})
    t['settings'] = t['settings'][:1] + rules
    # Plain text in nvim's colour (gruvbox: fg1 #ebdbb2 instead of the theme's fg0 #fbf1c7)
    for r in t['settings']:
        st = r.get('settings', {})
        for k in ('foreground', 'highlight', 'highlightForeground'):
            if st.get(k, '').lower() == '#fbf1c7':
                st[k] = '#ebdbb2'
    t['settings'][0]['settings']['foreground'] = '#ebdbb2'
    # Other themes: the base's leftover gruvbox colours (global settings included) to the theme's
    remap = P.get('remap')
    if remap:
        for r in t['settings']:
            st = r.get('settings', {})
            for k, v in list(st.items()):
                if isinstance(v, str) and v[:7].lower() in remap:
                    st[k] = remap[v[:7].lower()] + v[7:]
        t['settings'][0]['settings']['foreground'] = P['fg']
    plistlib.dump(t, open(DIR / f"{P['name']}.tmTheme", 'wb'))


for _palette in (GRUVBOX, SOLARIZED, BLUR):
    build_theme(_palette)

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
    # Builtins anywhere a command name goes (inside $( ) bat only knew them at the start of a
    # statement: `$(cmd || true)` and `x="$(pwd)"` came out as plain commands). nvim: @function.builtin
    builtins = ('alias bg bind builtin caller cd command compgen complete declare dirs disown echo enable eval '
                'exec exit export false fc fg getopts hash help history jobs kill let local logout mapfile '
                'popd printf pushd pwd read readarray readonly set shift shopt source suspend test times '
                'trap true type typeset ulimit umask unalias unset wait').split()
    for ctx, end in (('cmd-name', '{{is_start_of_arguments}}|{{is_end_of_interpolation}}'),
                     ('cmd-name-bt', '{{is_start_of_arguments}}|{{is_end_of_interpolation}}|`')):
        old = f"  {ctx}:\n    - match: \"\"\n"
        assert s.count(old) == 1, ctx
        s = s.replace(old, f"  {ctx}:\n    - match: '(?:{'|'.join(builtins)})(?={end})'\n"
                           f"      scope: meta.function-call.shell support.function.shell\n      pop: true\n" + old.split('\n', 1)[1])
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

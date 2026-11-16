# xymon-plugins specification

The rules of the plugin model: what a plugin is, where its files go, how it
is installed, updated and removed, and what the administrator can count on.

Every numbered rule is enforced by a test: each test that checks a rule cites
it as `[S<n>]` in an assertion's message, and `tests/compat/spec-rules.sh`
fails when a rule is cited by no test, or a test cites a rule this file does
not number. That test prints which tests check each rule. A rule is numbered
in the pull request that brings its test; until then it is under Planned.
Numbers are not reused. A rule changes through a pull request to this file.

How a change is made and reviewed, and how versions move, is in
`CONTRIBUTING.md`; how to install and use the plugins, in `README.md` and
`plugins/README.md`. This file holds the guarantees those pages describe.

## Goal

An administrator adds a plugin to Xymon, switches it on, updates it and
takes it away again, the same way for every plugin, and never ends up with a
Xymon that runs, reads or serves something of a plugin that is gone.

## Principles

Where the rules lead; the rules say what holds today, Planned what is still
to come.

- **A plugin lives in its directory.** Everything a plugin installs is under
  its directory: `$XYMONHOME/ext/NAME/` on the Xymon server, the client's
  `ext/NAME/` on a monitored host, `$PREFIX/libexec/xymon-plugins/NAME/` on
  your own machine. What another program must find elsewhere -- a task, a
  setting, a manual page, a web server snippet -- is a link into that
  directory, or a file that program reads only when it exists.
- **Removing the directory removes the plugin.** Deleting an `ext/NAME`
  directory by hand is a valid way to take away the part installed there;
  the plugin is gone once every directory holding one of its parts has
  been removed.
  Then no task of it runs, no setting of it
  applies, nothing of it is served, and no program reports an error. What is
  left is at most a link that points nowhere, which every reader skips, and
  which the next removal takes away -- or a SELinux module, which grants
  nothing while its booleans are off (S23).
- **Installing does not enable.** An install puts the files in place and
  changes nothing that runs; switching a plugin on is a step of its own, and
  so is switching it off.
- **What the administrator chose survives an update.** Installing again
  replaces a plugin's code and keeps whether it is on, and its settings.
- **What the administrator wants to keep lives outside.** Data that should
  outlive the plugin -- the API's tokens, a search index -- is kept outside
  its directory, and does nothing once the plugin is gone.
- **What a plugin makes while it runs lies where Xymon keeps its own.** A socket
  is in Xymon's runtime directory, its own directory there, made when it
  starts and taken away when it stops; a log, in Xymon's log directory.
- **One command, nothing particular to a plugin.** The command reads each
  plugin's `PLUGIN` file and holds no plugin's name; a new plugin is a
  directory and its `PLUGIN` file.
- **Every rule is enforced by a test**, so a change that breaks one fails at
  once.

## Rules

### What a plugin is

**S1. A plugin is a directory with a `PLUGIN` file.**
`plugins/NAME/` holds the `PLUGIN` file, a README, a manual page per side,
tests and the code. `install.sh` installs every plugin from its `PLUGIN`
file, and names none.

**S2. A plugin carries its version.**
The `version:` line, `X.Y.Z`, moves as `CONTRIBUTING.md` (Versions) says. The
install writes beside the installed files, in `VERSION`, the plugin's
release tag when the checkout is at one, else that version.

**S3. A plugin names the plugins it needs.**
Its `needs:` line names them; the install of a plugin installs them with it,
and its removal is refused while an installed plugin needs it, naming that
plugin.

**S14. A plugin names the Xymon it needs.**
A `xymon:` line in `PLUGIN`, `X.Y.Z`, gives the lowest Xymon version the
plugin's server side works with. `install-server` compares it with what
`$XYMONHOME/bin/xymon --version` gives, for the plugin and each it needs,
before it installs any:

- older: refused, naming both versions, unless `--force` is given, which
  installs it and says so. A distribution may carry a feature back to an
  older number, and the administrator may know it does;
- not known, because the version cannot be read: installed, with a warning
  that it could not be checked;
- a development version, `4.3.32-dev`, comes after `4.3.31` and before
  `4.3.32`: a plugin that needs `4.3.32` installs on it with a warning, as
  it may lack what came before that release.

A plugin that needs a newer Xymon for one feature alone says so in its README
instead. Whatever the version, `install-server` says so when the server's
`xymonserver.cfg` does not read `xymonserver.d/`, where the plugins'
settings go: a configuration kept from before 4.3.31 ignores them.

**S4. A plugin has its side.**
The Xymon server (`server-*` lines: files under `$XYMONHOME/ext/NAME/`, a
xymonlaunch task, a section 8 manual page) and your own machine (`tools-*`
lines: files under `$PREFIX/libexec/xymon-plugins/NAME/`, commands in
`$PREFIX/bin`, a section 1 manual page). A plugin has one side or both. The
server side needs `XYMONHOME`, and without it installs nothing and says so.

**S18. A server action acts only on a server's tree.**
The tree `XYMONHOME` names is read for Xymon's marks, a whole pair counting
before any single mark: a server's, `etc/xymonserver.cfg` and `bin/xymond`,
which wins when a client's files are there too; else a client's,
`etc/xymonclient.cfg` and `bin/xymonclient.sh`. A client's tree, a tree with
one mark of a pair, and a tree with no marks are refused before anything
changes, naming the marks found or missing. Under `DESTDIR`, a staging
target, the marks are not read. Without `XYMONHOME`, the Xymon trees found
on the machine are named, and none is chosen.

### Installing, updating, removing

**S5. Installing enables nothing.**
A plugin's task is installed off, with no link (S13); the install says how
to turn it on.

**S6. A plugin's task lives in its directory.**
It is `ext/NAME/tasks.cfg`, and `etc/tasks.d/NAME`, when there, is a link to
it; under `DESTDIR` the link names the installed file. A regular file at
`tasks.d/NAME` -- a copy an older install made, or the file an editor left
in place of the link -- is the one xymonlaunch reads: it is moved into the
plugin's directory as it was, and linked unless it was `DISABLED`. A link
at `tasks.d/NAME` to something else is left as it is, and the install,
before it installs anything, `enable-server` and `disable-server` refused.

**S7. An update replaces the code and keeps the choices.**
Installing again replaces the plugin's directory as a whole, so a file a
newer version no longer ships is gone; it keeps the task file as the
administrator left it, whether it is on, and the web server snippets as the
administrator edited them.

**S8. Removing takes away the plugin and its links.**
The removal takes away the plugin's directory, its task link and its manual
pages, and is refused while another installed plugin needs it (S3).

**S9. Removing the directory by hand removes the task.**
Once `ext/NAME` is deleted, xymonlaunch no longer has the plugin's task, and
says nothing of the link left pointing nowhere; the next removal takes that
link away.

**S10. The administrator's data outlives the plugin.**
The removal keeps the API's tokens file, and says what it kept.

**S16. A plugin's web server snippet lives in its directory.**
A snippet the `conf:` line of `PLUGIN` names is installed in `ext/NAME/`,
`@XYMONHOME@` in it filled in as in the task file, and the web server is
told to include it in a way that skips it once it is gone: `IncludeOptional`
on Apache, a wildcard `include` on nginx and lighttpd. Removing the plugin,
or deleting `ext/NAME`, removes it, and the web server still starts. A
snippet an install finds as an older
version shipped it, by the cksum its `PLUGIN` file's `conf-stock:` lines
give -- its `$XYMONHOME` put back as `@XYMONHOME@`, so that one installed
under any tree is recognised -- was never edited, and takes this version's;
so does one byte for byte as an earlier install wrote it, which the install
keeps beside it in `ext/NAME/.shipped/`, where no include reaches it -- a
snippet naming a runtime directory moved since is not the administrator's.
One that differs from both is the administrator's, kept, and the install
says it differs. A web server goes on with the snippets it read until it
reloads: when an install adds, replaces or drops a snippet, or an uninstall
takes them away, it says to reload the web server, and reloads none itself;
under `DESTDIR` there is none to reload. A snippet is written as a new file,
never through a link, symbolic or hard; one kept as edited that does not
name Xymon's runtime directory is said to.

**S13. A plugin is on when its link is there.**
A plugin's task is on when `etc/tasks.d/NAME` links to its task file, and
off when the link is absent: xymonlaunch has the task exactly then.
`enable-server` makes the link, `disable-server` removes it, and each says
so when there is nothing to do. The task file carries no `DISABLED`: one an
older install wrote with that line is off, and the line is taken out, and
the install says how to turn it on.

**S19. `/plugins` serves only what a plugin declares.**
What a server stages for `/plugins`, in `ext/xymon-plugins-dist`, is for
each plugin its `PLUGIN` file, its `README.md`, and the files, manual
pages, task and web server snippets its `PLUGIN` file names, with
`install.sh` and `LICENSE`: a file left beside them in the checkout is not
served. Each install prunes what is staged to the same, and to the
plugins installed on the server, before staging, so that what an older
install staged, or a plugin since renamed or removed left, is not served
either; a link in the stage is removed, never written through, and a
removal that fails stops the install. A name with a `/`, `.` or `..`, in
a plugin's files or in `needs:`, or a plugin file that is a link, stops
the install before anything is copied.

**S20. An installed plugin keeps its `PLUGIN` file, and is managed by it.**
An install copies the plugin's `PLUGIN` file into its installed directory,
beside `VERSION`, and keeps its manual page there too, linked from
`MANDIR`. Uninstalling, enabling, disabling, reporting `status` and
checking what needs a plugin, and in what order to remove several, read
that copy, not the checkout's, so that a checkout of another version, or
one the plugin is gone from, still removes what was installed: its
directory, its command, its manual page, its task link or the task file in
the link's place. An action given no names covers the plugins installed
with a copy that the checkout no longer has. An update reads the copy
before replacing it, and removes the command, manual page and task link
the installed version put in place and the new one does not. A plugin
installed before the copy existed is managed by the checkout's `PLUGIN`
file, as before, until it is installed again. The copy lies in a directory
the Xymon user can write, so it decides nothing alone: a manual page is
removed only if it is the link into the plugin's directory, a command only
if it is, byte for byte, the one an install of that plugin wrote, and a
name only if it is a plain file name.

**S21. Under `DESTDIR`, nothing is written outside it.**
An install staged under `DESTDIR` writes only there. Xymon's own staged
install may leave `$XYMONHOME/etc` as an absolute link to where its
configuration goes once installed, `/etc/xymon` on Debian and with the
RPM, and a packager may link any directory of the stage the same way.
Every directory the install writes to or reads a setting from -- `ext/`,
`etc/`, `tasks.d/`, `MANDIR`, `$PREFIX/libexec`, `$PREFIX/bin` -- is
followed inside `DESTDIR`: a link to an absolute path from `DESTDIR`, a
relative one from where it lies, a `..` stopping at `DESTDIR`, a chain of
links each in turn, a link higher up the path as well as at its end; a
link that cannot be read stops the run. Below those directories, a link in
the place of a plugin's directory, of a file an update sets aside, or of
the stage's `plugins/` is removed, never followed, and a command is
written in place of a link, never through it. No virtualenv is made or
used under `DESTDIR`: it belongs to the installed system.

**S22. A socket a plugin makes for another program is in Xymon's runtime
directory.**
The API's sockets are in its directory there,
`$XYMONRUNDIR/xymonapi/`, or `$XYMONSERVERLOGS/xymonapi/` when
`XYMONRUNDIR` is empty, as Xymon does: `relay.sock` for the web server,
and `local/api.sock` for the server's own programs, `local/` being the
Xymon user's and its group's alone; the clients look for it there. The install writes that path into
the web server snippets, asking Xymon's `xymoncmd`, which loads the
server's configuration as xymonlaunch does for the API -- its includes,
its variables, its defaults; under `DESTDIR`, or where `xymoncmd` is
missing or fails, read from `xymonserver.cfg` and then the files of
`xymonserver.d/`, the last `XYMONRUNDIR=` line, quoted or not. Where that
gives no absolute path -- a variable read without Xymon -- the snippets
keep `@XYMONRUNDIR@` and the install says so. The API makes its directories there when it starts and
takes them away when it stops.

**S23. A plugin's SELinux module grants nothing until the admin says so.**
A plugin that needs a SELinux rule ships it as a module, `NAME.cil` among
its server files, named in its `PLUGIN` file's `selinux:` line. Where
SELinux is active, `install-server` loads it with `semodule` and says how
to switch it on: what it grants lies behind booleans, off. `uninstall-server`
removes it, and an update to a version without one: the module named after
the plugin, never one the installed `PLUGIN` copy names otherwise. Under
`DESTDIR`, or where SELinux is not active, nothing is loaded. The module
lies outside the plugin's directory: deleting `ext/NAME` by hand leaves it
loaded, inert while its booleans are off, until the next removal through
the command.

### Knowing what is installed

**S15. `status` says what is installed.**
`status-server` and `status-tools` say, for each plugin of the side, or
those named: whether it is installed, the version installed, from its
`VERSION`, a release tag read as its `X.Y.Z`; on the server, whether its
task is on; and the version of the checkout run from, marked newer when it
is. A name that is no plugin is refused. `status` changes nothing.

### Running the command

**S17. With no verb and no terminal, nothing is done.**
Run with no verb, its input or its output not on a terminal, the command
prints its usage, exits 2 and changes nothing, settings given or not: a
script that forgot its verb installs, enables and removes nothing.

### Getting the code

**S11. `stable` is code every test passed.**
CI moves `stable` to a commit of `main` once every test passed on it, forward
only; installing from `stable` installs tested code.

**S12. The installer runs on every machine a plugin goes to.**
`install.sh` and the tests keep to Xymon's portability rules, but the one
against Python, which every plugin needs, and the one against the
`rrdtool` command, which the API runs to read the RRD files.

## Planned

Rules decided but not yet tested; each is numbered in the pull request that
brings its test.


- **A plugin has up to three parts.** Each is declared by its own lines of
  `PLUGIN`, and a plugin has one, two or all three. The server and client
  parts are its Xymon parts:

  | part | lines | where | installed by |
  |---|---|---|---|
  | tools | `tools-*` | any machine, under `PREFIX` (`~/.local`) | the person, as themselves |
  | server | `server-*` | a Xymon server's tree, `ext/NAME/` | the user that may write it, usually root |
  | client | `client-*` | a Xymon client's tree, `ext/NAME/`, its task started from a standalone client's `clientlaunch.d`, or, for a server's own client, from that server's `tasks.d` | the same |

  A Xymon server has a client tree of its own, the `XYMONCLIENTHOME` its
  `xymonserver.cfg` names: it belongs to that server, and a plugin's client
  part installed on the server goes there. A client tree no server names is
  a standalone client, a monitored host. Once built, this replaces S4's two
  sides and S18's refusal of a client's tree, and the `side:` lines of today's `PLUGIN` files, which call the
  tools part "client", are removed: the parts a plugin has are those its
  lines declare. A client part keeps its runtime files in `$XYMONTMP/NAME`
  and its logs in `XYMONCLIENTLOGS`, the places Xymon gives a client; a
  server part keeps its runtime files in `XYMONRUNDIR` (S22) and its logs
  in Xymon's log directory. The checks under `checks/`, copied into place by hand today, each
  move under `plugins/` as a client part when they get a `PLUGIN` file.
- **One command, read as a sentence.** `xymon-plugin`, at the top of the
  repository, replaces `install.sh`, and takes a verb and the plugins it
  acts on:

  ```sh
  ./xymon-plugin install xymonapi
  ./xymon-plugin enable xymonapi
  ./xymon-plugin disable xymonapi
  ./xymon-plugin update xymonapi
  ./xymon-plugin remove xymonapi
  ./xymon-plugin status
  ./xymon-plugin connect https://xymon.example.ch
  ```

  With no plugin named, a verb acts on every plugin of the installation it
  targets (below), but `remove`, which needs a plugin named, or `--all`;
  what `install` with no plugin named takes is open (below).
  The Python environment a plugin needs is made and completed by `install`
  and `update`, with no verb of its own. On a terminal they ask before
  fetching modules; off a terminal, and under `DESTDIR` (S21), they fetch
  none and say how to make it. An environment that cannot be made does not
  fail the install, which says how to make it. `enable`
  refuses a plugin whose Python lacks the modules it needs, and `status`
  says so. `connect URL` connects this machine to an API. It installs the
  tools part of the plugin whose `PLUGIN` has a `connect:` line, then
  hands over to that plugin, which gets a token and registers the AI tools
  found. The command itself still names no plugin. It is POSIX `sh` and needs no `make`.
- **The parts are asked for, or named.** `--server`, `--client` and
  `--tools` name the parts a verb acts on, for every verb; what they mean
  for `connect`, and `--tools` for `enable` and `disable`, is open (below). `--server` and
  `--client` may be given together; `--tools` is given alone. Without them,
  on a terminal, the command asks which parts, offering those the
  installation a run targets (below) takes and the plugin has: on a
  server's tree, its server part, and its client part into the server's
  own client tree; on a standalone client's tree, its client part --
  whether it asks when only one applies is open (below). Off a
  terminal, a verb that changes a Xymon part needs them; `status` without
  them covers every part. A part the plugin does not
  have is skipped when not named, and refused when named, saying why. On a
  server, `--client` means the server's own client tree; `--server` asked
  of a standalone client's tree is refused. The tools part is never
  installed with the Xymon parts: it belongs to the person, under
  `PREFIX`, while they belong to whoever owns the Xymon tree, often root,
  and it is installed only when asked -- `--tools`, `connect`, or the
  dialogue; `--tools` run as root is refused, unless `DESTDIR` or `PREFIX`
  is given. A refusal comes before
  anything changes. A machine with no Xymon installation installs no Xymon
  part, and says that the tools are installed with `--tools` or `connect`.
- **A run changes one Xymon installation, which `XYMONHOME` names.**
  An installation is a Xymon tree, a server's, marked by
  `etc/xymonserver.cfg` and `bin/xymond`, with its own client tree, or a
  standalone client's, marked by `etc/xymonclient.cfg` and
  `bin/xymonclient.sh`. A machine may hold several installations, and a run
  changes one; `status` may read them all. `XYMONHOME`, or `--xymon-home PATH`, is the only thing that
  chooses it without asking -- running under `xymoncmd`, which sets it, counts as naming
  it; `--xymon-home` wins when both are given, which the first line says --
  and it is checked against its marks (S18). A `XYMONHOME` that is the
  client tree of a server found by detection stops the run. The message
  names that server, and the command to type: `--xymon-home` its tree, and
  `--client`. Detection -- the tree
  holding the current directory, `ext/` included, the trees of a running
  `xymonlaunch`, the packages' usual paths, the `xymon` user's home -- only
  proposes. Trees are compared by their resolved path -- one tree may be
  reached by several, as Homebrew's `opt/` and `Cellar/` -- and a client
  tree a found server names is part of that server, not another
  installation. On a terminal, without a name, with a verb or with none,
  the one installation found is proposed, and the person confirms, Enter
  for yes; several are listed, with as default the one used last, else none:
  neither the current directory nor what runs at that moment chooses it. Off a terminal, without
  a name, a verb that changes a Xymon part is refused, listing the trees
  found: a script's target depends neither on its current directory nor
  on what runs at that moment. `status` then lists the trees, what each
  holds, and the person's tools. Every
  run says, before it changes anything, the target, the parts, and what
  chose them: named, or detected and confirmed. As decided in #39, no record of the target is written
  in an installed part, which keeps only its `PLUGIN` and `VERSION`; the
  one used last is remembered apart (open, below).
- **With no verb on a terminal, the command shows where things stand, then
  offers what applies.** Run with no verb, its input and its output on a
  terminal, it first says what it found: the Xymon installation, by the
  rule above, which the person confirms, each plugin installed there, by
  part, with its version and, for a part with a task, whether it is on, and the person's tools. It
  then offers only what applies: install a plugin, each listed with one
  line on what it does and none chosen by default, the plugins it needs
  added and named (S3); turn one on or off; update; remove one, with no
  default, refusing one another installed plugin needs (S8); install tools
  for the person; connect this machine to an API; or nothing, the default.
  It prints the command those answers spell, asks `Proceed? [Y/n]`, runs
  exactly that command and nothing else, and says what comes next. After
  an install it offers enabling, below; otherwise it stops. An install it runs enables
  nothing (S5): turning the plugin on is offered after it, as a second
  command printed and confirmed with `[y/N]`, so that Enter declines it.
  Off a terminal, S17.
- **The code comes from a source.** `install` and `update` take a
  plugin's code from a source: a Xymon server, through its API or its web
  server; GitHub, the plugin's releases; or one named with `--source`, a
  checkout or a URL. With none named, the tools part takes it from the
  Xymon server `connect` connected the machine to; a Xymon server's
  parts, from GitHub; a standalone client's part, from the Xymon server it
  reports to, whose URL is asked the first time, as `XYMONSERVERS` gives
  an address and no URL. A source named with `--source` is trusted: what it
  gives is installed unchecked, and the first line says so.
- **Open, to decide.** What a source not named does with code no proof
  checks -- configurable, its defaults to choose -- and how a compromised
  Xymon server is warned of or blocked: a contradiction with GitHub's
  release, a memory of the code installed, a published block list, an
  emergency stop -- urgent, as no plugin has a release on GitHub yet.
  Also:
  - the `connect:` line's details: its value, two plugins declaring it,
    tools already installed, a failure; `connect` run as root; which
    selectors `connect` takes;
  - the checkout `xymon-plugin` runs from: whether it is a source, under
    `DESTDIR`, offline, or with no release; where the list of plugins and
    "newer" come from;
  - where the tools part comes from before the first `connect`;
  - `install` with no plugin named, and how `install` and `update` differ;
  - `enable` and `disable` for a part with no task, as `--tools`;
  - whether the command asks for the parts when only one applies;
  - whether `needs:` (S3) holds part by part;
  - on a server, the name of a client part's link in `tasks.d`, which may
    be the server part's, and the environment its task runs with, the
    client's `xymonclient.cfg`, without which `XYMONTMP` is the server's;
  - removing a client part's directory by hand: what its launcher does
    with the link left (S9 says it for the server only);
  - a standalone client's server URL: where it is kept, and off a
    terminal the first time;
  - whether a server installed from a checkout serves an archive at all;
  - the current directory reached through a link, as Homebrew's `ext/`;
  - finding the server a client tree belongs to when detection does not;
  - where "the one used last" is kept, per machine or per person, and
    what is proposed when it is gone;
  - on a terminal, with several installations, whether `status` asks for
    one or lists them all;
  - how a script makes the Python environment, as there is no verb for it
    and `install` off a terminal fetches nothing;
  - whether `--tools` and `connect` ask for a Xymon installation, which
    they do not need; whether `status --tools` run as root is refused.
- **Removing the directory by hand removes everything of that part.**
  Beyond the task (S9), what each program reads it reads through the place
  below, so that after `ext/NAME` is deleted Xymon no longer applies the
  plugin's settings, and the API no longer serves it:

  | What | Lives in | Seen by its reader through |
  |---|---|---|
  | settings | `ext/NAME/xymonserver.cfg` | a link in `etc/xymonserver.d/`, which Xymon reads after `xymonserver.cfg` |
  | manual page | `ext/NAME/` | a link in `MANDIR` |
  | what `/plugins` serves | the release archive the part was installed from, kept in `ext/NAME/` | the API, serving that archive at `/plugins/NAME` |
  | Python modules | `ext/NAME/venv/` | the plugin's own launcher |

  A plugin that needs Python modules beyond the standard library has its
  own virtualenv, in its directory, instead of the one shared today: none is
  left behind by a plugin removed, at the cost of a module two plugins need
  being installed twice. The test installs every plugin, enables it, deletes
  `ext/`, and checks xymonlaunch, `xymoncmd`, `apachectl configtest` and
  `nginx -t`.
- **What `/plugins` serves can be checked against the repository.** Each
  release of a plugin, its tag `NAME/vX.Y.Z`, has an archive that CI builds
  from that tag -- reproducibly, so that the same tag always gives the same
  bytes -- attests, and attaches to the release. A server serves those
  bytes, one archive per plugin, at `/plugins/NAME`: the archive it
  installed, not one built on the spot. `install` from a server it was not
  told to trust with `--source` checks the archive before it installs, by any proof that does not come from that
  server: its attestation, verified with `gh`, `cosign` or Python's
  `sigstore`, with no key kept, as the attestation is signed for the CI run
  that built the archive; or the same archive rebuilt from the release tag
  in a copy of the repository, from any mirror, the way for a machine with
  no access to GitHub. A server installed from a checkout that is not a
  release tag -- `stable`, `main` -- has no attested archive, and
  `/plugins/NAME` says so. What an install does with an archive a proof
  contradicts, or none can prove, is open (above).

## Later

Directions the rules leave room for, not yet decided:

- **A repository plugin.** The serving of plugins moves out of the API into a
  plugin of its own on the Xymon server: it fetches each release's archive
  and attestation, keeps several versions, and serves both, so that a
  machine without access to GitHub checks an archive offline against its
  attestation, and so that monitored hosts get their plugins from the
  server. `xymon-plugin` stays the command that installs the first plugin.
  Discussed in #29.
- **Working across installations.** Comparing their versions, installing
  into several in one run. Reading several is allowed -- `status` lists
  them all -- but nothing changes two installations in one run until then.
  Discussed in #39.

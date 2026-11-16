# Upgrading

What a change that breaks something asks of you, newest first: the plugin,
its version, what breaks, and what to do. Every other change needs nothing
but installing the new code (see each plugin's README). CI refuses a change
that breaks the API's contract without a line here.

## xymonapi-connect asks the password once more, from xymonapi 5.0.2

`xymonapi-connect` now keeps the API's URL beside the token, in
`~/.config/xymon-api/NAME.url`, and sends a token only to that URL. What
breaks: on a machine connected before, the first `xymonapi-connect URL`, or
`xymonapi-mcp register URL`, asks your password again, once, and keeps a new
token, which replaces the one before on that server; a token kept for
another server stays valid there until its `/tokens` revokes it.
The same server reached by another URL asks it too. Then the agent and
`xymonapi-rag` find the API with no `XYMONAPI_URL` set.

## The relay socket moves to Xymon's runtime directory, from xymonapi 5.0.0

The web server's relay socket is now `$XYMONRUNDIR/xymonapi/relay.sock`,
in the directory Xymon keeps for its sockets, or in its log directory,
`$XYMONSERVERLOGS`, when `XYMONRUNDIR` is empty, as Xymon does. It was
`$XYMONHOME/tmp/xymonapi-relay/relay.sock`. The socket for the server's
own programs is beside it, `$XYMONRUNDIR/xymonapi/local/api.sock`; it was
`$XYMONVAR/xymonapi/api.sock`, and the clients look only at the new path.
The install reads the directory
from `$XYMONHOME/etc/xymonserver.cfg` and replaces a 4.0.0 snippet it finds
unedited. What breaks: a snippet you edited is kept, and the install says
it differs: put the new socket path in it. Where `XYMONRUNDIR` names a
variable the install cannot read, the snippets keep `@XYMONRUNDIR@`, and
the install says to put the directory there. An SSH tunnel goes to the new
path. Setting `XYMONAPI_RELAY_SOCKET` keeps the socket where you name it.

## The web server reaches the API on its relay socket, from xymonapi 4.0.0

The API now also answers on a Unix socket for the web server,
`$XYMONHOME/tmp/xymonapi-relay/relay.sock` (`XYMONAPI_RELAY_SOCKET`), in plain
HTTP whether port 1986 speaks HTTPS or not, asking the same password or
token; the web server's snippets pass `/xymon/api/` there. Before, they
passed it to `127.0.0.1:1986` in plain HTTP, which failed with a 502 where
1986 speaks HTTPS, as it does by itself once xymond's certificate is in
`etc/tls/`. An install replaces a snippet it finds as an older version
shipped it; one you edited is kept, and the install says it differs: put the new
`ProxyPass`, `proxy_pass` or `proxy.server` line in it, from the snippet
the plugin ships. The snippets need Apache 2.4.7, or lighttpd
1.4.36, or later. An SSH tunnel can go to the socket too:
`ssh -L 1986:$XYMONHOME/tmp/xymonapi-relay/relay.sock HOST`.

What breaks: a path with a trailing slash, which redirected to the one
without, is now not_found -- a redirect would send a client behind a web
server back to http://. And there is no relay where the socket's
directory, or one on the way to it, can be changed by anyone but root and
the Xymon user: the API runs on, says why in its log, and `/health` says
`"relay": "refused"`; the log names the directory, and the group that may
write it. On Homebrew, `/opt/homebrew`'s directories -- `opt`, `Cellar`,
`var` -- are writable by the `admin` group, by Homebrew's design: set
`XYMONAPI_RELAY_TRUSTED_GROUPS=admin` in `xymonserver.d/`, if every admin is
trusted with the API's passwords.
`XYMONAPI_RELAY_SOCKET` set empty turns the relay off.
Under SELinux, as with Xymon's RPM on RHEL, Apache must be allowed to
connect to the socket: from xymonapi 5.0.1 the install loads a module
for it, its boolean off, `setsebool -P xymonapi_relay on`.

## Every install action names its side, install.sh from November 2026

`./install.sh install`, `uninstall`, `venv`, `enable`, `disable` and
`status`, the server actions without `-server`, are refused, naming the
action with a side: `install-server`, `uninstall-server`, `venv-server`,
`enable-server`, `disable-server`, `status-server`, and for the first
three and `status` the `-tools` ones too. A script that used a short
spelling adds `-server`. Nothing installed changes. The plain verbs are
`xymon-plugin`'s, the command SPEC.md plans to replace `install.sh`.

## The server actions need a Xymon server's tree, install.sh from November 2026

Every server action -- `install-server`, `enable-server`,
`disable-server`, `status-server`, `uninstall-server`, `venv-server` --
now reads the tree `XYMONHOME` names for a server's two marks,
`etc/xymonserver.cfg` and `bin/xymond`, and refuses it before changing
anything when they are not both there: a client's tree, part of a pair, or
a directory that is no Xymon tree at all. An install into an empty
directory, which used to make one, is refused; to stage the plugins for a
package, set `DESTDIR`, under which no marks are read. A plugin left in a
tree whose Xymon is already gone is removed by deleting `ext/NAME`. A real
server, packaged or built from source, needs nothing.

## A password file is needed, from xymonapi 3.0.0

With `XYMONAPI_PASSWD` not set and no `$XYMONHOME/etc/xymonpasswd`, the API
answered anyone who reached it. It now does not start, and says why. A
missing file -- a configuration kept from an older install that does not
read `xymonserver.d/`, a new install without the web pages' passwords --
no longer opens the API without a word. Create the file with `htpasswd`,
name another in `XYMONAPI_PASSWD`, or, for an API open to anyone who
reaches it, set `XYMONAPI_PASSWD=""` in a file under `xymonserver.d/`.

## Server tasks on and off, by a link, from xymonapi 2.4.0

A plugin's task is no longer turned on by removing `DISABLED` from its
file: it is on when `etc/tasks.d/NAME` links to `ext/NAME/tasks.cfg`, which
`XYMONHOME=... ./install.sh enable-server NAME` makes and `disable-server
NAME` removes. The first install with this version keeps each task as it
was: one still `DISABLED` stays off and loses that line, and says how to
turn it on; one you enabled stays on. A script that enabled a task by
editing its file runs `enable-server` instead.

## The install actions, from xymonapi 2.3.0

`./install.sh install-client`, `uninstall-client` and `venv-client` are now
`install-tools`, `uninstall-tools` and `venv-tools`: what they install are
the plugins' commands, on your own machine, and "client" is Xymon's word for
a monitored host. The old names are refused, saying the new one. The server
actions gain `-server` -- `install-server`, `uninstall-server`,
`venv-server` -- and keep their old spellings. What is installed, and where,
is unchanged: an install over the old one needs nothing more. In a
`PLUGIN` file, `client-files`, `client-manual`, `client-modules` and
`uninstalled-client` are `tools-files`, `tools-manual`, `tools-modules` and
`uninstalled-tools`. The directory the server stages the plugins in for
`/plugins`, `ext/xymon-plugins-client`, is `ext/xymon-plugins-dist`; a
server install renames nothing, so remove the old directory by hand after
the first install with this version, or leave it: nothing reads it.

## Every plugin's install, from xymonapi 2.2.0

The plugins install with `./install.sh` at the repository's top, and `make`
is no longer used: the `Makefile`s are gone. What was
`make install XYMONHOME=...` in `plugins/NAME` is
`XYMONHOME=... ./install.sh install NAME`; `make install-client`,
`make uninstall`, `make uninstall-client`, `make venv` and
`make venv-client` are the same words after `./install.sh`, and with no
`NAME` they act on every plugin of the side, as the top `Makefile` did.
`PREFIX`, `MANDIR`, `DESTDIR` and `PYTHON` mean what they meant, from the
environment or as `NAME=value` arguments. What is installed, and where, is
unchanged: an install over the old one needs nothing more. The tests run
with `tests/run.sh` instead of `make test`.

## xymonapi 2.0.0

An API started before its launcher named it by its full path -- one whose
`pgrep -lf app.py` line shows a bare `app.py` -- is not found by the install,
which from now on stops the running API itself, and keeps running the old
code. Stop it once by its number, `kill PID`; xymonlaunch starts the new
one, which the next install finds.

`/client` is now `/plugins`, what it gives unchanged: the plugins installed
on the server, as a `.tar.gz`. Machines already installed need nothing; one
downloading the code from the server asks for
`https://SERVER/xymon/api/v1/plugins` instead.

## xymonapi 1.0.0

`/client` gives the code of the plugins installed on the server, as a
`.tar.gz`, instead of a setup script; its `name` and `format` options, and
the settings `XYMONAPI_PUBLIC_URL` and `XYMONAPI_REPO`, are gone. Machines
already set up keep their token and registrations and need nothing. To set
up one, or redo it: get the code -- from `/client` or a clone -- run
`make install-client` in `plugins/xymonapi-mcp`, then
`xymonapi-mcp register URL` (or `xymonapi-connect URL` for the API alone).
On the server, `make install` at the repository's top now also stages
`xymonapi-mcp` there, for `/client`.

## xymonapi-mcp, xymonapi-rag 0.1.0

The clients send a token and nothing else: `XYMONAPI_USER`,
`XYMONAPI_PASSWORD` and `XYMONAPI_PASSWORD_FILE` are no longer read. A
machine set up with a password gets 401: run `xymonapi-connect`, which gets
it a token.

## xymonapi 0.1.0

A user removed from the password file loses every client token at the first
use of one; putting the user back does not bring them back. Each of that
user's machines runs `xymonapi-connect` again for a new token.

# SPDX-License-Identifier: GPL-2.0-or-later
"""Answer a question on a terminal, as a person would.

    answer.py PROMPT ANSWER COMMAND [ARG...]
    answer.py PROMPT ANSWER [PROMPT ANSWER...] -- COMMAND [ARG...]

Runs COMMAND on a pseudo-terminal of its own, waits until it writes PROMPT,
types ANSWER and a newline, does the same for each further pair, in order,
and waits for it to end; a "[y/N] " question that comes after is given
Enter, its default, as one that comes or not, as a virtualenv's offer. Prints everything
COMMAND wrote, and exits with its status -- 128 plus the signal when one
killed it. Exits 124 when PROMPT does not come within 60 seconds, or
COMMAND does not end within 120; COMMAND is then killed.
"""
import os
import pty
import select
import signal
import sys
import time

args = sys.argv[1:]
if "--" in args:
    cut = args.index("--")
    pairs, command = args[:cut], args[cut + 1:]
else:
    pairs, command = args[:2], args[2:]
pairs = [(pairs[i].encode(), pairs[i + 1].encode()) for i in range(0, len(pairs), 2)]
pid, fd = pty.fork()
if pid == 0:
    os.execvp(command[0], command)


def read(until: float) -> bytes:
    got = b""
    while time.time() < until:
        if select.select([fd], [], [], 0.1)[0]:
            try:
                chunk = os.read(fd, 4096)
            except OSError:
                break
            if not chunk:
                break
            got += chunk
    return got


out = b""
seen = 0
for prompt, answer in pairs:
    deadline = time.time() + 60
    while prompt not in out[seen:]:
        if time.time() > deadline:
            os.kill(pid, signal.SIGKILL)
            sys.stdout.write(out.decode(errors="replace"))
            sys.exit(124)
        out += read(time.time() + 0.2)
    seen = out.index(prompt, seen) + len(prompt)
    os.write(fd, answer + b"\n")
status = None
until = time.time() + 120
while time.time() < until:
    out += read(time.time() + 0.2)
    if b"[y/N] " in out[seen:]:
        seen = out.index(b"[y/N] ", seen) + len(b"[y/N] ")
        os.write(fd, b"\n")
    done, st = os.waitpid(pid, os.WNOHANG)
    if done:
        status = st
        break
out += read(time.time() + 0.2)
sys.stdout.write(out.decode(errors="replace"))
if status is None:
    os.kill(pid, signal.SIGKILL)
    sys.exit(124)
code = os.waitstatus_to_exitcode(status)
sys.exit(code if code >= 0 else 128 - code)

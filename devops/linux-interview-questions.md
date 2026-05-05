# Linux Interview Questions

A practical, teaching-style Q&A guide for Linux. Each question gives a plain-language explanation followed by a working command and example output where useful.

---

## Table of Contents

1. Filesystem and FHS
2. Permissions
3. Processes and Signals
4. Services and Systemd
5. Networking
6. SSH
7. Bash Scripting
8. Text Processing
9. File Operations
10. Package Management
11. Users and Cron
12. Monitoring and Troubleshooting

---

## 1. Filesystem and FHS

## Q1. What is the Filesystem Hierarchy Standard (FHS)?

**Answer:**

FHS defines the standard layout of directories on a Linux system. It is why every Linux distribution puts user binaries in `/usr/bin`, configs in `/etc`, and logs in `/var/log`. Knowing the layout helps you find files quickly.

| Path        | Purpose                                                  |
| ----------- | -------------------------------------------------------- |
| `/etc`      | System-wide configuration files                          |
| `/var`      | Variable data: logs, mail, databases, caches             |
| `/usr/bin`  | User-installed binaries (`ls`, `python`, `node`)         |
| `/usr/sbin` | System administration binaries                           |
| `/home`     | User home directories                                    |
| `/tmp`      | Temporary files; cleared on reboot                       |
| `/proc`     | Virtual filesystem exposing kernel and process info      |
| `/sys`      | Virtual filesystem exposing devices                      |
| `/dev`      | Device files                                             |
| `/opt`      | Optional, third-party software                           |

```bash
ls /
# bin  boot  dev  etc  home  lib  opt  proc  root  run  sbin  sys  tmp  usr  var
```

## Q2. What is an inode?

**Answer:**

An inode is a data structure on the filesystem that stores metadata about a file: its size, permissions, owner, timestamps, and pointers to the actual disk blocks. Notice the filename is *not* in the inode — names live in directories, which map names to inode numbers.

A filesystem can run out of inodes even when there is free disk space, usually from millions of tiny files.

```bash
ls -li /etc/hosts
# 12345 -rw-r--r-- 1 root root 220 May  5 10:00 /etc/hosts
#   ^ inode number

df -i      # show inode usage per filesystem
# Filesystem     Inodes IUsed IFree IUse% Mounted on
# /dev/sda1     2621440  98K  2.5M    4% /
```

## Q3. What is the difference between a hard link and a symbolic link?

**Answer:**

A hard link is a second name pointing to the same inode. The file exists as long as at least one hard link points to it. Hard links cannot cross filesystems and cannot point to directories.

A symbolic (soft) link is a tiny file containing a path to another file. If you delete the target, the symlink becomes broken.

```bash
echo "hello" > original.txt
ln original.txt hardlink.txt        # hard link (same inode)
ln -s original.txt softlink.txt     # symbolic link

ls -li
# 12345 -rw-r--r-- 2 user user 6 May  5 10:00 hardlink.txt
# 12345 -rw-r--r-- 2 user user 6 May  5 10:00 original.txt   <- same inode
# 67890 lrwxrwxrwx 1 user user 12 May  5 10:00 softlink.txt -> original.txt
```

## Q4. What is `/proc`?

**Answer:**

`/proc` is a virtual filesystem that exposes kernel and process information as files. Tools like `ps`, `top`, and `free` read from it.

```bash
cat /proc/cpuinfo            # CPU info
cat /proc/meminfo            # memory info
cat /proc/loadavg            # system load
cat /proc/$$/status          # status of current shell process
ls /proc/1/                  # PID 1 (init/systemd)
```

---

## 2. Permissions

## Q5. Explain Linux file permissions.

**Answer:**

Each file has three permission triplets — for the owner, the group, and others. Each triplet has read (r), write (w), and execute (x) bits. `ls -l` shows them as nine characters.

```bash
ls -l script.sh
# -rwxr-xr-- 1 alice devs 120 May  5 10:00 script.sh
#  ^^^^^^^^^
#  owner=rwx  group=r-x  others=r--
```

Numerically, r=4, w=2, x=1, summed per triplet:

| Mode | Triplet | Meaning            |
| ---- | ------- | ------------------ |
| 7    | rwx     | read, write, exec  |
| 6    | rw-     | read, write        |
| 5    | r-x     | read, exec         |
| 4    | r--     | read only          |

So `chmod 755 file` means owner=rwx, group=r-x, others=r-x.

## Q6. Give some `chmod` examples.

**Answer:**

```bash
chmod 755 script.sh         # rwx for owner, rx for group/others
chmod 600 secret.txt        # rw for owner only
chmod +x script.sh          # add execute for everyone
chmod u+rwx,go-rwx file     # symbolic notation
chmod -R 644 docs/          # recursive (careful with directories)
```

For directories, `x` means "you can enter this directory."

## Q7. How do you change ownership with `chown` and `chgrp`?

**Answer:**

```bash
sudo chown alice file.txt              # change owner only
sudo chown alice:devs file.txt         # change owner and group
sudo chgrp devs file.txt               # change group only
sudo chown -R www-data:www-data /var/www   # recursive
```

You normally need root to change ownership.

## Q8. What is `umask`?

**Answer:**

`umask` is the default permission mask for newly created files. The mask is *subtracted* from the maximum permissions (666 for files, 777 for directories).

```bash
umask                  # show current mask
# 0022

# Default file: 666 - 022 = 644 (rw-r--r--)
# Default dir : 777 - 022 = 755 (rwxr-xr-x)

umask 077              # only owner can access new files
touch test.txt
ls -l test.txt
# -rw------- 1 alice alice 0 May  5 10:00 test.txt
```

## Q9. What are SUID, SGID, and the sticky bit?

**Answer:**

- **SUID** on an executable means it runs with the file owner's privileges instead of the caller's. Example: `passwd` is SUID-root because it has to write `/etc/shadow`.
- **SGID** on an executable runs as the file's group. SGID on a directory makes new files inherit the directory's group.
- **Sticky bit** on a directory means only the file's owner can delete the file, even if others have write permission. Used on `/tmp`.

```bash
ls -l /usr/bin/passwd /tmp
# -rwsr-xr-x 1 root root /usr/bin/passwd     <- 's' = SUID
# drwxrwxrwt 1 root root /tmp                <- 't' = sticky

chmod u+s file        # set SUID
chmod g+s dir         # set SGID
chmod +t dir          # set sticky
```

## Q10. What are POSIX ACLs?

**Answer:**

ACLs (Access Control Lists) extend the basic owner/group/other model. You can grant explicit permissions to additional users or groups.

```bash
setfacl -m u:bob:rw report.txt        # give bob rw access
getfacl report.txt
# user::rw-
# user:bob:rw-
# group::r--
# mask::rw-
# other::r--

setfacl -x u:bob report.txt           # remove bob's ACL
setfacl -b report.txt                 # remove all ACLs
```

A `+` at the end of `ls -l` permissions means an ACL is in effect.

---

## 3. Processes and Signals

## Q11. How do you view processes?

**Answer:**

```bash
ps aux                # all processes, BSD style
ps -ef                # all processes, System V style
ps -ef --forest       # tree view
top                   # interactive, classic
htop                  # nicer interactive (install separately)
pgrep nginx           # PIDs by name
pidof nginx           # one-line PIDs
```

Example output of `ps aux`:

```text
USER       PID %CPU %MEM    VSZ   RSS TTY  STAT START   TIME COMMAND
root         1  0.0  0.1 168000 11000 ?    Ss   May04   0:01 /sbin/init
www-data  1234  0.5  2.0 200000 80000 ?    S    10:00   0:05 nginx: worker
```

## Q12. What are common kill signals?

**Answer:**

| Signal     | Number | Meaning                                       |
| ---------- | ------ | --------------------------------------------- |
| SIGHUP     | 1      | Reload config (many daemons interpret this)   |
| SIGINT     | 2      | Interrupt (what Ctrl+C sends)                 |
| SIGTERM    | 15     | Polite "please terminate" (default for `kill`) |
| SIGKILL    | 9      | Force kill; cannot be trapped                 |
| SIGSTOP    | 19     | Pause process                                 |
| SIGCONT    | 18     | Resume process                                |

```bash
kill 1234            # SIGTERM (graceful)
kill -9 1234         # SIGKILL (force, last resort)
kill -HUP 1234       # reload config
killall nginx        # by name
pkill -f "myscript"  # match by command line pattern
```

## Q13. What are process states?

**Answer:**

| State | Meaning                                                          |
| ----- | ---------------------------------------------------------------- |
| R     | Running or runnable                                              |
| S     | Sleeping (interruptible — usually waiting on I/O)                |
| D     | Uninterruptible sleep (usually disk I/O; cannot be killed)       |
| Z     | Zombie (process exited; parent has not collected exit status)    |
| T     | Stopped (paused by signal)                                       |

You see them in the STAT column of `ps`.

## Q14. What is a zombie process?

**Answer:**

A zombie is a child process that has exited but whose parent has not yet called `wait()` to collect its exit status. The kernel keeps a small entry around so the parent can still read the exit code.

A few zombies are harmless. Many zombies usually mean a buggy parent process. If the parent dies, init/systemd inherits the children and reaps them.

```bash
ps aux | awk '$8=="Z"'    # find zombies
```

## Q15. What is the difference between foreground and background?

**Answer:**

```bash
sleep 100             # runs in foreground; terminal blocks
sleep 100 &           # runs in background; you get prompt back
jobs                  # list background jobs
fg %1                 # bring job 1 to foreground
bg %1                 # resume stopped job in background
Ctrl+Z                # suspend foreground job (then bg/fg)

nohup myscript.sh &   # survives logout
disown -h %1          # detach from current shell
```

## Q16. What is the difference between a process and a thread?

**Answer:**

A process has its own memory space (address space, file descriptors, etc.) and is isolated from other processes. A thread runs inside a process and shares memory with the other threads of that process. Threads are cheaper to create and to switch between, but they need synchronization to avoid corrupting shared data.

```bash
ps -eLf | head        # show threads (LWP column = thread ID)
top -H                # interactive, threads view
cat /proc/<pid>/status | grep Threads
```

---

## 4. Services and Systemd

## Q17. What is systemd?

**Answer:**

systemd is the init system used by most modern Linux distributions. It is PID 1 and is responsible for booting, managing services, mounting filesystems, handling logs, and more. You interact with it via `systemctl` (services) and `journalctl` (logs).

## Q18. What are the most common `systemctl` commands?

**Answer:**

```bash
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx          # signal reload, no restart
sudo systemctl enable nginx          # auto-start on boot
sudo systemctl disable nginx
systemctl status nginx               # current state and recent logs
systemctl list-units --type=service  # all loaded service units
systemctl list-unit-files            # installed units and enabled state
systemctl is-active nginx            # active / inactive
systemctl is-enabled nginx
```

## Q19. Show me a sample systemd unit file.

**Answer:**

A unit file describes how to manage a service: what to run, how to restart it, what it depends on, and which user to run as.

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My Node App
After=network.target

[Service]
Type=simple
User=myapp
WorkingDirectory=/opt/myapp
ExecStart=/usr/bin/node /opt/myapp/server.js
Restart=on-failure
RestartSec=5
Environment=NODE_ENV=production
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

After editing, reload and enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp
journalctl -u myapp -f
```

## Q20. What are the basics of `journalctl`?

**Answer:**

`journalctl` reads systemd's structured log database.

```bash
journalctl                            # all logs
journalctl -u nginx                   # logs for one unit
journalctl -u nginx -f                # follow, like tail -f
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx --since "2025-05-05" --until "2025-05-06"
journalctl -p err                     # priority error or worse
journalctl -k                         # kernel logs (dmesg)
journalctl --disk-usage
sudo journalctl --vacuum-time=7d      # prune older than 7 days
```

## Q21. What is the difference between systemd timers and cron?

**Answer:**

Both run jobs on a schedule. systemd timers integrate with units (logs go to journald, dependencies, environment, restart policies) and have richer scheduling. cron is simpler and ubiquitous.

A timer needs two units: a service (what to run) and a timer (when to run it).

```ini
# myjob.service
[Unit]
Description=Run my job

[Service]
Type=oneshot
ExecStart=/opt/myapp/cleanup.sh
```

```ini
# myjob.timer
[Unit]
Description=Run myjob every hour

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable --now myjob.timer
systemctl list-timers
```

---

## 5. Networking

## Q22. What is the difference between modern and legacy networking commands?

**Answer:**

Older tools (`ifconfig`, `route`, `netstat`) are deprecated in favor of the `ip` and `ss` commands from the `iproute2` package. The new ones are faster and show more detail.

| Old        | New             |
| ---------- | --------------- |
| `ifconfig` | `ip addr`       |
| `route`    | `ip route`      |
| `netstat`  | `ss`            |
| `arp`      | `ip neigh`      |

## Q23. Give me some `ss` examples.

**Answer:**

```bash
ss -tulpn               # TCP/UDP listening sockets with PIDs
ss -tan                 # all TCP, numeric
ss -s                   # summary statistics
ss state established '( dport = :443 or sport = :443 )'
```

Example output:

```text
Netid State  Local Address:Port    Peer Address:Port  Process
tcp   LISTEN 0.0.0.0:80            0.0.0.0:*          users:(("nginx",pid=1234))
tcp   LISTEN 127.0.0.1:5432        0.0.0.0:*          users:(("postgres",pid=2345))
```

## Q24. Give me some `ip` command examples.

**Answer:**

```bash
ip addr                          # show IP addresses
ip -br addr                      # brief output
ip route                         # routing table
ip route get 1.1.1.1             # which route would be used
ip link set eth0 up
ip addr add 10.0.0.5/24 dev eth0
ip route add default via 10.0.0.1
```

## Q25. How do you diagnose connectivity?

**Answer:**

Walk the layers from the bottom up.

```bash
ping 8.8.8.8                       # is the network reachable?
ping example.com                   # does DNS work?
dig example.com                    # which IPs does DNS return?
traceroute example.com             # which hops; where it dies
mtr example.com                    # combined ping + traceroute
curl -v https://example.com        # full HTTP request/response
nc -vz example.com 443             # is the port open?
```

## Q26. iptables vs nftables vs ufw — what is the difference?

**Answer:**

- **iptables** is the older firewall framework. Still widely used.
- **nftables** is the modern replacement. Faster and unified.
- **ufw** (Uncomplicated Firewall) is a simple front-end that wraps iptables/nftables. Easy for common cases.

```bash
# ufw
sudo ufw allow 22/tcp
sudo ufw allow 80,443/tcp
sudo ufw enable
sudo ufw status verbose

# iptables
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
sudo iptables -L -n -v
```

## Q27. How do you find which process is using a port?

**Answer:**

```bash
sudo ss -tulpn | grep :80
# tcp LISTEN 0 511 0.0.0.0:80 0.0.0.0:* users:(("nginx",pid=1234,fd=6))

sudo lsof -i :80
sudo fuser 80/tcp
```

---

## 6. SSH

## Q28. How do you generate and use SSH keys?

**Answer:**

```bash
ssh-keygen -t ed25519 -C "you@example.com"
# Generates ~/.ssh/id_ed25519 (private) and ~/.ssh/id_ed25519.pub (public)

ssh-copy-id user@server
# Or manually: append id_ed25519.pub to remote ~/.ssh/authorized_keys (mode 600)
```

For better server security, disable password login:

```ini
# /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
```

```bash
sudo systemctl reload sshd
```

## Q29. Show me a useful `~/.ssh/config` example.

**Answer:**

The SSH client reads `~/.ssh/config` to remember per-host settings, so you can type `ssh prod` instead of a long command.

```text
Host prod
  HostName 10.0.0.5
  User deploy
  IdentityFile ~/.ssh/prod_ed25519
  Port 22

Host *.internal
  ProxyJump bastion
  User ubuntu

Host bastion
  HostName bastion.example.com
  User ec2-user
  IdentityFile ~/.ssh/bastion_ed25519
```

```bash
ssh prod
ssh db.internal     # transparently goes through bastion
```

## Q30. What is SSH tunneling?

**Answer:**

SSH tunneling forwards TCP connections through an SSH session. Useful to reach a service that is not exposed to the internet by going through a bastion host.

```bash
# Local forward: localhost:5433 -> remote db:5432 via bastion
ssh -L 5433:db:5432 bastion

# Remote forward: bastion:8080 -> my localhost:3000
ssh -R 8080:localhost:3000 bastion

# Dynamic (SOCKS proxy)
ssh -D 1080 bastion

# Background with no remote command
ssh -fN -L 5433:db:5432 bastion
```

## Q31. What is `ssh-agent`?

**Answer:**

`ssh-agent` is a small program that holds your private keys decrypted in memory so you do not have to type your passphrase every time.

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l                      # list loaded keys

# Forwarding (use carefully — gives the remote server access to your keys)
ssh -A user@server
```

---

## 7. Bash Scripting

## Q32. Show me a script template with safety flags.

**Answer:**

```bash
#!/usr/bin/env bash
set -euo pipefail
# -e exit on any error
# -u error on unset variable
# -o pipefail propagate errors through pipes

IFS=$'\n\t'

main() {
  echo "Hello, $1"
}

main "$@"
```

These flags catch a huge number of bugs early.

## Q33. How do you handle variables and quoting?

**Answer:**

```bash
name="alice"
greet="Hello, $name"        # double quotes expand variables
literal='Hello, $name'      # single quotes do not expand

# ALWAYS quote variables to avoid word splitting
file="my file.txt"
ls "$file"                  # correct
ls $file                    # WRONG: tries to ls "my" and "file.txt"
```

Command substitution:

```bash
today="$(date +%F)"
echo "$today"
```

## Q34. How do conditionals work?

**Answer:**

```bash
if [[ -f /etc/hosts ]]; then
  echo "exists"
elif [[ -d /etc ]]; then
  echo "etc dir exists"
else
  echo "neither"
fi

# Common test flags
# -f file exists and is regular
# -d directory
# -e exists
# -r readable
# -z empty string
# -n non-empty string
# str1 == str2 / != / < / >
# num1 -eq -ne -lt -le -gt -ge

[[ "$user" == "root" ]] && echo "you are root"
```

## Q35. How do loops work?

**Answer:**

```bash
for f in *.txt; do
  echo "$f"
done

for i in {1..5}; do
  echo "$i"
done

# C-style
for ((i=0; i<5; i++)); do
  echo "$i"
done

# while
i=0
while (( i < 3 )); do
  echo "$i"
  ((i++))
done

# Process command output line by line
while IFS= read -r line; do
  echo "Got: $line"
done < /etc/hosts
```

## Q36. How do functions work?

**Answer:**

```bash
greet() {
  local name="$1"
  echo "Hello, $name"
}

greet "alice"

# Return value via echo (capture with $())
add() {
  echo $(( $1 + $2 ))
}
sum=$(add 2 3)

# Exit code via return (0 = success)
is_root() {
  [[ "$EUID" -eq 0 ]]
}
if is_root; then echo "root"; fi
```

## Q37. How do arrays work in bash?

**Answer:**

```bash
# Indexed
files=(one.txt two.txt three.txt)
echo "${files[0]}"             # one.txt
echo "${#files[@]}"            # length: 3
for f in "${files[@]}"; do echo "$f"; done

# Associative (bash 4+)
declare -A user
user[name]="alice"
user[age]=30
echo "${user[name]}"
for key in "${!user[@]}"; do
  echo "$key=${user[$key]}"
done
```

## Q38. How do exit codes and traps work?

**Answer:**

Every command has an exit code. 0 means success, non-zero is failure. `$?` holds the exit code of the last command.

```bash
ls /nonexistent
echo "$?"        # 2

# Traps run on signals or shell exit
cleanup() {
  rm -f /tmp/lockfile
}
trap cleanup EXIT INT TERM

touch /tmp/lockfile
# ... do work ...
# on exit (any cause), cleanup runs
```

## Q39. What are heredocs?

**Answer:**

A heredoc lets you embed a multi-line string in a script.

```bash
cat > config.yml <<EOF
host: $(hostname)
port: 8080
EOF

# No expansion (literal): quote the marker
cat > script.sh <<'EOF'
echo "$HOME"     # literal, not expanded
EOF

# Indented (strips leading tabs): use <<-
cat <<-EOF
	indented
	with tabs
EOF
```

---

## 8. Text Processing

## Q40. What are the essentials of `grep`?

**Answer:**

```bash
grep "error" log.txt              # find lines containing "error"
grep -i "ERROR" log.txt           # case-insensitive
grep -v "debug" log.txt           # invert: lines NOT containing
grep -r "TODO" src/               # recursive
grep -n "panic" log.txt           # show line numbers
grep -E "warn|error" log.txt      # extended regex (or)
grep -A 3 -B 2 "error" log.txt    # 3 lines after, 2 before
grep -c "error" log.txt           # count matches
grep -l "secret" *.conf           # only filenames
```

Example:

```bash
grep -n "ERROR" /var/log/app.log
# 142:2025-05-05 10:32:11 ERROR connection refused
# 188:2025-05-05 10:35:01 ERROR timeout
```

## Q41. Give me some `sed` examples.

**Answer:**

`sed` is a stream editor — best for in-place text substitution.

```bash
sed 's/foo/bar/' file.txt          # replace first occurrence per line
sed 's/foo/bar/g' file.txt         # all occurrences
sed -i 's/foo/bar/g' file.txt      # edit file in place
sed -i.bak 's/foo/bar/g' file.txt  # in place with backup

sed -n '10,20p' file.txt           # print lines 10-20
sed '/^#/d' file.conf              # delete comment lines
sed '/^$/d' file.txt               # delete empty lines
```

## Q42. Give me some `awk` examples.

**Answer:**

`awk` is a small language for column-based text processing. Each line is split into fields ($1, $2, ...).

```bash
awk '{print $1, $3}' file.txt              # print columns 1 and 3
awk -F: '{print $1}' /etc/passwd           # split by ":"; print usernames
awk '$3 > 100 {print $0}' file.txt         # filter by column value
awk '{sum+=$1} END {print sum}' nums.txt   # sum first column

# Common one-liner: top 10 IP addresses in a log
awk '{print $1}' access.log | sort | uniq -c | sort -rn | head
```

## Q43. What other text tools should I know?

**Answer:**

```bash
sort file.txt              # alphabetical
sort -n file.txt           # numeric
sort -u file.txt           # remove duplicates
uniq                       # remove ADJACENT duplicates (sort first)
uniq -c                    # count duplicates
cut -d',' -f1,3 data.csv   # columns 1 and 3 of CSV
tr 'a-z' 'A-Z' < file      # transliterate (lowercase to upper)
wc -l file                 # count lines
head -n 20 file
tail -n 20 file
tail -f log                # follow new lines
```

## Q44. Give me a pipe example: top 10 IPs in an access log.

**Answer:**

```bash
awk '{print $1}' /var/log/nginx/access.log \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -10
```

Expected output:

```text
   142 192.168.1.10
    98 10.0.0.5
    87 203.0.113.4
   ...
```

---

## 9. File Operations

## Q45. Give me some `find` examples.

**Answer:**

```bash
find . -name "*.log"                       # by name
find . -iname "*.LOG"                      # case-insensitive
find . -type f -size +100M                 # files larger than 100MB
find . -mtime -7                           # modified in last 7 days
find /var/log -name "*.log" -mtime +30 -delete   # delete logs older than 30 days
find . -name "*.tmp" -exec rm {} \;        # exec for each match
find . -name "*.tmp" -exec rm {} +         # batch (faster)
find . -type d -empty                      # empty dirs
find . -user alice                         # by owner
```

## Q46. find vs locate?

**Answer:**

`find` searches the filesystem live — slower but always current.

`locate` queries a pre-built database — instant but may be stale. Update the DB with `sudo updatedb`.

```bash
locate nginx.conf
sudo updatedb
```

## Q47. What is `xargs`?

**Answer:**

`xargs` builds command lines from input. Useful when a tool does not accept input piped in.

```bash
find . -name "*.log" | xargs rm           # but breaks on filenames with spaces

# Better: NUL-terminated
find . -name "*.log" -print0 | xargs -0 rm

# Run in parallel
cat urls.txt | xargs -n 1 -P 8 curl -s
```

## Q48. How do you archive and compress files?

**Answer:**

```bash
# tar
tar -czf archive.tar.gz dir/        # create gzip
tar -cjf archive.tar.bz2 dir/       # bzip2
tar -cJf archive.tar.xz dir/        # xz
tar -tzf archive.tar.gz             # list contents
tar -xzf archive.tar.gz             # extract
tar -xzf archive.tar.gz -C /tmp     # extract to specific dir

# zip / unzip
zip -r archive.zip dir/
unzip archive.zip

# gzip a single file
gzip file.txt        # creates file.txt.gz, removes original
gunzip file.txt.gz
```

---

## 10. Package Management

## Q49. apt vs yum/dnf — what is the difference?

**Answer:**

- **apt** is used on Debian and Ubuntu.
- **yum** is the older RHEL/CentOS package manager. **dnf** is its modern replacement.

```bash
# Debian/Ubuntu
sudo apt update
sudo apt install nginx
sudo apt upgrade
sudo apt remove nginx
sudo apt list --installed
apt search keyword

# RHEL/Fedora
sudo dnf install nginx
sudo dnf update
sudo dnf remove nginx
sudo dnf list installed
dnf search keyword
```

---

## 11. Users and Cron

## Q50. How do you manage users and groups?

**Answer:**

```bash
sudo useradd -m -s /bin/bash alice    # create user with home, bash shell
sudo passwd alice                     # set password
sudo userdel -r alice                 # delete user and home

sudo groupadd devs
sudo usermod -aG devs alice           # add to group (-a is critical to APPEND)
groups alice                          # show alice's groups
id alice                              # uid, gid, groups
```

## Q51. What are the basics of `sudo`?

**Answer:**

`sudo` lets a user run a command as another user (usually root). Privilege rules live in `/etc/sudoers`. Edit only via `visudo` to avoid syntax errors that lock you out.

```bash
sudo visudo                  # safely edit sudoers
sudo -l                      # what can I run with sudo?
sudo -u alice command        # run as alice
sudo -i                      # full root login shell
```

Drop-in files in `/etc/sudoers.d/` are preferred for additions:

```text
# /etc/sudoers.d/devs
%devs ALL=(ALL) NOPASSWD: /bin/systemctl restart myapp
```

## Q52. How do environment variables and PATH work?

**Answer:**

```bash
echo "$PATH"                              # search path for executables
export FOO="bar"                          # set for current session and children
echo "$FOO"

# Persist
# ~/.bashrc, ~/.profile, /etc/environment, /etc/profile.d/*.sh

# Add a directory to PATH
export PATH="$HOME/bin:$PATH"

env                                       # show all environment variables
printenv FOO
```

`/etc/environment` is read by PAM at login; use it for system-wide vars. `/etc/profile.d/*.sh` is sourced by login shells.

## Q53. What is cron syntax?

**Answer:**

cron schedules periodic jobs. Each line in a crontab has five time fields plus a command.

```text
m h dom mon dow  command
* * * * *        every minute
0 * * * *        top of every hour
0 2 * * *        2:00 AM every day
*/15 * * * *     every 15 minutes
0 0 * * 0        midnight every Sunday
0 9 1 * *        9:00 AM on the 1st of each month
```

```bash
crontab -e         # edit your user's crontab
crontab -l         # show
sudo crontab -e -u www-data    # edit another user's crontab
```

System cron lives in `/etc/cron.d/`, `/etc/cron.daily/`, etc.

## Q54. What is `logrotate`?

**Answer:**

`logrotate` rotates, compresses, and prunes log files so they do not fill up disks. It runs daily via cron or a systemd timer.

```text
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 myapp myapp
    postrotate
        systemctl reload myapp >/dev/null 2>&1 || true
    endscript
}
```

```bash
sudo logrotate -d /etc/logrotate.d/myapp     # dry run
sudo logrotate -f /etc/logrotate.d/myapp     # force run
```

---

## 12. Monitoring and Troubleshooting

## Q55. How do you diagnose CPU issues?

**Answer:**

```bash
top                # interactive
htop               # nicer
uptime             # load averages over 1/5/15 min
mpstat -P ALL 1    # per-CPU usage (sysstat package)
pidstat 1          # per-process CPU usage
vmstat 1           # processes, memory, IO, CPU
```

A "load average" higher than the number of CPUs means more processes are waiting than your CPUs can serve.

## Q56. How do you diagnose memory issues?

**Answer:**

```bash
free -h            # quick summary
                   #               total  used  free  shared  buff/cache  available
                   # Mem:           7.7Gi 2.0Gi  3.2Gi 100Mi   2.5Gi       5.4Gi
vmstat 1
ps aux --sort=-%mem | head
cat /proc/meminfo
```

Pay attention to "available" rather than "free" — Linux uses free RAM for cache and reclaims it as needed.

## Q57. How do you diagnose disk issues?

**Answer:**

```bash
df -h                         # filesystem usage
df -i                         # inode usage
du -sh /var/*                 # sizes of subdirectories
du -h --max-depth=1 / 2>/dev/null | sort -h
iostat -xz 1                  # I/O stats per device
iotop                         # interactive I/O per process
ncdu /                        # interactive disk usage explorer
lsblk                         # block devices
```

## Q58. `df` shows space but I get "No space left on device". Why?

**Answer:**

Two common causes:

1. **Inodes are exhausted.** Tons of tiny files have used up all inodes. Check with `df -i`.
2. **Open deleted files.** A process is still holding a file that has been deleted from the filesystem; the disk space is not freed until the process closes the file.

```bash
df -i                                       # check inodes
sudo lsof +L1                               # files with link count 0 (deleted but open)
sudo lsof | grep deleted | head
```

Restarting the holding process releases the space.

## Q59. The system is under high load — how do you investigate?

**Answer:**

```bash
uptime                                  # load averages
top  -o %CPU                            # by CPU
top  -o %MEM                            # by memory
ps auxf --sort=-%cpu | head             # top CPU users
vmstat 1                                # context switches, run queue
iostat -xz 1                            # disk wait
ss -s                                   # socket summary
dmesg -T | tail                         # kernel messages
```

Decide whether the bottleneck is CPU, memory, disk, or network, then drill down with the appropriate tool.

## Q60. How do you diagnose an out-of-memory situation?

**Answer:**

```bash
free -h
dmesg -T | grep -i "killed process"      # OOM killer victims
journalctl -k | grep -i "out of memory"
ps aux --sort=-%mem | head
```

The Linux OOM killer terminates a process when memory is exhausted. The `oom_score` of each process determines the victim.

## Q61. What is a network troubleshooting checklist?

**Answer:**

1. Local interface up? `ip -br link`
2. IP assigned? `ip -br addr`
3. Default route? `ip route`
4. DNS works? `dig example.com`
5. Reach the host? `ping example.com`
6. Reach the port? `nc -vz example.com 443`
7. HTTP layer OK? `curl -v https://example.com`
8. Firewall? `sudo iptables -L -n` or `sudo ufw status`

## Q62. What are the common log locations?

**Answer:**

| Log                    | Path                              |
| ---------------------- | --------------------------------- |
| Authentication / sudo  | `/var/log/auth.log` (Debian) or `/var/log/secure` (RHEL) |
| Kernel                 | `/var/log/kern.log` or `dmesg`    |
| System / general       | `/var/log/syslog` or `/var/log/messages` |
| Nginx                  | `/var/log/nginx/`                 |
| Apache                 | `/var/log/apache2/`               |
| Mail                   | `/var/log/mail.log`               |
| Boot                   | `/var/log/boot.log`               |

On systemd-based systems, prefer `journalctl`.

## Q63. How do you tune kernel parameters?

**Answer:**

Kernel parameters live under `/proc/sys` and are configured with `sysctl`.

```bash
# View
sysctl net.ipv4.ip_forward
cat /proc/sys/net/ipv4/ip_forward

# Temporary
sudo sysctl -w net.ipv4.ip_forward=1

# Persist
echo "net.ipv4.ip_forward = 1" | sudo tee /etc/sysctl.d/99-custom.conf
sudo sysctl --system
```

Common knobs: `vm.swappiness`, `net.core.somaxconn`, `net.ipv4.tcp_tw_reuse`, `fs.file-max`.

## Q64. What is `ulimit` and why does it matter?

**Answer:**

`ulimit` shows or sets per-process resource limits, such as the max number of open file descriptors. Many production issues ("Too many open files") come from default limits.

```bash
ulimit -a               # show all
ulimit -n               # max open files (often 1024 default)
ulimit -n 65535         # raise for current session

# Persistent system limits
# /etc/security/limits.conf
# myapp soft nofile 65535
# myapp hard nofile 65535

# For systemd services, set in the unit:
# LimitNOFILE=65535
```

## Q65. What is a sensible Linux production checklist?

**Answer:**

- SSH: key auth only, root login disabled, fail2ban or similar.
- Firewall configured (`ufw` / `nftables`).
- Automatic security updates enabled.
- Time synced via `chrony` or `systemd-timesyncd`.
- Logs rotating with `logrotate`; journald disk usage capped.
- Application as a non-root user with a tight systemd unit.
- Backups of `/etc`, application data, and databases — tested.
- Monitoring: load, memory, disk, log errors.
- `ulimit -n` raised for high-traffic services.
- Swap configured appropriately for the workload.

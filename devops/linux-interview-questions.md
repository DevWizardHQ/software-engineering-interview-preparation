# Linux Interview Questions

**Level:** Mid to Senior
**Topics:** Filesystem, Permissions, Processes, Systemd, Networking, SSH, Bash, Text Processing, Troubleshooting

---

## Table of Contents

1. [Filesystem and FHS](#filesystem-and-fhs)
2. [Permissions](#permissions)
3. [Processes and Signals](#processes-and-signals)
4. [Services and Systemd](#services-and-systemd)
5. [Networking](#networking)
6. [SSH](#ssh)
7. [Bash Scripting](#bash-scripting)
8. [Text Processing](#text-processing)
9. [File Operations](#file-operations)
10. [Package Management](#package-management)
11. [Users and Cron](#users-and-cron)
12. [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)

---

## Filesystem and FHS

### Q1. What is the Filesystem Hierarchy Standard (FHS)?

**Answer:**
A convention for the directory layout of Linux systems.

| Path | Purpose |
|------|---------|
| `/` | Root |
| `/bin`, `/usr/bin` | Essential user binaries |
| `/sbin`, `/usr/sbin` | System binaries (often root-only) |
| `/etc` | System configuration |
| `/home` | User home directories |
| `/var` | Variable data — logs, mail, spool |
| `/var/log` | System logs |
| `/tmp` | Temporary, world-writable, often cleared on reboot |
| `/opt` | Optional/third-party software |
| `/usr` | Read-only user data — most binaries, libs, docs |
| `/lib`, `/usr/lib` | Shared libraries |
| `/proc` | Virtual fs exposing kernel/process info |
| `/sys` | Virtual fs exposing devices/kernel |
| `/dev` | Device files |
| `/boot` | Kernel and bootloader |
| `/mnt`, `/media` | Mount points |
| `/root` | Root user's home |
| `/run` | Runtime state (PID files, sockets) |

---

### Q2. What is an inode?

**Answer:**
A data structure storing metadata for a file: permissions, owner, size, timestamps, and pointers to data blocks. The filename lives in a directory entry that maps name → inode.

```bash
ls -i file.txt    # show inode
df -i             # inode usage per filesystem
stat file.txt     # full inode info
```

You can run out of inodes even with disk space free (millions of tiny files).

---

### Q3. Hard link vs symbolic link?

| | Hard link | Symbolic (soft) link |
|---|---|---|
| Points to | Inode | Path |
| Across filesystems | No | Yes |
| Survives target deletion | Yes (shares inode) | Becomes broken |
| Directories | Not allowed (typically) | Allowed |
| Created by | `ln src link` | `ln -s src link` |

---

### Q4. What is `/proc`?

**Answer:**
A virtual filesystem exposing kernel and process state.

```bash
cat /proc/cpuinfo
cat /proc/meminfo
cat /proc/<pid>/status
cat /proc/<pid>/limits
cat /proc/sys/net/ipv4/tcp_keepalive_time
ls /proc/<pid>/fd        # open file descriptors
```

`/proc/sys` lets you tune kernel parameters at runtime; persist them in `/etc/sysctl.conf` or `/etc/sysctl.d/`.

---

## Permissions

### Q5. Explain Linux file permissions.

**Answer:**
Three classes (owner, group, other) × three perms (read, write, execute).

```
-rwxr-xr--
```

| Char | Octal | Meaning |
|------|-------|---------|
| r | 4 | read |
| w | 2 | write |
| x | 1 | execute (or traverse for dir) |

`rwxr-xr--` = `754` (7 owner, 5 group, 4 other).

---

### Q6. `chmod` examples?

```bash
chmod 644 file              # rw-r--r--
chmod 755 script.sh         # rwxr-xr-x
chmod u+x script.sh         # add execute for owner
chmod g-w file              # remove write for group
chmod o= file               # remove all for others
chmod -R 750 dir            # recursive
chmod a+r file              # all (ugo) read
```

---

### Q7. `chown` and `chgrp`?

```bash
chown alice file
chown alice:devs file       # owner and group
chown -R alice:devs /srv/app
chgrp devs file
```

---

### Q8. What is `umask`?

**Answer:**
The default permission mask for newly created files. Subtracted from base permissions (666 for files, 777 for dirs).

```bash
umask         # show current
umask 022     # default for many systems → files 644, dirs 755
umask 077     # files 600, dirs 700 (private)
```

Set persistently in `/etc/profile`, `~/.bashrc`.

---

### Q9. SUID, SGID, sticky bit?

| Bit | Octal | On file | On dir |
|-----|-------|---------|--------|
| SUID | 4000 | Executes as file's owner | n/a |
| SGID | 2000 | Executes as file's group | New files inherit dir's group |
| Sticky | 1000 | n/a | Only owner can delete files (e.g., `/tmp`) |

```bash
chmod u+s /usr/bin/passwd     # SUID
chmod g+s /srv/shared          # SGID
chmod +t /tmp                  # sticky
ls -l                          # shows s/t in perms
```

`passwd` uses SUID to update `/etc/shadow` as root. SUID on shell scripts is ignored for security.

---

### Q10. POSIX ACLs?

**Answer:**
Fine-grained permissions beyond owner/group/other.

```bash
getfacl file
setfacl -m u:bob:rwx file
setfacl -x u:bob file
setfacl -d -m g:devs:rx /srv/proj   # default ACL for new files in dir
```

The `+` after permissions in `ls -l` indicates ACLs are present.

---

## Processes and Signals

### Q11. View processes?

```bash
ps aux                        # all processes
ps -ef                        # alternate format
ps -eo pid,ppid,user,%cpu,%mem,cmd --sort=-%cpu | head
top                           # interactive
htop                          # better top
pgrep -fl node                # find by name
pidof nginx
```

---

### Q12. Common kill signals?

| Signal | Number | Default behavior |
|--------|--------|------------------|
| SIGTERM | 15 | Polite termination (default) |
| SIGKILL | 9 | Force kill (uncatchable) |
| SIGINT | 2 | Ctrl+C |
| SIGHUP | 1 | Hangup; often used to reload config |
| SIGSTOP | 19 | Pause (uncatchable) |
| SIGCONT | 18 | Resume |
| SIGUSR1/2 | 10/12 | App-defined |
| SIGQUIT | 3 | Quit + core dump |

```bash
kill 1234            # SIGTERM
kill -9 1234         # SIGKILL — last resort
kill -HUP 1234       # reload
killall nginx
pkill -f "node worker"
```

---

### Q13. Process states?

| State | Meaning |
|-------|---------|
| R | Running or runnable |
| S | Interruptible sleep |
| D | Uninterruptible sleep (usually I/O) — can't kill, even with -9 |
| Z | Zombie (dead, parent hasn't reaped) |
| T | Stopped |
| < / N | High / low priority |

`D`-state processes typically indicate stuck I/O (failing disk, NFS).

---

### Q14. What is a zombie process?

**Answer:**
A child that exited but whose parent hasn't called `wait()`. It holds an entry in the process table but no resources. Many zombies indicate a buggy parent. Reparenting to PID 1 (`init`/`systemd`) usually cleans them up.

---

### Q15. Foreground vs background?

```bash
long_running_cmd &           # background
jobs                          # list jobs
fg %1                         # bring to foreground
bg %1                         # resume in background
disown %1                     # detach from shell
nohup cmd &                   # immune to HUP
Ctrl+Z                        # suspend → SIGTSTP
```

For long-running commands across logout: `nohup`, `tmux`, `screen`, or systemd unit.

---

### Q16. Process vs thread?

**Answer:**
- **Process** — independent address space, own PID, isolated memory.
- **Thread** — shares address space with siblings inside a process; LWP (light-weight process) on Linux.

`ps -eLf` shows threads. `top -H` shows threads too.

---

## Services and Systemd

### Q17. What is systemd?

**Answer:**
The default init system on most modern distros. Manages services (units), sockets, timers, mounts, etc. Replaces SysV init, Upstart.

---

### Q18. Common systemctl commands?

```bash
systemctl status nginx
systemctl start nginx
systemctl stop nginx
systemctl restart nginx
systemctl reload nginx        # SIGHUP — config reload
systemctl enable nginx        # start on boot
systemctl disable nginx
systemctl is-active nginx
systemctl is-enabled nginx
systemctl list-units --type=service
systemctl list-units --failed
systemctl daemon-reload       # after editing unit files
```

---

### Q19. Sample systemd unit?

```ini
# /etc/systemd/system/myapp.service
[Unit]
Description=My App
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=app
Group=app
WorkingDirectory=/srv/myapp
EnvironmentFile=/etc/myapp/env
ExecStart=/usr/bin/node /srv/myapp/server.js
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now myapp
```

---

### Q20. journalctl basics?

```bash
journalctl -u nginx                  # for a unit
journalctl -u nginx -f               # follow
journalctl -u nginx --since "1 hour ago"
journalctl -u nginx -n 100 --no-pager
journalctl -p err                    # priority error+
journalctl --disk-usage
journalctl --vacuum-time=7d          # prune
```

Persistent logs require `Storage=persistent` in `/etc/systemd/journald.conf` and `/var/log/journal` to exist.

---

### Q21. Systemd timer vs cron?

**Answer:**
Both schedule jobs. Timers offer:
- Logs in journal.
- Dependencies on other units.
- Accurate accounting (handles missed runs with `Persistent=true`).
- Resource limits.

```ini
# myjob.timer
[Unit]
Description=Daily job

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

Pair with `myjob.service`. `systemctl list-timers` shows next run.

---

## Networking

### Q22. Modern vs legacy networking commands?

| Legacy | Modern |
|--------|--------|
| `ifconfig` | `ip addr`, `ip link` |
| `route` | `ip route` |
| `netstat` | `ss` |
| `arp` | `ip neigh` |
| `iptables` | `nftables`, `iptables` (still common) |

Prefer modern tools — they're maintained and faster.

---

### Q23. `ss` examples?

```bash
ss -tulpn                  # TCP/UDP listening with PIDs
ss -tan                    # all TCP
ss -s                      # summary
ss -tn state established
ss dst :443                # connections to port 443
```

---

### Q24. `ip` command examples?

```bash
ip addr                    # all interfaces
ip -br addr                # brief
ip link show
ip route
ip route add 10.0.0.0/24 via 192.168.1.1
ip route get 8.8.8.8       # which path?
ip neigh                   # ARP cache
```

---

### Q25. Diagnose connectivity?

```bash
ping host
ping -c 4 host
traceroute host            # path
mtr host                   # continuous traceroute
dig example.com            # DNS
dig +short example.com
dig @8.8.8.8 example.com   # query specific resolver
nslookup example.com
host example.com
curl -v https://api.example.com
curl -I https://api.example.com           # headers only
curl -w "%{http_code} %{time_total}\n" -o /dev/null -s url
nc -zv host 443            # TCP port reachable?
telnet host 443            # legacy alternative
```

---

### Q26. iptables vs nftables vs ufw?

**Answer:**
- **iptables** — classic packet filter; many tutorials still use it.
- **nftables** — modern replacement; unified syntax for IPv4/IPv6/ARP.
- **ufw** — user-friendly frontend (Ubuntu).
- **firewalld** — frontend on RHEL/CentOS/Fedora.

```bash
# ufw
ufw allow 22/tcp
ufw allow from 10.0.0.0/8 to any port 5432
ufw enable
ufw status verbose

# iptables
iptables -L -n -v
iptables -A INPUT -p tcp --dport 22 -j ACCEPT
```

---

### Q27. Find what process is using a port?

```bash
ss -tulpn | grep :3000
lsof -iTCP:3000 -sTCP:LISTEN
fuser 3000/tcp
```

---

## SSH

### Q28. Generate and use SSH keys?

```bash
ssh-keygen -t ed25519 -C "alice@example.com"   # ~/.ssh/id_ed25519
ssh-copy-id user@host                          # install to remote
# or manually: append id_ed25519.pub to ~/.ssh/authorized_keys (mode 600)
```

Use ed25519 (or rsa-4096 if compatibility needed). Always disable password auth in production:
```
# /etc/ssh/sshd_config
PasswordAuthentication no
PermitRootLogin no
```

---

### Q29. `~/.ssh/config` example?

```
Host bastion
  HostName bastion.example.com
  User alice
  IdentityFile ~/.ssh/id_ed25519

Host db-prod
  HostName 10.0.5.10
  User ubuntu
  ProxyJump bastion
  IdentityFile ~/.ssh/id_prod
  ServerAliveInterval 60
```

```bash
ssh db-prod
```

---

### Q30. SSH tunneling?

```bash
# Local forward: localhost:5433 → remote db:5432 via bastion
ssh -L 5433:db-internal:5432 bastion

# Remote forward: bastion:8080 → my localhost:3000
ssh -R 8080:localhost:3000 bastion

# Dynamic (SOCKS proxy)
ssh -D 1080 bastion

# Background with no remote command
ssh -fN -L 5433:db:5432 bastion
```

---

### Q31. ssh-agent?

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l
ssh -A user@host           # forward agent (use cautiously)
```

Avoid `-A` to untrusted hosts — they can use your loaded keys.

---

## Bash Scripting

### Q32. Script template with safety flags?

```bash
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# -e exit on error
# -u error on unset variable
# -o pipefail propagate errors through pipes
```

---

### Q33. Variables and quoting?

```bash
name="alice"
echo "Hello, $name"            # double quotes interpolate
echo 'Hello, $name'            # single quotes literal
echo "Files: $(ls | wc -l)"    # command substitution
count=$(( 5 + 3 ))             # arithmetic
echo "${name:-default}"        # default if unset
echo "${name:=default}"        # assign default
echo "${name:?must be set}"    # error if unset
echo "${file##*/}"             # basename
echo "${file%.*}"              # remove extension
```

Always quote variables with spaces: `"$var"`, especially in tests and arguments.

---

### Q34. Conditionals?

```bash
if [[ -f "$file" ]]; then
  echo "file exists"
elif [[ -d "$file" ]]; then
  echo "dir"
else
  echo "missing"
fi

# Common test flags
[[ -e path ]]  # exists
[[ -f path ]]  # regular file
[[ -d path ]]  # directory
[[ -r path ]]  # readable
[[ -w path ]]  # writable
[[ -x path ]]  # executable
[[ -z $s   ]]  # empty string
[[ -n $s   ]]  # non-empty
[[ $a == $b ]] # equal
[[ $a != $b ]]
[[ $n -eq 5 ]] # numeric equal (-ne -lt -le -gt -ge)
[[ $s =~ ^[0-9]+$ ]] # regex
```

Use `[[ ]]` (bash) over `[ ]` (POSIX) — safer with strings and supports regex.

---

### Q35. Loops?

```bash
for f in *.txt; do
  echo "$f"
done

for i in {1..10}; do echo $i; done
for ((i=0; i<10; i++)); do echo $i; done

while read -r line; do
  echo "$line"
done < file.txt

# Process command output line by line
while IFS= read -r line; do
  echo ">> $line"
done < <(ls)
```

---

### Q36. Functions?

```bash
log() {
  local level=$1
  shift
  printf '[%s] %s\n' "$level" "$*" >&2
}

log INFO "starting"

# Return value via echo (capture with $())
sum() { echo $(( $1 + $2 )); }
total=$(sum 3 4)

# Exit code via return
is_root() { [[ $EUID -eq 0 ]]; }
if is_root; then ...; fi
```

---

### Q37. Arrays?

```bash
arr=(one two three)
echo "${arr[0]}"
echo "${arr[@]}"            # all elements
echo "${#arr[@]}"           # length
arr+=(four)                 # append

# Associative (bash 4+)
declare -A map
map[name]=alice
map[role]=admin
echo "${map[name]}"
for k in "${!map[@]}"; do echo "$k=${map[$k]}"; done
```

---

### Q38. Exit codes and traps?

```bash
cmd
echo $?              # exit code of last command (0 = success)

cleanup() {
  rm -f /tmp/work.$$
}
trap cleanup EXIT
trap 'echo "interrupted"; exit 130' INT TERM
```

Common conventions: 0 success, 1 generic, 2 misuse, 126 not executable, 127 not found, 128+N killed by signal N.

---

### Q39. Heredocs?

```bash
cat <<EOF > config.yml
host: $HOST
port: 5432
EOF

# No expansion (literal)
cat <<'EOF' > script.sh
echo "$VAR is literal"
EOF

# Indented (strips leading tabs)
cat <<-EOF
	indented
EOF
```

---

## Text Processing

### Q40. grep essentials?

```bash
grep "pattern" file
grep -i "case insensitive" file
grep -r "TODO" src/                 # recursive
grep -rn "TODO" src/                # with line numbers
grep -v "exclude" file              # invert
grep -c "pattern" file              # count
grep -l "pattern" *.log             # files matching
grep -E "foo|bar" file              # extended regex
grep -P "\d+" file                  # Perl regex
grep -A 3 -B 1 "error" log          # context
grep --color=auto -n "pattern" file
```

For huge codebases, use `ripgrep` (`rg`) — faster, respects `.gitignore`.

---

### Q41. sed examples?

```bash
sed 's/old/new/' file               # first per line
sed 's/old/new/g' file              # all per line
sed -i 's/old/new/g' file           # in-place
sed -i.bak 's/old/new/g' file       # in-place with backup
sed -n '5,10p' file                 # print lines 5-10
sed '/^#/d' file                    # delete comment lines
sed 's|/usr/bin|/usr/local/bin|g' file   # alt delimiter
sed -E 's/[0-9]+/N/g' file          # extended regex
```

---

### Q42. awk examples?

```bash
awk '{print $1}' file               # first column (whitespace)
awk -F',' '{print $2}' file.csv     # CSV
awk '$3 > 100' file                 # rows where col 3 > 100
awk '{sum += $1} END {print sum}' file
awk '/error/ {print}' file
awk 'NR==1 {next} {print}' file     # skip header

# Common one-liner: sum group counts
awk '{count[$1]++} END {for (k in count) print k, count[k]}' file
```

---

### Q43. Other text tools?

```bash
cut -d',' -f1,3 file.csv
cut -c1-10 file              # chars 1-10
sort file                     # sort lines
sort -n file                  # numeric
sort -k2,2 file               # by column 2
sort -u file                  # unique
uniq                          # only adjacent dups; usually after sort
sort file | uniq -c | sort -rn  # frequency count
tr 'a-z' 'A-Z' < file         # uppercase
tr -d '\r' < winfile          # strip CR
head -n 20 file
tail -n 20 file
tail -f file                  # follow
wc -l file                    # line count
```

---

### Q44. Pipe example: top 10 IPs in access log?

```bash
awk '{print $1}' access.log \
  | sort \
  | uniq -c \
  | sort -rn \
  | head -10
```

---

## File Operations

### Q45. find examples?

```bash
find . -name "*.log"
find . -iname "*.LOG"                # case-insensitive
find /var/log -type f -mtime +7      # modified > 7 days ago
find . -size +100M                   # bigger than 100M
find . -name "*.tmp" -delete
find . -type f -name "*.sh" -exec chmod +x {} \;
find . -type f -name "*.txt" -exec grep -l "TODO" {} +
find . -newer reference.txt
find . -user alice -group devs
find . -empty
find . -maxdepth 2 -type d
```

`-exec ... +` batches, much faster than `\;` per-file.

---

### Q46. find vs locate?

**Answer:**
- `find` — live filesystem scan; accurate, slower.
- `locate` — queries a precomputed database (`updatedb`); fast but stale.

---

### Q47. xargs?

```bash
find . -name "*.log" -print0 | xargs -0 rm
echo "1 2 3" | xargs -n 1 echo
ls *.txt | xargs -I {} mv {} archive/{}
xargs -P 4 -I {} curl {} < urls.txt   # parallel, 4 at a time
```

Always use `-print0` and `-0` to handle filenames with spaces/newlines safely.

---

### Q48. Archive and compression?

```bash
# tar
tar -czf out.tar.gz dir/             # create gzip
tar -cjf out.tar.bz2 dir/            # bzip2
tar -cJf out.tar.xz dir/             # xz
tar -tzf out.tar.gz                  # list
tar -xzf out.tar.gz                  # extract
tar -xzf out.tar.gz -C /opt          # extract into dir

# zip / unzip
zip -r out.zip dir/
unzip out.zip

# gzip a single file
gzip file        # → file.gz
gunzip file.gz
```

---

## Package Management

### Q49. apt vs yum/dnf?

| Action | Debian/Ubuntu (apt) | RHEL/CentOS/Fedora (dnf) |
|--------|---------------------|--------------------------|
| Update index | `apt update` | `dnf check-update` |
| Upgrade all | `apt upgrade` | `dnf upgrade` |
| Install | `apt install pkg` | `dnf install pkg` |
| Remove | `apt remove pkg` | `dnf remove pkg` |
| Purge configs | `apt purge pkg` | n/a |
| Search | `apt search term` | `dnf search term` |
| Info | `apt show pkg` | `dnf info pkg` |
| List installed | `dpkg -l` | `rpm -qa` |
| File → package | `dpkg -S /path` | `rpm -qf /path` |
| Package contents | `dpkg -L pkg` | `rpm -ql pkg` |

`yum` is the older RHEL package manager; `dnf` is its modern replacement.

---

## Users and Cron

### Q50. User and group management?

```bash
useradd -m -s /bin/bash alice
passwd alice
usermod -aG docker,sudo alice         # add to groups (-a important!)
groups alice
id alice
deluser alice
groupadd devs
gpasswd -a alice devs
```

User info: `/etc/passwd`. Groups: `/etc/group`. Hashed passwords: `/etc/shadow`.

---

### Q51. sudo basics?

**Answer:**
Run commands as another user (default root) per rules in `/etc/sudoers`. Edit only with `visudo`.

```
# /etc/sudoers.d/devs
%devs ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart myapp
alice ALL=(ALL:ALL) ALL
```

```bash
sudo -u postgres psql
sudo -i                   # root shell
sudo -E cmd               # preserve env
```

---

### Q52. Environment variables and PATH?

```bash
echo $PATH
export FOO=bar             # export to children
unset FOO
env                        # show all
printenv FOO

# Persist
# ~/.bashrc, ~/.profile, /etc/environment, /etc/profile.d/*.sh
```

`PATH` is colon-separated. `which cmd` finds first match; `type cmd` shows aliases/functions too.

---

### Q53. cron syntax?

```
# m h dom mon dow  command
*/5 * * * *  /usr/local/bin/check.sh   # every 5 min
0 2 * * *    /opt/backup.sh            # daily 02:00
0 0 1 * *    /opt/monthly.sh           # monthly
@reboot      /opt/init.sh
```

```bash
crontab -e            # edit user crontab
crontab -l            # list
crontab -r            # remove
```

System cron: `/etc/crontab` and `/etc/cron.{hourly,daily,weekly,monthly}`. Cron has minimal env — set `PATH` and use absolute paths. Capture errors:

```
0 2 * * * /opt/backup.sh >> /var/log/backup.log 2>&1
```

---

### Q54. logrotate?

```
# /etc/logrotate.d/myapp
/var/log/myapp/*.log {
  daily
  rotate 14
  missingok
  notifempty
  compress
  delaycompress
  copytruncate
  postrotate
    systemctl reload myapp >/dev/null 2>&1 || true
  endscript
}
```

Test: `logrotate -d /etc/logrotate.d/myapp` (dry run).

---

## Monitoring and Troubleshooting

### Q55. CPU diagnostics?

```bash
top                        # interactive
htop                       # better
uptime                     # load averages
vmstat 1 5                 # 5 samples, 1s apart
mpstat -P ALL 1            # per-CPU
pidstat 1                  # per-process
```

**Load average** — runnable + uninterruptible processes averaged over 1/5/15 min. > number of cores = saturation.

---

### Q56. Memory diagnostics?

```bash
free -h
cat /proc/meminfo
ps aux --sort=-%mem | head
smem -tk                   # better breakdown (PSS, USS)
slabtop                    # kernel slab allocator
```

`free` shows `available` — what apps can use without swapping. `buff/cache` is reclaimable.

---

### Q57. Disk diagnostics?

```bash
df -h                      # filesystem usage
df -i                      # inodes
du -sh *                   # per-entry size
du -h --max-depth=1 /var | sort -h
ncdu /                     # interactive
iostat -xz 1               # per-device I/O
iotop                      # per-process I/O
lsblk
mount | column -t
```

---

### Q58. "No space left on device" but `df` shows space?

**Answer:** Usually inodes are exhausted.
```bash
df -i
find / -xdev -type f | awk -F/ '{print $2}' | sort | uniq -c | sort -rn | head
```

Common culprit: millions of files under `/var/lib/docker`, `/tmp`, or session stores.

---

### Q59. High load — how to investigate?

1. `uptime` — load averages.
2. `top -o %CPU` and `top -o %MEM`.
3. `vmstat 1` — `r` column = runnable processes; `b` = blocked on I/O; `wa` = % time waiting on I/O.
4. `iostat -xz 1` — `%util` close to 100 means disk-bound.
5. `pidstat -d 1` — per-process I/O.
6. `dmesg -T | tail` — OOM killer? hardware errors?
7. `journalctl -p err -S "1 hour ago"`.

---

### Q60. Out of memory — diagnosis?

```bash
dmesg -T | grep -i "out of memory"
journalctl -k | grep -i oom
ps aux --sort=-%mem | head
```

OOM killer logs which process was killed. Set `vm.overcommit_memory`, `cgroup` limits, or swap appropriately.

---

### Q61. Network troubleshooting checklist?

1. **DNS** — `dig host`, `getent hosts host`.
2. **Reachability** — `ping`, `traceroute`, `mtr`.
3. **Port** — `nc -zv host port`, `ss -tulpn`.
4. **TLS** — `openssl s_client -connect host:443 -servername host`.
5. **HTTP** — `curl -v`, `curl -w "%{http_code} %{time_total}\n"`.
6. **Local firewall** — `iptables -L -n -v`, `ufw status`.
7. **Cloud security groups** / NACLs.
8. **Routing** — `ip route get target`.
9. **Packet capture** — `tcpdump -i any -nn port 443 -w out.pcap`.

---

### Q62. Common log locations?

| Log | Path |
|-----|------|
| Auth | `/var/log/auth.log` (Debian), `/var/log/secure` (RHEL) |
| Kernel | `/var/log/kern.log`, `dmesg` |
| Syslog | `/var/log/syslog`, `/var/log/messages` |
| systemd | `journalctl -u <unit>` |
| Web | `/var/log/nginx/`, `/var/log/apache2/` |
| Cron | `/var/log/cron`, `journalctl -u cron` |
| Boot | `/var/log/boot.log`, `journalctl -b` |

Always tail with `journalctl -f` or `tail -F` (capital F handles rotation).

---

### Q63. Kernel parameters tuning?

```bash
# View
sysctl net.core.somaxconn
cat /proc/sys/net/core/somaxconn

# Temporary
sysctl -w net.core.somaxconn=4096

# Persist
echo "net.core.somaxconn=4096" >> /etc/sysctl.d/99-tune.conf
sysctl --system
```

Common production tunables: `net.core.somaxconn`, `net.ipv4.tcp_tw_reuse`, `vm.swappiness`, `fs.file-max`, `net.ipv4.ip_local_port_range`.

---

### Q64. `ulimit` and resource limits?

```bash
ulimit -a            # current
ulimit -n            # open files (default often 1024)
ulimit -n 65536      # raise for current shell
```

Persist in `/etc/security/limits.conf`:
```
*       soft    nofile  65536
*       hard    nofile  65536
```

For systemd units, set `LimitNOFILE=` in the `[Service]` section.

---

### Q65. Senior-level production checklist?

- [ ] Time sync (chronyd/ntpd) running.
- [ ] Logs rotated, persisted, and shipped to central store.
- [ ] Monitoring (CPU, mem, disk, net, app metrics) and alerts.
- [ ] SSH hardened — keys only, no root login, fail2ban.
- [ ] Firewall configured.
- [ ] Unattended security upgrades.
- [ ] Backup and tested restore procedure.
- [ ] Regular CVE patching cycle.
- [ ] Resource limits per service.
- [ ] systemd unit with `Restart=` and proper user.
- [ ] Health checks and runbooks.
- [ ] Configuration in version control (Ansible/Terraform/Chef).

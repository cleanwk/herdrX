#include "PTY.h"
#include <util.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <libproc.h>
#include <string.h>
#include <sys/ioctl.h>
#include <spawn.h>

// Own a process group so timeout/cancellation can stop shell children too.
pid_t herd_command(const char *file, char *const argv[], char *const env[], int input, int output, int error) {
    posix_spawnattr_t attr;
    posix_spawn_file_actions_t actions;
    posix_spawnattr_init(&attr); posix_spawn_file_actions_init(&actions);
    sigset_t empty, defaults; sigemptyset(&empty); sigemptyset(&defaults);
    sigaddset(&defaults, SIGTERM); sigaddset(&defaults, SIGINT); sigaddset(&defaults, SIGHUP);
    posix_spawnattr_setsigmask(&attr, &empty); posix_spawnattr_setsigdefault(&attr, &defaults);
    posix_spawnattr_setpgroup(&attr, 0);
    posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF | POSIX_SPAWN_CLOEXEC_DEFAULT);
    posix_spawn_file_actions_adddup2(&actions, input, 0);
    posix_spawn_file_actions_adddup2(&actions, output, 1);
    posix_spawn_file_actions_adddup2(&actions, error, 2);
    pid_t pid = -1;
    int result = posix_spawn(&pid, file, &actions, &attr, argv, env);
    posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attr);
    return result == 0 ? pid : -1;
}
pid_t herd_pty(int *master, const char *file, char *const argv[], char *const env[]) {
    struct winsize size = {.ws_row = 24, .ws_col = 80};
    pid_t pid = forkpty(master, NULL, NULL, &size);
    if (pid == 0) {
        sigset_t signals; sigemptyset(&signals); sigprocmask(SIG_SETMASK, &signals, NULL);
        execve(file, argv, env); _exit(127);
    }
    if (pid > 0) { fcntl(*master, F_SETFD, FD_CLOEXEC); fcntl(*master, F_SETFL, O_NONBLOCK); }
    return pid;
}
int herd_cwd(pid_t pid, char *buffer, int size) {
    struct proc_vnodepathinfo info;
    if (proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &info, sizeof(info)) != sizeof(info)) return 0;
    strlcpy(buffer, info.pvi_cdir.vip_path, size); return 1;
}

int herd_is_shell(int pid) {
    struct proc_bsdinfo info;
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, sizeof(info)) != sizeof(info)) return 0;
    return !strcmp(info.pbi_comm, "zsh") || !strcmp(info.pbi_comm, "bash") || !strcmp(info.pbi_comm, "fish") || !strcmp(info.pbi_comm, "sh");
}

#include "PTY.h"
#include <util.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <libproc.h>
#include <string.h>
#include <sys/ioctl.h>
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

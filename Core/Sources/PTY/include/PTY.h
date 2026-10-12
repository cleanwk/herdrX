#pragma once
#include <sys/types.h>
pid_t herd_pty(int *master, const char *file, char *const argv[], char *const env[]);
int herd_cwd(pid_t pid, char *buffer, int size);

int herd_is_shell(int pid);
pid_t herd_command(const char *file, char *const argv[], char *const env[], int input, int output, int error);

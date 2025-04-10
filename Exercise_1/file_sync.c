#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <wait.h>
#include <limits.h>
#include <time.h>

#define MAX_FILES 100
#define MAX_FILENAME 256
#define MAX_PATH 1024

// Alphabetical sort
int compare(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

// Check if file exists
int file_exists(const char *path) {
    struct stat st;
    return stat(path, &st) == 0;
}

// Check if path is a regular file
int is_regular_file(const char *path) {
    struct stat st;
    return stat(path, &st) == 0 && S_ISREG(st.st_mode);
}

// Check if source file is newer
int source_is_newer(const char *src, const char *dst) {
    struct stat src_stat, dst_stat;
    stat(src, &src_stat);
    stat(dst, &dst_stat);
    return difftime(src_stat.st_mtime, dst_stat.st_mtime) > 0;
}

// Use diff -q to compare files (suppressed output)
int files_are_different(const char *src, const char *dst) {
    pid_t pid = fork();
    if (pid == 0) {
        int null_fd = open("/dev/null", O_WRONLY);
        dup2(null_fd, STDOUT_FILENO);
        close(null_fd);
        execl("/usr/bin/diff", "diff", "-q", src, dst, NULL);
        perror("exec diff failed");
        exit(1);
    }
    int status;
    waitpid(pid, &status, 0);
    return WEXITSTATUS(status);  // 0 = same, 1 = different
}

// Copy file using cp
void copy_file(const char *src, const char *dst) {
    pid_t pid = fork();
    if (pid == 0) {
        execl("/bin/cp", "cp", src, dst, NULL);
        perror("exec cp failed");
        exit(1);
    }
    wait(NULL);
    printf("Copied: %s -> %s\n", src, dst);
}

// Create nested directories (like mkdir -p)
void mkdir_p(const char *path) {
    char tmp[MAX_PATH];
    strncpy(tmp, path, MAX_PATH);
    int len = strlen(tmp);
    if (tmp[len - 1] == '/') tmp[len - 1] = '\0';

    for (char *p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, 0755);
            *p = '/';
        }
    }
    mkdir(tmp, 0755);
}

int main(int argc, char *argv[]) {
    // Argument validation
    if (argc != 3) {
        printf("Usage: file_sync <source_directory> <destination_directory>\n");
        return 1;
    }

    char abs_src[MAX_PATH], abs_dst[MAX_PATH];
    if (realpath(argv[1], abs_src) == NULL) {
        printf("Error: Source directory '%s' does not exist.\n", argv[1]);
        return 1;
    }

    // Try to resolve destination path
    int dst_exists = realpath(argv[2], abs_dst) != NULL;
    if (!dst_exists) {
        strncpy(abs_dst, argv[2], MAX_PATH);
        mkdir_p(abs_dst);
        printf("Created destination directory '%s'.\n", abs_dst);
    }

    // Print current directory
    char cwd[MAX_PATH];
    if (getcwd(cwd, sizeof(cwd)) == NULL) {
        perror("getcwd failed");
        return 1;
    }
    printf("Current working directory: %s\n", cwd);
    printf("Synchronizing from %s to %s\n", abs_src, abs_dst);

    // Open source directory
    DIR *src_dp = opendir(abs_src);
    if (!src_dp) {
        perror("Failed to open source directory");
        return 1;
    }

    // Collect regular files
    char *files[MAX_FILES];
    int count = 0;
    struct dirent *entry;
    while ((entry = readdir(src_dp)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;
        char full[MAX_PATH];
        snprintf(full, sizeof(full), "%s/%s", abs_src, entry->d_name);
        if (is_regular_file(full)) {
            files[count++] = strdup(entry->d_name);
            if (count >= MAX_FILES) break;
        }
    }
    closedir(src_dp);

    // Sort alphabetically
    qsort(files, count, sizeof(char *), compare);

    // Process files
    for (int i = 0; i < count; i++) {
        char src_file[MAX_PATH], dst_file[MAX_PATH];
        snprintf(src_file, sizeof(src_file), "%s/%s", abs_src, files[i]);
        snprintf(dst_file, sizeof(dst_file), "%s/%s", abs_dst, files[i]);

        if (!file_exists(dst_file)) {
            printf("New file found: %s\n", files[i]);
            copy_file(src_file, dst_file);
        } else {
            int different = files_are_different(src_file, dst_file);
            if (!different) {
                printf("File %s is identical. Skipping...\n", files[i]);
            } else if (source_is_newer(src_file, dst_file)) {
                printf("File %s is newer in source. Updating...\n", files[i]);
                copy_file(src_file, dst_file);
            } else {
                printf("File %s is newer in destination. Skipping...\n", files[i]);
            }
        }
        free(files[i]);
    }

    printf("Synchronization complete.\n");
    return 0;
}

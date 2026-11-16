#define _GNU_SOURCE
#include <arpa/inet.h>
#include <dlfcn.h>
#include <errno.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <netinet/tcp.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <unistd.h>

#ifndef TCP_THIN_LINEAR_TIMEOUTS
#define TCP_THIN_LINEAR_TIMEOUTS 16
#endif

#ifndef TCP_THIN_DUPACK
#define TCP_THIN_DUPACK 17
#endif

#define MAX_TRACKED_FDS 8

static volatile int g_ipv4_fds[MAX_TRACKED_FDS] = {-1, -1, -1, -1, -1, -1, -1, -1};
static volatile unsigned int g_fd_cursor = 0;

static void track_ipv4_fd(int sockfd) {
    if (sockfd < 0) {
        return;
    }
    for (int i = 0; i < MAX_TRACKED_FDS; i++) {
        if (g_ipv4_fds[i] == sockfd) {
            return;
        }
    }
    for (int i = 0; i < MAX_TRACKED_FDS; i++) {
        if (g_ipv4_fds[i] == -1) {
            g_ipv4_fds[i] = sockfd;
            return;
        }
    }
    unsigned int idx = __atomic_fetch_add(&g_fd_cursor, 1, __ATOMIC_RELAXED) % MAX_TRACKED_FDS;
    g_ipv4_fds[idx] = sockfd;
}

static void untrack_ipv4_fd(int fd) {
    if (fd < 0) {
        return;
    }
    for (int i = 0; i < MAX_TRACKED_FDS; i++) {
        if (g_ipv4_fds[i] == fd) {
            g_ipv4_fds[i] = -1;
        }
    }
}

static inline int is_tracked_ipv4_fd(int sockfd) {
    if (sockfd < 0) {
        return 0;
    }
    for (int i = 0; i < MAX_TRACKED_FDS; i++) {
        if (g_ipv4_fds[i] == sockfd) {
            return 1;
        }
    }
    return 0;
}

static void apply_low_latency_opts(int sockfd) {
    const char *nodelay_env = getenv("L2_TCP_NODELAY");
    if (!nodelay_env || nodelay_env[0] != '1') {
        return;
    }

    int one = 1;
    setsockopt(sockfd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));
#ifdef TCP_QUICKACK
    setsockopt(sockfd, IPPROTO_TCP, TCP_QUICKACK, &one, sizeof(one));
#endif
    setsockopt(sockfd, IPPROTO_TCP, TCP_THIN_LINEAR_TIMEOUTS, &one, sizeof(one));
    setsockopt(sockfd, IPPROTO_TCP, TCP_THIN_DUPACK, &one, sizeof(one));

    int tos = 0xb8; /* DSCP EF (46) for Wi-Fi WMM AC_VO priority */
    if (setsockopt(sockfd, IPPROTO_IP, IP_TOS, &tos, sizeof(tos)) < 0) {
        int lowdelay = IPTOS_LOWDELAY;
        setsockopt(sockfd, IPPROTO_IP, IP_TOS, &lowdelay, sizeof(lowdelay));
    }
}

static inline void rearm_quickack(int sockfd) {
#ifdef TCP_QUICKACK
    const char *nodelay_env = getenv("L2_TCP_NODELAY");
    if (nodelay_env && nodelay_env[0] == '1') {
        int one = 1;
        setsockopt(sockfd, IPPROTO_TCP, TCP_QUICKACK, &one, sizeof(one));
    }
#else
    (void)sockfd;
#endif
}

/**
 * Intercepts AF_INET connect() targeting AuthServer port (2106 by default,
 * configurable via L2_AUTH_TARGET_PORT) and redirects it to 127.0.0.1 on
 * L2_AUTH_PROXY_PORT (default 21060) so Wine's WSAAsyncSelect completes the
 * local TCP handshake before L2.exe overwrites FD_CONNECT with FD_READ.
 * Also applies low-latency per-socket TCP/QoS options when L2_TCP_NODELAY=1.
 */
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    static int (*orig_connect)(int, const struct sockaddr *, socklen_t) = NULL;
    if (!orig_connect) {
        orig_connect = dlsym(RTLD_NEXT, "connect");
    }

    int rc = 0;
    int target_handled = 0;
    int is_ipv4 = (addr && addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in));

    if (is_ipv4) {
        track_ipv4_fd(sockfd);
        apply_low_latency_opts(sockfd);

        const struct sockaddr_in *in = (const struct sockaddr_in *)addr;
        const char *target_env = getenv("L2_AUTH_TARGET_PORT");
        int target_port = target_env ? atoi(target_env) : 2106;

        if (target_port > 0 && ntohs(in->sin_port) == (uint16_t)target_port) {
            const char *proxy_env = getenv("L2_AUTH_PROXY_PORT");
            int proxy_port = proxy_env ? atoi(proxy_env) : 21060;
            if (proxy_port > 0) {
                struct sockaddr_in local = *in;
                local.sin_port = htons((uint16_t)proxy_port);
                local.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
                rc = orig_connect(sockfd, (const struct sockaddr *)&local, sizeof(local));
                target_handled = 1;
            }
        }
    }

    if (!target_handled) {
        rc = orig_connect(sockfd, addr, addrlen);
    }

    if (is_ipv4) {
        int saved_errno = errno;
        apply_low_latency_opts(sockfd);
        errno = saved_errno;
    }

    return rc;
}

/**
 * Prevent Wine or Engine.dll from disabling TCP_NODELAY when L2_TCP_NODELAY=1.
 */
int setsockopt(int sockfd, int level, int optname, const void *optval, socklen_t optlen) {
    static int (*orig_setsockopt)(int, int, int, const void *, socklen_t) = NULL;
    if (!orig_setsockopt) {
        orig_setsockopt = dlsym(RTLD_NEXT, "setsockopt");
    }

    if (level == IPPROTO_TCP && optname == TCP_NODELAY) {
        const char *nodelay_env = getenv("L2_TCP_NODELAY");
        if (nodelay_env && nodelay_env[0] == '1') {
            int one = 1;
            (void)optval;
            (void)optlen;
            return orig_setsockopt(sockfd, level, optname, &one, sizeof(one));
        }
    }

    return orig_setsockopt(sockfd, level, optname, optval, optlen);
}

ssize_t recv(int sockfd, void *buf, size_t len, int flags) {
    static ssize_t (*orig_recv)(int, void *, size_t, int) = NULL;
    if (!orig_recv) {
        orig_recv = dlsym(RTLD_NEXT, "recv");
    }

    ssize_t ret = orig_recv(sockfd, buf, len, flags);
    if (ret > 0 && is_tracked_ipv4_fd(sockfd)) {
        int saved_errno = errno;
        rearm_quickack(sockfd);
        errno = saved_errno;
    }
    return ret;
}

ssize_t recvfrom(int sockfd, void *buf, size_t len, int flags,
                 struct sockaddr *src_addr, socklen_t *addrlen) {
    static ssize_t (*orig_recvfrom)(int, void *, size_t, int, struct sockaddr *, socklen_t *) = NULL;
    if (!orig_recvfrom) {
        orig_recvfrom = dlsym(RTLD_NEXT, "recvfrom");
    }

    ssize_t ret = orig_recvfrom(sockfd, buf, len, flags, src_addr, addrlen);
    if (ret > 0 && is_tracked_ipv4_fd(sockfd)) {
        int saved_errno = errno;
        rearm_quickack(sockfd);
        errno = saved_errno;
    }
    return ret;
}

ssize_t recvmsg(int sockfd, struct msghdr *msg, int flags) {
    static ssize_t (*orig_recvmsg)(int, struct msghdr *, int) = NULL;
    if (!orig_recvmsg) {
        orig_recvmsg = dlsym(RTLD_NEXT, "recvmsg");
    }

    ssize_t ret = orig_recvmsg(sockfd, msg, flags);
    if (ret > 0 && is_tracked_ipv4_fd(sockfd)) {
        int saved_errno = errno;
        rearm_quickack(sockfd);
        errno = saved_errno;
    }
    return ret;
}

int close(int fd) {
    static int (*orig_close)(int) = NULL;
    if (!orig_close) {
        orig_close = dlsym(RTLD_NEXT, "close");
    }

    untrack_ipv4_fd(fd);
    return orig_close(fd);
}

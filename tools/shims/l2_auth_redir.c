#define _GNU_SOURCE
#include <arpa/inet.h>
#include <dlfcn.h>
#include <netinet/in.h>
#include <stdlib.h>
#include <sys/socket.h>

/**
 * Intercepts AF_INET connect() targeting AuthServer port (2106 by default,
 * configurable via L2_AUTH_TARGET_PORT) and redirects it to 127.0.0.1 on
 * L2_AUTH_PROXY_PORT (default 21060) so Wine's WSAAsyncSelect completes the
 * local TCP handshake before L2.exe overwrites FD_CONNECT with FD_READ.
 */
int connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    int (*orig_connect)(int, const struct sockaddr *, socklen_t) =
        dlsym(RTLD_NEXT, "connect");

    if (addr && addr->sa_family == AF_INET && addrlen >= sizeof(struct sockaddr_in)) {
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
                return orig_connect(sockfd, (const struct sockaddr *)&local, sizeof(local));
            }
        }
    }

    return orig_connect(sockfd, addr, addrlen);
}

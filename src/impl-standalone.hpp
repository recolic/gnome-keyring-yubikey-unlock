/*
 * This is another implementation to unlock gnome keyring.
 * It sends a hand-crafted control message to `/run/user/1000/keyring/control`, to unlock the keyring.
 * This interface is easier, not requiring external lib, but only allows unlocking default keyring.
 *
 * Credit: https://github.com/umglurf/gnome-keyring-unlock
 *         https://codeberg.org/umglurf/gnome-keyring-unlock
 *         (This repo also tells you how to unlock with TPM)
 */

#include <rlib/macro.hpp>
#include <rlib/scope_guard.hpp>
#include <rlib/sys/sio.hpp>
#include <filesystem>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/un.h>

namespace utils {
    inline auto get_control_socket() {
        namespace fs = std::filesystem;
    
        // Helper function to check if a path is a socket
        auto is_socket = [](const fs::path& path) {
            struct stat s;
            return stat(path.c_str(), &s) == 0 && S_ISSOCK(s.st_mode);
        };
    
        if (const char* gnome_keyring_control = std::getenv("GNOME_KEYRING_CONTROL")) {
            fs::path control_socket = fs::path(gnome_keyring_control) / "control";
            if (fs::exists(control_socket) && is_socket(control_socket)) {
                return control_socket;
            }
        }
    
        if (const char* xdg_runtime_dir = std::getenv("XDG_RUNTIME_DIR")) {
            fs::path control_socket = fs::path(xdg_runtime_dir) / "keyring/control";
            if (fs::exists(control_socket) && is_socket(control_socket)) {
                return control_socket;
            }
        }
    
        throw std::runtime_error("Unable to find control socket");
    }
    
    inline int connect_unix_socket(std::string path) {
        // Create a UNIX socket
        int sockfd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (sockfd == -1) {
            throw std::runtime_error("Unable to create unix socket");
        }
    
        // Set up socket address
        struct sockaddr_un addr {};
        addr.sun_family = AF_UNIX;
        std::strncpy(addr.sun_path, path.c_str(), sizeof(addr.sun_path) - 1);
    
        // Connect to the socket
        if (connect(sockfd, reinterpret_cast<struct sockaddr*>(&addr), sizeof(addr)) == -1) {
            close(sockfd);
            throw std::runtime_error("Unable to connect to unix socket");
        }
        return sockfd;
    }

    enum ControlOp : uint32_t {
        INITIALIZE = 0,
        UNLOCK = 1,
        CHANGE = 2,
        QUIT = 4
    };

    enum ControlRes : uint32_t {
        OK = 0,
        DENIED = 1,
        FAILED = 2,
        NO_DAEMON = 3
    };
}

constexpr auto GNOME_KEYRING_RESULT_OK = utils::ControlRes::OK;

inline auto do_unlock(std::string keyring, std::string password) {
    auto sockfd = utils::connect_unix_socket(utils::get_control_socket());
    rlib_defer([&] { close(sockfd); });

    rlib::sockIO::quick_send(sockfd, std::string(1, '\0'));

    uint32_t oplen = 8 + 4 + password.size();
    uint32_t pktBuf = htonl(oplen);
    rlib::sockIO::sendn_ex(sockfd, &pktBuf, sizeof(pktBuf), 0);

    pktBuf = htonl(utils::ControlOp::UNLOCK);
    rlib::sockIO::sendn_ex(sockfd, &pktBuf, sizeof(pktBuf), 0);

    pktBuf = htonl(password.size());
    rlib::sockIO::sendn_ex(sockfd, &pktBuf, sizeof(pktBuf), 0);
    rlib::sockIO::quick_send(sockfd, password);

    rlib::sockIO::recvn_ex(sockfd, &pktBuf, sizeof(pktBuf));
    if (ntohl(pktBuf) != 8)
        throw std::runtime_error("invalid api response length: expecting len = 8");

    rlib::sockIO::recvn_ex(sockfd, &pktBuf, sizeof(pktBuf));
    return ntohl(pktBuf);
}

inline std::string keyringResultToString(int res) {
    switch (res) {
#define RLIB_IMPL_GEN_RESULT(value) RLIB_IMPL_GEN_RESULT_1(value, RLIB_MACRO_TO_CSTR(value))
#define RLIB_IMPL_GEN_RESULT_1(value, cstr) case (utils::ControlRes::value): return (cstr)

        RLIB_IMPL_GEN_RESULT(OK);
        RLIB_IMPL_GEN_RESULT(DENIED);
        RLIB_IMPL_GEN_RESULT(FAILED);
        RLIB_IMPL_GEN_RESULT(NO_DAEMON);
    default:
        return std::string("Unknown Result Code: ") + std::to_string(res);
    }
}
/*
 * This is another implementation to unlock gnome keyring.
 * It sends a hand-crafted control message to `/run/user/1000/keyring/control`, to unlock the keyring.
 * This interface is easier, not requiring external lib, but only allows unlocking default keyring.
 *
 * Credit: https://github.com/umglurf/gnome-keyring-unlock
 *         https://codeberg.org/umglurf/gnome-keyring-unlock
 *         (This repo also tells you how to unlock with TPM)
 */

#include <string>
#include <rlib/macro.hpp>

constexpr auto GNOME_KEYRING_RESULT_OK = 0;

inline GnomeKeyringResult do_unlock(std::string keyring, std::string password) {
    return TODO;
}

inline std::string keyringResultToString(GnomeKeyringResult res) {
}


/*
 * This is an implementation to unlock gnome keyring.
 * It talks to `org.gnome.keyring.InternalUnsupportedGuiltRiddenInterface` through `/run/user/1000/bus`,
 *   calling the `UnlockWithMasterPassword` function, to unlock the keyring.
 * It involves multiple send/recv, allows unlocking any keyring.
 */

#include <gnome-keyring-1/gnome-keyring.h>
#include <string>
#include <rlib/macro.hpp>

inline GnomeKeyringResult do_unlock(std::string keyring, std::string password) {
    return gnome_keyring_unlock_sync(keyring.c_str(), password.c_str());
}

inline std::string keyringResultToString(GnomeKeyringResult res) {
    switch(res) {
#define RLIB_IMPL_GEN_RESULT(value) RLIB_IMPL_GEN_RESULT_1(value, RLIB_MACRO_TO_CSTR(value))
#define RLIB_IMPL_GEN_RESULT_1(value, cstr) case (value): return (cstr)

        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_OK);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_DENIED);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_NO_KEYRING_DAEMON);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_ALREADY_UNLOCKED);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_NO_SUCH_KEYRING);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_BAD_ARGUMENTS);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_IO_ERROR);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_CANCELLED);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_KEYRING_ALREADY_EXISTS);
        RLIB_IMPL_GEN_RESULT(GNOME_KEYRING_RESULT_NO_MATCH);
        default:
            return std::string("Unknown Result Code: ") + std::to_string(res);
    }
}

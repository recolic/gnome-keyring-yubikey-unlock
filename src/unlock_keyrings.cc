#include <rlib/log.hpp>
#include <rlib/opt.hpp>
#include "keyring_op.hpp"

rlib::logger rlog(std::cerr);

int main(int argc, char **argv) {
    rlib::opt_parser args(argc, argv);

    if(args.getBoolArg("-h", "--help")) {
        rlog.info("Usage: {} [-h/--help] [-q/--quiet] --secret-file <filename> # use `-` as stdin.");
        return 0;
    }
    if(args.getBoolArg("-q", "--quiet")) {
        rlog.set_log_level(rlib::log_level_t::FATAL);
    }

    auto secret_file_name = args.getValueArg("--secret-file");
    if(secret_file_name == "-")
        secret_file_name = "/dev/fd/0";
    
    std::ifstream secret_input (secret_file_name);
    if(not secret_input) {
        rlog.error("Unable to open file {}. Exiting...", secret_file_name);
        return 2;
    }
    size_t line_num = 0;
    bool no_error = true;
    while(not secret_input.eof()) {
        auto line = rlib::scanln(secret_input).strip("\t\n\r");
        auto line_removed_space = line;
        line_removed_space.strip(' '); // Remove space may break keyring_name or password.
        if(line_removed_space.empty() or line_removed_space[0] == '#')
            continue; // Skip comments.
        
        auto keyring_and_pswd = line.split(':');
        if(keyring_and_pswd.size() != 2) {
            rlog.error("Secret file line {} has wrong format. Expecting `${keyring}:${password}`", line_num);
            return 3;
        }

        auto res = do_unlock(keyring_and_pswd.at(0), keyring_and_pswd.at(1));
        auto msg = keyringResultToString(res);
        if(res == GNOME_KEYRING_RESULT_OK)
            rlog.info("line {}: Working on keyring `{}`: {}.", line_num, keyring_and_pswd.at(0), msg);
        else {
            rlog.error("line {}: Working on keyring `{}`: {}.", line_num, keyring_and_pswd.at(0), msg);
            no_error = false;
        }

        ++line_num;
    }

    return no_error ? 0 : 4;
}


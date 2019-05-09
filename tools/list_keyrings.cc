// You can use this naive program to know keyring names.
// eval g++ (pkg-config --cflags --libs gnome-keyring-1) list.cc -o s
#include <gnome-keyring-1/gnome-keyring.h>
#include <iostream>

int main() {
    GList *pRes = nullptr;
    GnomeKeyringResult res = gnome_keyring_list_keyring_names_sync(&pRes);
    for(int i = 0; i < g_list_length(pRes); ++i) {
        gpointer dat = g_list_nth_data(pRes, i);
        gchar *gs = (gchar *)dat;
        std::cout << gs << std::endl;
    }
}

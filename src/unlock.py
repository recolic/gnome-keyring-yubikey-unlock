#!/usr/bin/env python3

# SPDX-FileCopyrightText: 2022 Håvard Moen <post@haavard.name>
#
# SPDX-License-Identifier: GPL-3.0-or-later

from enum import IntEnum
import os
from pathlib import Path
import socket
import sys


class ControlOp(IntEnum):
    INITIALIZE = 0
    UNLOCK = 1
    CHANGE = 2
    QUIT = 4


class ControlResult(IntEnum):
    OK = 0
    DENIED = 1
    FAILED = 2
    NO_DAEMON = 3


def buffer_encode_uint32(val):
    """
    Encode a 32 bit int to 4 bytes
    """
    buf = bytearray(4)
    buf[0] = (val >> 24) & 0xFF
    buf[1] = (val >> 16) & 0xFF
    buf[2] = (val >> 8) & 0xFF
    buf[3] = (val >> 0) & 0xFF
    return buf


def buffer_decode_uint32(val):
    """
    Decode four bytes to 32 bit int
    """
    return val[0] << 24 | val[1] << 16 | val[2] << 8 | val[3]


def get_control_socket():
    """
    Find the control socket for gnome keyring
    """
    if "GNOME_KEYRING_CONTROL" in os.environ:
        control_socket = Path(os.environ["GNOME_KEYRING_CONTROL"]) / Path("control")
        if control_socket.exists() and control_socket.is_socket():
            return control_socket
    if "XDG_RUNTIME_DIR" in os.environ:
        control_socket = Path(os.environ["XDG_RUNTIME_DIR"]) / Path("keyring/control")
        if control_socket.exists() and control_socket.is_socket():
            return control_socket
    raise Exception("Unable to find control socket")


def unlock_keyring():
    # pw = sys.stdin.read().strip()
    pw = '1'

    control_socket = get_control_socket()
    print(control_socket)
    s = socket.socket(family=socket.AF_UNIX, type=socket.SOCK_STREAM)
    s.connect(str(control_socket))

    # write credentials
    ret = s.send(bytearray(1))
    if ret < 0:
        raise Exception("Error writing credentials byte")

    # oplen is
    # 8 = packet size + op code
    # 4 size of length of pw byte
    oplen = 8 + 4 + len(pw)

    # write length
    ret = s.send(buffer_encode_uint32(oplen))
    if ret != 4:
        raise Exception("Error sending data to gnome-keyring control")

    # write op = UNLOCK
    ret = s.send(buffer_encode_uint32(ControlOp.UNLOCK.value))
    if ret != 4:
        raise Exception("Error sending unlock to gnome-keyring control")

    pw_len = len(pw)
    # write password string length
    ret = s.send(buffer_encode_uint32(pw_len))
    if ret != 4:
        raise Exception("Error sending password length to gnome-keyring control")
    while pw_len > 0:
        # write password
        ret = s.send(pw.encode())
        if ret < 0:
            raise Exception("Error writing password to gnome-keyring control")
        pw = pw[ret:]
        pw_len = len(pw)

    val = s.recv(4)
    l = buffer_decode_uint32(val)
    if l != 8:
        raise Exception("Invalid response length")
    val = s.recv(4)
    res = buffer_decode_uint32(val)
    s.close()
    if res == ControlResult.DENIED:
        raise Exception("Unlock denied")
    elif res == ControlResult.FAILED:
        raise Exception("Unlock failed")


if __name__ == "__main__":
    try:
        unlock_keyring()
    except Exception as e:
        sys.stderr.write(str(e) + "\n")
        sys.exit(1)

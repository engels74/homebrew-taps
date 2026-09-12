#!/usr/bin/env python3
"""Launch real apps in a disposable X11/Wayland session; never use user settings.

Run under xvfb-run + dbus-run-session, or headless Weston + dbus-run-session.
This checks window creation and image loading, not media/capture feature parity.
"""

import argparse
import base64
import ctypes
import os
from pathlib import Path
import shutil
import signal
import subprocess
import struct
import tempfile
import time
import zlib


def png_chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def x11_titles(screenshot):
    x = ctypes.CDLL("libX11.so.6")
    ptr = ctypes.c_void_p
    window = ctypes.c_ulong
    x.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x.XOpenDisplay.restype = ptr
    x.XDefaultRootWindow.argtypes = [ptr]
    x.XDefaultRootWindow.restype = window
    x.XQueryTree.argtypes = [ptr, window, ctypes.POINTER(window), ctypes.POINTER(window),
                            ctypes.POINTER(ctypes.POINTER(window)), ctypes.POINTER(ctypes.c_uint)]
    x.XFetchName.argtypes = [ptr, window, ctypes.POINTER(ctypes.c_char_p)]
    x.XFree.argtypes = [ptr]
    x.XCloseDisplay.argtypes = [ptr]
    x.XGetGeometry.argtypes = [ptr, window, ctypes.POINTER(window), ctypes.POINTER(ctypes.c_int),
                              ctypes.POINTER(ctypes.c_int), *([ctypes.POINTER(ctypes.c_uint)] * 4)]
    x.XGetImage.argtypes = [ptr, window, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint,
                           ctypes.c_ulong, ctypes.c_int]
    x.XGetImage.restype = ptr
    x.XGetPixel.argtypes = [ptr, ctypes.c_int, ctypes.c_int]
    x.XGetPixel.restype = ctypes.c_ulong
    x.XDestroyImage.argtypes = [ptr]
    display = x.XOpenDisplay(None)
    if not display:
        raise RuntimeError("Cannot connect to X11")
    try:
        root, parent, count = window(), window(), ctypes.c_uint()
        children = ctypes.POINTER(window)()
        x.XQueryTree(display, x.XDefaultRootWindow(display), ctypes.byref(root), ctypes.byref(parent),
                     ctypes.byref(children), ctypes.byref(count))
        titles = []
        try:
            for i in range(count.value):
                name = ctypes.c_char_p()
                if x.XFetchName(display, children[i], ctypes.byref(name)) and name.value:
                    titles.append(name.value.decode(errors="replace"))
                    x.XFree(name)
        finally:
            if children:
                x.XFree(children)
        width, height, border, depth = (ctypes.c_uint() for _ in range(4))
        left, top = ctypes.c_int(), ctypes.c_int()
        x.XGetGeometry(display, root, ctypes.byref(parent), ctypes.byref(left), ctypes.byref(top),
                       ctypes.byref(width), ctypes.byref(height), ctypes.byref(border), ctypes.byref(depth))
        picture = x.XGetImage(display, root, 0, 0, width.value, height.value, ctypes.c_ulong(-1), 2)
        if not picture:
            raise RuntimeError("X11 screenshot failed")
        pixels = bytearray()
        red_pixels = 0
        try:
            for row in range(height.value):
                pixels.append(0)
                for col in range(width.value):
                    pixel = x.XGetPixel(picture, col, row)
                    rgb = ((pixel >> 16) & 255, (pixel >> 8) & 255, pixel & 255)
                    red_pixels += rgb == (255, 0, 0)
                    pixels.extend(rgb)
        finally:
            x.XDestroyImage(picture)
        screenshot.write_bytes(b"\x89PNG\r\n\x1a\n" +
                               png_chunk(b"IHDR", struct.pack(">IIBBBBB", width.value, height.value, 8, 2, 0, 0, 0)) +
                               png_chunk(b"IDAT", zlib.compress(pixels)) + png_chunk(b"IEND", b""))
        return titles, red_pixels
    finally:
        x.XCloseDisplay(display)


def run_app(token, session, image=None):
    executable = shutil.which(token)
    if not executable:
        raise RuntimeError(f"Missing executable: {token}")
    with tempfile.TemporaryDirectory(prefix=f"tap-{token}-gui-") as scratch:
        work = Path(scratch)
        env = os.environ.copy()
        env.update(HOME=scratch, XDG_CONFIG_HOME=str(work / "config"), XDG_DATA_HOME=str(work / "data"),
                   XDG_CACHE_HOME=str(work / "cache"), PATH="/usr/bin:/bin", LIBGL_ALWAYS_SOFTWARE="1")
        if session == "wayland":
            env.update(QT_QPA_PLATFORM="wayland", GDK_BACKEND="wayland", WAYLAND_DEBUG="client")
            env.pop("DISPLAY", None)
        else:
            env.update(QT_QPA_PLATFORM="xcb", GDK_BACKEND="x11")
            env.pop("WAYLAND_DISPLAY", None)
        args = [executable]
        if image:
            fixture = work / f"fixture.{image}"
            if image == "svg":
                fixture.write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32">'
                                   '<rect width="32" height="32" fill="red"/></svg>')
            elif image == "gif":
                fixture.write_bytes(base64.b64decode("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"))
            else:
                fixture.write_bytes(b"\x89PNG\r\n\x1a\n" +
                                    png_chunk(b"IHDR", struct.pack(">IIBBBBB", 32, 32, 8, 2, 0, 0, 0)) +
                                    png_chunk(b"IDAT", zlib.compress((b"\0" + b"\xff\0\0" * 32) * 32)) +
                                    png_chunk(b"IEND", b""))
            args.append(str(fixture))
        with (work / "app.log").open("w+") as log:
            process = subprocess.Popen(args, env=env, cwd=work, stdout=log, stderr=log, start_new_session=True)
            try:
                time.sleep(5)
                log.flush()
                log.seek(0)
                output = log.read()
                artifacts = Path(os.environ.get("GUI_TEST_ARTIFACTS", "/tmp/tap-gui-results"))
                artifacts.mkdir(parents=True, exist_ok=True)
                label = f"{token}-{session}-{image or 'window'}"
                (artifacts / f"{label}.log").write_text(output)
                if process.poll() is not None:
                    raise RuntimeError(f"{token} exited ({process.returncode}):\n{output[-6000:]}")
                if session == "x11":
                    titles, red_pixels = x11_titles(artifacts / f"{label}.png")
                    expected = f"fixture.{image}" if image else {"fredtv": "Fred TV", "fcast-sender": "FCast"}[token]
                    if not any(expected.lower() in title.lower() for title in titles):
                        raise RuntimeError(f"Missing {expected} window; found {titles}\n{output[-3000:]}")
                    if image in ("png", "svg") and red_pixels < 100:
                        raise RuntimeError(f"{image} did not render the expected red square")
                elif "attach(" not in output or "commit(" not in output:
                    raise RuntimeError(f"No Wayland surface buffer submitted:\n{output[-6000:]}")
                if session == "x11":
                    (artifacts / f"{label}.titles.txt").write_text("\n".join(titles))
                print(f"PASS {token} {session} {image or 'window'}", flush=True)
            finally:
                try:
                    os.killpg(process.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--session", choices=["x11", "wayland"], required=True)
    parser.add_argument("apps", nargs="+", choices=["qview", "fredtv", "fcast-sender"])
    args = parser.parse_args()
    for app in args.apps:
        for image in (["png", "svg", "gif"] if app == "qview" else [None]):
            run_app(app, args.session, image)

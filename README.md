# static-wine32
*Batteries included, MULTIPLE times!* 🔋🔋🔋⚡⚡

*"Bro, unreal!! Latest Wine, latest Mesa, latest everything!" – Gandalf, a
famous 🧙*

*"See, eh, now Little Tony can finally enjoy all his games, eh, yeah." – the Mob 🇮🇹*

**TL;DR** Does it even work?! Yes, absolutely. But it shouldn't, really. 🤡🤡

## Contents

* [About](#about)
* [Installation](#installation)
  * [Building a Docker image with the needed dependencies](#building-a-docker-image-with-the-needed-dependencies)
  * [Building a statically linked 32-bit Wine](#building-a-statically-linked-32-bit-wine)
* [What isn't supported yet?](#what-isnt-supported-yet)
* [Frequently asked questions](#frequently-asked-questions)
  * [Isn't static linking bad?](#isnt-static-linking-bad)
  * [What operating systems and hardware platforms are supported?](#what-operating-systems-and-hardware-platforms-are-supported)
  * [Are there precompiled binary packages available?](#are-there-precompiled-binary-packages-available)
  * [Are external graphics drivers supported?](#are-external-graphics-drivers-supported)
  * [Is Vulkan supported?](#is-vulkan-supported)
  * [Is winetricks supported?](#is-winetricks-supported)
  * [Is DXVK supported?](#is-dxvk-supported)
  * [Is Gallium Nine supported?](#is-gallium-nine-supported)
  * [Is there any speed increase?](#is-there-any-speed-increase)
  * [What is known to work?](#what-is-known-to-work)
* [Troubleshooting](#troubleshooting)
  * [Unhandled exception](#unhandled-exception)
  * [winedevice.exe causes 100% CPU usage](#winedeviceexe-causes-100-cpu-usage)
* [Related repositories](#related-repositories)
* [Credits](#credits)
* [License](#license)

## About

Welcome to the Docker recipe for building a statically linked 32-bit
Wine for x86_64 targets. The build supports [most](#what-isnt-supported-yet)
Wine features. The motivation for this bizarre experiment is to avoid having
to install hundreds of `:i386` dependencies in order to run Wine but it might
be useful beyond that as well, i.e. to get an extremely optimized and
performant Wine. Just do a `sudo apt install wine32` on a freshly
installed Ubuntu and see what burden people have to struggle with every day just
to run their favorite Deus Ex and System Shock 2. Never again lose your temper
over unavailable packages which you'll never need anyhow! Gentoo users, no
need to thank me, I'm just doing my job *\*tips hat\** ! The recipe should
be straightforward to adapt for targets other than x86.

Actually, in retrospect, just compiling the (dynamic) Wine dependencies
and bundling them should be enough to make people happy but where's the fun in
that? It's much better to have libz statically linked 20+ times. Also, static
linking allows us to go berserk with treats like link time optimization (LTO).

All dependencies except for critical stuff like libc, libstdc++, libm,
libresolv, libdl, librt, libpthread are statically linked in
Wine's `.so` and `.dll` modules. This includes graphics drivers, scanner
drivers, multimedia codecs etc. The graphics drivers are
[Mesa's](https://mesa3d.org/). They're awesome if you have Intel or AMD
hardware. For Nvidia you'll be stuck with nouveau which is probably not what
you want. Vendor provided drivers are **NOT** supported. Why are you even
wasting your time with Linux if you're gonna use black box software operating
at kernel level?

The project uses a modified version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies which I
continuously update to the latest Wine release. The changes are
only intended to make Wine compatible with statically linked dependencies as is
clearly visible in the [diff](https://github.com/wine-mirror/wine/compare/master...MIvanchev:static-dependencies?expand=1).
Basically I just removed the dynamic loading of libraries and replaced the
function pointers that Wine `dlsym`s with the actual library symbols. This
removes one level of indirection. There are a couple of hacks like `win32u.so`
loading OpenGL symbols from `winex11.so` to avoid statically linking Mesa two
times.

This Wine build is **very** unorthodox. I cannot stress on this enough.
[Several libraries](https://github.com/MIvanchev/static-wine32#related-repositories)
were patched (although lightly) to pull this off. Are you
really gonna trust something like that? Also, using statically compiled
software is in general a **bad** idea if you don't know what you're doing and
comes with significant dangers. Use at your own risk and discretion. I assume no
responsibility for any damage resulting from using this project. I do use it
myself all the time to play GoG games and use some Windows programs.

Please report any bugs and problems. I really greatly appreciate your
feedback even if it's an angry rant about reformatted hard drive. Let's make
static-wine32 better together and liberate ourselves from the dynamic oppression.
Feel free to share your ideas and contributions as well.

## Installation

Before you begin building and installing you need to be aware that to *run*
a statically compiled Wine you need 32-bit libc and libstdc++ along with a
couple of other closely related libraries like libm, librt, libphread etc. If
you're on Ubuntu, start with `apt install libc6:i386 libstdc++6:i386`. That
might be all you'll have to do. For other distros you'll have to figure it out.

Statically linked Wine will also probably crash if you have an "official"
32-bit Wine installation at a well-known location or if you've preinstalled
32-bit versions of some of the Wine dependencies like libX11, SDL, GStreamer,
LLVM, GnuTLS etc. If you experience crashes remove the official 32-bit Wine,
all `:i386` dependencies and start over. You won't be needing them anyhow.
Consult the [troubleshooting](#troubleshooting) section when in trouble.

Now, the installation involves two major steps. Building a Docker image with all
dependencies compiled as statically linkable libraries (`.a` files) and
compiling Wine using these dependencies. Let's dive in!

### Building a Docker image with the needed dependencies

1. Clone this repository. Let's call the absolute path to the downloaded
directory `<static-wine-dir>`.

2. Run `<static-wine-dir>/dependencies/download.sh`. This pre-downloads
the source code of the dependencies to your machine. They will be copied
into the Docker image when we start building.

3. In `Dockerfile`, search for the following variables and set them
as follows:
* `PLATFORM=<your CPU's architecture>`: see the available values for the
`-march` option of GCC here https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html and
set to the value that matches your CPU's architecture, i.e. `broadwell` for the
i7-5600U CPU. This optimizes static-wine32 for your machine.
* `BUILD_WITH_LLVM=y`: uncomment this variable to compile the AMD OpenGL
driver, the Vulkan software renderer and a faster OpenGL software renderer;
they require LLVM to compile code on the fly. This will increase the build
time and size significantly.
* `BUILD_JOBS=1|2|3|4|...`: set to number of parallel build jobs you'd like.
Usually the number of your CPU cores. Be careful not to melt your CPU, we have
chip shortages.

4. Run `cd <static-wine-dir>` and  execute

       DOCKER_BUILDKIT=0 docker build -t static-wine32:latest . 2>&1 | tee build.log

   This will take forever with `BUILD_WITH_LLVM`. Otherwise about 45 minutes on 4
cores.

If all goes well you'll have a Docker image with statically linkable Wine
dependencies. You can open a shell to a container
using this image by

```
docker run -it static-wine32:latest /bin/bash
```

Check out all the libs in `/usr/local/lib`. Wow!

If there are errors the recipes for the affected packages in ``Dockerfile``
will have to be fixed. This usually happens when moving to newer or older
versions of the dependencies. What I usually do is to build an image that works
and then try out new recipes within it. Sometimes this takes days.

### Building a statically linked 32-bit Wine

1. Clone https://github.com/MIvanchev/wine and checkout the branch
`static-dependencies`:

       git clone --branch static-dependencies --depth 1 https://github.com/MIvanchev/wine.git

   Let's call the absolute path to the download directory `<wine-dir>`. You can
also clone from within the container of course but for me this way is easier.

2. Run the container and mount your Wine clone:

       docker run -v <wine-dir>:/build/wine -it static-wine32:latest /bin/bash

   For example:

       docker run -v /home/king/Develop/wine:/build/wine -it static-wine32:latest /bin/bash

   Make sure Wine is mounted with `ls /build/wine`.

3. Build and install Wine in the container.

       PLATFORM=<your CPU's architecture>
       INSTALL_DIR=/build/wine-build
       cd /build/wine
       autoreconf -f
       CFLAGS="-m32 -march=$PLATFORM -O2 -pipe"
       CPPFLAGS=$CFLAGS
       CXXFLAGS=$CFLAGS
       LDFLAGS=-fno-lto
       CFLAGS=$CFLAGS CPPFLAGS=$CPPFLAGS CXXFLAGS=$CXXFLAGS LDFLAGS=$LDFLAGS ./configure --disable-tests --prefix="$INSTALL_DIR"
       make -j$(nproc) install

4. If you want a highly optimized build of Wine using LTO dependencies, before
typing `make -j$(nproc) install` open the generated Makefile
`/build/wine/Makefile`, find the line `LDFLAGS = -fno-lto` and replace it with
`LDFLAGS = -flto -flto-partition=one -fuse-linker-plugin`.

5. This step is optional; minimize the build size by stripping away unneccessary
code and information

       strip -s "$INSTALL_DIR/lib/wine/i386-unix/"*
       strip -s "$INSTALL_DIR/lib/wine/i386-windows/"*

6. Finally we create an installation package outside of the container
for local installation
 
       tar czvf /build/wine/wine-build.tar.gz -C "$INSTALL_DIR" .

   The package is now available locally in `<wine-dir>/wine-build.tar.gz`.

7. To install Wine I extract the contents of the package to `~/.local`
because it's a well-known location and nothing else is needed. You can
however install it wherever you see fit. You can then just do
`<wine-installation-dir>/bin/winecfg` or just `winecfg` if you install to a
place like `~/.local` because `~/.local/bin` is most likely in your path.

## What isn't supported yet?

* OSS – honestly I have no idea about that, everything is so confusing with
OSS... contributions welcome.
* OpenCL – I have no idea about OpenCL, contributions welcome.
* Web cameras – Wine uses libgphoto2 which is not designed for static linkage
because the drivers are always loaded dynamically. This could be patched and
I'll get to it. It's a fair amount of work.
* Samba – the build process is little tough... I need to find a way to compile
libnetapi.

## FAQ

### Isn't static linking bad??

Depends on the context. Not per se. Installing thousands of shared libraries
with sketchy interdependencies is not better IMHO if you only want to run Wine.
However static compilation requires some knowledge of what's going on under
the hood.

To name just one example, the virtual memory of your Wine process will
now contain N copies of some dependency, say libz, where it would usually
contain only one. This multiplication could quickly cause a catastrophy if you
let copy `<x>` handle data originating from copy `<y>` assuming that `<x>`
is `<y>` which with a dynamic library will indeed be the case. Here's where
Wine's architecture really shines. It's so well decoupled that assumptions
like that seem to have been avoided entirely but be on your guard at all times.

Static linking also allows us to perform whole program optimization which could
potentially result in significant performance increases.

### What operating systems and hardware platforms are supported?

For now only x64 Linux.

### Are there precompiled binary packages available?

No and there won't be. With static linkage of so many dependencies the
licensing situation becomes impossible to resolve. The build process is
however not that complicated so give it a go! If you're stuck contact
me and I'll guide you through it.

### Are external graphics drivers supported?

No. The project features a statically compiled Mesa with the open-source
video drivers you're likely to need but there's no way to use dynamic libraries
supplied by your hardware's vendor (i.e. Nvidia). I'm working on allowing that
because I understand the importance. If you have an Nvidia card static-wine32
might not be for you.

### Is Vulkan supported?

Yes it is! Intel, AMD and software rendering drivers are included, Nvidia
users are out of luck. The Zink OpenGL driver is also included if Mesa
provides no OpenGL driver for your hardware.

Vulkan employs a dynamic loading architecture for drivers and layers that
wasn't easy to hack away but everything seems to be running OK. However, I'm
still working on preincluding the Mesa layers, it shouldn't be long now.
Please let me know if you have issues.

### Is winetricks supported?

I don't use winetricks so I don't know but most of it should, yes. Please let
me know if you try it out.

### Is DXVK supported?

Yes it is! DXVK runs perfectly fine with static-wine32. In fact it should be
your first choice if you intend to run Direct3D software and your GPU supports
Vulkan. If you're running software using Direct3D versions earlier than
Direct3D 9 you should consider using
[dgVoodoo](http://dege.freeweb.hu/dgVoodoo2/dgVoodoo2/) with DXVK.

### Is Gallium Nine supported?

No but I'm working on it. Statically building the Mesa module is not
complicated but finding a way to make it cooperate with Wine is somewhat
harder. Yes, I'm aware of
[Gallium Nine Standalone](https://github.com/iXit/wine-nine-standalone).

### Is there any speed increase?

I haven't benchmarked but probably only minimal with the default build flags.
The REAL shit should happen if you compile with link time optimization (LTO),
people sometimes report speed increase in Mesa alone of about 15-20%.

### What is known to work?

Among others the GOG versions of System Shock 2, Deus Ex,
Hidden and Dangerous 2, Sid Meyer's Alpha Centauri, Hotline Miami,
Hitman: Codename 47, Supreme Commander Gold Edition (sound doesn't work
but seems to be a [Wine issue](https://bugs.winehq.org/show_bug.cgi?id=49970)),
Total Annihilation: Commander Pack; Max Payne, Rainbow Six: Rogue Spear,
Microsoft Office 2007, TeamViewer, Winamp Classic.

## Troubleshooting

### Unhandled exception

Make sure you haven't installed a 32-bit Wine through your distro's package
manager. If you have, remove it because it'll likely interfere with the static
build. I haven't researched it well but I think it's because the static build
will load modules of the offical version.

Next, check whether you have any official `:i386` libraries which Wine loads
but shouldn't. Libraries like libc, libstdc++, librt, libpthread, libm are
fine, but anything else shouldn't be.

A good way to see what libraries Wine is loading at runtime is
`cat /proc/<id>/maps` where `<id>` is the process ID of one of Wine's processes.

If nothing else helps you could dedicate a week to build Wine without
optimizations and with full debug symbols. You'll deeply regret it so just
jump to official Wine while you still can.

### winedevice.exe causes 100% CPU usage

I've experienced this on one of my machines but have no I idea what causes it.

## Related repositories

The modifications I made to the major dependencies are available as forks and
included as [patches](https://github.com/MIvanchev/static-wine32/tree/master/dependencies/patches)
in static-wine32.

* Wine: https://github.com/MIvanchev/wine/tree/static-dependencies
* Mesa: https://gitlab.freedesktop.org/mivanchev/mesa/-/tree/mesa-23.0.0-patched
* Vulkan loader: https://github.com/MIvanchev/Vulkan-Loader/tree/ver-1.3.242

## Credits

Thanks to my friends and their friends for compilation hardware, testing and
general support.

Thanks to everybody on the #dri-devel IRC channel for Mesa-related questions.

Thanks to everybody on the #winehackers IRC channel for Wine-related questions,
especially nsivov, zf and stefand.

Thanks to all the OSS devs for their hard work.

## License

This project, i.e. the recipe for building a statically linked Wine, is licensed
under the 3-Clause BSD License. See the [license file](LICENSE) for the full
text.

Both Wine and my [fork](https://github.com/MIvanchev/wine) with the necessary
adjustments are licensed under the [GNU Lesser General Public License,
version 2.1.](https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)

However I can't say what license the end product, i.e. the statically linked
Wine itself, would fall under. You should probably limit yourself to personal
non-profit use only.


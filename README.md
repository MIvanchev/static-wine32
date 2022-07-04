# static-wine32
*Batteries included, MULTIPLE times!* 🔋🔋🔋⚡⚡

*"Bro, unreal!! Latest Wine, latest Mesa, latest everything!" – Gandalf, a
famous 🧙*

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
  * [Is Gallium Nine supported?](#is-gallium-nine-supported)
  * [Is there any speed increase?](#is-there-any-speed-increase)
  * [What is known to work?](#what-is-known-to-work)
* [Troubleshooting](#troubleshooting)
  * [0048:err:vulkan:get_vulkan_driver Wine was built without Vulkan support.](#0048errvulkanget_vulkan_driver-wine-was-built-without-vulkan-support)
  * [Unhandled exception](#unhandled-exception)
  * [winedevice.exe causes 100% CPU usage](#winedeviceexe-causes-100-cpu-usage)
* [Credits](https://github.com/MIvanchev/static-wine32#credits)
* [License](https://github.com/MIvanchev/static-wine32#license)

## About

Welcome to the Docker recipe for building a statically linked 32-bit
Wine for x86_64 targets. The build supports [most](#what-isnt-supported-yet)
Wine features. The motivation for this bizarre experiment is to avoid having
to install hundreds of `:i386` dependencies in order to run Wine but it might
be useful beyond that as well. Just do a `sudo apt install wine32` on a freshly
installed Ubuntu and see what burden people have to struggle with every day just
to run their favorite Deus Ex and System Shock 2. Never again lose your temper
over unavailable packages which you'll never need! The recipe should be
straightforward to adapt for targets other than x86.

Actually, in retrospect, just compiling the (dynamic) Wine dependencies
and bundling them should be enough to make people happy but where's the fun in
that? It's much better to have libz statically linked 20+ times.

All dependencies except for critical stuff like libc, libstdc++, libm,
libresolv, libdl, librt, libpthread and libgnutls are statically linked in
Wine's `.so` and `.dll` modules. This includes graphics drivers, scanner
drivers, multimedia codecs etc. The included graphics drivers are
[Mesa's](https://mesa3d.org/). They're awesome if you have Intel or AMD
hardware. For Nvidia you'll be stuck with nouveau which is probably not what
you want. Vendor provided drivers are **NOT** supported.

The project uses a modifed version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies which is
continuously updated to the latest Wine release. The changes are
only intended to make Wine compatible with statically linked dependencies as is
clearly visible in the [diff](https://github.com/wine-mirror/wine/compare/master...MIvanchev:static-dependencies?expand=1.)
Basically I just removed the dynamic loading of libraries and replaced the
function pointers that Wine `dlsym`s with the actual library symbols. This
removes one level of indirection. There are a couple of hacks like `win32u.so`
loading OpenGL symbols from `winex11.so` to avoid statically linking Mesa two
times.

This Wine build is **highly** experimental. I cannot stress on this enough. 
Several libraries were patched (although lightly) to pull this off. Are you
really gonna trust something like that? Also, using statically compiled
software is in general a **bad** idea if you don't know what you're doing and
comes with significant dangers. Use at your own risk and discretion. I assume no
responsibility for any damage resulting from using this project. I do use it
myself all the time to play GoG games and use some Windows programs.

Pleae report any bugs and problems. I really greatly appreciate your
feedback even if it's an angry rant about reformatted hard drive. Let's make
static-wine32 better together and liberate ourselves from the dynamic oppression.
Feel free to share your ideas and contributions as well.

## Installation

Before you begin building and installing you need to be aware that to *run*
a statically compiled Wine you need 32-bit libc and libstdc++ along with a
couple of other closely related libraries like libm, librt, libphread etc. If
you're on Ubuntu, start with `apt install libc6:i386 libstdc++6:i386`. That
might be all you'll have to do. For other distros you'll have to figure it out.

GnuTLS is also compiled but because of the security implications it's not linked
statically. Instead it's bundled as a shared library and you'll have to modify
your `LD_LIBRARY_PATH` to let Wine use it. If you're already sweating blood try
using the official GnuTLS of your distro. I haven't tried but it should work.

Statically linked Wine will also probably crash if you have an "official"
32-bit Wine installation at a well-known location or if you've preinstalled
32-bit versions of some of the Wine dependencies like libX11, SDL, GStreamer,
LLVM etc. If you experience crashes remove the official 32-bit Wine, all `:i386`
dependencies and start over. You won't be needing them anyhow. Consult the
[troubleshooting](#troubleshooting) section when in trouble.

Now, the installation involves two major steps. Building a Docker image with all
dependencies compiled as statically linkable libraries (`.a` files) and
compiling Wine using these dependencies. Let's dive in!

### Building a Docker image with the needed dependencies

1. Clone this repository. Let's call the absolute path to the downloaded
directory `<static-wine-dir>`.

2. Run `<static-wine-dir>/dependencies/download.sh`. This pre-downloads
the source code of the dependencies to your machine. They will be copied
into the Docker image when we start building.

3. In `Dockerfile`, set the following variables to the values you want:
* `WITH_LLVM=0|1`: set to `1` if you need support for AMD GPUs or want a
better software renderer. This will increase the build time significantly.
* `WITH_GNUTLS=0|1`: set to `1` if you need secure networking. Note that
GnuTLS is the only dynamic library static-wine32 uses.
* `BUILD_JOBS=1|2|3|4|...`: set to number of parallel build jobs you'd like.
Usually the number of your CPU cores. Be careful not to melt your CPU, we have
chip shortages.

4. Run `cd <static-wine-dir>` and  execute

       docker build -t static-wine32:latest . | tee build.log

   This will take forever with `WITH_LLVM=1`. Otherwise about 45 minutes on 4
cores.

If all goes well you'll have a Docker image with statically linkable Wine
dependencies and maybe a shared GnuTLS. You can open a shell to a container
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

3. Do `cd /build/wine`, then

       autoreconf -f
       ./configure --disable-tests --prefix=/build/wine-build

   Note that we will install Wine in the container. This is because we need to
strip the libraries first before we install on your PC. Analyze the output of
the configuration script and finally do

       make -j$(nproc)
       INSTALL_PROGRAM_FLAGS="-s" make install

4. Do `cd /build/wine-build`. If you have set `WITH_GNUTLS=1` copy
`libgnutls.so` to the Wine installation with

       mkdir lib/wine/i386-unix/custom && cp /usr/local/lib/libgnutls.so lib/wine/i386-unix/custom/

5. Remove unnecessary symbols with

       strip -s lib/wine/i386-unix/*
       strip -s lib/wine/i386-windows/*

   and if you're building with `WITH_GNUTLS=1` also

       strip -s lib/wine/i386-unix/custom/*

   This greatly reduces the size of the build.

6. Finally we create an installation package outside of the container
for local installation
 
       tar czvf /build/wine/wine-build.tar.gz .

   The package is now available locally in `<wine-dir>/wine-build.tar.gz`.

7. To install Wine I extract the contents of the package to `~/.local`
because it's a well-known location and nothing else is needed. You can
however install it wherever you see fit. You can then just do
`<wine-installation-dir>/bin/winecfg` or just `winecfg` if you install to a
place like `~/.local` because `~/.local/bin` is most likely in your path.

8. If you have used `WITH_GNUTLS=1` you need to modify `LD_LIBRARY_PATH` to
include `<wine-installation-dir>/lib/wine/i386-unix/custom`
because `libgnutls.so` is the only dynamic dependency. Consider adding
`LD_LIBRARY_PATH` to your `~/.profile` so you don't have to set it manually.
 For instance I have the following in my `~/.profile`:

       export LD_LIBRARY_PATH=~/.local/lib/wine/i386-unix/custom
       export GALLIUM_HUD=simple,fps,cpu

   Notice the usage of `GALLIUM_HUD` which shows me frame rate and CPU usage.

## What isn't supported yet?

* Vulkan – the loader architecture of Vulkan is hard to link statically, not
as easily as OpenGL at least. I'll have to research it.
* OSS – honestly I have no idea about that, everything is so confusing with
OSS... contributions welcome.
* OpenCL – I have no idea about OpenCL, contributions welcome.
* Web cameras – Wine uses libgphoto2 which is not designed for static linkage
because the drivers are always loaded dynamically. This could be patched and
I'll get to it. It's a fair amount of work.
* Samba – the build process is little tough... I need to find a way to compile
libnetapi.

## FAQ

### Isn't static linking bad?

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

### What operating systems and hardware platforms are supported?

For now only x64 Linux.

### Are there precompiled binary packages available?

No and there won't be. With static linkage of so many dependencies the
licensing situation becomes impossible to resolve. The build process is
however not that complicated so give it a go! If you're stuck contact
me and I'll guide you through it.

### Are external graphics drivers supported?

Not yet. The project features a statically compiled Mesa with the open-source
video drivers you're likely to need but there's no way to use dynamic libraries
supplied by your hardware's vendor (i.e. Nvidia). I'm working on allowing that
because I understand the importance. If you have an Nvidia card static-wine32
might not be for you.

### Is Vulkan supported?

No. Vulkan employs a dynamic loading architecture for drivers which is not
as easy to hack away as Mesa's. There seems to be hope because the Vulkan loader
allows static linking for MacOS so I might be able to start hacking there.

### Is winetricks supported?

I don't use winetricks so I don't know but most of it should, yes. Please let
me know if you try it out.

### Is Gallium Nine supported?

Not but I'm working on it. Statically building the Mesa module is not
complicated but finding a way to make it cooperate with Wine is somewhat
harder. Yes, I'm aware of
[Gallium Nine Standalone](https://github.com/iXit/wine-nine-standalone).

### Is there any speed increase?

I haven't benchmarked but probably only minimal.

### What is known to work?

Among others the GOG versions of System Shock 2, Deus Ex,
Hidden and Dangerous 2, Sid Meyer's Alpha Centauri, Hotline Miami,
Supreme Commander Gold Edition (sound doesn't work but seems to be a
[Wine issue](https://bugs.winehq.org/show_bug.cgi?id=49970)),
Total Annihilation: Commander Pack; Max Payne, Microsoft Office 2007,
Winamp Classic.

## Troubleshooting

### 0048:err:vulkan:get_vulkan_driver Wine was built without Vulkan support.

You can safely ignore this message, it's actually a warning not an error and
100% expected and normal. It's not the cause for whatever it is that you're
experiencing.

### Unhandled exception

Make sure you haven't installed a 32-bit Wine through your distro's package
manager. If you have, remove it because it'll likely interfere with the static
build. I haven't researched it well but I think it's because the static build
will load modules of the offical version.

Next, check whether you have any official `:i386` libraries which Wine loads
but shouldn't. Libraries like libc, libstdc++, librt, libpthread, libm are
fine, but an official installation of libgnutls might confuse the statically
linked Wine. You could try removing all `:i386` dependencies and starting over.

A good way to see what libraries Wine is loading at runtime is
`cat /proc/<id>/maps` where `<id>` is the process ID of one of Wine's processes.

If nothing else helps you could dedicate a week to build Wine without
optimizations and with full debug symbols. You'll deeply regret it so just jump
to official Wine while you still can.

### winedevice.exe causes 100% CPU usage

I've experienced this on one of my machines but have no I idea what causes it.

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


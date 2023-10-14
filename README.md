# static-wine32
*Batteries included, MULTIPLE times!* 🔋🔋🔋⚡⚡

*"Bro, unreal!! Latest Wine, latest Mesa, latest everything!" – Gandalf, a
famous 🧙*

*"See, eh, now Little Tony can finally enjoy all his games, eh, yeah." – the Mob 🇮🇹*

**TL;DR** Does it even work?! Yes, absolutely. But it shouldn't, really. 🤡🤡

## Contents

* [About](#about)
* [Installation](#installation)
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
  * [How can I reduce the size of the build?](#how-can-i-reduce-the-size-of-the-build)
  * [Is there any speed increase?](#is-there-any-speed-increase)
  * [What is known to work?](#what-is-known-to-work)
* [Troubleshooting](#troubleshooting)
  * [Unhandled exception](#unhandled-exception)
  * [winedevice.exe causes 100% CPU usage](#winedeviceexe-causes-100-cpu-usage)
* [Patched libraries](#patched-libraries)
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
[Several libraries](dependencies/patches)
were patched (although lightly) to pull this off. Are you
really gonna trust something like that? Also, using statically compiled
software is in general a **bad** idea if you don't know what you're doing and
comes with significant dangers. Use at your own risk and discretion. I assume no
responsibility for any damage resulting from using this project. I do use it
myself all the time to play GoG games and use some Windows programs and I've
never had any issues.

Please report any bugs and problems. I really greatly appreciate your
feedback even if it's an angry rant about reformatted hard drive. Let's make
static-wine32 better together and liberate ourselves from the dynamic
oppression. Feel free to share your ideas and contributions as well.

## Installation

Before you begin building and installing you need to be aware that to *run*
a statically compiled Wine you need 32-bit libc and libstdc++ along with a
couple of other closely related libraries like libm, librt, libphread etc. If
you're on Ubuntu, start with `apt install libc6:i386 libstdc++6:i386`. That
might be all you'll have to do. For other distros you'll have to figure it out
but most likely it's something similar.

Statically linked Wine will also probably crash if you have an "official"
32-bit Wine installation at a well-known location or if you've preinstalled
32-bit versions of some of the Wine dependencies like libX11, SDL, GStreamer,
LLVM, GnuTLS etc. If you experience crashes remove the official 32-bit Wine,
all `:i386` dependencies and start over. You won't be needing them anyhow.
Consult the [troubleshooting](#troubleshooting) section when in trouble.

You'll also need to install Docker in order to *build* static-wine32 but
actually **running it does not require Docker**. This is because the
build downloads and compiles a lot of dependencies and I thought this
is best done as an image recipe. Once the image is created, you can copy
the Wine build out of it.

The steps are as follows:

1. Clone this repository. Let's call the absolute path to the downloaded
directory `<static-wine-dir>`.

2. Run `cd <static-wine-dir>` and  execute

       DOCKER_BUILDKIT=0 docker build --build-arg PLATFORM=<your CPU's architecture> --build-arg PREFIX=$HOME/.local -t static-wine32:latest . 2>&1 | tee build.log

   The value of the `PLATFORM` argument is used to optimize static-wine32 for your
machine. Find a suitable value from the possible values of the `-march` option
of GCC here https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html, i.e.
`broadwell` if you have the i7-5600U CPU.

   The `PREFIX` argument denotes the directory to which
you'll later install Wine, most likely `$HOME/.local` or `/usr/local`.

   Additionally you can pass the following arguments:

   * `--build-arg BUILD_WITH_LTO=n`: disables the link time optimizations.

   * `--build-arg BUILD_WITH_LLVM=y`: compiles the AMD OpenGL driver, the
Vulkan software renderer and a faster OpenGL software renderer; they
require LLVM for on the fly code generation. Increases the build time
and size significantly.

   * `--build-arg BUILD_JOBS=1|2|3|4|...`: set to number of parallel build jobs
you'd like. By default it's set to 8. 🎶 It's gettin' hot in here 🎶

   If you encounter errors during the build the recipes for the affected packages
in ``Dockerfile`` will have to be fixed. This usually happens when moving to
newer or older versions of the dependencies. What I usually do is to build an
image that works and then try out new recipes within it. Sometimes this takes
days.

   The image also contains statically contained `glxgears` and `vkcube` in
`/usr/local/bin` in case you want debug something.

3. Copy the Wine build from `/root/wine-build.tar.gz` in the image to your
computer, there are many ways to do this but I use a temporary container
which is deleted immediately afterwards.

       docker cp $(docker create --name foo static-wine32):/root/wine-build.tar.gz . && docker rm foo

4. Extract the Wine build to the installation directory.

       tar xvf wine-build.tar.gz -C "$HOME/.local"

5. Enjoy Wine!

## What isn't supported yet?

* Wayland – working on it.
* Databases – working on it.
* OSS – honestly I have no idea about that, everything is so confusing with
OSS... contributions welcome.
* OpenCL – I have no idea about OpenCL, contributions welcome.
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

### How can I reduce the size of the build?

Try building only the graphics drivers that you actually need. Open
[Dockerfile](Dockerfile) and find the lines where the Mesa drivers are
configured, something like
`-Dgallium-drivers=swrast,zink,i915,iris,crocus,nouveau,r300,r600${BUILD_WITH_LLVM:+,radeonsi} \`
and `-Dvulkan-drivers=intel,intel_hasvk,amd${BUILD_WITH_LLVM:+,swrast} \`.
Change these to include only what you need, e.g. `-Dgallium-drivers=iris \`
and `-Dvulkan-drivers=intel \`.

### Is there any speed increase?

I haven't benchmarked. Per default static-wine32 is compiled with link time
optimizations (LTO) so the speed up might be significant. There are rumors
on the web that Mesa runs 15-20% faster when compiled with LTO.

### What is known to work?

Among others the GOG versions of System Shock 2, Deus Ex,
Hidden and Dangerous 2, Sid Meyer's Alpha Centauri, Hotline Miami,
Hitman: Codename 47, Supreme Commander Gold Edition (sound doesn't work
but seems to be a [Wine issue](https://bugs.winehq.org/show_bug.cgi?id=49970)),
Total Annihilation: Commander Pack; Max Payne, Rainbow Six: Rogue Spear,
Fightcade, Microsoft Office 2007, TeamViewer, Winamp Classic.

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

## Patched libraries

I patched numerous libraries to make them compile statically. All the patches
are available in the [patches](dependencies/patches)
directory or in [Dockerfile](Dockerfile).

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


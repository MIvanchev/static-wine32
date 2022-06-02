# static-wine32
*Batteries included, MULTIPLE times!* 🔋🔋🔋⚡⚡

TL;DR
Does it even work?! Yes, absolutely. But it shouldn't, really. 🤡🤡

Welcome to the Docker recipe for building a statically linked 32-bit
Wine for x86_64 targets. The build supports most Wine features. The motivation
for this bizarre experiment is to avoid having to install hundreds of `:i386`
dependencies in order to run Wine but it might be useful beyond that as well.
Just do a `sudo apt install wine32` on a freshly installed Ubuntu and see what
burden people have to struggle with every day just to run their favorite Deus
Ex and System Shock 2. Never again lose your temper over unavailable packages
which you'll never need! The recipe should be straightforward to adapt for
non-x86 targets. Actually, just compiling the (dynamic) Wine dependencies
should be enough but where's the fun in that? It's much better to have libz
statically linked 20+ times.

All dependencies except for critical stuff like libm, libresolv, libc,
libstdc++, ld, libdl, librt, libpthread and libgnutls are statically linked in
the Wine .so and .dll modules. This includes graphics drivers, scanner drivers,
multimedia codecs etc. The included graphics drivers are from Mesa and are
great for Intel and ATI cards. For Nvidia you'll be stuck with Nouveau which
is probably not what you want. Vendor provided drivers are NOT supported.

The project uses a modifed version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies which is
continuously updated to the latest Wine release. The changes are
only intended to make Wine compatible with statically linked dependencies as is
visible in the diff
https://github.com/wine-mirror/wine/compare/master...MIvanchev:static-dependencies?expand=1.
Basically I just removed the dynamic loading of libraries and replaced the
function pointers with the actual library symbols. There are a couple of hacks
like `win32u.so` loading OpenGL symbols from `winex11.so` to avoid statically
linking Mesa 2 times.

This Wine build is **highly** experimental. I cannot stress on this enough.
Using stiatically compiled software is in general a **bad** idea if you don't
know what you're doing and comes with significant dangers. Use at your own risk
and discretion. I assume no responsibility for any damage resulting from using
this project. I do use it myself all the time to play games though.

Pleae report any bugs and problems. I really greatly appreciate your
feedback even if it's an angry rant about reformatted hard drive. Let's make
static-wine32 better together and liberate ourselves from the dynamic opression.
Feel free to share your ideas and contributions as well.

## Installation

Before you begin building and installing you need to be aware that to *run*
static-wine32 you need 32-bit libc and libstdc++ along with a couple of other closely related libraries like libm, librt, libphread etc. If you're on Ubuntu, start
with `apt install libc6:i386 libstdc++6:i386`. That might be all you'll have to
do. For other distros you'll have to figure it out. Statically linked Wine might
crash if you've preinstalled 32-bit versions of some of the dependencies like X11, SDL etc. If you get crashes try removing all 32-bit dependencies and starting over. You won't be needing them anyhow. See the FAQ section as well.

Now, the installation involves 2 major steps. Building a Docker image with all
dependencies compiled as statically linkable libraries (`.a` files) and compiling Wine using these dependencies. Let's dive in!

### Building the Docker image with the needed dependencies

1. Clone this repository. Let's call the absolute path to the downloaded
directory `<static-wine-dir>`.
2. Run `<static-wine-dir>/dependencies/download.sh`. This pre-downloads
the source code of the dependencies to your machine. They will be copied
into the Docker image when we start building.
3. In `Dockerfile`, set the following variables to the values you want:
* `WITH_LLVM=0|1`: set to `1` if you want support for AMD GPUs and
a better software renderer.
* `WITH_GNUTLS=0|1`: set to `1` if you want secure networking. Note that
GnuTLS is the only dynamic library that will be used.
* `BUILD_JOBS=4`: set to number of parallel build jobs you'd like. Usually
the number of your CPU cores.
4. Run `cd <static-wine-dir>` and  execute `docker build -t
static-wine32:latest . | tee build.log`. This will take forever if you have
enabled LLVM. Otherwise about 45 minutes. Now you have a Docker image with the statically linkable Wine dependencies and maybe a shared GnuTLS.

You can open a shell to a container using this image by `docker run -it
static-wine:latest /bin/bash`. Check out all the libs in `/usr/local/lib`. Wow!

### Building a statically linked 32-bit Wine

1. Clone https://github.com/MIvanchev/wine.git and checkout the branch
`static-dependencies`: `git clone --branch static-dependencies --depth 1
https://github.com/MIvanchev/wine.git`. Let's call the absolute path to the
download directory `<wine-dir>`. You can also clone from within the container
of course but for me this way is easier.
2. Run the container and mount your Wine clone:
`docker run -v <wine-dir>:/build/wine -it /bin/bash`.
For example:
`docker build -v /home/king/Develop/wine:/build/wine -it /bin/bash`. Make sure
Wine is mounted with `ls /build/wine`.
3. Do `cd /build/wine`, then `./configure --disable-tests
--prefix=/build/wine-build`. Note that we will install in the container. This
is because we need to strip the libraries first. Analyze the output of the
configuration script and finally do
`make -j$(nproc)`. If the build is successfull install by `make install`.
4. Do `cd /build/wine-build`. If you have set `WITH_GNUTLS=1` copy
`libgnutls.so` with `mkdir lib/wine/i386-unix/custom &&
cp /usr/local/lib/libgnutls.so lib/wine/i386-unix/custom/`.
5. Remove unnecessary symbols with `strip -s lib/wine/i386-unix/*` and
`strip -s lib/wine/i386-windows/*`. This greatly reduces the size of the build.
6. Finally we package everything together and transfer outside the container
for installation: `tar czvf /build/wine/wine-build.tar.gz .`. The package is
now available locally in `<wine-dir>/wine-build.tar.gz`.
11. To install Wine I extract the contents of the package to my `~/.local`
because `~/.local` is a well known location and nothing else is needed. You can
however install it wherever you see fit. You can then just do
`<installation-dir>/bin/winecfg` or just `winecfg` if you install to a place
like ~/local. If you have used `WITH_GNUTLS=1` you need to modify
`LD_LIBRARY_PATH` to include `<wine-installation-dir>/lib/wine/i386-unix/custom`
because `libgnutls.so` is the only dynamic dependency. Consider adding
LD_LIBRARY_PATH to your `~/.profile` so you don't have to set it manually. For
instance I have the following in my `~/.profile`:

```
export LD_LIBRARY_PATH=~/.local/lib/wine/i386-unix/custom
```

### What's currently not supported

* Vulkan — the architecture doesn't allow static linking easily, no as easy as
OpenGL at least. I'll have to research it.
* OSS — honestly I have no idea about that, everything is so confusing with
OSS...
* OpenCL — I have no idea about OpenCL.
* Web cameras — Wine uses gPhoto2 but its architecture is not designed for
static linkage. This could be patched and I'll get to it, it's a fair
amount of work.
* Samba — the build process is little tough. I need to find a way to compile
libnetapi alone.

### FAQ

### Isn't static linking bad?

Depends on the context. Not per se. Installing thousands of shared libraries
with sketchy interdependencies is not better IMHO if you only want to run Wine.
However static compilation requires some knowledge of what's going on under
the hood.

### Are external graphics drivers supported?

Not yet. The project features a statically compiled Mesa with the open-source
video drivers you're likely to need but there's no way to use dynamic libraries
supplied by your hardware's vendor (i.e. Nvidia). I'm working on allowing that
because I understand the importance. If you have an Nvidia card static-wine32
might not be for you.

### Is Vulkan supported?

No. Vulkan uses a very weird dynamic loading architecture which is not easy to
hack away.

### Is winetricks supported?

I don't use it soI don't know but most of it should, yes.

### Credits

I'd like to thank all the people who helped me with testing and provided me
with compilation hardware.

Thanks to everybody on #dri-devel.
Thanks to everybody on #winehackers for their support, especially...

Thanks to all the OSS devs for their hard work!

## License

You are free to use the project for yourself, who's gonna know LOL. You can also
install it on your mother's laptop so she can continue using MS Office 2007.
However in all other scenarios you need my explicit prior consent to use the
project or any part of it for anything which you'll make available to others in
whatever form.

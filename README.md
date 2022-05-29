# static-wine32
Batteries included, multiple times!

TL;DR
Does it even work?! Yes, absolutely.

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

The project uses a modifed version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies which is
continuously updated to the latest Wine release. The changes are
only intended to make Wine compatible with statically linked dependencies as is
visible in the diff
https://github.com/MIvanchev/wine/compare/master...MIvanchev:static-dependencies?expand=1.
Basically I just removed the dynamic loading of libraries and replaced the
function pointers with the actual library symbols. There are a couple of hacks
like win32u.so loading OpenGL symbols from winex11.so to avoid statically
linking Mesa 2 times.

This Wine build is **highly** experimental. Using stiatically compiled software
is in general a **bad** idea if you don't know what you're doing and comes with
significant dangers. Use at your own risk and discretion. I assume no
responsibility for any damage resulting from using this project. I do use it
myself all the time.

Pleae report any bugs and problems. I really greatly appreciate your
feedback even if it's an angry rant about reformatted hard drive. Let's make
static-wine32 better together. Feel free to share your ideas and contributions
as well.

* Right now the only exceptions are the C and C++ standard libraries and
security software such as GnuTLS. They are so critical that statically linking
them would be insane. So make sure you install `libc6:i386` and
`libstdc++6:i386` before you run Wine. Also, some libraries are impossible to
be used statically because of their architecture.

## Installation

The build the Docker image:

1. Clone this repository.
2. Run `<prj-root>/dependencies/download.sh`. This pre-downloads the source
code of the dependencies of your machine. They will be copied into the Docker
image.
4. In `Dockerfile`, set `WITH_LLVM=1` if you want support for AMD GPUs and
a better software renderer. Set `WITH_GNUTLS=1` if you want secure networking.
5. Run `cd <prj-root>` and  execute `docker build -t static-wine32:latest .
| tee build.log`. This will take forever if you have enabled LLVM.
Be patient. Now you have a Docker image containing the statically compiled
Wine dependencies and maybe a dynamically compiled GnuTLS.
6. Run `git clone --branch static-dependnecies
https://github.com/MIvanchev/wine.git` somewhere on your disk to clone the
patched Wine repository.


This creates an image containing the compiled Wine.

### What's currently (maybe) not supported

 * Security -- Wine requires GnuTLS and I'm not linking that statically because it'll would be irresponsible
 * Vulkan -- the architecture doesn't allow static linking
 * OSS -- honestly I have no idea about that, everything is so confusing with OSS...
 * Scanning -- this shou
 * OpenCL -- I'm not knowledgable on the topic and 
 * Web cameras -- the library GPhoto is not designed for static linkage; this could be patched, V4L is included
however so you might get lucky
 * OpenLDAP -- haven't had the time to think about the best course of action; requires a daemon
 * Kerberos -- dito
 * Samba -- dito


### Isn't static linking bad?

Depends on the context. If you have to install hundreds of dependencies some of
which are probably unavailable to run a single program I think it's better to
go the static route. It's easier to update package versions and gives you
better control not to mention the speed increase. However static compilation
requires some knowledge of what's going on under the hood.

### Are external graphics drivers supported?

Not yet. The project features a statically compiled Mesa with the open-source
video drivers you're likely to need but there's no way to use dynamic libraries
supplied by your hardware's vendor (i.e. Nvidia). I'm working on allowing that
because I understand the importance. If you have an Nvidia card static-wine32
might not be for you.

### Is Vulkan supported?

No. Vulkan uses a very weird dynamic loading architecture which is not easy to
hack away.

### Credits

I'd like to thank all the people who helped me with testing and provided me
with compilation hardware.

Thanks to all the OSS devs for their hard work!

## License

You are free to use the project for yourself, who's gonna know LOL. However
you need my explicit prior consent to use the project or any part of it for
anything which you'll make available to others in whatever form.

# static-wine32

This project provides a Docker recipe for building a fully statically linked
32-bit Wine for x86_64. The motivation for this bizarre project is to avoid
having to install hundreds of :i386 dependencies in order to run Wine but it
might be useful beyond that. Just do a `sudo apt install wine32` on a freshly
installed Ubuntu and you'll see what I'm talking about. 

The project uses a continously updated modifed version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies. The changes are
only intended to make Wine compatible with statically linked dependencies.

Using stiatically compiled software is in general a BAD idea and comes with
significant risks. Use at your own risk and discreption. No responsibility
will be assumed for any damage resulting from using this project.

## Installation

The build the Docker image:

* clone this repository
* run `dependencies/download-packages.sh`
* change to the root directory
* execute `docker build -t wine:latest . | tee build.log`

This compiles creates an image containing the compiled wine.

`docker run -it wine:latest /bin/bash`

## License



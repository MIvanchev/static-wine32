# static-wine32

This project provides a Docker recipe for building a fully statically linked
32-bit Wine for x86_64. The motivation for this bizarre project is to avoid
having to install hundreds of `:i386` dependencies in order to run Wine but it
might be useful beyond that. Just do a `sudo apt install wine32` on a freshly
installed Ubuntu and you'll see what I'm talking about. 

The project uses a continously updated modifed version of Wine available at
https://github.com/MIvanchev/wine/tree/static-dependencies. The changes are
only intended to make Wine compatible with statically linked dependencies.

Using stiatically compiled software is in general a **bad** idea and comes with
significant risks. Use at your own risk and discretion. I assume no
responsibility for any damage resulting from using this project.

## Installation

The build the Docker image:

1. clone this repository
2. run `dependencies/download-packages.sh`
3. change to the root directory
4. execute `docker build -t wine:latest . | tee build.log`

This creates an image containing the compiled Wine.

## License

You are free to use the project for yourself, who's gonna know LOL. However
you need my explicit prior consent to use the project or any part of it for
anything which you'll make available to others in whatever form.

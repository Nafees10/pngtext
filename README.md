# pngtext

A steganography tool to store text or other data inside PNG images.  

**NOTE: this version (v1.0.1) is incompatible with previous versions**

## Getting Started

Follow these instructions to build pngtext. These instructions guide on how to build pngtext as a program, but it can also be used as a library.

### Prerequisites

You need to have these installed on you machine to build pngtext:

1. the `dub` package manager
1. a dlang compiler. `dmd` works, use `gdc` if you care about speed
1. an internet connection for `dub` to fetch the dependencies

### Building

Run these commands to build pngtext:

```bash
dub fetch pngtext
dub build pngtext -c=pngtextapp -b=release #--compiler=gdc # uncomment to use gdc to compile
```

If the build is succesful, the built binary will be in `~/.dub/packages/pngtext-*/pngtext/`  
Copy the binary to a path where the shell can find it (could be `~/.local/bin/`).

### Running Tests

To run the unittests on pngtext run:  
`dub test pngtext`

## Using

This describes how to use pngtext.

### Writing Data to PNG Image

### Text Editor

pngtext comes with a built in simple terminal based text editor. To edit hidden text in a png image, run this:  
`pngtext path/to/pngImage.png`  
or:  
`pngtext editor -i path/to/pngImage.png -o path/to/outputImage.png`  

### Commmands

Aside from text editor, you can also write other types of data using `write` command:  

The following command will read
data from stdin and encode it in `pngFile.png`, and write resulting image to `outputPngFile.png`:  
`pngtext write -i pngFile.png -o outputPngFile.png`  

To read the data from a file, use the `--file` or `-f` option:  
`pngtext write -i pngFile.png -o outputPngFile.png -f fileContainingData`  

### Reading Data from PNG Image

To read data, that was written using pngtext, use the `read` command:  
`pngtext read -i pngFile.png`  

To read the stored data into a file, use the `--output` or `-o` option to specify the output file:  
`pngtext read -i pngFile.png -o outputDataFile`

### Calculating Maximum Data Capacity from PNG Image

To calculate exactly how many bytes a png image will be able to store, use the `size` command:  
`pngtext size -i pngFile.png [-q QUALITY]`  
This will write the number of bytes `pngFile.png` can hold if all pixels are used.  
Possible values for `-q` option are below:

* `1` - highest quality - 3 bits per pixel
* `2` - high quality - 6 bits per pixel
* `3` - low quality - 12 bits per pixel
* `4` - zero quality - 24 bits per pixel

_1 pixel = 4 bytes = 32 bits_  
_the alpha byte is not used, so transparancy of an image will not be affected_
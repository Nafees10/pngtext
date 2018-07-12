# pngtext
A steganography tool to store text or other data inside PNG images.

## Getting Started
Follow these instructions to build pngtext

### Prerequisites
You need to have these installed on you machine to build pngtext:  
 1. `dub` package manager  
 2. a dlang compiler. `dmd` works  
 3. an internet connection for `dub` to fetch the dependencies  
 4. `git` to clone the repository  

### Building
Run these commands to build pngtext:
```
git clone https://github.com/Nafees10/pngtext
cd pngtext
dub build --build=release
```
If the build is succesful, the built binary will be in the current directory named `pngtext`.  
Copy the binary to a path where the shell can find it (could be `/usr/local/bin`).

### Running Tests
To run the unittests on pngtext, first `cd` into the directory containing pngtext, and run:  
`dub test`

## Using
This describes how to use pngtext.

### Writing Data to PNG Image
Use the `write` command to write data or text to a png image:  
`pngtext write -i pngFile.png -o outputPngFile.png [other options]`  
To write small amount of plain text, use the `--text` or `-t` option:  
`pngtext write -i pngFile.png -o outputPngFile.png -t "text to write"`  
To write non-plain-text data, or large amount of text, from file, use the `--file` or `-f` option:  
`pngtext write -i pngFile.png -o outputPngFile.png -f fileContainingData`  

### Reading Data from PNG Image:
To read data, that was written using pngtext, use the `read` command:  
`pngtext read -i pngFile.png`  
To read the stored data into a file, use the `--output` or `-o` option to specify the output file:  
`pngtext read -i pngFile.png -o outputDataFile`

### Calculating Maximum Data Capacity from PNG Image:
To calculate exactly how many bytes a png image will be able to store, use the `size` command:  
`pngtext size -i pngFile.png`  
This will write the number of bytes a png image can store to stdout.

### Specifying How Much Data to Store in Each Pixel
pngtext allows you to specify how many bits are used from each pixel. The data is only stored in the bytes storing amount of green, blue, and alpha for each pixel. The byte storing red is not used to store data. For each of the bytes used, either 2, 4, or 8 bits can be used. the default is 2, as it affects the quality of the image the least.  

To specify how many bits are to be used, use the `--density` or `-d` option:  
`pngtext write -i i.png -o o.png -t someText -d 4`  
`pngtext read -i o.png -d 4`  
`pngtext size -i i.png -d 4`  
One thing to keep in mind regarding `-d` option is that if `pngtext write` if used with `-d 4`, then `pngtext read` must also be used with the same number.
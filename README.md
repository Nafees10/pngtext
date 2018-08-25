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
Use the `write` command to write data or text to a png image.  

The following command will read 
data from stdin and encode it in `pngFile.png`, and write resulting image to `outputPngFile.png`:  
`pngtext write -i pngFile.png -o outputPngFile.png [other options]`  

To write data from a file, use the `--file` or `-f` option:  
`pngtext write -i pngFile.png -o outputPngFile.png -f fileContainingData`  

### Reading Data from PNG Image:
To read data, that was written using pngtext, use the `read` command:  
`pngtext read -i pngFile.png`  

To read the stored data into a file, use the `--output` or `-o` option to specify the output file:  
`pngtext read -i pngFile.png -o outputDataFile`

### Calculating Maximum Data Capacity from PNG Image:
To calculate exactly how many bytes a png image will be able to store, use the `size` command:  
`pngtext size -i pngFile.png`  
After asking about the quality of resulting image, it will write the number of bytes `pngFile.png` can hold if all pixels are used.
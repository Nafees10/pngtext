module pngtext;

import arsd.png;
import arsd.color;
import utils.misc;
import utils.lists;
import utils.baseconv;
import std.math;
import std.file;

/// reads a png as a stream of ubyte[4]
/// no checks are present in here to see if pngFilename is valid or not
/// Returns: array of ubyte[4], where [0] is read, [1] is blue, [2] is green, [3] is alpha
private ubyte[4][] readAsStream(string pngFilename, ref uinteger width, ref uinteger height){
	MemoryImage pngMem = readPng(pngFilename);
	ubyte[4][] r;
	height = pngMem.height;
	width = pngMem.width;
	r.length = height * width;
	for (uinteger i = 0; i < r.length; i ++){
		Color pixel = pngMem.getPixel(cast(int)(i % width), cast(int)(i / width));
		r[i][0] = pixel.r;
		r[i][1] = pixel.g;
		r[i][2] = pixel.b;
		r[i][3] = pixel.a;
	}
	return r;
}

/// writes a png from a stream of ubyte[4] to a file
/// no checks are present in here to see if pngFilename is valid or not
private void savePngStream(ubyte[4][] stream, string pngFilename, uinteger width, uinteger height){
	/// change to TrueColorImage
	TrueColorImage pngMem = new TrueColorImage(cast(int)width, cast(int)height);
	auto colorData = pngMem.imageData.colors;
	foreach (i, col; stream){
		colorData[i] = Color(col[0], col[1], col[2], col[3]);
	}
	writePng(pngFilename, pngMem);
}

/// Returns: how many bytes a png can store
public uinteger calculatePngCapacity(string pngFilename, ubyte density){
	MemoryImage pngMem = readPng(pngFilename);
	uinteger pixelCount = pngMem.width * pngMem.height;
	return pixelCount / (8 / density);
}

/// writes some data to a png image
/// Returns: [] if no errors occurred, or array of strings containing errors
public string[] writeDataToPng(string pngFilename, string outputFilename, string data, ubyte density){
	uinteger width, height;
	string[] errors = [];
	if (!exists(pngFilename) || !isFile(pngFilename)){
		errors ~= "file does not exist";
	}else if (density != 2 && density != 4 && density != 8){
		errors ~= "density must be either 2, 4, or 8";
	}else{
		ubyte[4][] pngStream = readAsStream(pngFilename, width, height);
		try{
			pngStream = encodeDataToPngStream(pngStream,
				cast(ubyte[])cast(char[])(data.dup),
				density);
			savePngStream(pngStream, outputFilename, width, height);
		}catch (Exception e){
			errors ~= e.msg;
		}
	}
	return errors;
}

/// reads some data from a png image
/// Returns: the data read in a string
/// Throws: Exception in case of error
public string readDataFromPng(string pngFilename, ubyte density){
	if (density != 2 && density != 4 && density != 8){
		throw new Exception ("density must be either 2, 4, or 8");
	}
	if (!exists(pngFilename) || !isFile(pngFilename)){
		throw new Exception ("file does not exist");
	}
	uinteger w, h;
	ubyte[4][] pngStream = readAsStream(pngFilename, w, h);
	return cast(string)cast(char[])extractDataFromPngStream(pngStream, density);
}


/// extracts the stored data-stream from a png-stream
/// Returns: the stream representing the data
private ubyte[] extractDataFromPngStream(ubyte[4][] stream, ubyte density){
	/// stores the raw data extracted, this will be processed to remove the part storing the "image" and be "joined" to become 8-bit
	ubyte[] rawData;
	foreach (pixel; stream){
		if (pixel[0] % 2 == 0){
			// it has data
			ubyte[3] toAdd = pixel[1 .. 4];
			// remove the image's pixel's data from it
			foreach (i, currentByte; toAdd){
				toAdd[i] = currentByte.readLastBits(density);
			}
			rawData ~= toAdd;
		}
	}
	/// number of bytes per actual data-storing-byte
	ubyte bytesPerChar = 8/density;
	// if there's some "extra bytes", remove those, becauese n(bytes) MOD (8/density) must equal 0
	rawData.length -= rawData.length % bytesPerChar;
	// now join the bytes
	ubyte[] data;
	data.length = rawData.length / bytesPerChar;
	for (uinteger readFrom = 0, writeTo = 0; readFrom < rawData.length; writeTo ++){
		data[writeTo] = joinByte(rawData[readFrom .. readFrom + bytesPerChar]);
		readFrom += bytesPerChar;
	}
	return data;
}

private ubyte[4][] encodeDataToPngStream(ubyte[4][] stream, ubyte[] data, ubyte density){
	// make sure it'll fit
	uinteger pixelsNeeded = (data.length * 8) / (density * 3);
	if (cast(float)(cast(float)data.length * 8f) / (cast(float)density * 3f) % 1 > 0){
		pixelsNeeded += 1;
	}
	if (pixelsNeeded > stream.length){
		throw new Exception ("there aren't enough pixels to hold that data");
	}
	stream = stream.dup;
	// divide the data into bytes where only last n-bits are used where n = density
	/// stores the data to be added to individual pixel
	ubyte[] rawData;
	rawData.length = pixelsNeeded;
	ubyte bytesPerChar = 8 / density;
	for (uinteger readFrom = 0, writeTo = 0; readFrom < data.length; readFrom ++){
		rawData[writeTo .. writeTo+bytesPerChar] = data[readFrom].splitByte(bytesPerChar);
		writeTo += bytesPerChar;
	}
	// calculate how much "gap" to leave between encoded pixels
	uinteger gapPixelsCount = (stream.length / pixelsNeeded) - 1;
	// mark the pixels that will be storing data, and make sure other pixels aren't marked, and put the data in marked pixels
	for (uinteger i = 0, readFrom = 0; i < stream.length; i ++){
		if (i % gapPixelsCount == 0){
			if (stream[i][0] % 2 != 0){
				// mark it
				if (stream[i][0] % 2 == 255)
					stream[i][0] --;
				else
					stream[i][0] ++;
			}
			// if there's no more data to put, skip
			if (readFrom >= rawData.length){
				continue;
			}
			// put data in it
			ubyte[3] rawDataToAdd = [0,0,0];
			if (readFrom+3 >= rawData.length){
				rawDataToAdd[0 .. rawData.length - readFrom] = rawData[readFrom .. rawData.length];
			}else{
				rawDataToAdd = rawData[readFrom .. readFrom + 3];
			}
			foreach (index, toAdd; rawDataToAdd){
				stream[i][index] += toAdd;
			}
		}else{
			// unmark if marked
			if (stream[i][0] % 2 == 0){
				stream[i][0] ++;
			}
		}
	}
	return stream;
}

/// stores a number in the last n-bits of a ubyte, the number must be less than 2^n
private ubyte setLastBits(ubyte originalNumber, ubyte n, ubyte toInsert){
	assert (n > 0 && toInsert < pow(2, n-1), "n must be > 0 and toInsert < pow(2,n-1) in setLastBits");
	// first, empty the last bits, so we can just use + to add
	originalNumber -=  originalNumber % pow(2, n);
	return cast(ubyte)(originalNumber + toInsert);
}
/// unittest
unittest{
	assert (cast(ubyte)(255).setLastBits(2,1) == 253);
	assert (cast(ubyte)(3).setLastBits(2,0) == 0);
	assert (cast(ubyte)(8).setLastBits(4,7) == 7);
}

/// reads and returns the number stored in last n-bits of a ubyte
private ubyte readLastBits(ubyte orignalNumber, ubyte n){
	return cast(ubyte)(orignalNumber % pow(2, n));
}
/// unittest
unittest{
	assert (cast(ubyte)(255).readLastBits(2) == 3);
	assert (cast(ubyte)(3).readLastBits(2) == 3);
	assert (cast(ubyte)(9).readLastBits(3) == 1);
}

/// splits a number stored in ubyte into several bytes, n must be either 2, 4, or 8
/// number is the number to split
/// n is the number of bytes to split into
private ubyte[] splitByte(ubyte number, ubyte n){
	assert (n == 2 || n == 4 || n == 8, "n must be 2, 4, or 8 in splitByte");
	ubyte[] r;
	r.length = n;
	uint modBy = pow(2, 8 / n);
	for (uinteger i = 0; i < n; i ++){
		r[i] = number % modBy;
		number = number / modBy;
	}
	return r;
}
/// unittest
unittest{
	assert (255.splitByte(2) == [15,15]);
	assert (255.splitByte(4) == [3,3,3,3]);
	assert (127.splitByte(2) == [15,7]);
}

/// joins bits from multiple bytes into a single number, i.e: opposite of splitByte
/// split is the ubyte[] in which only the last n-bits from each byte stores the required number
/// split.length must be either 2, 4, or 8
private ubyte joinByte(ubyte[] split){
	assert (split.length == 2 || split.length == 4 || split.length == 8, "split.length must be either 2, 4, or 8");
	ubyte r = 0;
	ubyte bitCount = 8 / split.length;
	uint modBy = cast(uint)pow(2, bitCount);
	for (uinteger i = 0; i < split.length; i ++){
		r += (split[i] % modBy) * pow(2, i * bitCount);
	}
	return r;
}
/// unittest
unittest{
	assert (255.splitByte(4).joinByte == 255);
	assert (255.splitByte(2).joinByte == 255);
	assert (126.splitByte(4).joinByte == 126);
	assert (127.splitByte(4).joinByte == 127);
}

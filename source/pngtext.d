module pngtext;

import arsd.png;
import arsd.color;
import utils.misc;
import utils.lists;
import utils.baseconv;
import std.math;
import std.file;

// constants

/// Number of bytes per pixel (red, green, blue, & alpha = 4)
const BYTES_PER_PIXEL = 4;
/// Number of bytes taken by header
const HEADER_BYTES = 12;
/// Density for writing/reading header
const HEADER_DENSITY = 2;

/// reads a png as a stream of ubyte[4]
/// no checks are present in here to see if pngFilename is valid or not
/// Returns: array with values of rgba of all pixels one after another
private ubyte[] readAsStream(string pngFilename, ref uinteger width, ref uinteger height){
	MemoryImage pngMem = readPng(pngFilename);
	ubyte[] r;
	height = pngMem.height;
	width = pngMem.width;
	r.length = height * width * BYTES_PER_PIXEL;
	for (uinteger i = 0, readTill = height * width; i < readTill; i ++){
		Color pixel = pngMem.getPixel(cast(int)(i % width), cast(int)(i / width));
		r[i*BYTES_PER_PIXEL .. (i+1)*BYTES_PER_PIXEL] = [pixel.r, pixel.g, pixel.b, pixel.a];
	}
	return r;
}

/// writes a png from a stream of ubyte[4] to a file
/// no checks are present in here to see if pngFilename is valid or not
private void savePngStream(ubyte[] stream, string pngFilename, uinteger width, uinteger height){
	/// change to TrueColorImage
	TrueColorImage pngMem = new TrueColorImage(cast(int)width, cast(int)height);
	auto colorData = pngMem.imageData.colors;
	for (uinteger i = 0; i < stream.length; i += BYTES_PER_PIXEL){
		colorData[i/BYTES_PER_PIXEL] = Color(stream[i], stream[i+1], stream[i+2], stream[i+3]);
	}
	writePng(pngFilename, pngMem);
}

/// Returns: how many bytes a png can store
public uinteger calculatePngCapacity(string pngFilename, ubyte density){
	MemoryImage pngMem = readPng(pngFilename);
	uinteger pixelCount = pngMem.width * pngMem.height;
	if (pixelCount <= 3){
		return 0;
	}
	return (pixelCount - 3)*density/2;
}

/// Returns: bytes required to hold data at a certain density
private uinteger calculateBytesNeeded(uinteger dataLength, ubyte density){
	return dataLength * 8 / density;
}

/// writes some data to a png image
/// Returns: [] if no errors occurred, or array of strings containing errors
public string[] writeDataToPng(string pngFilename, string outputFilename, string data, ubyte density){
	uinteger width, height;
	string[] errors = [];
	if (!exists(pngFilename) || !isFile(pngFilename)){
		errors ~= "file does not exist";
	}else if (density != 1 && density != 2 && density != 4 && density != 8){
		errors ~= "density must be either 2, 4, or 8";
	}else{
		ubyte[] pngStream = readAsStream(pngFilename, width, height);
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
	if (density != 1 && density != 2 && density != 4 && density != 8){
		throw new Exception ("density must be either 1, 2, 4, or 8");
	}
	if (!exists(pngFilename) || !isFile(pngFilename)){
		throw new Exception ("file does not exist");
	}
	uinteger w, h;
	ubyte[] pngStream = readAsStream(pngFilename, w, h);
	return cast(string)cast(char[])extractDataFromPngStream(pngStream, density);
}

/// reads the header (data-length) from begining of png stream
uinteger readHeader(ubyte[] stream){
	ubyte[HEADER_BYTES / BYTES_PER_PIXEL] headerBytes;
	ubyte[HEADER_BYTES] headerPixels;
	foreach (i, b; stream[0 .. HEADER_BYTES]){
		headerPixels[i] = b.readLastBits(HEADER_DENSITY);
	}
	ubyte bytesPerChar = 8 / HEADER_DENSITY;
	for (uinteger i = 0; i < HEADER_BYTES; i += bytesPerChar){
		headerBytes[i / bytesPerChar] = joinByte(headerPixels[i .. i + bytesPerChar]);
	}
	return charToDenary(cast(char[])headerBytes);
}

/// Returns: the header (first 3 pixels storing the data-length)
ubyte[HEADER_BYTES] writeHeader(uint dataLength, ubyte[HEADER_BYTES] stream){
	assert (dataLength <= pow (2, 24), "data-length must be less than 16 megabytes");
	ubyte[] data = cast(ubyte[])(dataLength.denaryToChar());
	ubyte[] rawData;
	ubyte bytesPerChar = 8/HEADER_DENSITY;
	for (uinteger i = 0; i < data.length; i ++){
		rawData ~= data[i].splitByte(bytesPerChar);
	}
	if (rawData.length < HEADER_BYTES){
		ubyte[] newData;
		newData.length = HEADER_BYTES;
		newData[] = 0;
		newData[HEADER_BYTES - rawData.length .. newData.length] = rawData;
		rawData = newData;
	}
	stream = stream.dup;
	for (uinteger i = 0; i < rawData.length; i ++){
		stream[i] = stream[i].setLastBits(HEADER_DENSITY, rawData[i]);
	}
	return stream;
}

/// extracts the stored data-stream from a png-stream
/// Returns: the stream representing the data
private ubyte[] extractDataFromPngStream(ubyte[] stream, ubyte density){
	// stream.length must be at least 3 pixels, i.e stream.length == 3*4
	assert (stream.length >= HEADER_BYTES, "image does not have enough pixels");
	stream = stream.dup;
	uinteger length = readHeader(stream[0 .. HEADER_BYTES]);
	stream = stream[HEADER_BYTES .. stream.length];
	/// stores the raw data extracted, this will be processed to remove the part storing the "image" and be "joined" to become 8-bit
	ubyte[] rawData;
	rawData.length = calculateBytesNeeded(length, density);
	// extract the last few bits
	for (uinteger i = 0; i < rawData.length; i++){
		rawData[i] = stream[i].readLastBits(density);
	}
	/// number of bytes per actual data-storing-byte
	ubyte bytesPerChar = 8/density;
	// if there's some "extra bytes", remove those, becauese n(bytes) MOD (8/density) must equal 0
	rawData.length -= rawData.length % bytesPerChar;
	// now join the bytes
	ubyte[] data;
	data.length = length;
	for (uinteger i = 0; i < rawData.length; i += bytesPerChar){
		data[i / bytesPerChar] = joinByte(rawData[i .. i + bytesPerChar]);
	}
	return data;
}

private ubyte[] encodeDataToPngStream(ubyte[] stream, ubyte[] data, ubyte density){
	// stream.length must be at least 3 pixels, i.e stream.length == 3*4
	assert (stream.length >= HEADER_BYTES, "image does not have enough pixels");
	// data can not be more than or equal to 2^(4*3*2) = 2^24 bytes
	assert (data.length < pow(2, HEADER_BYTES * HEADER_DENSITY), "data length is too much to be stored in header");
	// make sure it'll fit
	assert (calculateBytesNeeded(data.length, density) + HEADER_BYTES <= stream.length,
		"image does not have enough pixels to hold that mcuh data");
	stream = stream.dup;
	// put the header into the data (header = stores the length of the data, excluding the header)
	ubyte[HEADER_BYTES] headerStream = writeHeader(cast(uint)data.length, stream[0 .. HEADER_BYTES]);
	stream = stream[HEADER_BYTES .. stream.length];
	/// stores the data to be added to individual pixel
	ubyte[] rawData;
	// divide the data into bytes where only last n-bits are used where n = density
	ubyte bytesPerChar = 8 / density;
	for (uinteger i = 0; i < data.length; i ++){
		rawData ~= data[i].splitByte(bytesPerChar);
	}
	for (uinteger i = 0; i < rawData.length; i ++){
		stream[i] = stream[i].setLastBits(density, rawData[i]);
	}
	return headerStream ~ stream;
}

/// stores a number in the last n-bits of a ubyte, the number must be less than 2^n
private ubyte setLastBits(ubyte originalNumber, ubyte n, ubyte toInsert){
	assert (n > 0 && toInsert < pow(2, n), "n must be > 0 and toInsert < pow(2,n) in setLastBits");
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

/// splits a number stored in ubyte into several bytes
/// number is the number to split
/// n is the number of bytes to split into
private ubyte[] splitByte(ubyte number, ubyte n){
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
	assert (split.length == 1 || split.length == 2 || split.length == 4 || split.length == 8,
		"split.length must be either 1, 2, 4, or 8");
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

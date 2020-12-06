/++
Contains the functions to read/write to hidden data in png files.
+/
module pngtext.pngtext;

import arsd.png;
import arsd.color;
import utils.misc;
import std.file;
import std.conv : to;
debug{import std.stdio;}

// constants

/// version
private enum PNGTEXT_VERSION = "1.0.1";

/// Number of bytes per pixel (red, green, blue, & alpha = 4)
private enum BYTES_PER_PIXEL = 4;
/// Number of bytes per pixel that are to be used
private enum BYTES_USE_PER_PIXEL = 3;
/// Number of bytes taken by header in image (after encoding)
private enum HEADER_BYTES = 12;
/// Density for writing/reading header
private enum HEADER_DENSITY = 2;
/// length of data stored in header
private enum HEADER_LENGTH = HEADER_BYTES * HEADER_DENSITY / 8;
/// max number that can be stored in header
private enum HEADER_MAX = (1 << HEADER_LENGTH * 8) - 1;

version (app){
	/// description of constants
	public enum CONST_INFO = 
"PNGText version: "~PNGTEXT_VERSION~"
bytes per pixel: "~BYTES_USE_PER_PIXEL.to!string~"
bytes for header: "~HEADER_BYTES.to!string~"
bits/byte (density) for header: "~HEADER_DENSITY.to!string~"
header length: "~HEADER_LENGTH.to!string~"
max stored data length: "~HEADER_MAX.to!string~" bytes";
}

/// Low storage density (1 bit per 8 bits)
public enum DENSITY_LOW = 1;
/// Medium storage density (2 bits per 8 bits)
public enum DENSITY_MEDIUM = 2;
/// High storage density (4 bits per 8 bits)
public enum DENSITY_HIGH = 4;
/// Maximum storage density (8 bits per 8 bits)
public enum DENSITY_MAX = 8;

/// Possible values for density
public const ubyte[4] DENSITIES = [1, 2, 4, 8];
/// names associated with above densities
public const string[4] DENSITY_NAMES = ["low", "medium", "high", "maximum"];
/// quality names associated with above densities
public const string[4] QUALITY_NAMES = ["highest", "medium", "low", "zero"];

/// Bytes with the number of bits as 1 same as density
private const ubyte[4] DENSITY_BYTES = [0B00000001, 0B00000011, 0B00001111, 0B11111111];

/// To read/write data from a png image
public class PNGText{
private:
	/// the png image currently being edited
	TrueColorImage _pngImage;
	/// the png image as an array of ubyte (excluding alpha)
	ubyte[] _stream;
	/// filename of currently loaded image
	string _filename;
	/// if there is an image loaded
	bool _loaded = false;
	/// max number of bytes currently loaded image can store. -1 if not yet calculated
	int[ubyte] _capacity;
	/// the data to encode into the image
	ubyte[] _data;

	/// "splits" a single ubyte over an array of ubyte
	/// 
	/// `val` is the byte to split
	/// `densityMask` is the index of chosen density in `DENSITIES`
	/// `r` is the array/slice to put the splitted byte to
	static void splitByte(ubyte val, ubyte densityIndex, ubyte[] r){
		immutable ubyte mask = DENSITY_BYTES[densityIndex];
		immutable ubyte density = DENSITIES[densityIndex];
		for (ubyte i = 0; i < r.length; i ++){
			r[i] = (r[i] & (~cast(int)mask) ) | ( ( val >> (i * density) ) & mask );
		}
	}
	/// opposite of splitByte, joins last bits from ubyte[] to make a single ubyte
	static ubyte joinByte(ubyte[] bytes, ubyte densityIndex){
		immutable ubyte mask = DENSITY_BYTES[densityIndex];
		immutable ubyte density = DENSITIES[densityIndex];
		ubyte r = 0;
		for (ubyte i = 0; i < bytes.length; i ++){
			r |= ( bytes[i] & mask ) << (i * density);
		}
		return r;
	}

	/// Calculates capacity of an image
	void calculateCapacity(ubyte density){
		if (!_loaded || _stream.length <= HEADER_BYTES)
			return;
		_capacity[density] = ((cast(int)_stream.length - HEADER_BYTES) * density) / 8; /// bytes * density / 8;
	}
	/// ditto
	void calculateCapacity(){
		foreach (density; DENSITIES)
			calculateCapacity(density);
	}
	/// Calculates number of bytes needed in _stream to store n bytes of data. Adjusts for HEADER_BYTES
	///
	/// Returns: number of bytes needed
	static int streamBytesNeeded(int n, ubyte density){
		if (n == 0)
			return HEADER_BYTES;
		return HEADER_BYTES + ((n * 8)/density);
	}
	/// Calculates smallest value for density with which n bytes of data will fit in a number of bytes of _stream
	/// 
	/// Returns: smallest value for density that can be used in this case, or 0 if data wont fit
	static ubyte calculateOptimumDensity(int n, int streamBytes){
		foreach (density; DENSITIES){
			if (streamBytesNeeded(n, density) <= streamBytes)
				return density;
		}
		return 0;
	}
	/// reads header bytes from stream
	ubyte[HEADER_LENGTH] readHeader(){
		ubyte[HEADER_LENGTH] header;
		immutable ubyte byteCount = 8 / HEADER_DENSITY; /// number of bytes in stream for single byte of header
		immutable ubyte densityIndex = cast(ubyte)DENSITIES.indexOf(HEADER_DENSITY);
		foreach (i; 0 .. HEADER_LENGTH){
			header[i] = joinByte(_stream[i*byteCount .. (i+1)*byteCount], densityIndex);
		}
		return header;
	}
	/// writes bytes to header in stream
	void writeHeader(ubyte[] header){
		immutable ubyte byteCount = 8 / HEADER_DENSITY; /// number of bytes in stream for single byte of header
		immutable ubyte densityIndex = cast(ubyte)DENSITIES.indexOf(HEADER_DENSITY);
		if (header.length > HEADER_LENGTH)
			header = header[0 .. HEADER_LENGTH];
		foreach (i, byteVal; header){
			splitByte(byteVal, densityIndex, _stream[i*byteCount .. (i+1)*byteCount]);
		}
	}
	/// encodes _data to _stream. No checks are performed, so make sure the data fits before calling this
	void encodeDataToStream(ubyte density, int offset = HEADER_BYTES){
		immutable ubyte densityIndex = cast(ubyte)DENSITIES.indexOf(density);
		immutable ubyte byteCount = 8 / density;
		foreach (i, byteVal; _data){
			splitByte(byteVal, densityIndex, _stream[(i*byteCount) + offset .. ((i+1)*byteCount) + offset]);
		}
	}
	/// reads into _data from _stream. _data must have enough length before this function is called
	void decodeDataFromStream(ubyte density, int length, int offset = HEADER_BYTES){
		immutable ubyte densityIndex = cast(ubyte)DENSITIES.indexOf(density);
		immutable ubyte byteCount = 8 / density;
		foreach (i; 0 .. length){
			_data[i] = joinByte(_stream[(i*byteCount) + offset .. ((i+1)*byteCount) + offset], densityIndex);
		}
	}
	/// writes _stream back into _pngImage
	void encodeStreamToImage(){
		for (int i = 0, readIndex = 0; i < _pngImage.imageData.bytes.length && readIndex < _stream.length;
		i += BYTES_PER_PIXEL){
			foreach (j; 0 .. 3){
				if (readIndex >= _stream.length)
					break;
				_pngImage.imageData.bytes[i+j] = _stream[readIndex];
				readIndex ++;
			}
		}
	}
	/// Creates a dummy stream of length l. USE FOR DEBUG ONLY
	void createDummyStream(uint l){
		_stream.length = l;
	}
public:
	/// Constructor
	this(){
		_loaded = false;
	}
	~this(){
	}
	/// Checks if a number is a valid value for use as storage density
	/// 
	/// Returns: true if valid
	static bool isValidDensity(ubyte density){
		return DENSITIES.hasElement(density);
	}
	/// Returns: a string describing a certain density. Or an empty string in case of invalid density value
	static string densityName(ubyte density){
		if (!isValidDensity(density))
			return "";
		return DENSITY_NAMES[DENSITIES.indexOf(density)];
	}
	/// Returns: a string describing image quality at a certain density. or empty string in case of invalid density value
	static string qualityName(ubyte density){
		if (!isValidDensity(density))
			return "";
		return QUALITY_NAMES[DENSITIES.indexOf(density)];
	}
	/// Returns: the filename to read/write the image from/to
	@property string filename(){
		return _filename;
	}
	/// ditto
	@property string filename(string newVal){
		return _filename = newVal;
	}
	/// Returns: true if an image is loaded
	@property bool imageLoaded(){
		return _loaded;
	}
	/// Returns: the data to encode, or the data that was decoded from a loaded image
	@property ref ubyte[] data(){
		return _data;
	}
	/// ditto
	@property ref ubyte[] data(ubyte[] newVal){
		return _data = newVal;
	}
	/// Returns: the capacity of an image at a certain storage density. In case of error, like invalid density value, returns -1
	int capacity(ubyte density){
		if (!isValidDensity(density))
			return -1;
		if (density !in _capacity || _capacity[density] == -1)
			calculateCapacity(density);
		return _capacity[density];
	}
	/// Loads an image.
	/// 
	/// Throws: Exception in case of error
	void load(){
		if (_filename == "" || !exists(_filename) || !isFile(_filename))
			throw new Exception(_filename~" is not a valid filename, or file does not exist");
		_loaded = false;
		_pngImage = readPng(_filename).getAsTrueColorImage;
		immutable int height = _pngImage.height, width = _pngImage.width;
		_stream.length = height * width * BYTES_USE_PER_PIXEL;
		for (int i = 0, writeIndex = 0; i < _pngImage.imageData.bytes.length; i += BYTES_PER_PIXEL){
			foreach (j; 0 .. 3){
				_stream[writeIndex] = _pngImage.imageData.bytes[i+j];
				writeIndex ++;
			}
		}
		_loaded = true;
	}
	/// Saves an image
	/// 
	/// Throws: Exception in case of error
	void save(){
		if (_filename == "")
			throw new Exception(_filename~" is not a valid filename, or file already exists");
		writePng(_filename, _pngImage);
	}
	/// Calculates the least density that can be used to store n bytes into loaded image.
	/// 
	/// Returns: calculated density, or zero in case of error
	ubyte calculateOptimumDensity(int n){
		if (!imageLoaded || n <= HEADER_BYTES)
			return 0;
		return calculateOptimumDensity(n, cast(int)_stream.length);
	}
	/// encodes data into loaded image.
	/// 
	/// Throws: Exception on error
	void encode(){
		if (!imageLoaded)
			throw new Exception("no image loaded, cannot encode data");
		immutable ubyte density = calculateOptimumDensity(cast(int)_data.length);
		if (density == 0)
			throw new Exception("image too small to hold data");
		if (_data.length > HEADER_MAX)
			throw new Exception("data is bigger than "~HEADER_MAX.to!string~" bytes");
		// put header in, well, header
		ubyte[HEADER_LENGTH] header;
		foreach (i; 0 .. HEADER_LENGTH)
			header[i] = cast(ubyte)( _data.length >> (i * 8) );
		this.writeHeader(header);
		this.encodeDataToStream(density);
		this.encodeStreamToImage();
	}
	/// decodes data from loaded image
	/// 
	/// Throws: Exception on error
	void decode(){
		if (!imageLoaded)
			throw new Exception("no image loaded, cannot decode data");
		// read header, needed for further tests
		if (_stream.length < HEADER_BYTES)
			throw new Exception("image too small to hold data, invalid header");
		immutable ubyte[HEADER_LENGTH] header = readHeader();
		int len = 0;
		foreach (i, byteVal; header)
			len |= byteVal << (i * 8);
		immutable ubyte density = calculateOptimumDensity(len);
		if (len > HEADER_MAX || len > capacity(DENSITY_MAX) || density == 0)
			throw new Exception("invalid data");
		_data.length = len;
		decodeDataFromStream(density, len);
	}
}
/// 
unittest{
	writeln("pngtext.d unittests:");
	import std.stdio : writeln;
	import std.conv : to;
	writeln("unittests for PNGText.splitByte and PNGText.joinByte started");
	// splitByte
	ubyte[] bytes;
	bytes.length = 8;
	bytes[] = 128;
	PNGText.splitByte(cast(ubyte)0B10101010, cast(ubyte)0, bytes);
	assert(bytes == [128, 129, 128, 129, 128, 129, 128, 129]);
	assert(PNGText.joinByte(bytes, cast(ubyte)0) == 0B10101010);

	PNGText.splitByte(cast(ubyte)0B10101010, cast(ubyte)1, bytes);
	assert(bytes[0 .. 4] == [130, 130, 130, 130]);
	assert(PNGText.joinByte(bytes[0 .. 4], cast(ubyte)1) == 0B10101010);

	PNGText.splitByte(cast(ubyte)0B10101010, cast(ubyte)2, bytes);
	assert(bytes[0 .. 2] == [0B10001010, 0B10001010]);
	assert(PNGText.joinByte(bytes[0 .. 2], cast(ubyte)2) == 0B10101010);

	PNGText.splitByte(cast(ubyte)0B10101010, cast(ubyte)3, bytes);
	assert(bytes[0] == 0B10101010);
	assert(PNGText.joinByte(bytes[0 .. 1], cast(ubyte)3) == 0B10101010);

	writeln("unittests for PNGText.writeHeader and PNGText.readHeader started");
	// write some stuff
	PNGText obj = new PNGText();
	obj.createDummyStream(1024);
	obj._stream[] = 0B01011100;
	bytes.length = HEADER_LENGTH;
	bytes = [215, 1, 0];
	obj.writeHeader(bytes);
	assert (obj.readHeader == bytes);
	// write some more stuff
	bytes[] = 0B00111100;
	obj.writeHeader(bytes);
	assert(obj.readHeader == [0B00111100, 0B00111100, 0B00111100]);

	writeln("unittests for PNGText.encodeDataToStream and PNGText.decodeDataFromStream started");
	bytes.length = 100;
	foreach (i; 0 .. bytes.length){
		bytes[i] = cast(ubyte)i;
	}
	foreach (density; DENSITIES){
		obj._data = bytes.dup;
		writeln("\tencoding with density=",density);
		obj.encodeDataToStream(density);
		obj._data[] = 0;
		writeln("\tdecoding with density=",density);
		obj.decodeDataFromStream(density, 100);
		assert(obj._data == bytes);
	}
	writeln("pngtext.d unittests over");
}
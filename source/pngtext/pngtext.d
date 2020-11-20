/++
Contains the functions to read/write to hidden data in png files.
+/
module pngtext.pngtext;

import arsd.png;
import arsd.color;
import utils.misc;
import utils.lists;
import utils.baseconv;
import std.math;
import std.file;
debug{import std.stdio, std.conv : to;}

// constants

/// Number of bytes per pixel (red, green, blue, & alpha = 4)
private enum BYTES_PER_PIXEL = 4;
/// Number of bytes per pixel that are to be used
private enum BYTES_USE_PER_PIXEL = 3;
/// Number of bytes taken by header
private enum HEADER_BYTES = 12;
/// Density for writing/reading header
private enum HEADER_DENSITY = 2;

/// Low storage density (1 bit per 8 bits)
public enum DENSITY_LOW = 1;
/// Medium storage density (2 bits per 8 bits)
public enum DENSITY_MEDIUM = 2;
/// High storage density (4 bits per 8 bits)
public enum DENSITY_HIGH = 4;
/// Maximum storage density (8 bits per 8 bits)
public enum DENSITY_MAX = 8;

/// Possible values for density
private const ubyte[4] DENSITIES = [1, 2, 4, 8];
/// names associated with above densities
private const string[4] DENSITY_NAMES = ["low", "medium", "high", "maximum"];
/// quality names associated with above densities
private const string[4] QUALITY_NAMES = ["highest", "medium", "low", "zero"];
/// Bytes with the number of bits as 1 same as density
private const ubyte[4] DENSITY_BYTES = [0B00000001, 0B00000011, 0B00001111, 0B11111111];

/// To read/write data from a png image
class PNGText{
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
	int[DENSITIES.length] _capacity;
	/// the data to encode into the image
	ubyte[] _data;

	/// "splits" a single ubyte over an array of ubyte
	/// 
	/// `val` is the byte to split
	/// `densityMask` is the index of chosen density in `DENSITIES`
	/// `r` is the array/slice to put the splitted byte to
	void splitByte(ubyte val, ubyte densityIndex, ref ubyte[] r){
		immutable ubyte mask = DENSITY_BYTES[densityIndex];
		immutable ubyte density = DENSITIES[densityIndex];
		immutable ubyte bytesCount = DENSITIES[$ - (densityIndex+1)]; // just read DENSITIES in reverse to read number of bytes needed
		for (ubyte i = 0; i < bytesCount; i ++){
			r[i] = (r[i] & !mask) | ( ( val >> (i * density) ) & mask );
		}
	}

	/// Calculates capacity of an image
	void calculateCapacity(ubyte density){
		if (!_loaded){
			_capacity[] = -1;
			return;
		}
		immutable uint pixels = _pngImage.width * _pngImage.height;
		_capacity[density] = 0;
		if (pixels <= HEADER_BYTES / BYTES_PER_PIXEL)
			return;
		_capacity[density] = ((pixels - (HEADER_BYTES / BYTES_PER_PIXEL)) * density) / 8; // (totalPixels - headerPixels)*8 / density
	}
	/// ditto
	void calculateCapacity(){
		foreach (density; DENSITIES)
			calculateCapacity(density);
	}
	/// writes _stream back into _pngImage
	void encodeStreamToImage(){
		for (uint i = 0, readIndex = 0; i < _pngImage.imageData.bytes.length && readIndex < _stream.length;
		i += BYTES_PER_PIXEL){
			foreach (j; 0 .. 3){
				if (readIndex >= _stream.length)
					break;
				_pngImage.imageData.bytes[i+j] = _stream[readIndex];
				readIndex ++;
			}
		}
	}
	/// encodes _data to _stream. No checks are performed, so make sure the data fits before calling this
	void encodeDataToStream(){
		/// start with the header (length of data)

	}
public:
	/// Constructor
	this(){
		_loaded = false;
		_capacity[] = -1;
	}
	~this(){
	}
	/// Calculates number of pixels needed to store n number of bytes
	///
	/// Returns: number of pixels needed, -1 if invalid density
	static int pixelsNeeded(uint n, ubyte density){
		static immutable int headerPixels = HEADER_BYTES / BYTES_PER_PIXEL;
		if (n == 0)
			return headerPixels;
		immutable int r = (n * 8)/density; // (n*8) is number of bits in n, overall, this becomes the number of bytes needed
		return headerPixels + (r/BYTES_USE_PER_PIXEL) + (r % BYTES_USE_PER_PIXEL ? 1 : 0);
	}
	/// Calculates smallest value for density with which n bytes of data will fit in a number of pixels
	/// 
	/// Returns: smallest value for density that can be used in this case, or 0 if data wont fit
	static ubyte calculateOptimumDensity(uint n, uint pixels){
		foreach (density; DENSITIES){
			if (pixelsNeeded(n, density) <= pixels)
				return density;
		}
		return 0;
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
		if (_capacity[density] == -1)
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
		_capacity[] = -1;
		_pngImage = readPng(_filename).getAsTrueColorImage;
		immutable int height = _pngImage.height, width = _pngImage.width;
		_stream.length = height * width * BYTES_USE_PER_PIXEL;
		for (uint i = 0, writeIndex = 0; i < _pngImage.imageData.bytes.length; i += BYTES_PER_PIXEL){
			foreach (j; 0 .. 3){
				_stream[writeIndex] = _pngImage.imageData.bytes[i+j];
				writeIndex ++;
			}
		}
		_capacity[] = -1;
		_loaded = true;
	}
	/// Saves an image
	/// 
	/// Throws: Exception in case of error
	void save(){
		if (_filename == "" || exists(_filename))
			throw new Exception(_filename~" is not a valid filename, or file already exists");
		writePng(_filename, _pngImage);
	}
}
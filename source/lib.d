module lib;

version(lib){
	import utils.misc;
	import pngtext;
	import std.string;

	/// reads data from png image
	extern (C) ubyte[] readFromPng(char* filename){
		return readDataFromPng(cast(string)fromStringz(filename));
	}

	/// writes data to png image
	extern (C) void writeToPng(char* filename, char* outputFilename, ubyte[] data){
		writeDataToPng(cast(string)fromStringz(filename),
			cast(string)fromStringz(outputFilename),
			data);
	}

	/// returns the number of bytes that can be stored when the image is "saturated", i.e, capacity at zero quality
	extern (C) uinteger pngCapacityMax(char* filename){
		return calculatePngCapacity (cast(string)fromStringz(filename), 8);
	}

	/// returns the number of bytes that can be stored when at low quality
	extern (C) uinteger pngCapacityLowQ(char* filename){
		return calculatePngCapacity (cast(string)fromStringz(filename), 4);
	}

	/// returns the number of bytes that can be stored at high quality
	extern (C) uinteger pngCapacityHighQ(char* filename){
		return calculatePngCapacity (cast(string)fromStringz(filename), 2);
	}

	/// returns a float number, which tells the quality of the output image
	/// 
	/// the number is the average number of bits used per one byte (each pixel = 4 bytes). Only bytes from pixels which are used to hold
	/// data are considered in the calcualtion, untouched pixels are not counted as they remain as-they-were;
	/// the number can be at max 8 (saturated image), lowest 0 (no data & highest quality). Lower means higher quality.
	extern (C) float getQuality(char* filename, uinteger dataLength){
		// get the optimum quality assoc_array
		uinteger[ubyte] optimumQ = calculateOptimumDensity(cast(string)fromStringz(filename) , dataLength);
		// The formula is (index * value at index, for each index) / (total used bytes, = sum of values at all indexes)
		uinteger numerator = 0, denominator = 0;
		foreach (index, value; optimumQ){
			numerator += index * value;
			denominator += value;
		}
		return (cast(float)numerator) / (cast(float)denominator);
	}
}

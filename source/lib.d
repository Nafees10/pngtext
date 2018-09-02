module lib;

version(lib){
	import utils.misc;
	import pngtext;
	import std.string;
	import core.runtime;
	import core.memory;

	/// to init the runtime, idk why `shared static this` won't work
	extern (C) void init(){
		rt_init();
	}

	/// to terminate the runtime, idk why `shared static ~this` won't work
	extern (C) void term(){
		if (dataRead.ptr !is null){
			.destroy (dataRead);
		}
		GC.collect();
		rt_term;
	}

	/// stores the return from readFromPng so the GC doesn't free that memory
	private ubyte[] dataRead;

	/// reads data from png image
	extern (C) ubyte* readFromPng(char* fn, uint* length){
		string filename = fromStringz(fn).idup;
		if (dataRead.ptr !is null){
			.destroy (dataRead);
		}
		try{
			dataRead = readDataFromPng(filename);
		}catch (Exception e){
			*length = 0;
			return null;
		}
		*length = cast(uint)dataRead.length;
		return dataRead.ptr;
	}

	/// writes data to png image
	/// 
	/// Returns: true if successful
	extern (C) bool writeToPng(char* fn, char* oFn, ubyte* dataPtr, uint dataLength){
		string filename = fromStringz(fn).idup;
		string outputFilename = fromStringz(oFn).idup;
		ubyte[] data;
		data.length = dataLength;
		ubyte* ptr = dataPtr;
		foreach (i; 0 .. dataLength){
			data[i] = *dataPtr;
			dataPtr++;
		}
		try{
			return writeDataToPng(filename, outputFilename, data).length == 0? true : false;
		}catch (Exception e){
			return false;
		}
	}

	/// returns the number of bytes that can be stored
	extern (C) uint pngCapacity(char* fn, ubyte density){
		string filename = fromStringz(fn).idup;
		return cast(uint)calculatePngCapacity (filename, density);
	}

	/// returns a float number, which tells the quality of the output image
	/// 
	/// the number is the average number of bits used per one byte (each pixel = 4 bytes). Only bytes from pixels which are used to hold
	/// data are considered in the calcualtion, untouched pixels are not counted as they remain as-they-were;
	/// the number can be at max 8 (saturated image), lowest 0 (no data & highest quality). Lower means higher quality.
	extern (C) float getQuality(char* fn, uint dataLength){
		string filename = fromStringz(fn).idup;
		// get the optimum quality assoc_array
		uinteger[ubyte] optimumQ = calculateOptimumDensity(filename , dataLength);
		// The formula is (index * value at index, for each index) / (total used bytes, = sum of values at all indexes)
		uinteger numerator = 0, denominator = 0;
		foreach (index, value; optimumQ){
			numerator += index * value;
			denominator += value;
		}
		return (cast(float)numerator*8) / (cast(float)denominator*8);
		
	}
}

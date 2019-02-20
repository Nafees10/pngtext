module app;

version (app){
	import std.stdio;
	import std.conv : to;
	import core.stdc.stdlib;
	import utils.misc;
	import std.file;
	import pngtext.pngtext;
	// QUI for the text editor
	import qui.qui;
	import qui.widgets;
	import editor;

	/// stores the version
	const VERSION = "0.2.0";

	/// stores the default density
	const DEFAULT_DENSITY = 1;

	// help text
	const string HELP_TEXT = "pngtext - hides data inside png images
usage:
pngtext [command] [options]
commands:
 write         write to a png file, if --file is not specified, stdin is used to
               input data
 read          read data from a png file
 size          calculate how many bytes a png image can store.
 editor        opens a text editor in terminal to edit hidden text.
options:
 --file -f     specify file containing data to write into png image
 --input -i    specify original png image to write to, or read from
 --ouput -o    specify file to write output to, for write, and read
 --version -v  display this program's version
 --help -h     display this message";

	void main(string[] args){
		if (args.length >= 2){
			if (args[1] == "--version" || args[1] == "-v"){
				writeln(VERSION);
			}else if (args[1] == "--help" || args[1] == "-h"){
				writeln(HELP_TEXT);
			}else{
				string command;
				string[string] options;
				string[] errors;
				options = readArgs(args[1 .. args.length].dup, command, errors);
				foreach (error; errors){
					writeln ("error: "~error);
				}
				if (errors.length > 0){
					exit(1);
				}
				errors = validateOptions(options.dup, command);
				foreach (error; errors){
					writeln ("error: "~error);
				}
				if (errors.length > 0){
					exit(1);
				}
				if (command == "write"){
					string inputFile = options["input"];
					string outputFile = options["output"];
					string text;
					if ("file" in options){
						text = cast(string)cast(char[])read(options["file"]);
					}else{
						writeln ("Enter text to write (Ctrl+D to terminate):");
						text = "";
						while (!stdin.eof){
							char c;
							readf ("%s", c);
							text ~= c;
						}
					}
					errors = writeDataToPng(inputFile, outputFile, cast(ubyte[])cast(char[])text);
					foreach (error; errors){
						writeln (error);
					}
					if (errors.length > 0){
						exit(1);
					}
				}else if (command == "read"){
					string inputFile = options["input"];
					ubyte[] text;
					try{
						text = readDataFromPng(inputFile);
					}catch (Exception e){
						writeln ("Failed to read from png image:\n",e.msg);
					}
					if ("output" in options){
						try{
							File outputFile = File(options["output"], "w");
							outputFile.write(cast(char[])text);
							outputFile.close();
						}catch (Exception e){
							writeln ("Failed to write to output file:\n",e.msg);
						}
					}else{
						writeln (cast(string)cast(char[])text);
					}
				}else if (command == "size"){
					string inputFile = options["input"];
					// get the quality
					writeln ("Select an image quality:\n"," [1] Highest\n [2] High\n [3] Low\n [4] Zero quality:");
					string quality = readln;
					quality.length --;
					if (["1","2","3","4"].hasElement(quality)){
						try{
							writeln (calculatePngCapacity(inputFile, quality=="1"?1 : (quality == "2" ? 2 : (quality == "3" ? 4 : 8))));
						}catch (Exception e){
							writeln ("Failed to read png image:\n",e.msg);
						}
					}else{
						writeln ("Invalid selection");
						exit (1);
					}
				}else if (command == "editor"){
					// if no output specified, use readOnly=true
					Editor editorInstance;
					if ("output" in options)
						editorInstance = new Editor(options["input"], options["output"], false);
					else
						editorInstance = new Editor(options["input"], "", true);
					editorInstance.run();
					.destroy(editorInstance);
				}
			}
		}else{
			writeln("usage:\n pngtext [command] [options]");
			writeln("or enter following for help:\n pngtext --help");
		}
	}

	/// reads arguments, returns values for options in assoc array
	/// `args` is the array containing arguments. arg0 (executable name) should not be included in this
	/// `command` is the string in which the provided command will be "returned"
	/// `errors` is the array to put any errors in
	private string[string] readArgs(string[] args, ref string command, ref string[] errors){
		/// stores list of possible options
		string[] optionNames = [
			"file", "input", "output"
		];
		/// returns option name from the option provided in arg
		/// returns zero length string if invalid
		static string getOptionName(string option){
			/// stores full option names for short names
			const string[string] completeOptionNames = [
				"-f" : "file",
				"-i" : "input",
				"-o" : "output"
			];
			if (option.length >= 3 && option[0 .. 2] == "--"){
				option = option[2 .. option.length];
			}else if (option.length == 2 && option[0] == '-' && option in completeOptionNames){
				option = completeOptionNames[option];
			}else{
				option = "";
			}
			return option;
		}
		string[string] r;
		errors = [];
		if (args.length == 0){
			errors ~= "no arguments provided";
		}
		if (["read","write","size","editor"].indexOf(args[0]) == -1){
			errors ~= "invalid command provided";
		}else{
			command = args[0];
		}
		args = args[1 .. args.length];
		for (uinteger i = 0; i < args.length; i ++){
			if (args[i][0] == '-'){
				// is an option, ad error if is !valid
				string optionName = getOptionName(args[i]);
				if (optionName.length == 0 || optionNames.indexOf(optionName) == -1){
					errors ~= args[i]~" is not a valid option, use --help";
					break;
				}
				// get value
				if (args.length > i+1){
					r[optionName] = args[i+1];
					i += 1;
				}else{
					errors ~= "value for "~optionName~" not provided";
				}
			}
		}
		if (errors.length > 0){
			r.clear;
		}
		return r;
	}

	/// validates if all the values provided for options are correct
	/// Returns: array containing errors, [] if no errors found
	private string[] validateOptions(string[string] options, string command){
		// assume that only correct options were passed, no "option does not exist" checks are here
		string[] errors = [];
		if (command == "write"){
			foreach (option; ["input", "output"]){
				if (option !in options){
					errors ~= "--"~option~" not specified";
				}
			}
		}else if (command == "read" || command == "size"){
			if ("input" !in options){
				errors ~= "--input not specified";
			}
		}else if (command == "editor"){
			if ("input" !in options){
				errors ~= "--input not specified";
			}
		}
		// check if provided files exist
		string[] filesToCheck = [];
		if ("input" in options)
			filesToCheck ~= options["input"];
		if ("file" in options)
			filesToCheck ~= options["file"];
		foreach (toCheck; filesToCheck){
			if (!exists(toCheck) || !isFile(toCheck)){
				errors ~= "file "~toCheck~" does not exist";
			}
		}
		return errors;
	}
}

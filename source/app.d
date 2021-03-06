module app;

version (app){
	import std.stdio;
	import std.conv : to;
	import core.stdc.stdlib;
	import utils.misc;
	import std.file;
	import std.path : baseName;
	import pngtext.pngtext;
	// QUI for the text editor
	import editor;

	/// help text
	enum string HELP_TEXT = 
"pngtext - hides data inside png images
Made by Nafees Hassan (Nafees10@GitHub.com) at https://github.com/Nafees10/pngtext
usage:
 pngtext [command] [options]
 or:
 pngtext [pngFile.png] # to open a basic text editor
commands:
 write         write to a png file, if --file is not specified, stdin is used to
               input data
 read          read data from a png file.
 size          calculate how many bytes a png image can store.
 editor        opens a text editor in terminal to edit hidden text.
options:
 --file -f     specify file containing data to write into png image
 --input -i    specify original png image to write to, or read from
 --ouput -o    specify file to write output to, for write, and read. Default is
               same as --input, will overwrite.
--quality -q   specify quality, for use with size command. 
               1 - Highest, 2 - Medium, 3 - Low, 4 - Zero quality. Default: 1
 --version -v  display this program's version and build info
 --help -h     display this message";

	/// build info
	enum string BUILD_INFO = CONST_INFO;

	void main(string[] args){
		if (args.length >= 2){
			if (args[1] == "--version" || args[1] == "-v"){
				writeln(BUILD_INFO);
			}else if (args[1] == "--help" || args[1] == "-h"){
				writeln(HELP_TEXT);
			}else{
				string command;
				string[string] options;
				string[] errors;
				options = readArgs(args[1 .. args.length].dup, command, errors);
				foreach (error; errors){
					stderr.writeln ("error: "~error);
				}
				if (errors.length > 0){
					exit(1);
				}
				errors = validateOptions(options.dup, command);
				foreach (error; errors){
					stderr.writeln ("error: "~error);
				}
				if (errors.length > 0){
					exit(1);
				}
				PNGText pngEdit = command == "editor" ? null : new PNGText;
				if (command == "write"){
					string inputFile = options["input"];
					string outputFile = "output" in options ? options["output"] : inputFile;
					char[] text;
					if ("file" in options){
						text = cast(char[])read(options["file"]);
					}else{
						text = [];
						while (!stdin.eof){
							char c;
							readf ("%s", c);
							text ~= c;
						}
						if (text[$-1] == 0xFF)
							text.length--; // remove the 0xFF from end
					}
					try{
						pngEdit.filename = inputFile;
						pngEdit.load;
						pngEdit.data = cast(ubyte[]) text;
						pngEdit.encode;
						pngEdit.filename = outputFile;
						pngEdit.save;
					}catch (Exception e){
						stderr.writeln(e.msg);
						exit(1);
					}
				}else if (command == "read"){
					string inputFile = options["input"];
					char[] text;
					try{
						pngEdit.filename = inputFile;
						pngEdit.load;
						pngEdit.decode;
						text = cast(char[])pngEdit.data;
					}catch (Exception e){
						stderr.writeln ("Failed to read from png image:\n",e.msg);
					}
					if ("output" in options){
						try{
							File outputFile = File(options["output"], "w");
							outputFile.write(cast(char[])text);
							outputFile.close();
						}catch (Exception e){
							stderr.writeln ("Failed to write to output file:\n",e.msg);
						}
					}else{
						write (cast(string)text);
					}
				}else if (command == "size"){
					string inputFile = options["input"];
					string quality = "quality" in options ? options["quality"] : "1";
					if (["1","2","3","4"].hasElement(quality)){
						try{
							pngEdit.filename = inputFile;
							pngEdit.load();
							writeln(pngEdit.capacity(quality == "1" ? DENSITY_LOW : quality == "2" ? DENSITY_MEDIUM :
								quality == "3" ? DENSITY_HIGH : DENSITY_MAX));
						}catch (Exception e){
							stderr.writeln ("Failed to read png image:\n",e.msg);
						}
					}else{
						stderr.writeln ("Invalid value for --quality provided");
						exit (1);
					}
				}else if (command == "editor"){
					App editor = new App(options["input"], "output" in options ? options["output"] : options["input"], baseName(args[0]) == "pnghacker");
					editor.run();
					.destroy(editor);
				}
				.destroy(pngEdit);
			}
		}else{
			stderr.writeln("usage:\n pngtext [command] [options]");
			stderr.writeln("or, to open basic text editor:\n pngtext [pngFile.png]");
			stderr.writeln("or enter following for help:\n pngtext --help");
		}
	}

	/// reads arguments, returns values for options in assoc array
	/// `args` is the array containing arguments. arg0 (executable name) should not be included in this
	/// `command` is the string in which the provided command will be "returned"
	/// `errors` is the array to put any errors in
	private string[string] readArgs(string[] args, ref string command, ref string[] errors){
		/// stores list of possible options
		string[] optionNames = [
			"file", "input", "quality", "output"
		];
		/// returns option name from the option provided in arg
		/// returns zero length string if invalid
		static string getOptionName(string option){
			/// stores full option names for short names
			const string[string] completeOptionNames = [
				"-f" : "file",
				"-i" : "input",
				"-q" : "quality",
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
			// beware tiny hack below
			command = "editor";
			args = [command, "-i", args[0]];
		}else{
			command = args[0];
		}
		args = args[1 .. args.length];
		for (uinteger i = 0; i < args.length; i ++){
			if (args[i][0] == '-'){
				// is an option, add error if is !valid
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
			foreach (option; ["input"]){
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

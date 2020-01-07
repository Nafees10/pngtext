module editor;

import pngtext.pngtext;

import utils.misc;

import qui.qui;
import qui.widgets;

import std.stdio;

/// The in-terminal text editor using qui.widgets.MemoWidget
class Editor{
private:
	/// the terminal
	QTerminal _terminal;
	/// the text editor
	MemoWidget _editor;
	/// to occupy space on left of 
	SplitterWidget _statusBarLeft;
	/// shows the shortcut keys, sits next to _statusLabel
	TextLabelWidget _shortcutLabel;
	/// Contains the and _shortcutLabel
	QLayout _statusBar;
	/// filename of original png
	string _inputPng;
	/// filename of output png
	string _outputPng;
public:
	/// constructor
	/// 
	/// if text only has to be displayed, use readOnly=true, and no need to specify saveAs, just leave it blank
	this(string image, string saveAs, bool readOnly=false){
		_inputPng = image;
		_outputPng = saveAs;
		// setup the terminal
		_terminal = new QTerminal(QLayout.Type.Vertical);
		_statusBar = new QLayout(QLayout.Type.Horizontal);
		_editor = new MemoWidget(!readOnly);
		_statusBarLeft = new SplitterWidget();
		_shortcutLabel = new TextLabelWidget();
		// set up each widget
		// first comes the editor:
		_editor.wantsTab = false;
		_editor.lines.loadArray(separateLines(cast(char[])readDataFromPng(_inputPng)));//load the lines
		// now comes the _statusLabel
		// now the _shortcutLabel
		_shortcutLabel.textColor = DEFAULT_BG;
		_shortcutLabel.backgroundColor = DEFAULT_FG;
		_shortcutLabel.caption = "Ctrl+C - Save & Exit";
		_shortcutLabel.size.maxWidth = _shortcutLabel.caption.length;
		// put both of these in _statusBar, and set it up too
		_statusBar.addWidget([_statusBarLeft, _shortcutLabel]);
		_statusBar.size.maxHeight = 1;
		_statusBar.size.minHeight = 1;
		// put all those in QTerminal
		_terminal.addWidget([_editor, _statusBar]);
		// register all widgets
		_terminal.registerWidget([_editor, _statusBar, _statusBarLeft, _shortcutLabel]);
		// and its done, ready to start*/
	}
	/// destructor
	~this(){
		.destroy(_terminal);
		.destroy(_editor);
		.destroy(_statusBar);
		.destroy(_statusBarLeft);
		.destroy(_shortcutLabel);
	}
	/// runs the editor
	/// 
	/// Returns: false if there were errors(s)
	bool run(){
		_terminal.run;
		// save
		const string[] lines = _editor.lines.toArray;
		ubyte[] data;
		uinteger writeTo = 0;
		foreach (line; lines){
			data.length += line.length+1;
			foreach (ch; line){
				data[writeTo] = cast(ubyte)ch;
				writeTo++;
			}
			data[writeTo] = '\n';
			writeTo++;
		}
		const string[] errors = writeDataToPng(_inputPng, _outputPng, data);
		if (errors.length){
			stderr.writeln("Errors while writing to image:");
			foreach (err; errors){
				stderr.writeln(err);
			}
			return false;
		}
		return true;
	}

}

/// reads a single string into string[], separating the lines
string[] separateLines(string s){
	string[] r;
	for(uinteger i = 0, readFrom = 0; i < s.length; i ++){
		if (s[i] == '\n'){
			r ~= s[readFrom .. i].dup;
			readFrom = i+1;
		}else if (i+1 == s.length){
			r ~= s[readFrom .. i + 1].dup;
		}
	}
	return r;
}
/// ditto
string[] separateLines(char[] s){
	return separateLines(cast(string)s);
}
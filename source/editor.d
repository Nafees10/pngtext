module editor;

import pngtext.pngtext;

import utils.misc;

import qui.qui;
import qui.widgets;

/// The in-terminal text editor using qui.widgets.MemoWidget
package class Editor{
private:
	/// the terminal
	QTerminal _terminal;
	/// the text editor
	MemoWidget _editor;
	/// the label at bottom, acts as a status bar
	TextLabelWidget _statusLabel;
	/// shows the shortcut keys, sits next to _statusLabel
	TextLabelWidget _shortcutLabel;
	/// Contains the _statusLabel and _shortcutLabel
	QLayout _statusBar;
	/// just used to catch the shortcut keys
	KeyCatcher _keyCatch;
	/// filename of original png
	string _inputPng;
	/// filename of output png
	string _outputPng;
	/// called by a key catching widget, on keyboard event
	/// TODO: implement shortcuts, and changing status on _statusLabel, after I figure out that weird "color.d" bug
	void onKeyboardEvent(QWidget widget, KeyboardEvent event){
		if (event.key == Key.ctrlS){

		}else if (event.key == Key.ctrlR){

		}else{

		}
	}
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
		_statusLabel = new TextLabelWidget();
		_keyCatch = new KeyCatcher([Key.ctrlS, Key.ctrlR]);
		// set up each widget
		// first comes the editor:
		_editor.wantsTab = false;
		_editor.lines.loadArray(separateLines(readDataFromPng(_inputPng)));//load the lines
		// now comes the _statusLabel
		// invert the colors
		_statusLabel.textColor = DEFAULT_BG;
		_statusLabel.backgroundColor = DEFAULT_FG;
		// now the _shortcutLabel
		_shortcutLabel.textColor = DEFAULT_BG;
		_shortcutLabel.backgroundColor = DEFAULT_FG;
		if (readOnly)
			_shortcutLabel.caption = "^C Exit";
		else
			_shortcutLabel.caption = "^S Save; ^R Revert; ^C Exit";
		_shortcutLabel.size.maxWidth = _shortcutLabel.caption.length;
		// put both of these in _statusBar, and set it up too
		_statusBar.addWidget([_statusLabel, _shortcutLabel]);
		_statusBar.size.maxHeight = 1;
		_statusBar.size.minHeight = 1;
		// now set up shortcut keys
		_terminal.onKeyboardEvent = &onKeyboardEvent;
		// put all those in QTerminal
		_terminal.addWidget([_editor, _statusBar]);
		// register all widgets
		_terminal.registerWidget([_editor, _statusBar, _statusLabel, _shortcutLabel]);
		// and its done, ready to start
	}
	/// destructor
	~this(){
		.destroy(_terminal);
		.destroy(_editor);
		.destroy(_statusBar);
		.destroy(_statusLabel);
		.destroy(_shortcutLabel);
	}
	/// runs the editor
	void run(){
		_terminal.run;
	}

}

/// reads a single string into string[], separating the lines
string[] separateLines(string s){
	string[] r;
	for(uinteger i = 0, readFrom = 0, lastIndex = s.length - 1; i < s.length; i ++){
		if (s[i] == '\n'){
			r ~= s[readFrom .. i].dup;
			readFrom = i+1;
		}else if (i == lastIndex){
			r ~= s[readFrom .. i + 1].dup;
		}
	}
	return r;
}
/// ditto
string[] separateLines(char[] s){
	return separateLines(cast(string)s);
}
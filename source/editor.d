module editor;

import pngtext.pngtext;

import utils.misc;

import qui.qui;
import qui.widgets;

import std.stdio;
import std.conv : to;
import std.path;

/// shortcuts text
private enum STATUSBAR_SHORTCUTS = "^C - Exit  ^O - Save;";
/// prefix text for file saved label
private enum STATUSBAR_FILESAVED_PREFIX = "File saved to ";
/// prefix text for quality label
private enum STATUSBAR_QUALITY_PREFIX = "Quality: ";
/// prefix text for number of bytes label
private enum STATUSBAR_BYTECOUNT_PREFIX = "Characters/Max/Limit: ";
/// text for when file failed to save
private enum STATUSBAR_FILESAVE_ERROR = "Error saving file";
/// time (msecs) until "File saved to: ..." & errors disappears
private enum ERROR_DISAPPEAR_TIME = 500;

/// The top title display
private class TitleWidget : QLayout{
private:
	/// empty space on left
	SplitterWidget _leftSplitter;
	/// empty space on right
	SplitterWidget _rightSplitter;
	/// text
	TextLabelWidget _titleLabel;
	/// background color
	Color _bgColor;
	/// text color
	Color _textColor;
public:
	/// constructor
	this(dstring text, Color fg = Color.black, Color bg = Color.white){
		super(QLayout.Type.Horizontal);
		_leftSplitter = new SplitterWidget();
		_rightSplitter = new SplitterWidget();
		_titleLabel = new TextLabelWidget();
		this.text = text;
		_leftSplitter.color = bg;
		_rightSplitter.color = bg;
		_titleLabel.backgroundColor = bg;
		_titleLabel.textColor = fg;
		this.size.maxHeight = 1;
		this.size.minHeight = 1;
		// exaggerate the sizeRatio of _titleLabel, so splitters can become as small as needed
		_titleLabel.sizeRatio = 1000;
		this.addWidget([_leftSplitter, _titleLabel, _rightSplitter]);
	}
	~this(){
		.destroy(_leftSplitter);
		.destroy(_rightSplitter);
		.destroy(_titleLabel);
	}
	/// text displayed
	@property dstring text(){
		return _titleLabel.caption;
	}
	/// ditto
	@property dstring text(dstring newVal){
		_titleLabel.caption = newVal;
		_titleLabel.size.maxWidth = newVal.length;
		this.resizeEvent();
		return newVal;
	}
}

/// To display a log with a title
private class LogPlusPlusWidget : QLayout{
private:
	/// to display a title at top of errors
	TitleWidget _title;
	/// log to show the errors
	LogWidget _log;
public:
	/// constructor
	this(dstring title, uint lines, Color fg, Color bg){
		super(QLayout.Type.Vertical);
		_title = new TitleWidget(title, bg, fg);
		_log = new LogWidget(lines);
		_log.textColor = fg;
		_log.backgroundColor = bg;
		_log.size.minHeight = lines;
		_log.size.maxHeight = lines;
		this.size.minHeight = lines+1;
		this.size.maxHeight = lines+1;
		this.addWidget([_title, _log]);
	}
	~this(){
		.destroy(_title);
		.destroy(_log);
	}
	/// clears error messages
	void clear(){
		_log.clear;
	}
	/// adds an error message
	void add(dstring message){
		_log.add(message);
	}
	/// whether this widget is shown or not
	override @property bool show(bool newVal){
		return super.show = newVal;
	}
	/// ditto
	override @property bool show(){
		return super.show;
	}
}

/// A status bar. Displays TextLabelWidgets with spaces in between.
private class StatusBarWidget : QLayout{
private:
	TextLabelWidget[] _label;
	SplitterWidget[] _splitter;
public:
	this(ubyte count, Color fg, Color bg){
		assert(count, "count cannot be 0");
		super(QLayout.Type.Horizontal);
		_label.length = count;
		_splitter.length = count -1;
		_label[0] = new TextLabelWidget();
		_label[0].sizeRatio = 1000;
		_label[0].textColor = fg;
		_label[0].backgroundColor = bg;
		this.addWidget(_label[0]);
		foreach (i; 1 .. count){
			_splitter[i-1] = new SplitterWidget();
			_splitter[i-1].color = bg;
			this.addWidget(_splitter[i-1]);
			_label[i] = new TextLabelWidget();
			_label[i].sizeRatio = 1000;
			_label[i].textColor = fg;
			_label[i].backgroundColor = bg;
			this.addWidget(_label[i]);
		}
		this.size.maxHeight = 1;
	}
	~this(){
		foreach (widget; _label)
			.destroy(widget);
		foreach(widget; _splitter)
			.destroy(widget);
	}
	/// Sets text of a label
	void setText(uint label, dstring newText){
		_label[label].caption = newText;
		_label[label].size.maxWidth = newText.length;
		requestResize();
	}
}

/// Memo with extra functions
private class MemoPlusPlusWidget : MemoWidget{
public:
	this(){
		super(true);
	}
	/// Calculates number of bytes required to store the characters typed
	uint bytesCount(){
		uint r;
		dstring[] linesArray = this.lines.toArray;
		foreach (line; linesArray)
			r += to!string(line).length;
		r += lines.length; // for the \n at end of each line
		return r;
	}
	/// Returns: the contents of memo as a single string
	string getString(){
		dstring[] linesArray = this.lines.toArray;
		uint len;
		// first calculate total length needed
		foreach (line; linesArray)
			len += to!string(line).length;
		len += linesArray.length; // for the \n at end of each line
		char[] r;
		r.length = len;
		for (uint lineno, writeIndex; lineno < linesArray.length; lineno ++){
			string line = linesArray[lineno].to!string;
			r[writeIndex .. writeIndex + line.length+1] = line~'\n';
			writeIndex += line.length+1;
		}
		return cast(string)r;
	}
}

/// The text editor app
public class App : QTerminal{
private:
	/// path of output image
	string _outputPath;
	/// the PNGText class instance
	PNGText _imageMan;
	/// Title at top
	TitleWidget _title;
	/// memo for editing
	MemoPlusPlusWidget _memo;
	/// error messages
	LogPlusPlusWidget _log;
	/// status bar
	StatusBarWidget _statusBar;

	/// stores how many bytes can be stored at what densities
	int[ubyte] _capacity;
	/// how many msecs until the shortcut keys are shown again in status bar instead of "File saved..."
	int _msecsUntilReset;
	
	/// updates status bar
	void updateStatusBar(){
		immutable int bytesCount = _memo.bytesCount;
		ubyte density = 0;
		int max = 0;
		foreach (d; DENSITIES){
			if (_capacity[d] >= bytesCount){
				density = d;
				max = _capacity[d];
				break;
			}
		}
		_statusBar.setText(0, 
			STATUSBAR_QUALITY_PREFIX~(density == 0 ? "OVER CAPACITY" : _imageMan.qualityName(density).to!dstring));
		// now for bytes count
		_statusBar.setText(1, STATUSBAR_BYTECOUNT_PREFIX~bytesCount.to!dstring~"/"~max.to!dstring~"/"~
			_capacity[DENSITIES[$-1]].to!dstring);
		// now shortcuts or leave it at that "file saved"
		if (_msecsUntilReset <= 0)
			_statusBar.setText(2, STATUSBAR_SHORTCUTS);
	}

	/// initializes _capacity
	void initCapacity(){
		foreach (i; DENSITIES){
			_capacity[i] = _imageMan.capacity(i);
		}
	}
	/// loads image, initializes _imageMan.
	/// 
	/// Displays error in _log if any
	void initImageMan(){
		try{
			_imageMan.load();
			_imageMan.decode();
			_imageMan.filename = _outputPath;
		}catch (Exception e){
			_log.clear;
			_log.add("Error loading image:");
			_log.add(e.msg.to!dstring);
			_log.show = true;
			_msecsUntilReset = int.max;
		}
	}
	/// Reads data from _imageMan to memo
	void initMemo(){
		_memo.lines.loadArray((cast(char[])_imageMan.data).to!dstring.separateLines);
	}
	/// Writes data from memo to _imageMan and then saves
	void save(){
		string data = _memo.getString();
		_imageMan.data = cast(ubyte[])cast(char[])data;
		_msecsUntilReset = int.max;
		try{
			_imageMan.encode();
			_imageMan.save();
			_statusBar.setText(2, STATUSBAR_FILESAVED_PREFIX~_outputPath.to!dstring);
		}catch (Exception e){
			_log.clear;
			_log.add("Error saving image:");
			_statusBar.setText(2, STATUSBAR_FILESAVE_ERROR);
			_log.add(e.msg.to!dstring);
			_log.show = true;
			_msecsUntilReset = int.max;
		}
	}
protected:
	override void timerEvent(uinteger msecs){
		super.timerEvent(msecs);
		if (_msecsUntilReset > 0)
			_msecsUntilReset -= msecs;
		if (_log.show && _msecsUntilReset <= 0)
			_log.show = false;
		updateStatusBar();
		requestUpdate();
	}
	override void keyboardEvent(KeyboardEvent key){
		super.keyboardEvent(key);
		// nothing happens if there was an error loading
		if (!_imageMan.imageLoaded)
			return;
		if (_msecsUntilReset > ERROR_DISAPPEAR_TIME)
			_msecsUntilReset = ERROR_DISAPPEAR_TIME;
		if (key.isCtrlKey && key.key == KeyboardEvent.CtrlKeys.CtrlO){
			save();
		}
	}
public:
	/// Constructor
	this(string imagePath, string outputPath, bool hackerman = false){
		// construct the interface
		_title = new TitleWidget(baseName(imagePath).to!dstring, 
			Color.black, hackerman ? Color.green : Color.white);
		_memo = new MemoPlusPlusWidget();
		if (hackerman)
			_memo.textColor = Color.green;
		_log = new LogPlusPlusWidget("Error Messages", 3, hackerman ? Color.green : Color.red, Color.black);
		_statusBar = new StatusBarWidget(3, Color.black, hackerman ? Color.green : Color.white);
		// arrange em
		this.addWidget([_title, _memo, _log, _statusBar]);
		// make _imageMan
		_imageMan = new PNGText();
		_imageMan.filename = imagePath;
		_outputPath = outputPath;
	}
	~this(){
		.destroy(_imageMan);
		.destroy(_title);
		.destroy(_memo);
		.destroy(_log);
		.destroy(_statusBar);
	}
	/// starts the app
	override void run(){
		initImageMan();
		initMemo();
		if (_imageMan.imageLoaded)
			initCapacity;
		super.run();
	}
}

/// reads a single dstring into dstring[], separating the lines
private dstring[] separateLines(dstring s){
	dstring[] r;
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
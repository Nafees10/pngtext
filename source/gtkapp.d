module gtkapp.d;

// This was written in a hurry, so beware, it's not much readable

version (gtk){
	import gio.Application: GioApplication = Application;
	import gtk.Application;
	import gtk.ApplicationWindow;
	import gtk.Window;
	import gtk.Dialog;
	import gtk.AboutDialog;
	import gtk.MessageDialog;
	import gtk.FileChooserDialog;
	import gtk.FileFilter;
	import gtk.AccelGroup;
	import gtk.Builder;
	
	import gtk.VBox;
	import gtk.Box;

	import gtk.Widget;
	import gdk.Event;
	// for GtkTextView
	import gtk.ScrolledWindow;	
	import gtk.TextView;
	import gtk.TextBuffer;

	// Menu
	import gtk.Menu;
	import gtk.MenuBar;
	import gtk.MenuItem;

	// other imports
	import core.stdc.stdlib;
	import utils.misc;
	import std.file;
	import std.stdio;
	import std.path;
	import pngtext;

	// constants
	/// path of the glade file
	const GLADE_FILE = "ui.glade";

	int main(string[] args){
		/// stores the path of the currently open png file
		string filePath = "";
		// check if a file name was passed on
		if (args.length >= 3 && args[1] == "-f"){
			filePath = args[2];
		}
		auto application = new Application("org.nafees10.pngtext", GApplicationFlags.FLAGS_NONE);
		void buildDisplay(GioApplication a){
			auto builder = new Builder();
			if (!builder.addFromFile(GLADE_FILE)){
				writeln ("Failed to load file: ",GLADE_FILE);
				exit (1);
			}
			/// get widgets
			auto window = cast(ApplicationWindow)builder.getObject("window");
			window.setApplication (application);
			auto aboutDialog = cast(AboutDialog)builder.getObject("aboutWindow");
			auto existingPngFileChooser = cast(FileChooserDialog)builder.getObject("existingPngFileChooser");
			auto newPngFileChooser = cast(FileChooserDialog)builder.getObject("newPngFileChooser");
			auto textBuffer = cast(TextBuffer)builder.getObject("textBuffer");
			auto menuSave = cast(MenuItem)builder.getObject("menuSave");
			auto menuOpen = cast(MenuItem)builder.getObject("menuOpen");
			auto menuQuit = cast(MenuItem)builder.getObject("menuQuit");
			auto menuAbout = cast(MenuItem)builder.getObject("menuAbout");
			auto textView = cast(TextView)builder.getObject("textView");
			// set events
			// quit event
			void onQuit(MenuItem w){
				application.quit();
			}
			menuQuit.addOnActivate(&onQuit);
			// about event
			void onAbout(MenuItem w){
				aboutDialog.run();
				aboutDialog.hide();
			}
			menuAbout.addOnActivate(&onAbout);
			// save
			void onSave(MenuItem w){
				// make sure the file exists
				if (!filePath.exists){
					filePath = getOriginalPng(window);
				}
				if (filePath.exists){
					string[] errors = writeDataToPng(filePath, filePath, textBuffer.getText());
					if (errors.length > 0){
						foreach (error; errors){
							showError (window, error);
						}
					}
				}
			}
			menuSave.addOnActivate(&onSave);
			// open
			void onOpen(MenuItem w){
				filePath = getOriginalPng(window);
				if (filePath.exists){
					try{
						textBuffer.setText (readDataFromPng(filePath));
					}catch (Exception e){
						showError (window, e.msg);
					}
				}
			}
			menuOpen.addOnActivate(&onOpen);
			// to add accels
			auto accelGroup = new AccelGroup();
			window.addAccelGroup(accelGroup);
			void addAccel(ApplicationWindow window, Widget widget, string accelerator, string signal){
				uint key;
				GdkModifierType mod;
				AccelGroup.acceleratorParse(accelerator, key, mod);
				widget.addAccelerator (signal, accelGroup, key, mod, GtkAccelFlags.VISIBLE);
			}
			// add accels
			addAccel(window, menuOpen, "<Control>o", "activate");
			addAccel(window, menuSave, "<Control>s", "activate");
			addAccel(window, menuQuit, "<Control>q", "activate");
			
			// show it
			window.showAll();
		}
		application.addOnActivate(&buildDisplay);
		return application.run (args);
	}

	/// to show a message dialog
	void showMessage(ApplicationWindow parent, string message){
		auto dialog = new MessageDialog(cast(Window)parent, GtkDialogFlags.DESTROY_WITH_PARENT, GtkMessageType.INFO, GtkButtonsType.OK, message);
		dialog.run();
		dialog.hide();
		.destroy (dialog);
	}

	/// to show an error dialog
	void showError(ApplicationWindow window, string message){
		auto dialog = new MessageDialog(cast(Window)window, GtkDialogFlags.DESTROY_WITH_PARENT, GtkMessageType.ERROR, GtkButtonsType.OK, message);
		dialog.run();
		dialog.hide();
		.destroy (dialog);
	}

	/// Returns: the filepath of the original PNG image
	string getOriginalPng(ApplicationWindow window){
		// prepare the filter
		auto filter = new FileFilter();
		filter.setName("PNG Images");
		filter.addMimeType ("image/png");
		filter.addPattern ("*.png");
		// now the dialog
		auto dialog = new FileChooserDialog("Select the original PNG file", cast(Window)window, GtkFileChooserAction.OPEN,
			["Cancel", "Open"], [ResponseType.CANCEL, ResponseType.OK]);
		dialog.addFilter(filter);
		// run it
		auto response = dialog.run();
		dialog.hide();
		string r = "";
		if (response == ResponseType.OK){
			r = dialog.getFilename();
		}
		.destroy (dialog);
		.destroy (filter);
		return r;
	}
}

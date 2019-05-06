import std.stdio;
import std.process;
import std.string;

import gtk.MainWindow;
import gtk.Main;
import gtk.Entry;
import gtk.Button, gtk.Widget, gtk.Box, gdk.Event;
import gtk.Label;
import gtk.Grid;


string getOutput(string[] cmd) {
	auto pipes = pipeProcess(cmd, Redirect.stdout | Redirect.stderr);
	scope(exit) wait(pipes.pid);

	string output = strip(pipes.stdout.readln());
	
	return output;	
}

string getUserRealName(string username) {
	string passOut = getOutput(["getent", "passwd", username]);
	if (!passOut.length) {
		return "";
	}
	auto cutPipe = pipeProcess(["cut", "-f", "5", "-d", ":"], Redirect.all);
	cutPipe.stdin.writeln(passOut);
	cutPipe.stdin.close();

	scope(exit) wait(cutPipe.pid);
	
	auto realName = strip(cutPipe.stdout.readln());
	if (realName.length > 0) {
		return realName;
	} else {
		return "";
	}
}

class UserManagerMain
{
	MainWindow win = null;
	int defaultPadding = 20;
	Grid mainGrid = null;

	this(string[] argv) {
		Main.init(argv);
		this.win = new MainWindow("User Manager");
		this.win.setDefaultSize(600, 300);

		this.mainGrid = new Grid();
		this.mainGrid.setBorderWidth(20);
		this.mainGrid.setRowSpacing(10);
	}

	void addCreateInputs() {
        auto usernameEntry = new Entry();
		auto realNameEntry = new Entry();
		auto emailEntry = new Entry();

		string username = getOutput(["whoami"]);
		usernameEntry.setText(username);
		
		string realName = getUserRealName(username);
		if (realName) {
			realNameEntry.setText(realName);
		}

		auto usernameLabel = new Label("Username:");
		auto realNameLabel = new Label("Real Name:");
		auto emailLabel = new Label("Email:");

		usernameEntry.setHexpand(true);  // only need to do this once I guess.

		Grid inputsGrid = new Grid();
		inputsGrid.setColumnSpacing(10);
		inputsGrid.setRowSpacing(10);
		inputsGrid.setBorderWidth(10);

		inputsGrid.attach(usernameLabel, 0, 0, 1, 1);
		inputsGrid.attach(usernameEntry, 1, 0, 1, 1);

		inputsGrid.attach(realNameLabel, 0, 1, 1, 1);
		inputsGrid.attach(realNameEntry, 1, 1, 1, 1);
			
		inputsGrid.attach(emailLabel, 0, 2, 1, 1);
		inputsGrid.attach(emailEntry, 1, 2, 1, 1);

		this.mainGrid.attach(inputsGrid, 0, 0, 1, 1);
	}

	void addButtons() {
		auto changePassButton = new Button("Change Password");
		auto saveButton = new Button("Save");
		auto cancelButton = new Button("Cancel");

		Box buttonBox = new Box(Orientation.HORIZONTAL, 50);
		buttonBox.add(saveButton);
		buttonBox.add(changePassButton);
		buttonBox.add(cancelButton);

		this.mainGrid.attach(buttonBox, 0, 1, 1, 1);
	}

	void run() {
		this.win.add(mainGrid);
		win.showAll();
		Main.run();
	}
}

class LabelledInput : Box
{
	Label label = null;
	Entry entry = null;

	this(Entry entry, Label label, int spacing = 10) {
		super(Orientation.HORIZONTAL, spacing);
		this.label = label;
		this.entry = entry;

		this.add(this.label);
		this.add(this.entry);
	}
}

void main(string[] argv)
{
	UserManagerMain umm = new UserManagerMain(argv);
	umm.addCreateInputs();
	umm.addButtons();
	umm.run();
}


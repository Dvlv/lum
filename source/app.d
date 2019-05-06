import std.stdio;
import gtk.MainWindow;
import gtk.Main;
import gtk.Entry;
import gtk.Button, gtk.Widget, gtk.Box, gdk.Event;
import gtk.Label;
import gtk.Grid;


class UserManagerMain
{
	MainWindow win = null;
	int defaultPadding = 20;

	this(string[] argv) {
		Main.init(argv);
		this.win = new MainWindow("User Manager");
		this.win.setDefaultSize(600, 300);
	}

	void addCreateInputs() {
                auto usernameEntry = new Entry();
		auto realNameEntry = new Entry();
		auto emailEntry = new Entry();
		auto passwordEntry = new Entry();

		auto usernameLabel = new Label("Username:");
		auto realNameLabel = new Label("Real Name:");
		auto emailLabel = new Label("Email:");
		auto passwordLabel = new Label("Password:");

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

		inputsGrid.attach(passwordLabel, 0, 3, 1, 1);
		inputsGrid.attach(passwordEntry, 1, 3, 1, 1);

		this.win.add(inputsGrid);
	}

	void run() {
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
	umm.run();
}


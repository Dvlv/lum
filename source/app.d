import std.stdio;
import std.process;
import std.string;

import gtk.MainWindow;
import gtk.Main;
import gtk.Entry;
import gtk.Button, gtk.Widget, gtk.Box, gdk.Event;
import gtk.Label;
import gtk.Grid;
import gtk.ListBox;
import gtk.ListBoxRow;



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

string[] getAllAvailableUsers()
{
    auto catPipe = pipeProcess(["cat", "/etc/passwd"], Redirect.stderr | Redirect.stdout);
    scope(exit) wait(catPipe.pid);
    
    auto grepPipe = pipeProcess(["grep", "-v", "-e", "nologin", "-e", "git-shell"], Redirect.all);
    foreach(catline; catPipe.stdout.byLine) grepPipe.stdin.writeln(catline);
    grepPipe.stdin.close();
    scope(exit) wait(grepPipe.pid);
    
    auto cutPipe = pipeProcess(["cut", "-f", "1", "-d", ":"], Redirect.all);
    foreach(grepline; grepPipe.stdout.byLine) cutPipe.stdin.writeln(grepline);
    cutPipe.stdin.close();
    scope(exit) wait(cutPipe.pid);
    
    string[] cutLines;
    foreach(cutline; cutPipe.stdout.byLine) cutLines ~= cutline.idup;
    
    return cutLines;
}



class UserManagerMain
{
	MainWindow win = null;
	int defaultPadding = 20;
	Grid mainGrid = null;
	
	string launchedUser = "";
	
	ListBox usersList = null;
	InputsGrid inputsGrid = null;
	Box buttonBox = null;

	this(string[] argv) {
		Main.init(argv);
		this.win = new MainWindow("User Manager");
		this.win.setDefaultSize(600, 300);

		this.mainGrid = new Grid();
		this.mainGrid.setBorderWidth(20);
		this.mainGrid.setRowSpacing(10);
	}
	
	ListBox getExistingUsersListBox() {
        ListBox usersList = new ListBox();
        usersList.setHexpand(true);
        
        string[] users = getAllAvailableUsers();
        if (users.length == 0) {
            return usersList;
        }
        
        foreach(user; users) {
            ListBoxRow row = new ListBoxRow();
            Label userLabel = new Label(user);
            row.add(userLabel);
            
            usersList.add(row);
        }
        
        usersList.addOnRowSelected(&this.showUserInfo);
        
        return usersList;
        
       
	}
	
	void showUserInfo(ListBoxRow row, ListBox lb) {
        Widget label = row.getChild();
        Label userLabel = cast(Label) label;
        string username = userLabel.getText();
        
        this.inputsGrid.fillInUserDetails(username);
	}
	
	void addCreateInputs() {
        this.inputsGrid = new InputsGrid();
        this.inputsGrid.fillInUserDetails(this.launchedUser);
        
		this.mainGrid.attach(this.inputsGrid, 1, 0, 1, 1);
	}

	void addButtons() {
		auto changePassButton = new Button("Change Password");
		auto saveButton = new Button("Save");
		auto cancelButton = new Button("Cancel");

		Box buttonBox = new Box(Orientation.HORIZONTAL, 30);
		buttonBox.setBorderWidth(20);
		buttonBox.setHomogeneous(true);
		
		buttonBox.add(saveButton);
		buttonBox.add(changePassButton);
		buttonBox.add(cancelButton);

		this.mainGrid.attach(buttonBox, 1, 1, 1, 1);
	}

	void run() {
        this.usersList = getExistingUsersListBox();
        this.mainGrid.attach(this.usersList, 0, 0, 1, 3);
        
		this.win.add(mainGrid);
		win.showAll();
		Main.run();
	}
}

class InputsGrid : Grid
{
    Entry usernameEntry = null;
	Entry realNameEntry = null;
	Grid inputsGrid = null;
     
    this() {
        this.usernameEntry = new Entry();
		this.usernameEntry.setHexpand(true);  // only need to do this once I guess.
     
		this.realNameEntry = new Entry();
		this.layoutInputs();
    }
    
    void layoutInputs() {
		this.setColumnSpacing(10);
		this.setRowSpacing(10);
		this.setBorderWidth(10);

		Label usernameLabel = new Label("Username:");
		Label realNameLabel = new Label("Real Name:");
		
		this.attach(usernameLabel, 1, 0, 1, 1);
		this.attach(this.usernameEntry, 2, 0, 1, 1);

		this.attach(realNameLabel, 1, 1, 1, 1);
		this.attach(this.realNameEntry, 2, 1, 1, 1);
    }
    
    void fillInUserDetails(string username) {
		this.usernameEntry.setText(username);
		
		string realName = getUserRealName(username);
		if (realName) {
			this.realNameEntry.setText(realName);
		}
	}
}

void main(string[] argv)
{
    string me = getOutput(["whoami"]);
	UserManagerMain umm = new UserManagerMain(argv);
	umm.launchedUser = me;
	umm.addCreateInputs();
	umm.addButtons();
	umm.run();
}


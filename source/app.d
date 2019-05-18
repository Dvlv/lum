import std.stdio;
import std.process;
import std.string;
import std.typecons;

import gtk.MainWindow;
import gtk.Window;
import gtk.Main;
import gtk.Entry;
import gtk.Button, gtk.Widget, gtk.Box, gdk.Event;
import gtk.Label;
import gtk.Grid;
import gtk.ListBox;
import gtk.ListBoxRow;
import gtk.MessageDialog, gtk.Dialog;
import gtk.VBox;

string getOutput(string[] cmd)
{
    auto pipes = pipeProcess(cmd, Redirect.stdout | Redirect.stderr);
    scope (exit)
        wait(pipes.pid);

    string output = strip(pipes.stdout.readln());

    return output;
}

string getUserRealName(string username)
{
    string passOut = getOutput(["getent", "passwd", username]);
    if (!passOut.length)
    {
        return "";
    }
    auto cutPipe = pipeProcess(["cut", "-f", "5", "-d", ":"], Redirect.all);
    cutPipe.stdin.writeln(passOut);
    cutPipe.stdin.close();

    scope (exit)
        wait(cutPipe.pid);

    auto realName = strip(cutPipe.stdout.readln());
    if (realName.length > 0)
    {
        return realName;
    }
    else
    {
        return "";
    }
}

string[] getAllAvailableUsers()
{
    auto catPipe = pipeProcess(["cat", "/etc/passwd"], Redirect.stderr | Redirect.stdout);
    scope (exit)
        wait(catPipe.pid);

    auto grepPipe = pipeProcess([
            "grep", "-v", "-e", "nologin", "-e", "git-shell"
            ], Redirect.all);
    foreach (catline; catPipe.stdout.byLine)
        grepPipe.stdin.writeln(catline);
    grepPipe.stdin.close();
    scope (exit)
        wait(grepPipe.pid);

    auto cutPipe = pipeProcess(["cut", "-f", "1", "-d", ":"], Redirect.all);
    foreach (grepline; grepPipe.stdout.byLine)
        cutPipe.stdin.writeln(grepline);
    cutPipe.stdin.close();
    scope (exit)
        wait(cutPipe.pid);

    string[] cutLines;
    foreach (cutline; cutPipe.stdout.byLine)
        cutLines ~= cutline.idup;

    return cutLines;
}

Tuple!(bool, string) changeOwnPassword(string oldPassword, string newPassword, string confirmNew)
{
    if (newPassword != confirmNew)
    {
        return tuple(false, "Passwords do not match!");
    }

    if (newPassword.length < 8)
    {
        return tuple(false, "New password is not long enough!");
    }

    if (newPassword == oldPassword)
    {
        return tuple(false, "New password is the same as the old one!");
    }

    string passStr = format("%s\n%s\n%s", oldPassword, newPassword, confirmNew);
    auto echoPipe = pipeProcess(["echo", "-e", passStr], Redirect.stdout | Redirect.stderr);
    scope (exit)
        wait(echoPipe.pid);

    auto passwdPipe = pipeProcess(["passwd"], Redirect.all);
    foreach (echoline; echoPipe.stdout.byLine)
        passwdPipe.stdin.writeln(echoline);
    passwdPipe.stdin.close();
    scope (exit)
        wait(passwdPipe.pid);

    string[] passwdErrorLines;
    foreach (pErrline; passwdPipe.stderr.byLine)
        passwdErrorLines ~= pErrline.idup;

    string[] passwdOutLines;
    foreach (pOutline; passwdPipe.stdout.byLine)
        passwdOutLines ~= pOutline.idup;

    string fullOut = join(passwdOutLines, "\n");
    string fullErr = join(passwdErrorLines, "\n");

    writeln("out:");
    writeln(fullOut);
    writeln("err");
    writeln(fullErr);

    if (indexOf(fullErr, "Authentication failure") > -1)
    {
        return tuple(false, "Old password is incorrect!");
    }
    else if (indexOf(fullErr, "BAD PASSWORD") > -1)
    {
        return tuple(false, "New password is too simple, or too similar to your old one!");
    }
    else if (indexOf(fullErr, "aborted") > -1)
    {
        return tuple(false, "Password was not changed!");
    }
    else if ((indexOf(fullErr, "updated successfully") > -1) || indexOf(fullOut,
            "updated successfully") > -1)
    {
        return tuple(true, "Password was changed!");
    }

    return tuple(false, "Unable to determine state of password change.");
}

Tuple!(bool, string) changeUserPassword(string username, string newPass, string confirmNewPass)
{
    if (newPass != confirmNewPass)
    {
        return tuple(false, "Passwords do not match!");
    }

    string chpassString = format("%s:%s", username, newPass);

    auto chPipe = pipeProcess(["chpasswd"], Redirect.all);
    chPipe.stdin.writeln(chpassString);
    chPipe.stdin.close();
    scope (exit)
        wait(chPipe.pid);

    string[] chErrorLines;
    foreach (pErrline; chPipe.stderr.byLine)
        chErrorLines ~= pErrline.idup;

    string[] chOutLines;
    foreach (pOutline; chPipe.stdout.byLine)
        chOutLines ~= pOutline.idup;

    // chpasswd doesnt seem to output anything
    if (!chErrorLines.length && !chOutLines.length)
    {
        return tuple(true, format("Password changed for %s successfully!", username));
    }

    string fullOut = join(chOutLines, "\n");
    string fullErr = join(chErrorLines, "\n");

    writeln(fullOut);
    writeln(fullErr);

    return tuple(false,
            "Unable to determine result of password change! Assume the password was not set.");
}

void showError(Window parent, string message)
{
    MessageDialog errorMsg = new MessageDialog(parent, DialogFlags.MODAL,
            MessageType.ERROR, ButtonsType.CLOSE, message);
    errorMsg.addOnResponse((int responseId, Dialog dlg) => dlg.destroy());
    errorMsg.show();
}

void showMessage(Window parent, string message, bool destroyParent = false)
{
    MessageDialog msg = new MessageDialog(parent, DialogFlags.MODAL,
            MessageType.INFO, ButtonsType.CLOSE, message);
    msg.setTransientFor(parent);

    void delegate(int i, Dialog d) f;
    if (destroyParent)
    {
        f = delegate(int i, Dialog d) { d.destroy(); parent.destroy(); };
    }
    else
    {
        f = delegate(int i, Dialog d) { d.destroy(); };
    }

    msg.addOnResponse(f);

    msg.show();
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

    string currentlySelectedUser = null;
    bool isRoot = false;

    this(string[] argv, bool isRoot)
    {
        Main.init(argv);
        this.win = new MainWindow("User Manager");
        this.win.setDefaultSize(750, 300);

        this.mainGrid = new Grid();
        this.mainGrid.setBorderWidth(20);
        this.mainGrid.setRowSpacing(10);

        this.isRoot = isRoot;
    }

    ListBox getExistingUsersListBox()
    {
        ListBox usersList = new ListBox();
        usersList.setHexpand(true);

        string[] users = [];

        if (this.isRoot)
        {
            foreach (u; getAllAvailableUsers())
            {
                users ~= u;
            }
        }
        else
        {
            users ~= this.launchedUser;
        }

        if (users.length == 0)
        {
            return usersList;
        }

        foreach (user; users)
        {
            ListBoxRow row = new ListBoxRow();
            Label userLabel = new Label(user);

            row.add(userLabel);
            usersList.add(row);

            if (user == this.launchedUser)
            {
                usersList.selectRow(row);
            }
        }

        usersList.addOnRowSelected(&this.showUserInfo);

        return usersList;
    }

    void showUserInfo(ListBoxRow row, ListBox lb)
    {
        Widget label = row.getChild();
        Label userLabel = cast(Label) label;
        string username = userLabel.getText();

        this.inputsGrid.fillInUserDetails(username);
        this.currentlySelectedUser = username;
    }

    void addCreateInputs()
    {
        this.inputsGrid = new InputsGrid();
        this.inputsGrid.fillInUserDetails(this.launchedUser);

        this.mainGrid.attach(this.inputsGrid, 1, 0, 1, 1);
    }

    void addButtons()
    {
        auto changePassButton = new Button("Change Password");
        auto saveButton = new Button("Save");
        auto cancelButton = new Button("Cancel");

        saveButton.addOnClicked(&saveChanges);
        changePassButton.addOnClicked(&showChangePasswordDialog);

        Box buttonBox = new Box(Orientation.HORIZONTAL, 30);
        buttonBox.setBorderWidth(20);
        buttonBox.setHomogeneous(true);

        buttonBox.add(saveButton);
        buttonBox.add(changePassButton);
        buttonBox.add(cancelButton);

        this.mainGrid.attach(buttonBox, 1, 1, 1, 1);
    }

    void saveChanges(Button b)
    {
        string realName = this.inputsGrid.getRealNameText();
        if (realName.length && realName != getUserRealName(currentlySelectedUser))
        {
            auto chfnPipe = pipeProcess([
                    "chfn", "-f", format("'%s'", realName),
                    this.currentlySelectedUser
                    ], Redirect.stderr | Redirect.stdout);
            if (wait(chfnPipe.pid) != 1)
            {
                showCouldNotUpdateUserError();
            }

            string chfnOut = strip(chfnPipe.stdout.readln());
            string chfnErr = strip(chfnPipe.stderr.readln());

            if (chfnErr.length && (indexOf(chfnErr, "login.defs forbids") > -1))
            {
                showCouldNotUpdateUserError();
            }
        }
    }

    void showCouldNotUpdateUserError()
    {
        showError(this.win, "Could not update user. Please contact your administrator.");
    }

    void showChangePasswordDialog(Button b)
    {
        auto cpd = new ChangePasswordDialog(this.win, this.isRoot, this.currentlySelectedUser);
        cpd.setTransientFor(this.win);
        cpd.run();
    }

    void run()
    {
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

    this()
    {
        this.usernameEntry = new Entry();
        this.usernameEntry.setHexpand(true); // only need to do this once I guess.
        this.usernameEntry.setProperty("editable", false);
        this.usernameEntry.setSensitive(false);

        this.realNameEntry = new Entry();
        this.layoutInputs();
    }

    void layoutInputs()
    {
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

    void fillInUserDetails(string username)
    {
        this.usernameEntry.setText(username);

        string realName = getUserRealName(username);
        if (realName)
        {
            this.realNameEntry.setText(realName);
        }
    }

    string getRealNameText()
    {
        return this.realNameEntry.getText();
    }
}

class ChangePasswordDialog : Dialog
{

    bool isRoot = false;
    string username = null;
    Entry oldPasswordEntry = null;
    Entry newPasswordEntry = null;
    Entry confirmNewPasswordEntry = null;

    this(Window parent, bool isRoot, string username)
    {
        super("Change Your Password", parent, DialogFlags.MODAL, [
                "Update", "Cancel"
                ], [ResponseType.OK, ResponseType.CANCEL]);

        this.isRoot = isRoot;
        this.username = username;

        auto oldPasswordLabel = new Label("Current Password: ");
        if (!isRoot)
        {
            this.oldPasswordEntry = new Entry();
            this.oldPasswordEntry.setVisibility(false);
        }

        auto newPasswordLabel = new Label("New Password: ");
        this.newPasswordEntry = new Entry();
        this.newPasswordEntry.setVisibility(false);

        auto confirmNewPasswordLabel = new Label("Confirm New Password: ");
        this.confirmNewPasswordEntry = new Entry();
        this.confirmNewPasswordEntry.setVisibility(false);

        Box innerBox = new Box(Orientation.VERTICAL, 5);
        innerBox.setBorderWidth(10);

        if (!isRoot)
        {
            innerBox.add(oldPasswordLabel);
            innerBox.add(this.oldPasswordEntry);
        }

        innerBox.add(newPasswordLabel);
        innerBox.add(this.newPasswordEntry);
        innerBox.add(confirmNewPasswordLabel);
        innerBox.add(this.confirmNewPasswordEntry);

        Box contentBox = this.getContentArea();
        contentBox.add(innerBox);

        this.showAll();

        this.addOnResponse(&onButtonClicked);
    }

    void onButtonClicked(int responseId, Dialog dlg)
    {
        // -4 = X button
        // -5 = Ok
        // -6 = Cancel
        switch (responseId)
        {
        default:
            this.destroy();
            break;
        case -5:
            Tuple!(bool, string) result;

            if (!this.isRoot)
            {
                result = changeOwnPassword(this.oldPasswordEntry.getText(),
                        this.newPasswordEntry.getText(), this.confirmNewPasswordEntry.getText());
            }
            else
            {
                result = changeUserPassword(this.username,
                        this.newPasswordEntry.getText(), this.confirmNewPasswordEntry.getText());
            }

            if (!result[0])
            {
                showError(this, result[1]);
            }
            else
            {
                showMessage(this, result[1], true);
            }
            break;
        }
    }
}

bool isRootUser()
{
    auto idPipe = pipeProcess(["id", "-u"], Redirect.stderr | Redirect.stdout);
    scope (exit)
        wait(idPipe.pid);

    auto op = strip(idPipe.stdout.readln());
    return op == "0";
}

void main(string[] argv)
{
    string me = getOutput(["whoami"]);
    bool isRoot = isRootUser();

    UserManagerMain umm = new UserManagerMain(argv, isRoot);
    umm.launchedUser = me;
    umm.addCreateInputs();
    umm.addButtons();
    umm.run();
}

import std.process;
import std.string;

import gtk.MainWindow;
import gtk.Window;
import gtk.Main;
import gtk.Button;
import gtk.Box;
import gtk.Widget;
import gtk.Label;
import gtk.Grid;
import gtk.ListBox;
import gtk.ListBoxRow;

import helpers.functions;
import widgets.inputsgrid;
import widgets.changepassworddialog;


class App
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

void main(string[] argv)
{
    string me = getOutput(["whoami"]);
    bool isRoot = isRootUser();

    App app = new App(argv, isRoot);
    app.launchedUser = me;
    app.addCreateInputs();
    app.addButtons();
    app.run();
}

import gtk.Grid;
import gtk.Entry;
import gtk.Label;

import helpers;


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



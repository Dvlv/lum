module widgets.inputsgrid;

import std.file;
import std.path;
import std.stdio;

import gtk.Widget;
import gtk.Grid;
import gtk.Entry;
import gtk.Label;
import gtk.Button;
import gtk.Image;
import gtk.IconTheme;
import gtk.FileChooserDialog;
import gtk.FileFilter;
import gtk.Window;

import gdk.Pixbuf;

import helpers.functions;


class InputsGrid : Grid
{
    Button avatarButton = null;
    Entry usernameEntry = null;
    Entry realNameEntry = null;
    Grid inputsGrid = null;
    Window parent = null;
    string currentUser = null;
    string newAvatarPath = null;

    this(Window parent)
    {
        this.parent = parent;

        this.avatarButton = new Button();

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
        Label avatarLabel = new Label("Icon:");

        this.attach(usernameLabel, 1, 0, 1, 1);
        this.attach(this.usernameEntry, 2, 0, 1, 1);

        this.attach(realNameLabel, 1, 1, 1, 1);
        this.attach(this.realNameEntry, 2, 1, 1, 1);

        this.attach(avatarLabel, 1, 2, 1, 1);
        this.attach(this.avatarButton, 2, 2, 1, 1);

        this.avatarButton.addOnPressed(&changeAvatar);
    }

    void changeAvatar(Button b)
    {
        auto filter = new FileFilter();
        filter.addPattern("*.png");

        auto fcd = new FileChooserDialog("Select an avatar", this.parent, FileChooserAction.OPEN);
        fcd.addFilter(filter);
        string newFaceFile = null;

        int response = fcd.run();
        if (response == ResponseType.OK)
        {
            newFaceFile = fcd.getFilename();
        }

        fcd.destroy();

        if (newFaceFile)
        {
            putAvatarImageOntoButton(newFaceFile);
            this.newAvatarPath = newFaceFile;
        }

        //        if (this.currentUser.length && isRoot)
        //       {
        //           string accountsServiceFile = "/var/lib/AccountsService/icons/" ~ this.currentUser;
        //           if (exists(accountsServiceFile))
        //           {
        //               newFaceFile.copy(accountsServiceFile);
        //           }
        //       }
    }

    void fillInUserDetails(string username)
    {
        this.currentUser = username;
        this.usernameEntry.setText(username);

        string realName = getUserRealName(username);
        if (realName)
        {
            this.realNameEntry.setText(realName);
        }

        putAvatarImageOntoButton(expandTilde("~/.face"));
    }

    void putAvatarImageOntoButton(string imagePath)
    {
        if (exists(imagePath))
        {
            Image avatarImage = new Image(imagePath);
            this.avatarButton.setImage(avatarImage);
        }
        else
        {
            IconTheme it = new IconTheme();
            Image plusImage = new Image();
            Pixbuf plusPixbuf = it.loadIcon("list-add", 20, GtkIconLookupFlags.FORCE_SVG);
            plusImage.setFromPixbuf(plusPixbuf);
            this.avatarButton.setImage(plusImage);
        }

    }

    string getRealNameText()
    {
        return this.realNameEntry.getText();
    }
}

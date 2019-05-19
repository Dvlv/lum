module widgets.inputsgrid;

import std.file;
import std.path;
import std.stdio;

import gtk.Grid;
import gtk.Entry;
import gtk.Label;
import gtk.Button;
import gtk.Image;
import gtk.IconTheme;
import gdk.Pixbuf;

import helpers.functions;


class InputsGrid : Grid
{
    Button avatarButton = null;
    Entry usernameEntry = null;
    Entry realNameEntry = null;
    Grid inputsGrid = null;

    this()
    {
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
    }

    void fillInUserDetails(string username)
    {
        this.usernameEntry.setText(username);

        string realName = getUserRealName(username);
        if (realName)
        {
            this.realNameEntry.setText(realName);
        }
        
        if( exists(expandTilde("~/.face"))) {
            Image avatarImage = new Image(expandTilde("~/.face"));
            this.avatarButton.setImage(avatarImage);
        } else {
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



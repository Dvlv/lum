import std.typecons;

import gtk.Dialog;
import gtk.Entry;
import gtk.Label;
import gtk.Box;
import gtk.Button;
import gtk.Window;

import helpers;

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

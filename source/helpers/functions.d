module helpers.functions;

import std.stdio;
import std.process;
import std.string;
import std.typecons;

import gtk.Window;
import gtk.MessageDialog;
import gtk.Dialog;

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
    auto catPipe = pipeProcess(["cat", "/etc/shadow"], Redirect.stderr | Redirect.stdout);
    scope (exit)
        wait(catPipe.pid);


    auto cutPipe = pipeProcess(["cut", "-f", "1,2", "-d", ":"], Redirect.all);
    foreach (catline; catPipe.stdout.byLine)
        cutPipe.stdin.writeln(catline);
    cutPipe.stdin.close();
    scope (exit)
        wait(cutPipe.pid);

    string[] cutLines;
    foreach (cutline; cutPipe.stdout.byLine)
        cutLines ~= cutline.idup;

    string[] realUsers;
    foreach (potentialUser; cutLines) {
        string[] userToPass = split(potentialUser, ":");
        if (!(userToPass[1] == "!!" || userToPass[1] == "!")) {
            realUsers ~= userToPass[0];
        }
    }

    return realUsers;
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

bool isRootUser()
{
    auto idPipe = pipeProcess(["id", "-u"], Redirect.stderr | Redirect.stdout);
    scope (exit)
        wait(idPipe.pid);

    auto op = strip(idPipe.stdout.readln());
    return op == "0";
}



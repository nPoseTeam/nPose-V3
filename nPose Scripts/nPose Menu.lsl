/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/

//default options settings.  Change these to suit personal preferences
string Permissions = "PUBLIC"; //default permit option Pubic, Locked, Group
string curmenuonsit = "off"; //default menuonsit option
string cur2default = "off";  //default action to revert back to default pose when last sitter has stood
string Facials = "on";
string menuReqSit = "off";  //required to be seated to get a menu
string RLVenabled = "on";   //default RLV enabled state  on or no
//

list victims;
string path;
list slots; //this slots list is not complete. it only contains seated AV key and seat numbers
string defaultPoseNcName; //holds the name of the default notecard.
string menuNC = ".Change Menu Order"; //holds the name of the menu order notecard to read.
list slotbuttons = [];//list of seat# or seated AV name for change seats menu.
//key toucherid;
list menus;
list menuPermPath;
list menuPermPerms;
float currentOffsetDelta = 0.2;
float menuDistance = 30.0;

key scriptID;

#define SET_PREFIX "SET"
#define BTN_PREFIX "BTN"
#define DEFAULT_PREFIX "DEFAULT"
#define CARD_PREFIXES [SET_PREFIX, DEFAULT_PREFIX, BTN_PREFIX]
#define DIALOG -900
#define DIALOG_RESPONSE -901
#define DIALOG_TIMEOUT -902
#define DOPOSE 200
#define ADJUST 201
#define SWAP 202
#define DUMP 204
#define STOPADJUST 205
#define SYNC 206
#define DOBUTTON 207
#define ADJUSTOFFSET 208
#define SETOFFSET 209
#define SWAPTO 210
#define UNSIT -222
#define DOMENU -800
#define DOMENU_ACCESSCTRL -801
#define EXTERNAL_UTIL_REQUEST -888
#define MEMORY_USAGE 34334
#define SEAT_UPDATE 35353
#define SEAT_BUTTONS 35354
#define VICTIMS_LIST -238
#define OPTIONS_NUM -240
#define FACIALS_FLAG -241
#define FWDBTN "forward"
#define BKWDBTN "backward"
#define LEFTBTN "left"
#define RIGHTBTN "right"
#define UPBTN "up"
#define DOWNBTN "down"
#define ZEROBTN "reset"
list offsetbuttons = [FWDBTN, LEFTBTN, UPBTN, BKWDBTN, RIGHTBTN, DOWNBTN, "0.2", "0.1", "0.05", "0.01", ZEROBTN];

//dialog button responses
#define SLOTBTN "ChangeSeat"
#define SYNCBTN "sync"
#define OFFSETBTN "offset"
#define BACKBTN "^"
#define ROOTMENU "Main"
#define ADMINBTN "admin"
#define ADJUSTBTN "Adjust"
#define STOPADJUSTBTN "StopAdjust"
#define POSDUMPBTN "PosDump"
#define UNSITBTN "Unsit"
#define OPTIONS "Options"
#define MENUONSIT "Menuonsit"
#define TODEFUALT "ToDefault"
#define PERMITBTN "Permit"
list adminbuttons = [ADJUSTBTN, STOPADJUSTBTN, POSDUMPBTN, UNSITBTN, OPTIONS];

// userDefinedPermissions
#define USER_PERMISSION_UPDATE -806

#define PERMISSION_GROUP "group"
#define PERMISSION_OWNER "owner"
#define PERMISSION_SEATED "seated"
#define USER_PERMISSION_TYPE_LIST "list"
#define USER_PERMISSION_TYPE_BOOL "bool"
list pluginPermissionList;

//NC Reader
#define NC_READER_CONTENT_SEPARATOR "%&§"
#define NC_READER_REQUEST 224
#define NC_READER_RESPONSE 225


Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page, string Path) {
    //check menu permissions
    if(
        //the whole if statement only exists for backward compability, because all this (and more) could be done via button permissions on root level
        (rcpt == llGetOwner() || Permissions == "GROUP" && llSameGroup(rcpt) || Permissions == "PUBLIC") &&
        (rcpt == llGetOwner() || menuReqSit == "off" || ~llListFindList(slots, [rcpt])) &&
        // old RLV plugin, (Lenoa: This behaves like gecko release)
        (rcpt == llGetOwner() || !~llListFindList(victims, [(string)rcpt]))
    ) {
        list thisMenuPath=llDeleteSubList(llParseStringKeepNulls(Path , [":"], []), 0, 0);
        //check button permission for this path up to the root
        //this also means that button permissions are inheritable
        list tempPath=thisMenuPath;
        do {
            integer indexc=llListFindList(menuPermPath, [llDumpList2String(tempPath, ":")]);
            if(~indexc) {
                if(!isAllowed(rcpt, llList2String(menuPermPerms, indexc))) {
                    return;
                }
            }
        } while (llGetListLength(tempPath=llDeleteSubList(tempPath, -1, -1)));
        //check button permission for each button
        integer stopc = llGetListLength(choices);
        integer nc;
        for(; nc < stopc; ++nc) {
            integer indexc = llListFindList(menuPermPath, [llDumpList2String(thisMenuPath + llList2String(choices, nc), ":")]);
            if(indexc != -1) {
                if(!isAllowed(rcpt, llList2String(menuPermPerms, indexc))) {
                    choices = llDeleteSubList(choices, nc, nc);
                    --nc;
                    --stopc;
                }
            }
        }
        if(llGetInventoryType(menuNC) != INVENTORY_NOTECARD) {
            choices = llListSort(choices, 1, 1);
        }
        llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page +
         "|" + llDumpList2String(choices, "`") + "|" + llDumpList2String(utilitybuttons, "`") + "|" + Path, scriptID);
    }
}

integer isAllowed(key rcpt, string permissions) {
    // Syntax of the permission string:
    // The permission string is the last part of the notecard name surrounded by {}
    // It contains KEYWORDS and OPERATORS.

    // OPERATORS (listed in order of their precedence)
    // ! means a logical NOT
    // & means a logical AND
    // ~ means a logical OR
    // Operators may be surrounded by spaces

    // KEYWORDS (case insensitive)
    // owner:  returns TRUE if the user is the object owner
    // group:  returns TRUE if the active group of the user is equal to the group of the object
    // seated: returns TRUE if the user is seated
    // any integer counts as a seatNumber: returns true if the user is sitting on the seat with the specified number
    // any other string counts as a permission registered by a plugin

    // Examples:
    // 1~3 : is TRUE if the user is seated on seat number 1 or 3
    // owner~2 : is TRUE for the object owner or anyone sitting on seat number 2
    // owner&!victim : is TRUE for the object owner, but only if he/she isn't a victim (victim is a UserDefinedPermission used by the RLV+ plugin)
    // 1~3&group: is TRUE for the user on seat 1 and also for the user on seat 3 if he/she has the same active group as the Object
    permissions=llStringTrim(permissions, STRING_TRIM);
    if(permissions=="") {
        return TRUE;
    }
    else {
        list permItemsOr=llParseString2List(llToLower(permissions), ["~"], []);
        integer indexOr=~llGetListLength(permItemsOr);
        integer result;
        while(++indexOr && !result) {
            list permItemsAnd=llParseString2List(llList2String(permItemsOr, indexOr), ["&"], []);
            integer indexAnd=~llGetListLength(permItemsAnd);
            result=TRUE;
            while(++indexAnd && result) {
                integer invert;
                string item=llStringTrim(llList2String(permItemsAnd, indexAnd), STRING_TRIM);
                if(llGetSubString(item, 0, 0)=="!") {
                    invert=TRUE;
                    item=llStringTrim(llDeleteSubString(item, 0, 0), STRING_TRIM);
                }
                if(item==PERMISSION_GROUP) {
                    result=logicalXor(invert, llSameGroup(rcpt));
                }
                else if(item==PERMISSION_OWNER) {
                    result=logicalXor(invert, llGetOwner()==rcpt);
                }
                else if(item==PERMISSION_SEATED) {
                    result=logicalXor(invert, ~llListFindList(slots, [rcpt]));
                }
                else if((string)((integer)item)==item){
                    /// seat number
                    integer slotIndex=llListFindList(slots, [rcpt]);
                    integer z=llSubStringIndex(llList2String(slots, slotIndex + 1), "§");
                    string seatNumber=llGetSubString(llList2String(slots, slotIndex + 1), z+5,-1);
                    result=logicalXor(invert, item==seatNumber);
                }
                else {
                    //maybe a plugin permission
                    integer pluginPermissionIndex=llListFindList(pluginPermissionList, [item]);
                    if(~pluginPermissionIndex) {
                        //plugin permission
                        string pluginPermissionType=llList2String(pluginPermissionList, pluginPermissionIndex+1);
                        if(pluginPermissionType==USER_PERMISSION_TYPE_LIST) {
                            result=logicalXor(invert, ~llSubStringIndex(llList2String(pluginPermissionList, pluginPermissionIndex+2), (string)rcpt));
                        }
                        else if(pluginPermissionType==USER_PERMISSION_TYPE_BOOL) {
                            result=logicalXor(invert, (integer)llList2String(pluginPermissionList, pluginPermissionIndex+2));
                        }
                        else {
                            //error unknown plugin permission type
                            //maybe a message to the owner?
                            result=invert;
                        }
                    }
                    else {
                        //maybe the plugin has not registered itself right now. So assume a blank list or a 0 as value
                        result=invert;
                    }
                }
            }
        }
        return result;
    }
}

integer logicalXor(integer conditionA, integer conditionB) {
    //lsl do only know a bitwise XOR :(
    return(conditionA && !conditionB) || (!conditionA && conditionB);
}

AdjustOffsetDirection(key id, vector direction) {
    vector delta = direction * currentOffsetDelta;
    llMessageLinked(LINK_SET, ADJUSTOFFSET, (string)delta, id);
}    

AdminMenu(key toucher, string path, string prompt, list buttons) {
    //added path to send to dialog script
    Dialog(toucher, prompt+"\n"+path+"\n", buttons, [BACKBTN], 0, path);
}

DoMenu(key toucher, string path, string menuPrompt, integer page) {//builds the final menu for authorized
    integer index = llListFindList(menus, [path]);
    if(~index) {
        list buttons = llParseStringKeepNulls(llList2String(menus, index+1), ["|"], []);
        list tmp = [];
        if(path != ROOTMENU) {
            tmp += [BACKBTN];
        }
        //added path to send to dialog script
        Dialog(toucher, menuPrompt + "\n"+path+"\n", buttons, tmp, page, path);
    }
}

BuildMenus(list cardNames) {//builds the user defined menu buttons
    menus = [];
    menuPermPath = [];
    menuPermPerms = [];
    integer stop = llGetListLength(cardNames);
    integer fromContents;
    if(!stop) {
        fromContents = TRUE;
        stop = llGetInventoryNumber(INVENTORY_NOTECARD);
    }
    integer defaultSet;// = FALSE; // false by default
    integer n;
    for(; n<stop; ++n) {//step through the notecards backwards so that default notecard is first in the contents
        string name = llList2String(cardNames, n);
        if(fromContents) {
            name = llGetInventoryName(INVENTORY_NOTECARD, n);
        }
        integer permsIndex1 = llSubStringIndex(name,"{");
        integer permsIndex2 = llSubStringIndex(name,"}");
        string menuPerms;
        if(~permsIndex1) { // found
            menuPerms = llGetSubString(name, permsIndex1+1, permsIndex2+-1);
            name = llDeleteSubString(name, permsIndex1, permsIndex2);
        }
        list pathParts = llParseStringKeepNulls(name, [":"], []);
        string prefix = llList2String(pathParts, 0);
        if((!defaultSet && prefix == SET_PREFIX) | (prefix == DEFAULT_PREFIX)) {
            if(!fromContents) {
                defaultPoseNcName = llList2String(cardNames, n);
            }
            else {
                defaultPoseNcName = llGetInventoryName(INVENTORY_NOTECARD, n);
            }
            defaultSet = TRUE;
        }
        pathParts = llListReplaceList(pathParts, [ROOTMENU], 0, 0);
        if(menuPerms) {
            menuPermPath += llDumpList2String(llDeleteSubList(pathParts, 0, 0), ":");
            menuPermPerms += menuPerms;
        }
        if(~llListFindList(CARD_PREFIXES, [prefix])) { // found
            pathParts = llDeleteSubList(pathParts, 0, 0);            
            while(llGetListLength(pathParts)) {
                string last = llList2String(pathParts, -1);
                string parentpath = llDumpList2String([ROOTMENU] + llDeleteSubList(pathParts, -1, -1), ":");
                integer index = llListFindList(menus, [parentpath]);
                if(~index && !(index & 1)) {
                    list children = llParseStringKeepNulls(llList2String(menus, index + 1), ["|"], []);
                    if(!~llListFindList(children, [last])) {
                        children += [last];
                        menus = llListReplaceList(menus, [llDumpList2String(children, "|")], index + 1, index + 1);
                    }
                }
                else {
                    menus += [parentpath, last];
                }
                pathParts = llDeleteSubList(pathParts, -1, -1);
            }
        }
    }
}

default{
    state_entry() {
        scriptID=llGetInventoryKey(llGetScriptName());
        if(llGetInventoryType(menuNC) != INVENTORY_NOTECARD) {
            BuildMenus([]);
        }
        else {
            llSleep(1.0); //be sure that the NC reader script finished resetting
            llMessageLinked(LINK_SET, NC_READER_REQUEST, menuNC, scriptID);
        }
    }
    
    touch_start(integer total_number) {
        key toucherKey = llDetectedKey(0);
        vector vDelta = llDetectedPos(0) - llGetPos();
        if(toucherKey == llGetOwner() || llVecMag(vDelta) < menuDistance) {
            DoMenu(toucherKey, ROOTMENU, "", 0);
        }
    }
    
    link_message(integer sender, integer num, string str, key id) {
        integer index;
        integer n;
        integer stop;
        if(str == "menuUP") {
            llMessageLinked(LINK_SET, -802, "PATH=" + path, NULL_KEY);
        }
        if(num == DIALOG_RESPONSE && id == scriptID) { //response from menu
            list params = llParseString2List(str, ["|"], []);  //parse the message
            integer page = (integer)llList2String(params, 0);  //get the page number
            string selection = llList2String(params, 1);  //get the button that was pressed from str
            key toucherid = llList2Key(params, 2);
            path = llList2String(params, 3); //get the path from params list
            if(selection == BACKBTN) {
                //handle the back button. admin menu gets handled differently cause buttons are custom
                list pathparts = llParseString2List(path, [":"], []);
                pathparts = llDeleteSubList(pathparts, -1, -1);
                if(llList2String(pathparts, -1) == ADMINBTN) {
                    //back button within admin menu
                   AdminMenu(toucherid, llDumpList2String(pathparts, ":"), "", adminbuttons);
                }
                else if(llGetListLength(pathparts) <= 1) {
                    //back button leads to root menu
                    DoMenu(toucherid, ROOTMENU, "", 0);
                }
                else {
                    //just back one menu
                    DoMenu(toucherid, llDumpList2String(pathparts, ":"), "", 0);
                }
//begin admin button section
            }
            else if(selection == ADMINBTN) {
                path += ":" + selection;
                AdminMenu(toucherid, path, "", adminbuttons);
            }
            else if(selection == SLOTBTN) {
                //someone wants to change sit positionss.
                //taking a place where someone already has that slot should do the swap regardless of how many 
                //places are open
                path = path + ":" + selection;
                AdminMenu(toucherid, path,  "Where will you sit?", slotbuttons);
            }
            else if(selection == OFFSETBTN) {
                //give offset menu
                path = path + ":" + selection;
                AdminMenu(toucherid, path,   "Adjust by " + (string)currentOffsetDelta
                 + "m, or choose another distance.", offsetbuttons);
            }
            else if(selection == ADJUSTBTN) {
                llMessageLinked(LINK_SET, ADJUST, "", "");
                AdminMenu(toucherid, path, "", adminbuttons);
            }
            else if(selection == STOPADJUSTBTN) {
                llMessageLinked(LINK_SET, STOPADJUST, "", "");
                AdminMenu(toucherid, path, "", adminbuttons);
            }
            else if(selection == POSDUMPBTN) {
                llMessageLinked(LINK_SET, DUMP, "", "");
                AdminMenu(toucherid, path, "", adminbuttons);
            }
            else if(selection == UNSITBTN) {
                list buttons;
                stop = llGetListLength(slots);
                for(; n < stop; n+=2) {
                    //grab all seated AV names to populate the buttons
                    buttons += [llGetSubString(llKey2Name((key)llList2String(slots, n)), 0, 20)];
                }
                if(buttons != []) {
                    //grab unsit menu if we have sitters to unsit
                    path += ":" + selection;
                    AdminMenu(toucherid, path, "Pick an avatar to unsit", buttons);
                }
                else {
                    //just re-menu if no one is seated
                    AdminMenu(toucherid, path, "", adminbuttons);
                }
            }
            else if(selection == OPTIONS) {
                path += ":" + selection;
                string optionsPrompt =  "Permit currently set to " + Permissions
                 + "\nMenuOnSit currently set to "+ curmenuonsit + "\nsit2GetMenu currently set to " + menuReqSit 
                 + "\n2default currently set to "+ cur2default + "\nFacialEnable currently set to "+ Facials
                 + "\nUseRLVBaseRestrict currently set to "+ RLVenabled + "\nmenudist currently set to "+ (string)menuDistance;
                AdminMenu(toucherid, path, optionsPrompt, []);
//end admin button section
            }
            else if(llList2String(llParseString2List(path, [":"], []), -1) == SLOTBTN) {//change seats
                if(llGetSubString(selection, 0,3)=="seat") { //clicker selected an open seat where menu is 'seat'+#
                    n = (integer)llGetSubString(selection, 4,-1);
                    if(n >= 0) {
                        llMessageLinked(LINK_SET, SWAPTO, (string)n, toucherid);
                    }
                }
                else { //clicker selected a name so get seat# from list
                    n = llListFindList(slotbuttons, [selection])+1;
                    if(n >= 0) {
                        llMessageLinked(LINK_SET, SWAPTO, (string)n, toucherid);
                    }
                }
                list pathparts = llParseString2List(path, [":"], []);
                pathparts = llDeleteSubList(pathparts, -1, -1);
                path = llDumpList2String(pathparts, ":");
                DoMenu(toucherid, path,  "", 0);
            }
            else if(llList2String(llParseString2List(path, [":"], []), -1) == UNSITBTN) {
                stop = llGetListLength(slots);
                list buttons;
                for(; n < stop; n+=2) {
                    key av = llList2Key(slots, n);
                    if(llGetSubString(llKey2Name(av), 0, 20) == selection) {
                        llMessageLinked(LINK_SET, UNSIT, (string)av, NULL_KEY);
                    }
                    else {
                        buttons += [llGetSubString(llKey2Name(av), 0, 20)];
                    }
                }
                if(buttons) {
                    AdminMenu(toucherid, path, "Pick an avatar to unsit", buttons);
                }
                else {
                    list pathParts = llParseString2List(path, [":"], []);
                    pathParts = llDeleteSubList(pathParts, -1, -1);
                    AdminMenu(toucherid, llDumpList2String(pathParts, ":"), "", adminbuttons);
                }
            }
            else if(llList2String(llParseString2List(path, [":"], []), -1) == OFFSETBTN) {
                     if(selection ==   FWDBTN) AdjustOffsetDirection(toucherid,  (vector)<1, 0, 0>);
                else if(selection ==  BKWDBTN) AdjustOffsetDirection(toucherid,  (vector)<-1, 0, 0>);
                else if(selection ==  LEFTBTN) AdjustOffsetDirection(toucherid,  (vector)<0, 1, 0>);
                else if(selection == RIGHTBTN) AdjustOffsetDirection(toucherid,  (vector)<0, -1, 0>);
                else if(selection ==    UPBTN) AdjustOffsetDirection(toucherid,  (vector)<0, 0, 1>);
                else if(selection ==  DOWNBTN) AdjustOffsetDirection(toucherid,  (vector)<0, 0, -1>);
                else if(selection ==  ZEROBTN) llMessageLinked(LINK_SET, SETOFFSET, (string)ZERO_VECTOR, toucherid);
                else currentOffsetDelta = (float)selection;
                AdminMenu(toucherid, path,  "Adjust by " + (string)currentOffsetDelta
                 + "m, or choose another distance.", offsetbuttons);
            }
            else if(selection == SYNCBTN) {
                llMessageLinked(LINK_SET, SYNC, "", "");
                DoMenu(toucherid, path, "", page);                    
            }
            else {
//begin and do the selection
                list pathlist = llDeleteSubList(llParseStringKeepNulls(path, [":"], []), 0, 0);
                string defaultname = llDumpList2String([DEFAULT_PREFIX] + pathlist + [selection], ":");                
                string setname = llDumpList2String([SET_PREFIX] + pathlist + [selection], ":");
                string btnname = llDumpList2String([BTN_PREFIX] + pathlist + [selection], ":");
                //correct the notecard name so the core can find this notecard

                integer permission = llListFindList(menuPermPath, [llDumpList2String(pathlist + [selection], ":")]);

                if(~permission) {
                    string thisPerm = llList2String(menuPermPerms, permission);
                    if(thisPerm != "") {
                        defaultname += "{"+thisPerm+"}";
                        setname += "{"+thisPerm+"}";
                        btnname += "{"+thisPerm+"}";
                    }
                }
                if(llGetInventoryType(defaultname) == INVENTORY_NOTECARD) {
                    llMessageLinked(LINK_SET, DOPOSE, defaultname, toucherid);                    
                }
                if(llGetInventoryType(setname) == INVENTORY_NOTECARD) {
                    llMessageLinked(LINK_SET, DOPOSE, setname, toucherid);
                }
                if(llGetInventoryType(btnname) == INVENTORY_NOTECARD) {
                    llMessageLinked(LINK_SET, DOBUTTON, btnname, toucherid);
                }
                if(~llListFindList(menus, [path + ":" + selection])) {
                    //here is where submenu button has been clicked
                    DoMenu(toucherid, path + ":" + selection, "", 0);
                }
                else if(llGetSubString(selection,-1,-1) != "-") {//re-menu only if last character in selections is NOT '-'
                    DoMenu(toucherid, path, "", page);
                }
            }
//end do the selection
        }
        else if(num == DIALOG_TIMEOUT) {//menu not clicked and dialog timed out
            if((cur2default == "on") && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()) && (defaultPoseNcName != "")) {
                llMessageLinked(LINK_SET, DOPOSE, defaultPoseNcName, NULL_KEY);
            }
//begin handle link message inputs
        }
        else if(num==OPTIONS_NUM) {
            //save new option(s) from LINKMSG
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            stop = llGetListLength(optionsToSet);
            for(; n<stop; ++n) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, n), ["="], []);
                string optionItem = llList2String(optionsItems, 0);
                string optionSetting = llList2String(optionsItems, 1);
                if(optionItem == "menuonsit") {curmenuonsit = optionSetting;}
                else if(optionItem == "permit") {Permissions = llToUpper(optionSetting);}
                else if(optionItem == "2default") {cur2default = optionSetting;}
                else if(optionItem == "sit2getmenu") {menuReqSit = optionSetting;}
                else if(optionItem == "menudist") {menuDistance = (float)optionSetting;}
                else if(optionItem == "facialExp") {
                    Facials = optionSetting;
                    llMessageLinked(LINK_SET, FACIALS_FLAG, Facials, NULL_KEY);
                }
                else if(optionItem == "rlvbaser") {
                    RLVenabled = optionSetting;
                    llMessageLinked(LINK_SET, -1812221819, "RLV=" + RLVenabled, NULL_KEY);
                }
            }
        }
        else if(num == EXTERNAL_UTIL_REQUEST) {
            if(str == ADMINBTN) {
                path += ":" + str;
                AdminMenu(id, path, "", adminbuttons);
            }
            else if(str == SLOTBTN) {
                //someone wants to change sit positionss.
                //taking a place where someone already has that slot should do the swap regardless of how many 
                //places are open
                path = path + ":" + str;
                AdminMenu(id, path,  "Where will you sit?", slotbuttons);
            }
            else if(str == OFFSETBTN) {
                //give offset menu
                path = path + ":" + str;
                AdminMenu(id, path,   "Adjust by " + (string)currentOffsetDelta
                 + "m, or choose another distance.", offsetbuttons);
            }
            else if(str == SYNCBTN) {
                llMessageLinked(LINK_SET, SYNC, "", "");
                DoMenu(id, path, "", 0);
            }
        }
        else if(num == DOMENU) {
            if(!llSubStringIndex(str, "PATH=")) str = llGetSubString(str, 5, -1);
            DoMenu(id, str, "", 0);
        }
        else if(num == DOMENU_ACCESSCTRL) {//external call to check permissions
            DoMenu(id, ROOTMENU, "", 0);
        }
        else if(num == VICTIMS_LIST) {
            victims = llCSV2List(str);
        }
        else if(num == NC_READER_RESPONSE) {
            if(id==scriptID) {
                BuildMenus(llList2List(llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []), 3, -1));
                str = "";
            }
        }
        else if(num == USER_PERMISSION_UPDATE) {
            // @param str string CSV: permissionName, permissionType, permissionValue[, permissionName, permissionType, permissionValue[, ...]]
            // permissionName: a unique name for a permission
            // permissionType: bool|list
            // permissionValue: 0|1 or a list with Avatar UUIDs (must not contain a ",")

            list newPermission=llCSV2List(str);
            integer n;
            integer length=llGetListLength(newPermission);
            for(; n<length; n+=3) {
                string permissionName=llToLower(llList2String(newPermission, n));
                index=llListFindList(pluginPermissionList, [permissionName]);
                if(~index) {
                    pluginPermissionList=llDeleteSubList(pluginPermissionList, index, index+2);
                }
                pluginPermissionList+=[permissionName] + llList2List(newPermission, n+1, n+2);
            }
        }
        else if(num==SEAT_UPDATE) {
            list slotsList = llParseStringKeepNulls(str, ["^"], []);
            slots = [];
            for(n=0; n<(llGetListLength(slotsList)/8); ++n) {
                slots += [(key)llList2String(slotsList, n*8+4), llList2String(slotsList, n*8+7)];
            }
        }
        else if (num==SEAT_BUTTONS) {
            slotbuttons = llParseString2List(str, [","], []);
            string strideSeat;
            for(n = 0; n < llGetListLength(slotbuttons); ++n) { // n is the slot number
                index = llSubStringIndex(llList2String(slotbuttons, n), "§");
                if(!index) {
                    strideSeat = llGetSubString(llList2String(slotbuttons, n), 1,-1);
                }
                else {
                    strideSeat = llGetSubString(llList2String(slotbuttons, n), 0, index+-1);
                }
                slotbuttons = llListReplaceList(slotbuttons, [strideSeat], n, n);
            }
        }
        else if(num == MEMORY_USAGE) {//dump memory stats to local
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
//end handle link message inputs
    }

    changed(integer change) {
        if(change & CHANGED_INVENTORY) {
            scriptID=llGetInventoryKey(llGetScriptName());
            if(llGetInventoryType(menuNC) != INVENTORY_NOTECARD) {
                BuildMenus([]);
            }
            else {
                llSleep(1.0); //be sure that the NC reader script finished resetting
                llMessageLinked(LINK_SET, NC_READER_REQUEST, menuNC, scriptID);
            }
        }
        if(change & CHANGED_OWNER) {
            llResetScript();
        }
        if((change & CHANGED_LINK) && (cur2default == "on")
         && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims())
         && (defaultPoseNcName != "")) {
            llMessageLinked(LINK_SET, DOPOSE, defaultPoseNcName, NULL_KEY);
        }
    }

    on_rez(integer params) {
        llResetScript();
    }
}

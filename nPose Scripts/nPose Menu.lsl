/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/

//default options settings.  Change these to suit personal preferences
string Permissions = "public"; //default permit option Pubic, Locked, Group
integer Cur2default;  //default action to revert back to default pose when last sitter has stood
integer Sit2GetMenu;  //required to be seated to get a menu
float MenuDistance = 30.0;
integer OptionUseDisplayNames; //use display names instead of usernames in changeSeat/unsit menu
//

list Slots; //this Slots list is not complete. it only contains seated AV key and seat numbers
string DefaultPoseNcName; //holds the name of the default notecard.
string MenuNc = ".Change Menu Order"; //holds the name of the menu order notecard to read.
//key toucherid;
list Menus;
list MenuPermPath;
list MenuPermPerms;

key ScriptId;

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
#define NC_READER_REQUEST 224
#define NC_READER_RESPONSE 225
#define UNSIT -222
#define DOMENU -800
#define DOMENU_ACCESSCTRL -801
#define USER_PERMISSION_UPDATE -806
#define PLUGIN_MENU_REGISTER -810
#define MENU_SHOW -815
#define PREPARE_MENU_STEP1 -820
#define PREPARE_MENU_STEP2 -821
#define PREPARE_MENU_STEP3 -822
#define PLUGIN_ACTION -830
#define PLUGIN_ACTION_DONE -831
#define PLUGIN_MENU -832
#define PLUGIN_MENU_DONE -833

#define EXTERNAL_UTIL_REQUEST -888
#define MEMORY_USAGE 34334
#define SEAT_UPDATE 35353
#define VICTIMS_LIST -238
#define OPTIONS_NUM -240

//dialog buttons
#define BACKBTN "^"
#define ROOTMENU "Main"

//TODO: option related
#define MENUONSIT "Menuonsit"
#define TODEFUALT "ToDefault"
#define PERMITBTN "Permit"


// userDefinedPermissions
#define PERMISSION_GROUP "group"
#define PERMISSION_OWNER "owner"
#define PERMISSION_SEATED "seated"
#define PERMISSION_OCCUPIED "occupied"
#define PERMISSION_OWNSEAT "ownseat"
#define USER_PERMISSION_TYPE_LIST "list"
#define USER_PERMISSION_TYPE_BOOL "bool"
#define USER_PERMISSION_TYPE_MACRO "macro"
list pluginPermissionList;

//NC Reader
#define NC_READER_CONTENT_SEPARATOR "%&§"

//own plugins related
#define MY_PLUGIN_MENU "npose_menu"
#define MY_PLUGIN_MENU_UNSIT "npose_unsit"
#define MY_PLUGIN_MENU_CHANGE_SEAT "npose_changeseat"

//store plugins base paths, register myself as plugin for the rootmenu
list PluginBasePathList=[ROOTMENU];
list PluginNamesList=[MY_PLUGIN_MENU];
list PluginParamsList=[""];

//TODO
#define BUTTON_NAME_SLOT "ChangeSeat"
#define BUTTON_NAME_OFFSET "offset"
#define BUTTON_NAME_UNSIT "Unsit"

//Button comments marker
#define MARKER_COMMENT_START "/*"
#define MARKER_COMMENT_END "*/"

/*
debug(list message){
    llOwnerSay((((llGetScriptName() + "\n##########\n#>") + llDumpList2String(message,"\n#>")) + "\n##########"));
}
*/

DoMenu(key rcpt, string path, integer page, string prompt, list additionalButtons) {
    list choices;
    integer index = llListFindList(Menus, [path]);
    if(~index) {
        choices=llParseStringKeepNulls(llList2String(Menus, index+1), ["|"], []);
    }
    choices+=additionalButtons;
    
    //check menu permissions
    if(
        //the whole if statement only exists for backward compability, because all this (and more) could be done via button permissions on root level
        (rcpt == llGetOwner() || Permissions == "group" && llSameGroup(rcpt) || Permissions == "public") &&
        (rcpt == llGetOwner() || !Sit2GetMenu || ~llListFindList(Slots, [rcpt]))
    ) {
        list thisMenuPath=llDeleteSubList(llParseStringKeepNulls(path , [":"], []), 0, 0);
        //check button permission for this path up to the root
        //this also means that button permissions are inheritable
        list tempPath=thisMenuPath;
        integer rcptSlotNumber=llListFindList(Slots, [rcpt]);
        if(~rcptSlotNumber) {
            rcptSlotNumber=rcptSlotNumber/2;
        }
        do {
            integer indexc=llListFindList(MenuPermPath, [llDumpList2String(tempPath, ":")]);
            if(~indexc) {
                if(!isAllowed(0, rcpt, rcptSlotNumber, llList2String(MenuPermPerms, indexc))) {
                    return;
                }
            }
        } while (llGetListLength(tempPath=llDeleteSubList(tempPath, -1, -1)));
        //check button permission for each button
        integer stopc = llGetListLength(choices);
        integer nc;
        for(; nc < stopc; ++nc) {
            integer indexc = llListFindList(MenuPermPath, [llDumpList2String(thisMenuPath + llList2String(choices, nc), ":")]);
            if(indexc != -1) {
                if(!isAllowed(0, rcpt, rcptSlotNumber, llList2String(MenuPermPerms, indexc))) {
                    choices = llDeleteSubList(choices, nc, nc);
                    --nc;
                    --stopc;
                }
            }
        }
        //generate utility buttons
        list utilitybuttons;

        //call the dialog
        llMessageLinked(LINK_SET, DIALOG, llDumpList2String([
            (string)rcpt,
            prompt,
            (string)page,
            llDumpList2String(choices, "`"),
            llDumpList2String(utilitybuttons, "`"),
            path
        ], "|"), ScriptId);
    }
}

integer isAllowed(integer mode, key avatarKey, integer slotNumber, string permissions) {
    // avatarKey: the key of the avatar using the menu

    // mode 0: (menu button check) 
    //    slotNumber: the slot number of the menu user (if the menu user is not in the slot list, provide a -1)

    // mode 1 (slot button check)
    //    slotNumber: the slotnumber for which the button should be created
    
    
    // Syntax of the permission string:
    // The permission string is the last part of the notecard name surrounded by {}
    // it can also be used in the change seat or unsit command
    // It contains KEYWORDS and OPERATORS.

    // OPERATORS (listed in order of their precedence)
    // ! means a logical NOT
    // & means a logical AND
    // ~ means a logical OR
    // Operators may be surrounded by spaces

    // KEYWORDS (case insensitive)
    // owner:
    //        mode 0: returns TRUE if the menu user is the object owner
    //        mode 1: returns TRUE if the object owner is sitting on the specified seat
    // group:
    //        mode 0: returns TRUE if the active group of the menu user is equal to the group of the object
    //        mode 1: returns TRUE if the active group of the user sitting on the specified seat is equal to the group of the object
    // seated:
    //        mode 0: returns TRUE if the menu user is seated
    //        mode 1: no usefull meaning
    // occupied:
    //        mode 0: no usefull meaning
    //        mode 1: returns TRUE if the given slot is in use
    // ownseat:
    //        mode 0: no usefull meaning
    //        mode 1: returns TRUE if the menu user sits in the specified slot
    // any integer counts as a seatNumber:
    //        mode 0: returns TRUE if menu user sits on the seat with the number seatNumber
    //        mode 1: returns TRUE if the specified slotNumber represents the seat with the number seatNumber
    // any other string counts as a UserDefinedPermission

    // Examples:
    // mode 0:
    // 1~3 : is TRUE if the menu user is seated on seat number 1 or 3
    // owner~2 : is TRUE if the menu user is the object owner or if the menu user is sitting on seat number 2
    // owner&!victim : is TRUE if the menu user is the object owner, but only if he/she isn't a victim (victim is a UserDefinedPermission used by the RLV+ plugin)
    // 1~3&group: is TRUE for the user on seat 1 and also for the user on seat 3 if he/she has the same active group as the Object
    permissions=llStringTrim(permissions, STRING_TRIM);
    if(permissions=="") {
        return TRUE;
    }
    else {
        key avatarInSlot;
        if(~slotNumber) {
            avatarInSlot=llList2Key(Slots, slotNumber*2);
        }
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
                    if(!mode) {
                        result=logicalXor(invert, llSameGroup(avatarKey));
                    }
                    else {
                        result=logicalXor(invert, llSameGroup(avatarInSlot));
                    }
                }
                else if(item==PERMISSION_OWNER) {
                    if(!mode) {
                        result=logicalXor(invert, llGetOwner()==avatarKey);
                    }
                    else {
                        result=logicalXor(invert, llGetOwner()==avatarInSlot);
                    }
                }
                else if(item==PERMISSION_SEATED) {
                    result=logicalXor(invert, slotNumber>=0);
                }
                else if(item==PERMISSION_OCCUPIED) {
                    result=logicalXor(invert, llList2String(Slots, slotNumber*2)!="" && llList2String(Slots, slotNumber*2)!=NULL_KEY);
                }
                else if(item==PERMISSION_OWNSEAT) {
                    result=logicalXor(invert, avatarKey==avatarInSlot);
                }
                else if((string)((integer)item)==item){
                    result=logicalXor(invert, slotNumber+1==(integer)item);
                }

                else {
                    //maybe a user defined permission
                    integer pluginPermissionIndex=llListFindList(pluginPermissionList, [item]);
                    if(~pluginPermissionIndex) {
                        //plugin permission
                        string pluginPermissionType=llList2String(pluginPermissionList, pluginPermissionIndex+1);
                        if(pluginPermissionType==USER_PERMISSION_TYPE_LIST) {
                            result=logicalXor(invert, ~llSubStringIndex(llList2String(pluginPermissionList, pluginPermissionIndex+2), (string)avatarKey));
                        }
                        else if(pluginPermissionType==USER_PERMISSION_TYPE_BOOL) {
                            result=logicalXor(invert, (integer)llList2String(pluginPermissionList, pluginPermissionIndex+2));
                        }
                        else if(pluginPermissionType==USER_PERMISSION_TYPE_MACRO) {
                            result=logicalXor(invert, isAllowed(mode, avatarKey, slotNumber, llList2String(pluginPermissionList, pluginPermissionIndex+2)));
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

BuildMenus(list cardNames) {//builds the user defined menu buttons
    Menus = [];
    MenuPermPath = [];
    MenuPermPerms = [];
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
                DefaultPoseNcName = llList2String(cardNames, n);
            }
            else {
                DefaultPoseNcName = llGetInventoryName(INVENTORY_NOTECARD, n);
            }
            defaultSet = TRUE;
        }
        pathParts = llListReplaceList(pathParts, [ROOTMENU], 0, 0);
        if(menuPerms) {
            MenuPermPath += llDumpList2String(llDeleteSubList(pathParts, 0, 0), ":");
            MenuPermPerms += menuPerms;
        }
        if(~llListFindList(CARD_PREFIXES, [prefix])) { // found
            pathParts = llDeleteSubList(pathParts, 0, 0);
            while(llGetListLength(pathParts)) {
                string last = llList2String(pathParts, -1);
                string parentpath = llDumpList2String([ROOTMENU] + llDeleteSubList(pathParts, -1, -1), ":");
                integer index = llListFindList(Menus, [parentpath]);
                if(~index && !(index & 1)) {
                    list children = llParseStringKeepNulls(llList2String(Menus, index + 1), ["|"], []);
                    if(!~llListFindList(children, [last])) {
                        children += [last];
                        if(llGetInventoryType(MenuNc) != INVENTORY_NOTECARD) {
                            children = llListSort(children, 1, 1);
                        }
                        Menus = llListReplaceList(Menus, [llDumpList2String(children, "|")], index + 1, index + 1);
                    }
                }
                else {
                    Menus += [parentpath, last];
                }
                pathParts = llDeleteSubList(pathParts, -1, -1);
            }
        }
    }
}

string getNcName(string path) {
    path = llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path, [":"], []), 0, 0), ":");
    integer permissionIndex = llListFindList(MenuPermPath, [path]);
    if(~permissionIndex) {
        string thisPerm = llList2String(MenuPermPerms, permissionIndex);
        if(thisPerm != "") {
            path+="{"+thisPerm+"}";
        }
    }
    if(path!="") {
        path=":"+path;
    }

    string ncName;
    if(llGetInventoryType(ncName=DEFAULT_PREFIX + path) == INVENTORY_NOTECARD) {
        return ncName;
    }
    if(llGetInventoryType(ncName=SET_PREFIX + path) == INVENTORY_NOTECARD) {
        return ncName;
    }
    if(llGetInventoryType(ncName=BTN_PREFIX + path) == INVENTORY_NOTECARD) {
        return ncName;
    }
    return "";
}

string deleteNode(string path, integer start, integer end) {
    return llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path, [":"], []), start, end), ":");
}

string buildParamSet1(string path, integer page, string prompt, list additionalButtons, string pluginName, string pluginLocalPath, string pluginStaticParams) {
    //We can't use colons in the promt, because they are used as a seperator in other messages
    //replace them with a UTF Symbol
    prompt=llDumpList2String(llParseStringKeepNulls(prompt, [","], []), "‚"); // CAUTION: the 2nd "‚" is a UTF sign!
    string buttons=llDumpList2String(additionalButtons, ",");
    return llDumpList2String([path, page, prompt, buttons, pluginName, pluginLocalPath, pluginStaticParams], "|");
}

list getPluginParams(string path) {
    //list content:
    //pluginName
    //pluginLocalPath
    //pluginStaticParams
    
    string pluginBasePath=path;
    while(pluginBasePath!="") {
        integer index=llListFindList(PluginBasePathList, [pluginBasePath]);
        if(~index) {
            return [
                llList2String(PluginNamesList, index),
                llDeleteSubString(path, 0, llStringLength(pluginBasePath)),
                llList2String(PluginParamsList, index)
            ];
        }
        else {
            pluginBasePath=deleteNode(pluginBasePath, -1, -1);
        }
    }
    return [MY_PLUGIN_MENU, path, ""];
}

default{
    state_entry() {
        ScriptId=llGetInventoryKey(llGetScriptName());
        if(llGetInventoryType(MenuNc) != INVENTORY_NOTECARD) {
            BuildMenus([]);
        }
        else {
            llSleep(1.0); //be sure that the NC reader script finished resetting
            llMessageLinked(LINK_SET, NC_READER_REQUEST, MenuNc, ScriptId);
        }
    }
    
    touch_start(integer total_number) {
        key toucherKey = llDetectedKey(0);
        vector vDelta = llDetectedPos(0) - llGetPos();
        if(toucherKey == llGetOwner() || llVecMag(vDelta) < MenuDistance) {
            llMessageLinked(LINK_SET, DOMENU, llDumpList2String([ROOTMENU, 0, ""], ","), toucherKey);
        }
    }
    
    link_message(integer sender, integer num, string str, key id) {
// This will not work anymore
//        if(str == "menuUP") {
//            //TODO: deprecated
//            llMessageLinked(LINK_SET, -802, "PATH=" + GlobalPath, id);
//        }
        if((num == DIALOG_RESPONSE && id == ScriptId )|| num==DOMENU || num==DOMENU_ACCESSCTRL) {
            //the following block is to sort the paramters from the different message (to be backward compatible)
            integer page;
            string selection;
            key toucherid;
            string path;
            string prompt;
            if(num==DOMENU || num==DOMENU_ACCESSCTRL) {
                list params = llParseStringKeepNulls(str, [","], []);  //parse the message
                //str: path[, page[, prompt]]
                path=llList2String(params, 0);
                //next lines to be backward compatible with the "PATH=" syntax
                if(!llSubStringIndex(path, "PATH=")) {
                     path = llGetSubString(path, 5, -1);
                }
                if(path=="") {
                    path=ROOTMENU;
                }
                page=(integer)llList2String(params, 1);
                prompt=llList2String(params, 2);
                toucherid=id;
            }
            else {
                list params = llParseStringKeepNulls(str, ["|"], []);  //parse the message
                page = (integer)llList2String(params, 0);  //get the page number
                selection = llList2String(params, 1);  //get the button that was pressed from str
                toucherid = llList2Key(params, 2);
                path = llList2String(params, 3); //get the path from params list
            }
            
            if(path!="" && selection!="") {
                path+=":";
            }
            path+=selection;
            //block end
            
            //BackButton
            if(deleteNode(path, 0, -2)==BACKBTN) {
                llMessageLinked(LINK_SET, PREPARE_MENU_STEP2, buildParamSet1(deleteNode(path, -2, -1), 0, prompt, [], "", "", ""), toucherid);
            }
            else {
                string paramSet1=buildParamSet1(path, page, prompt, [], "", "", "");
                string ncName=getNcName(path);
                if(ncName) {
                    //there is a NC that should be executed
                    integer newNum=DOBUTTON;
                    if(!llSubStringIndex(ncName, DEFAULT_PREFIX) || !llSubStringIndex(ncName, SET_PREFIX)) {
                        newNum=DOPOSE;
                    }
                    llMessageLinked(LINK_SET, newNum, ncName + NC_READER_CONTENT_SEPARATOR + paramSet1, toucherid);
                }
                else {
                    //no NC to be executed, initiate the remenu process without piping the messages trough the core
                    llMessageLinked(LINK_SET, PREPARE_MENU_STEP1, paramSet1, toucherid);
                }
            }
        }
        
        else if(num==PREPARE_MENU_STEP1) {
            list params=llParseStringKeepNulls(str, ["|"], []);  //parse the message
            string path=llList2String(params, 0);
            integer page=(integer)llList2String(params, 1);  //get the page number
            string prompt=llList2String(params, 2);
            string additionalButtons=llList2String(params, 3);
            
            list pluginParams=getPluginParams(path);
            if(llList2String(pluginParams, 0)!=MY_PLUGIN_MENU) {
                //handled by a different plugin
                string paramSet1=buildParamSet1(path, page, prompt, [additionalButtons], llList2String(pluginParams, 0), llList2String(pluginParams, 1), llList2String(pluginParams, 2));
                llMessageLinked(LINK_SET, PLUGIN_ACTION, paramSet1, id);
            }
            else {
                //handled by us
                if(~llListFindList(Menus, [path])) {
                    //this is a node
                    page=0;
                }
                else {
                    path=deleteNode(path, -1, -1);
                }
                string paramSet1=buildParamSet1(path, page, prompt, [additionalButtons], "", "", "");
                llMessageLinked(LINK_SET, PREPARE_MENU_STEP2, paramSet1, id);
            }
        }
        
        else if(num==PREPARE_MENU_STEP2) {
            list params=llParseStringKeepNulls(str, ["|"], []);  //parse the message
            string path=llList2String(params, 0);
            integer page=(integer)llList2String(params, 1);  //get the page number
            string prompt=llList2String(params, 2);
            string additionalButtons=llList2String(params, 3);

            list pluginParams=getPluginParams(path);
            if(llList2String(pluginParams, 0)!=MY_PLUGIN_MENU) {
                //handled by a different plugin
                string paramSet1=buildParamSet1(path, page, prompt, [additionalButtons], llList2String(pluginParams, 0), llList2String(pluginParams, 1), llList2String(pluginParams, 2));
                llMessageLinked(LINK_SET, PLUGIN_MENU, paramSet1, id);
            }
            else {
                //handled by us
                string paramSet1=buildParamSet1(path, page, prompt, [additionalButtons], "", "", "");
                llMessageLinked(LINK_SET, PREPARE_MENU_STEP3, getNcName(path) + NC_READER_CONTENT_SEPARATOR + paramSet1, id);
            }
        }
        else if(num==PLUGIN_MENU_DONE) {
            string path=llList2String(llParseStringKeepNulls(str, ["|"], []), 0);
            llMessageLinked(LINK_SET, PREPARE_MENU_STEP3, getNcName(path) + NC_READER_CONTENT_SEPARATOR + str, id);
        }
        else if(num==PLUGIN_MENU_REGISTER) {
            list params=llParseStringKeepNulls(str, ["|"], []);
            string basePath=llList2String(params, 0);
            string pluginName=llToLower(llList2String(params, 1));
            string pluginStaticParams=llList2String(params, 2);
            integer index=llListFindList(PluginBasePathList, [basePath]);
            if(~index) {
                PluginNamesList=llListReplaceList(PluginNamesList, [pluginName], index, index);
                PluginParamsList=llListReplaceList(PluginParamsList, [pluginStaticParams], index, index);
            }
            else {
                PluginBasePathList+=basePath;
                PluginNamesList+=pluginName;
                PluginParamsList+=pluginStaticParams;
            }
        }
        else if(num==PLUGIN_ACTION || num==PLUGIN_MENU) {
            //the menu script itself contains a few menu plugins.
            //the former admin menu is not part of it. We could simply use NCs for it.
            list params=llParseStringKeepNulls(str, ["|"], []);
            string path=llList2String(params, 0);
            integer page=(integer)llList2String(params, 1);
            string prompt=llList2String(params, 2);
            string additionalButtons=llList2String(params, 3);
            string pluginName=llList2String(params, 4);
            string pluginLocalPath=llList2String(params, 5);
            string pluginStaticParams=llList2String(params, 6);

            if(pluginName==MY_PLUGIN_MENU_CHANGE_SEAT || pluginName==MY_PLUGIN_MENU_UNSIT) {
                //TODO: Leona: check if nested plugins could be a good
                //idea, because both functions are something like a "pick Seat" function
                //and maybe a "pick Seat" dialog may also be useful in other plugins
                //
                //this is the change seat menu. It should stay inside this script, because it uses the isAllowed function and the Slots list. 

                if(num==PLUGIN_ACTION) {
                    // 1) Do the action if needed
                    // 2) correct the path if needed
                    // 3) finish with a PLUGIN_ACTION_DONE call
                    integer remenu=TRUE;
                    if(pluginLocalPath!="") {
                        //a new seat is selected
                        //the button comment contains the slot number
                        integer index=llSubStringIndex(pluginLocalPath, MARKER_COMMENT_END);
                        if(~index) {
                            integer slotNumber=(integer)llGetSubString(pluginLocalPath, 2, index);
                            if(pluginName==MY_PLUGIN_MENU_CHANGE_SEAT) {
                                llMessageLinked(LINK_SET, SWAPTO, (string)(slotNumber+1), id);
                            }
                            else {
                                key avatarToUnsit=llList2Key(Slots, slotNumber*2);
                                llMessageLinked(LINK_SET, UNSIT, avatarToUnsit, id);
                                if(avatarToUnsit==id) {
                                    //don't remenu if someone unsits oneself
                                    remenu=FALSE;
                                }
                            }
                        }
                        path=deleteNode(path, -1, -1);
                    }
                    if(remenu) {
                        llMessageLinked(LINK_SET, PLUGIN_ACTION_DONE, buildParamSet1(path, page, prompt, [additionalButtons], "", "", ""), id);
                    }
                }
                else if(num==PLUGIN_MENU) {
                    // 1) set a prompt if needed
                    // 2) generate your buttons if needed
                    // 3) finish with a PLUGIN_MENU_DONE call
                    if(pluginName==MY_PLUGIN_MENU_CHANGE_SEAT) {
                        prompt="Where will you sit?";
                    }
                    else if(pluginName==MY_PLUGIN_MENU_UNSIT) {
                        prompt="Pick an avatar to unsit.";
                    }
                    //build and show the menu
                    //generate the buttons
                    //A button will be
                    //0) if the menu user sits on the seat: "•" + menu user name + "•"
                    //1) if an avatar sits on the seat: "·" + an avatar name + "·"
                    //2) if the seat name is provided: a seat name
                    //3) else: seatX: where X is a number
                    //We use the "button comment" to store the slotnumber to make it easier to parse the response
                    //prefixing the button names is no longer essentially but we keep it because it looks nice
                    integer length=llGetListLength(Slots);
                    list buttons;
                    integer index;
                    for(; index<length; index+=2) {
                        if(isAllowed(1, id, index/2, pluginStaticParams)) {
                            string currentButtonName=MARKER_COMMENT_START + (string)(index/2) + MARKER_COMMENT_END;
                            key avatar=llList2Key(Slots, index);
                            list temp=llParseStringKeepNulls(llList2String(Slots, index+1), ["§"], []);
                            string seatName=llList2String(temp, 0);
                            string seatNumber=llList2String(temp, 1);
                            if(avatar) {
                                string surroundingCharacter="·";
                                if(avatar==id) {
                                    surroundingCharacter="⚫";
                                }
                                if(OptionUseDisplayNames) {
                                    currentButtonName+=surroundingCharacter + llGetDisplayName(avatar) + surroundingCharacter;
                                }
                                else {
                                    currentButtonName+=surroundingCharacter + llKey2Name(avatar) + surroundingCharacter;
                                }
                            }
                            else if(seatName) {
                                currentButtonName+=seatName;
                            }
                            else {
                                currentButtonName+=seatNumber;
                            }
                            buttons+=[currentButtonName];
                        }
                    }
                    llMessageLinked(LINK_SET, PLUGIN_MENU_DONE, buildParamSet1(path, page, prompt, buttons, "", "", ""), id);
                }
            }
        }
        else if(num == DIALOG_TIMEOUT) {//menu not clicked and dialog timed out
            if(Cur2default && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()) && (DefaultPoseNcName != "")) {
                llMessageLinked(LINK_SET, DOPOSE, DefaultPoseNcName, NULL_KEY);
            }
//begin handle link message inputs
        }
        else if(num==OPTIONS_NUM) {
            //save new option(s) from LINKMSG
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer length = llGetListLength(optionsToSet);
            integer index;
            for(; index<length; ++index) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionSetting = llToLower(llStringTrim(llList2String(optionsItems, 1), STRING_TRIM));
                integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;

                if(optionItem == "permit") {Permissions = optionSetting;}
                else if(optionItem == "2default") {Cur2default = optionSettingFlag;}
                else if(optionItem == "sit2getmenu") {Sit2GetMenu = optionSettingFlag;}
                else if(optionItem == "menudist") {MenuDistance = (float)optionSetting;}
                else if(optionItem == "usedisplaynames") {OptionUseDisplayNames = optionSettingFlag;}
            }
        }
        else if(num == MENU_SHOW) {
            list parts=llParseStringKeepNulls(str, ["|"], []);
            DoMenu(id, llList2String(parts, 0), (integer)llList2String(parts, 1), llList2String(parts, 2), llParseString2List(llList2String(parts, 3), [","], []));
        }
        else if(num == NC_READER_RESPONSE) {
            if(id==ScriptId) {
                BuildMenus(llList2List(llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []), 3, -1));
                str = "";
            }
        }
        else if(num == USER_PERMISSION_UPDATE) {
            // @param str string CSV: permissionName, permissionType, permissionValue[, permissionName, permissionType, permissionValue[, ...]]
            // permissionName: a unique name for a permission. A permission name of the type macro should begin with a @
            // permissionType: bool|list|macro
            // permissionValue:
            //   bool: 0|1
            //   list: a list with Avatar UUIDs (must not contain a ",")
            //   macro: a permission string

            list newPermission=llCSV2List(str);
            integer index;
            integer length=llGetListLength(newPermission);
            for(; index<length; index+=3) {
                string permissionName=llToLower(llList2String(newPermission, index));
                integer permissionIndex=llListFindList(pluginPermissionList, [permissionName]);
                if(~permissionIndex) {
                    pluginPermissionList=llDeleteSubList(pluginPermissionList, permissionIndex, permissionIndex+2);
                }
                pluginPermissionList+=[permissionName] + llList2List(newPermission, index+1, index+2);
            }
        }
        else if(num==SEAT_UPDATE) {
            list slotsList = llParseStringKeepNulls(str, ["^"], []);
            str="";
            Slots = [];
            integer index;
            for(; index<(llGetListLength(slotsList)/8); ++index) {
                Slots += [(key)llList2String(slotsList, index*8+4), llList2String(slotsList, index*8+7)];
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
            ScriptId=llGetInventoryKey(llGetScriptName());
            if(llGetInventoryType(MenuNc) != INVENTORY_NOTECARD) {
                BuildMenus([]);
            }
            else {
                llSleep(1.0); //be sure that the NC reader script finished resetting
                llMessageLinked(LINK_SET, NC_READER_REQUEST, MenuNc, ScriptId);
            }
        }
        if(change & CHANGED_OWNER) {
            llResetScript();
        }
        if(
            (change & CHANGED_LINK) && Cur2default
            && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims())
            && (DefaultPoseNcName != "")
         ) {
            llMessageLinked(LINK_SET, DOPOSE, DefaultPoseNcName, NULL_KEY);
        }
    }

    on_rez(integer params) {
        llResetScript();
    }
}

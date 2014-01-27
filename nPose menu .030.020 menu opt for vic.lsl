/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/

//default options settings.  Change these to suit personal preferences
list Permissions = ["Public"]; //default permit option [Pubic, Locked, Group]
string curmenuonsit = "off"; //default menuonsit option
string cur2default = "off";  //default action to revert back to default pose when last sitter has stood
string Facials = "on";
string menuReqSit = "off";  //required to be seated to get a menu
string RLVenabled = "on";   //default RLV enabled state  on or no
string vicGetsMenu = "off";  //default to allow/disallow victims getting nPose menu

key toucherid;
list avs;
list menus;
list menuPerm = [];
string setprefix = "SET";
string btnprefix = "BTN";
string defaultprefix = "DEFAULT";
list cardprefixes = [setprefix, defaultprefix, btnprefix];
list slotbuttons = [];//list of seat# or seated AV name for change seats menu.

list dialogids;     //3-strided list of dialog ids, the avs they belong to, and the menu path.
integer DIALOG = -900;
integer DIALOG_RESPONSE = -901;
integer DIALOG_TIMEOUT = -902;
integer DOPOSE = 200;
integer ADJUST = 201;
integer SWAP = 202;
integer DUMP = 204;
integer STOPADJUST = 205;
integer SYNC = 206;
integer DOBUTTON = 207;
integer ADJUSTOFFSET = 208;
integer SETOFFSET = 209;
integer SWAPTO = 210;
integer DOMENU = -800; 
integer DOMENU_ACCESSCTRL = -801;
integer memusage = 34334;
integer optionsNum = -240;
string FWDBTN = "forward";
string BKWDBTN = "backward";
string LEFTBTN = "left";
string RIGHTBTN = "right";
string UPBTN = "up";
string DOWNBTN = "down";
string ZEROBTN = "reset";
float currentOffsetDelta = 0.2;
list offsetbuttons = [FWDBTN, LEFTBTN, UPBTN, BKWDBTN, RIGHTBTN, DOWNBTN, "0.2", "0.1", "0.05", "0.01", ZEROBTN];
string defaultPose;//holds the name of the default notecard.
string cmdname;
integer curseatednumber = 0;

//dialog button responses
string SLOTBTN = "ChangeSeat";
string SYNCBTN = "sync";
string OFFSETBTN = "offset";
string BACKBTN = "^";
string ROOTMENU = "Main";
string ADMINBTN = "admin";
string ManageRLV = "ManageRLV";
string ADJUSTBTN = "Adjust";
string STOPADJUSTBTN = "StopAdjust";
string POSDUMPBTN = "PosDump";
string UNSITBTN = "Unsit";
string OPTIONS = "Options";
string MENUONSIT = "Menuonsit";
string TODEFUALT = "ToDefault";
string PERMITBTN = "Permit";
string PUBLIC = "Public";
string LOCKED = "Locked";
string GROUP = "Group";
list victims;
list adminbuttons = [ADJUSTBTN, STOPADJUSTBTN, POSDUMPBTN, UNSITBTN, OPTIONS];
//list options = [PERMITBTN, MENUONSIT, "sit2GetMenu", TODEFUALT, "FacialExp"];//remove the options from this list you don't want to show
list options = [];
string path;

key Dialog(key rcpt, string prompt, list choices, list utilitybuttons, integer page){
    key id = "";
    if (toucherid != llGetOwner() && (menuReqSit == "off")){
        integer stopc = llGetListLength(choices);
        integer nc;
        for (nc = 0; nc < stopc; ++nc){
            integer indexc = llListFindList(menuPerm, [llList2String(choices, nc)]);
            if (indexc != -1){
                if (llList2String(menuPerm, indexc+1) == "owner"){
                    choices = llDeleteSubList(choices, nc, nc);
                    nc--;
                    stopc--;
                }else if (llList2String(menuPerm, indexc+1) != "public"){
                    if (llList2String(menuPerm, indexc+1) == "group"){
                        if (llSameGroup(toucherid)!=1){
                            choices = llDeleteSubList(choices, nc, nc);
                            nc--;
                            stopc--;
                        }
                    }
                }
            }
        }
        id = llHTTPRequest("http://google.com", [HTTP_METHOD, "GET"], "");
        llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + 
            "|" + llDumpList2String(utilitybuttons, "`"), id);
    }else  if (((toucherid == llGetOwner()) || (menuReqSit == "off")) || (toucherid != llGetOwner() 
     && menuReqSit == "on" && llListFindList(SeatedAvs(), [(key)toucherid]) != -1)){
        id = llHTTPRequest("http://google.com", [HTTP_METHOD, "GET"], "");
        llMessageLinked(LINK_SET, DIALOG, (string)rcpt + "|" + prompt + "|" + (string)page + "|" + llDumpList2String(choices, "`") + 
            "|" + llDumpList2String(utilitybuttons, "`"), id);
    }
    return id;
}

list SeatedAvs(){ //returns the list of uuid's of seated AVs
    avs=[];
    integer counter = llGetNumberOfPrims();
    while (llGetAgentSize(llGetLinkKey(counter)) != ZERO_VECTOR){
        avs += [llGetLinkKey(counter)];
        counter--;
    }    
    return avs;
}

AdjustOffsetDirection(key id, vector direction) {
    vector delta = direction * currentOffsetDelta;
    llMessageLinked(LINK_SET, ADJUSTOFFSET, (string)delta, id);
}    

integer AvCount(){ //same as SeatedAvs except doesn't return the list of keys, just the count
    integer stop = llGetNumberOfPrims();
    integer n = stop;
    while (llGetAgentSize(llGetLinkKey(n)) != ZERO_VECTOR){
        n--;
    }
    return stop - n;
}

AdminMenu(key toucher, string path, string prompt, list buttons){
    key id = Dialog(toucher, prompt+"\n"+path+"\n", buttons, [BACKBTN], 0);
    integer index = llListFindList(dialogids, [toucher]);
    list addme = [id, toucher, path];
    if (index == -1){
        dialogids += addme;
    } else{
        dialogids = llListReplaceList(dialogids, addme, index - 1, index + 1);        
    }
}

DoMenu(key toucher, string path, string menuPrompt, integer page){//builds the final menu for authorized
    integer index = llListFindList(menus, [path]);
    if (index != -1){
        list buttons = llListSort(llParseStringKeepNulls(llList2String(menus, index + 1), ["|"], []), 1, 1);
        list utility = [];
        if (path != ROOTMENU){
            utility += [BACKBTN];
        }
        key id = Dialog(toucher, menuPrompt + "\n"+path+"\n", buttons, utility, page);    
        list addme = [id, toucher, path];
        index = llListFindList(dialogids, [toucher]);
        if (index == -1){
            dialogids += addme;
        }else{
            dialogids = llListReplaceList(dialogids, addme, index - 1, index + 1);        
        }        
    }
}

DoMenu_AccessCtrl(key toucher, string path, string menuPrompt, integer page){//checks and enforces who has access to the menu.
    integer authorized = FALSE;
    if (toucher == llGetOwner()){
        if ((llListFindList(victims, [(string)llGetOwner()]) != -1 && vicGetsMenu == "on") || llListFindList(victims, [(string)llGetOwner()]) == -1){
            //owner always gets authorized if not a victim, or if they are a victim and vicGetsMenu option is turned on
            authorized = TRUE;
        }
    }else if (((llList2String(Permissions, 0) == GROUP) && (llSameGroup(toucher))) || (llList2String(Permissions, 0) == PUBLIC)){
        if (llListFindList(victims, [(string)toucher]) == -1 && vicGetsMenu == "on"){ 
        //returns '-1' if not found in victims list and option is turned off.. if found, do not authorize
            authorized = TRUE;
        }
    }
    if (authorized){
        DoMenu(toucher, path, menuPrompt, page);
    }
}

BuildMenus(){//builds the user defined menu buttons
    menus = [];
    menuPerm = [];
    integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
    integer defaultSet = FALSE;
    integer n;
    for (n = 0; n<stop; ++n){//step through the notecards backwards so that default notecard is first in the contents
        string name = llGetInventoryName(INVENTORY_NOTECARD, n);
        integer permsIndex1 = llSubStringIndex(name,"{");
        integer permsIndex2 = llSubStringIndex(name,"}");
        string menuPerms = "";
        if (permsIndex1 != -1){
            menuPerms = llToLower(llGetSubString(name, permsIndex1+1, permsIndex2-1));
            name = llDeleteSubString(name, permsIndex1, permsIndex2);
        }else{
            menuPerms = "public";
        }
        list pathParts = llParseStringKeepNulls(name, [":"], []);
        menuPerm += [llList2String(pathParts, -1), menuPerms];
        string prefix = llList2String(pathParts, 0);
        if (!defaultSet && ((prefix == setprefix) || (prefix == defaultprefix))){
            defaultPose = llGetInventoryName(INVENTORY_NOTECARD,n);
            defaultSet = TRUE;
        }
        if (llListFindList(cardprefixes, [prefix]) != -1){
            pathParts = llDeleteSubList(pathParts, 0, 0);            
            while(llGetListLength(pathParts)){
                string last = llList2String(pathParts, -1);
                string parentpath = llDumpList2String([ROOTMENU] + llDeleteSubList(pathParts, -1, -1), ":");
                integer index = llListFindList(menus, [parentpath]);
                if (index != -1 && !(index % 2)){
                    list children = llParseStringKeepNulls(llList2String(menus, index + 1), ["|"], []);
                    if (llListFindList(children, [last]) == -1){
                        children += [last];
                        menus = llListReplaceList((menus = []) + menus, [llDumpList2String(children, "|")], index + 1, index + 1);
                    }
                }else{
                    menus += [parentpath, last];
                }
                pathParts = llDeleteSubList(pathParts, -1, -1);
            }
        }
    }
}

default{
    state_entry(){
        cmdname = (string)llGetKey();//don't really know why the relay uses this name param, but at least this ensures uniqueness for rlv
        BuildMenus();
    }

    touch_start(integer total_number){
        toucherid = llDetectedKey(0);
        DoMenu_AccessCtrl(toucherid,ROOTMENU, "",0);
    }
    
    link_message(integer sender, integer num, string str, key id){
        if (num == DIALOG_RESPONSE){ //response from menu
            integer index = llListFindList(dialogids, [id]); //find the id in dialogids
            if (index != -1){ //we found the toucher in dialogids
                list params = llParseString2List(str, ["|"], []);  //parse the message
                integer page = (integer)llList2String(params, 0);  //get the page number
                string selection = llList2String(params, 1);  //get the button that was pressed from str
                path = llList2String(dialogids, index + 2); //get the path from dialogids
                toucherid = llList2Key(dialogids, index + 1);
                if (selection == BACKBTN){
                    //handle the back button. admin menu gets handled differently cause buttons are custom
                    list pathparts = llParseString2List(path, [":"], []);
                    pathparts = llDeleteSubList(pathparts, -1, -1);
                    if (llList2String(pathparts, -1) == ADMINBTN){
                       AdminMenu(toucherid, llDumpList2String(pathparts, ":"), "", adminbuttons);
/*                    }else if (llList2String(pathparts, -1) == OPTIONS){
                        string optionsPrompt =  "Permit currently set to "+ llList2String(Permissions, 0)
                         + "\nMenuOnSit currently set to "+ curmenuonsit + "\nsit2GetMenu currently set to " + menuReqSit 
                         + "\n2default currently set to "+ cur2default + "\nFacialEnable currently set to "+ Facials;
                           AdminMenu(toucherid, llDumpList2String(pathparts, ":"), optionsPrompt, options);*/
                    }else if (llGetListLength(pathparts) <= 1){
                        DoMenu(toucherid, ROOTMENU, "", 0);
                    }else{
                        DoMenu(toucherid, llDumpList2String(pathparts, ":"), "", 0);
                    }
                }else if (selection == ADMINBTN){
                    path += ":" + selection;
                    AdminMenu(toucherid, path, "", adminbuttons);
                }else if (selection == SLOTBTN){
                    //someone wants to change sit positionss.
                    //taking a place where someone already has that slot should do the swap regardless of how many 
                    //places are open
                    path = path + ":" + selection;
                    AdminMenu(toucherid, path,  "Where will you sit?", slotbuttons);
                }else if (selection == OFFSETBTN){
                    //give offset menu
                    path = path + ":" + selection;
                    AdminMenu(toucherid, path,   "Adjust by " + (string)currentOffsetDelta
                     + "m, or choose another distance.", offsetbuttons);
                }else if (selection == ADJUSTBTN){
                    llMessageLinked(LINK_SET, ADJUST, "", "");
                    AdminMenu(toucherid, path, "", adminbuttons);
                }else if (selection == STOPADJUSTBTN){
                    llMessageLinked(LINK_SET, STOPADJUST, "", "");
                    AdminMenu(toucherid, path, "", adminbuttons);
                }else if (selection == POSDUMPBTN){
                    llMessageLinked(LINK_SET, DUMP, "", "");
                    AdminMenu(toucherid, path, "", adminbuttons);
                }else if (selection == UNSITBTN){
                    
                    avs = SeatedAvs();
                    list buttons;
                    integer stop = llGetListLength(avs);
                    integer n;
                    for (n = 0; n < stop; n++){
                        buttons += [llGetSubString(llKey2Name((key)llList2String(avs, n)), 0, 20)];
                    }
                    if (llGetListLength(buttons) > 0){
                        path += ":" + selection;
                        AdminMenu(toucherid, path, "Pick an avatar to unsit", buttons);
                    }else{
                        AdminMenu(toucherid, path, "", adminbuttons);
                    }
                }else if (selection == OPTIONS){
                    path += ":" + selection;
                    string optionsPrompt =  "Permit currently set to "+ llList2String(Permissions, 0)
                     + "\nMenuOnSit currently set to "+ curmenuonsit + "\nsit2GetMenu currently set to " + menuReqSit 
                     + "\n2default currently set to "+ cur2default + "\nFacialEnable currently set to "+ Facials
                    + "\nUseRLVBaseRestrict currently set to "+ RLVenabled;
                    AdminMenu(toucherid, path, optionsPrompt, options);
                }else if (~llListFindList(menus, [path + ":" + selection])){
                    path = path + ":" + selection;
                    DoMenu(toucherid, path, "", 0);
/*                }else if (selection == PERMITBTN){
                    //don't add selection to path here so back button will work as we want
                    AdminMenu(toucherid, path + ":" + selection, "\nCurrently set to "
                     + llList2String(Permissions, 0), [PUBLIC, LOCKED, GROUP]);
                }else if (selection == MENUONSIT){
                    //don't add selection to path here so back button will work as we want
                    AdminMenu(toucherid, path + ":" + selection, "\nCurrently set to "+ curmenuonsit, ["on", "off"]);
                }else if (selection == TODEFUALT){
                    //don't add selection to path here so back button will work as we want
                    AdminMenu(toucherid, path + ":" + selection, "\nCurrently set to "+ cur2default, ["on", "off"]);
                }else if (selection == "FacialExp"){
                    //don't add selection to path here so back button will work as we want
                    AdminMenu(toucherid, path + ":" + selection, "\nCurrently set to "+ Facials, ["on", "off"]);
                }else if (selection == "sit2GetMenu"){
                    //don't add selection to path here so back button will work as we want
                    AdminMenu(toucherid, path + ":" + selection, "\nCurrently set to "+ menuReqSit, ["on", "off"]);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == PERMITBTN){
                    Permissions = [selection];
                    AdminMenu(toucherid, path, "\nCurrently set to "+ llList2String(Permissions, 0), [PUBLIC, LOCKED, GROUP]);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == "FacialExp"){
                    Facials = selection;
                    llMessageLinked(LINK_SET, -241, Facials, NULL_KEY);
                    AdminMenu(toucherid, path, "\nCurrently set to "+ Facials, ["on", "off"]);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == "sit2GetMenu"){
                    menuReqSit = selection;
                    llMessageLinked(LINK_SET, -241, Facials, NULL_KEY);
                    AdminMenu(toucherid, path, "\nCurrently set to "+ menuReqSit, ["on", "off"]);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == MENUONSIT){
                    curmenuonsit = selection;
                    AdminMenu(toucherid, path, "\nCurrently set to " + curmenuonsit, ["on", "off"]);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == TODEFUALT){
                    if ((cur2default == "off") && (selection == "on") && (AvCount()<=0)){
                        cur2default = selection;
                        llMessageLinked(LINK_SET, DOPOSE, defaultPose, NULL_KEY);
                        AdminMenu(toucherid, path, "\nCurrently set to " + cur2default, ["on", "off"]);
                    }else{
                        cur2default = selection;
                        AdminMenu(toucherid, path, "\nCurrently set to " + cur2default, ["on", "off"]);
                    }*/
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == SLOTBTN){//change seats
                    if (llGetSubString(selection, 0,3)=="seat"){ //clicker selected an open seat where menu is 'seat'+#
                        integer slot = (integer)llGetSubString(selection, 4,-1);
                         if (slot >= 0) {
                            llMessageLinked(LINK_SET, SWAPTO, (string)(slot), toucherid);
                        }
                    }else{ //clicker selected a name so get seat# from list
                        integer slot = llListFindList(slotbuttons, [selection])+1;
                        if (slot >= 0) {
                            llMessageLinked(LINK_SET, SWAPTO, (string)(slot), toucherid);
                        }
                    }
                    list pathparts = llParseString2List(path, [":"], []);
                    pathparts = llDeleteSubList(pathparts, -1, -1);
                    path = llDumpList2String(pathparts, ":");
                    DoMenu(toucherid, path,  "", 0);
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == UNSITBTN){
                    integer stop = llGetListLength(avs);
                    integer n;
                    for (n = 0; n < stop; n++){
                        key av = llList2Key(avs, n);
                        if (llGetSubString(llKey2Name(av), 0, 20) == selection){
                            if (llListFindList(SeatedAvs(), [av]) != -1){ //just make sure the av is seated before doing this unsit
                                //letting the slave script do the unsit function so link message out the command to unsit
                                llMessageLinked(LINK_SET, -222, (string)av, NULL_KEY);
                                integer avIndex = llListFindList(avs, [av]);
                                avs = llDeleteSubList(avs, index, index);
                                n = stop;
                            }
                        }
                    }
                    list buttons = [];
                    stop = llGetListLength(avs);
                    for (n = 0; n < stop; n++){
                        buttons += [llGetSubString(llKey2Name((key)llList2String(avs, n)), 0, 20)];
                    }
                    if (llGetListLength(buttons) > 0){
                        AdminMenu(toucherid, path, "Pick an avatar to unsit", buttons);
                    }else{
                        list pathParts = llParseString2List(path, [":"], []);
                        pathParts = llDeleteSubList(pathParts, -1, -1);
                        AdminMenu(toucherid, llDumpList2String(pathParts, ":"), "", adminbuttons);
                    }
                }else if (llList2String(llParseString2List(path, [":"], []), -1) == OFFSETBTN){
                         if (selection ==   FWDBTN) AdjustOffsetDirection(toucherid,  (vector)<1.0, 0.0, 0.0>);
                    else if (selection ==  BKWDBTN) AdjustOffsetDirection(toucherid,  (vector)(-<1.0, 0.0, 0.0>));
                    else if (selection ==  LEFTBTN) AdjustOffsetDirection(toucherid,  (vector)<0.0, 1.0, 0.0>);
                    else if (selection == RIGHTBTN) AdjustOffsetDirection(toucherid,  (vector)(-<0.0, 1.0, 0.0>));
                    else if (selection ==    UPBTN) AdjustOffsetDirection(toucherid,  (vector)<0.0, 0.0, 1.0>);
                    else if (selection ==  DOWNBTN) AdjustOffsetDirection(toucherid,  (vector)(-<0.0, 0.0, 1.0>));
                    else if (selection ==  ZEROBTN) llMessageLinked(LINK_SET, SETOFFSET, (string)ZERO_VECTOR, toucherid);
                    else currentOffsetDelta = (float)selection;
                    AdminMenu(toucherid, path,  "Adjust by " + (string)currentOffsetDelta
                     + "m, or choose another distance.", offsetbuttons);
                }else if (selection == SYNCBTN){
                    llMessageLinked(LINK_SET, SYNC, "", "");
                    DoMenu(toucherid, path, "", page);                    
                }else{
                    list pathlist = llDeleteSubList(llParseStringKeepNulls(path, [":"], []), 0, 0);
                    integer permission = llListFindList(menuPerm, [selection]);
                    string defaultname = llDumpList2String([defaultprefix] + pathlist + [selection], ":");                
                    string setname = llDumpList2String([setprefix] + pathlist + [selection], ":");
                    string btnname = llDumpList2String([btnprefix] + pathlist + [selection], ":");
                    //correct the notecard name so the core can find this notecard
                    if (permission != -1){
                        if (llList2String(menuPerm, permission+1) != "public"){
                            defaultname += "{"+llList2String(menuPerm, permission+1)+"}";
                            setname += "{"+llList2String(menuPerm, permission+1)+"}";
                            btnname += "{"+llList2String(menuPerm, permission+1)+"}";
                        }
                    }
                    if (llGetInventoryType(defaultname) == INVENTORY_NOTECARD){
                        llMessageLinked(LINK_SET, DOPOSE, defaultname, toucherid);                    
                    }else if (llGetInventoryType(setname) == INVENTORY_NOTECARD){
                        llMessageLinked(LINK_SET, DOPOSE, setname, toucherid);
                    }else if (llGetInventoryType(btnname) == INVENTORY_NOTECARD){
                        llMessageLinked(LINK_SET, DOBUTTON, btnname, toucherid);
                    }
                    if (llGetSubString(selection,-1,-1) == "-"){//don't remenu
                        llMessageLinked(LINK_SET, -802, path, toucherid);
                    }else{
                        DoMenu(toucherid, path, "", page);
                    }
                }
            }
        }else if (num == DIALOG_TIMEOUT){//menu not clicked and dialog timed out
            integer index = llListFindList(dialogids, [id]);
            if (index != -1){
                dialogids = llDeleteSubList(dialogids, index, index + 2);
            }
            if (cur2default == "on" && llGetListLength(SeatedAvs()) < 1){
                llMessageLinked(LINK_SET, DOPOSE, defaultPose, NULL_KEY);
            }
        }else if (num==optionsNum){
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer stop = llGetListLength(optionsToSet);
            integer n;
            for (n=0; n<stop; ++n){
                list optionsItems = llParseString2List(llList2String(optionsToSet, n), ["="], []);
                string optionItem = llList2String(optionsItems, 0);
                string optionSetting = llList2String(optionsItems, 1);
                if (optionItem == "menuonsit") {curmenuonsit = optionSetting;}
                else if (optionItem == "permit") {Permissions = [optionSetting];}
                else if (optionItem == "2default") {cur2default = optionSetting;}
                else if (optionItem == "sit2getmenu") {menuReqSit = optionSetting;}
                else if (optionItem == "vicgetsmenu") {vicGetsMenu = optionSetting;}
                else if (optionItem == "facialExp"){
                    Facials = optionSetting;
                    llMessageLinked(LINK_SET, -241, Facials, NULL_KEY);
                }else if (optionItem == "rlvbaser"){
                    RLVenabled = optionSetting;
                    llMessageLinked(LINK_SET, -1812221819, "RLV=" + RLVenabled, NULL_KEY);
                }
            }
        }else if (num == -888 && str == ADMINBTN){
            path += ":" + str;
            AdminMenu(toucherid, path, "", adminbuttons);
        }else if (num == -888 && str == SLOTBTN){
            //someone wants to change sit positionss.
            //taking a place where someone already has that slot should do the swap regardless of how many 
            //places are open
            path = path + ":" + str;
            AdminMenu(toucherid, path,  "Where will you sit?", slotbuttons);
        }else if (num == -888 && str == OFFSETBTN){
            //give offset menu
            path = path + ":" + str;
            AdminMenu(toucherid, path,   "Adjust by " + (string)currentOffsetDelta
             + "m, or choose another distance.", offsetbuttons);
        }else if (num == -888 && str == SYNCBTN){
            llMessageLinked(LINK_SET, SYNC, "", "");
            DoMenu(toucherid, path, "", 0);                    
        }else if (num == DOMENU){
            toucherid = id;
            DoMenu(toucherid, str, "", 0);
        }else if (num == DOMENU_ACCESSCTRL){//external call to check permissions
            toucherid = id;
            DoMenu_AccessCtrl(toucherid, ROOTMENU, "", 0);
        }else if(num == -238){
            victims = llCSV2List(str);
        }else if (num==35354){
            slotbuttons = llParseString2List(str, [","], []);
        }else if (num == memusage){//dump memory stats to local
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }

    changed(integer change){
        if (change & CHANGED_INVENTORY){
            BuildMenus();           
        }
        if (change & CHANGED_OWNER){
            llResetScript();
        }
        // check on the options and act accordingly on av count change
        avs = SeatedAvs();
        if ((change & CHANGED_LINK) && (AvCount()>0)){ //we have a sitter
            if (curmenuonsit == "on"){
                integer lastSeatedAV = llGetListLength(avs);  //get current number of AVs seated
                if (lastSeatedAV > curseatednumber){  //we are in changed event so find out if 
                //it is a new sitter that brought us here
                    key id = llList2Key(avs,lastSeatedAV-curseatednumber-1);  //if so, get key of last sitter 
                    curseatednumber = lastSeatedAV;  //update our number of sitters
                    if (llListFindList(victims, [id])==-1){ //check if new sitter is a victim
                        DoMenu_AccessCtrl(id, ROOTMENU, "", 0);  //if not a victim, give menu
                    }
                }
            }
            curseatednumber=llGetListLength(avs);
        }else if ((change & CHANGED_LINK) && (cur2default == "on")){ //av count is 0 (we lost all sitters)
            llMessageLinked(LINK_SET, DOPOSE, defaultPose, NULL_KEY);
            curseatednumber=0;
        }
    }
    on_rez(integer params){
        llResetScript();
    }
}
/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/
//started as an adaptation of Schmobag Hogfather's SchmoDialog script

integer DIALOG = -900;
integer DIALOG_RESPONSE = -901;
integer DIALOG_TIMEOUT = -902;
integer OPTIONS = -240;
integer MACRO = -807;

integer PAGE_SIZE = 12;
integer MEMORY_USAGE = 34334;
string PAGE_FORWARD = "▶";
string PAGE_BACKWARD = "◀";
string PAGE_FORWARD_LAST_PAGE = "▷";
string PAGE_BACKWARD_FIRST_PAGE = "◁";
string BACK_BUTTON_DISPLAY="▲";
string BACK_BUTTON_REPORT="^";
string BLANK=" ";
string SEPARATOR="`";
integer REPEAT = 10;//how often the timer will go off, in seconds
integer Channel;
integer Listener = -1;

list Menus;
//9-strided list in form [recipient, caller id, starttime, prompt, menu buttons, utility buttons, page, path, lookupTable]
//where "menu buttons" means the big list of choices presented to the user
//and "utility buttons" means buttons that will appear on every page, such as one saying "go up one level"
//and "page" is an integer meaning which page of the menu the user is currently viewing
integer MENUS_PARAM_RECIPTIENT=0;
integer MENUS_PARAM_CALLER_ID=1;
integer MENUS_PARAM_TIMEOUTTIME=2;
integer MENUS_PARAM_PROMPT=3;
integer MENUS_PARAM_MENU_BUTTONS=4;
integer MENUS_PARAM_UTILITY_BUTTONS=5;
integer MENUS_PARAM_PAGE=6;
integer MENUS_PARAM_PATH=7;
integer MENUS_PARAM_LOOKUP_TABLE=8;
integer MENUS_STRIDE=9;

list Avs;//fill this on start and update on changed_link.  leave dialogs open until avs stand

list MacroNames;
list MacroValues;

list ZERO_WIDTH_UTF_CHARACTERS_BASE64=[
    "4oCL", // U+200b, ZERO WIDTH SPACE
    "4oCM", // U+200c, ZERO WIDTH NON-JOINER
    "4oCN", // U+200d, ZERO WIDTH JOINER
    "4oCO", // U+200e, LEFT-TO-RIGHT MARK,
    "4oCP", // U+200f, RIGHT-TO-LEFT MARK
    "4oCq", // U+202a, LEFT-TO-RIGHT
    "4oCr", // U+202b, RIGHT-TO-LEFT
    "4oCs", // U+202c, POP DIRECTIONAL
    "4oCt", // U+202d, LEFT-TO-RIGHT OVERRIDE
    "4oCu", // U+202e, RIGHT-TO-LEFT OVERRIDE
    "4oGg", // U+2060, WORD JOINER,
    "4oGh", // U+2061, FUNCTION APPLICATION
    "4oGi", // U+2062, INVISIBLE TIMES
    "4oGj", // U+2063, INVISIBLE SEPARATOR
    "4oGk" // U+2064, INVISIBLE PLUS
];
list CodingCharacterSet;
integer CodingBase;

string MARKER_COMMENT_START="/*";
string MARKER_COMMENT_END="*/";
string MARKER_BASE64_START="/$";
string MARKER_BASE64_END="$/";
string MARKER_MACRO_START="/@";
string MARKER_MACRO_END="@/";

string TemplateDialogPrompt="%PROMPT%\nPath: %NICE_PATH%\nPage: %CURRENT_PAGE%/%TOTAL_PAGES%%DIALOG_TIMEOUT_TEXT%";
string TemplateDialogTimeoutText="\n(Timeout in %TIMEOUT% seconds.)";
integer OptionDialogTimeout=120;
integer OptionUsePageBackward=FALSE;

/*
debug(list message){
    llOwnerSay((((llGetScriptName() + "\n##########\n#>") + llDumpList2String(message,"\n#>")) + "\n##########"));
}
*/

string integer2Invisible(integer num) {
    //converts an integer into a string with invisible (zero width) characters
    string str;
    do {
        str=llList2String(CodingCharacterSet, num%CodingBase)+str;
        num=num/CodingBase;
    } while(num);
    return str;
}
integer invisible2Integer(string str) {
    //converts the leading invisible characters of a string back to an integer
    integer num;
    integer currentFigure;
    do {
        num=num * CodingBase + currentFigure;
        string character=llGetSubString(str, 0, 0);
        str=llDeleteSubString(str, 0,0);
        currentFigure=llListFindList(CodingCharacterSet, [character]);
    } while (~currentFigure);
    return num;
}

string Utf8Trim(string s, integer iLen) {
    // This trims a string to iLen bytes interpreted as utf8 (not utf16).
    // The string returned will be utf16, but when interpreted as utf8,
    // it will be iLen bytes (not characters) or shorter.  Also, because
    // of the use of base64, it's best if iLen is a multiple of 3.  If
    // it's not, it will be rounded down to a multiple of 3 if trimming
    // is needed.  If trimming isn't needed, it will be unchanged regardless
    // of original length.
    string s2 = llStringToBase64(s);
    iLen = (iLen / 3) * 4; // This winds up being a multiple of 4, rounded down.
    if (llStringLength(s2) > iLen) {
        return llBase64ToString(llGetSubString(s2, 0, --iLen));
    }
    return s;
}

list SeatedAvs() {
    //like AvCount() but returns a list of seated avs, starting with lowest link number and moving up from there
    list avs;
    integer linkcount = llGetNumberOfPrims();
    integer n;
    for (n = linkcount; n >= 0; n--) {
        key id = llGetLinkKey(n);
        if (llGetAgentSize(id) != ZERO_VECTOR) {
            //it's a real av. add to list
            avs = [id] + avs;//adding it this way prevents having to reverse the av list later
        }
        else {
            //we've gotten down to a regular prim.  Break loop and return list
            return avs;
        }
    }
    //there must not have been anyone seated.  Shouldn't ever get here but LSL doesn't know that and wants a return value
    return [];
}

integer RandomUniqueChannel() {
    integer out = llRound(llFrand(10000000)) + 100000;
    if (out == Channel) {
        out = RandomUniqueChannel();
    }
    return out;
}

Dialog(key recipient, string prompt, list menuButtons, list utilityButtons, integer page, key id, string path, string lookupTable) {
    //menuButtons and utilityButtons ready to insert
    //the promt has to be sanitized
    
    integer backButtonNeeded;
    if(~llSubStringIndex(path, ":")) {
        backButtonNeeded=TRUE;
    }
    
    //correct page size
    integer numberOfMenuButtons=llGetListLength(menuButtons);
    integer myPageSize=PAGE_SIZE - llGetListLength(utilityButtons) - backButtonNeeded;
    integer pageSizeExceeded=numberOfMenuButtons>myPageSize;
    myPageSize = myPageSize - pageSizeExceeded - (pageSizeExceeded && OptionUsePageBackward);
    integer numberOfPages=llCeil((float)numberOfMenuButtons/(float)myPageSize);
    if(!numberOfPages) {
        numberOfPages=1;
    }

    //correct page if out of bounds
    while(page<0) {
        page=numberOfPages+page;
    }
    page=page%numberOfPages;
    
    list currentUtilityButtons=utilityButtons;
    //add back button
    if(backButtonNeeded) {
        currentUtilityButtons+=[BACK_BUTTON_DISPLAY];
    }
    //add page backward button
    if(pageSizeExceeded && OptionUsePageBackward) {
        if(page) {
            currentUtilityButtons+=[PAGE_BACKWARD];
        }
        else {
            currentUtilityButtons+=[PAGE_BACKWARD_FIRST_PAGE];
        }
    }
    //add page forward button
    if(pageSizeExceeded) {
        if(page<numberOfPages-1) {
            currentUtilityButtons+=[PAGE_FORWARD];
        }
        else {
            currentUtilityButtons+=[PAGE_FORWARD_LAST_PAGE];
        }
    }
    
    //build and sanitize promt
    string dialogPrompt=TemplateDialogPrompt;
    integer flagRecipientSitting=~llListFindList(Avs, [recipient]);
    if(flagRecipientSitting) {
        dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%DIALOG_TIMEOUT_TEXT%"], []), "");
    }
    else {
        dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%DIALOG_TIMEOUT_TEXT%"], []), resolveText(TemplateDialogTimeoutText));
    }
    if(prompt) {
        dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%PROMPT%"], []), "\n" + resolveText(prompt) + "\n");
    }
    else {
        dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%PROMPT%"], []), "");
    }
    dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%PATH%"], []), path);
    dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%NICE_PATH%"], []), resolveText(path));
    dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%CURRENT_PAGE%"], []), (string)(page+1));
    dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%TOTAL_PAGES%"], []), (string)numberOfPages);
    dialogPrompt=llDumpList2String(llParseStringKeepNulls(dialogPrompt, ["%TIMEOUT%"], []), (string)OptionDialogTimeout);
    dialogPrompt=Utf8Trim(dialogPrompt, 511);
    if(dialogPrompt=="") {
        dialogPrompt="\n";
    }
    
    //slice the menuButtons by page
    list currentMenuButtons=llList2List(menuButtons, page * myPageSize, (page + 1) * myPageSize - 1);

    //open the listener if neccesary
    if(!~Listener) {
        Listener = llListen(Channel, "", NULL_KEY, "");
        llSetTimerEvent(REPEAT);
    }
    
    //open the dialog
    llDialog(recipient, dialogPrompt, sortButtonsForDialog(currentMenuButtons, currentUtilityButtons), Channel);

    //remove old entrys from the Menus list
    integer index = llListFindList(Menus, [recipient]);
    if(~index) {
        Menus = RemoveMenuStride(Menus, index);
    }

    //generate a new Menus list entry
    Menus += [
        recipient,
        id,
        llGetUnixTime() + OptionDialogTimeout,
        prompt,
        llDumpList2String(menuButtons, SEPARATOR),
        llDumpList2String(utilityButtons, SEPARATOR),
        page,
        path,
        lookupTable
    ];
}

/*
list SanitizeButtons(list in) {
    integer length = llGetListLength(in);
    integer n;
    for (n = length - 1; n >= 0; n--) {
        //trim it to avoid shouting on Debug Channel
        string currentButton=Utf8Trim(llList2String(in, n), 24);
        if(currentButton) {
            in = llListReplaceList(in, [currentButton], n, n);
        }
        else {
            in = llDeleteSubList(in, n, n);
        }
    }
    return in;
}
*/

list sanitizeButtons(string buttons, string lookupTable) {
    //returns a list with 2 strings
    // - the sanitized button names concentrated into a string
    // - the modified lookupTable
    list buttonsList=llParseString2List(buttons, [SEPARATOR], []);
    list sanitizedButtonsList;
    integer index;
    integer length=llGetListLength(buttonsList);
    for(; index<length; index++) {
        string currentButton=llList2String(buttonsList, index);
        if(currentButton!="") {
            list temp=sanitizeButton(currentButton, lookupTable);
            sanitizedButtonsList+=llList2String(temp, 0);
            lookupTable=llList2String(temp, 1);
        }
    }
    return [llDumpList2String(sanitizedButtonsList, SEPARATOR), lookupTable];
}

list sanitizeButton(string button, string lookupTable) {
    //returns a list with 2 strings
    // - the button name ready for use in the dialog
    // - the modified lookupTable
    string niceButton=Utf8Trim(resolveText(button), 24);
    if(button==niceButton) {
        //nothing to do
        return [button, lookupTable];
    }
    else if(niceButton=="") {
        //the resolved button name is empty -> generate a BLANK button which should be handled by the dialog script
        return [BLANK, lookupTable];
    }
    else {
        //store the original Button text in the lookup table
        //prefix the nice Button text with the current index of the lookup table and trim it again
        list lookupTableList=llParseStringKeepNulls(lookupTable, [SEPARATOR], []);
        integer nextIndex=llGetListLength(lookupTableList);
        niceButton=Utf8Trim(integer2Invisible(nextIndex) + niceButton, 24);
        return [niceButton, llDumpList2String(lookupTableList + [button], SEPARATOR)];
    }
}

string resolveText(string text) {
    //this function removes comments /*thisIsAComment*/
    //replaces the base64 coded text /$thisIsABase64EncodedText$/
    //and inserts the macros recursiv /@thisIsAMacro@/
    //from a text
    //don't support nesting.
    list tempList=llParseStringKeepNulls(text, [], [MARKER_COMMENT_START, MARKER_COMMENT_END, MARKER_BASE64_START, MARKER_BASE64_END, MARKER_MACRO_START, MARKER_MACRO_END]);
    integer index;
    integer length=llGetListLength(tempList);
    integer remove;
    integer decode;
    integer macro;
    text="";
    for(; index<length; index++) {
        string tempString=llList2String(tempList, index);
        if(tempString==MARKER_COMMENT_START) {
            remove=TRUE;
        }
        else if(tempString==MARKER_COMMENT_END) {
            remove=FALSE;
        }
        else if(tempString==MARKER_BASE64_START) {
            decode=TRUE;
        }
        else if(tempString==MARKER_BASE64_END) {
            decode=FALSE;
        }
        else if(tempString==MARKER_MACRO_START) {
            macro=TRUE;
        }
        else if(tempString==MARKER_MACRO_END) {
            macro=FALSE;
        }
        else {
            if(!remove) {
                if(decode && !macro) {
                    text+=llBase64ToString(tempString);
                }
                else if(!decode && macro) {
                    integer macroIndex=llListFindList(MacroNames, [llToLower(tempString)]);
                    if(~macroIndex) {
                        text+=resolveText(llList2String(MacroValues, macroIndex));
                    }
                }
                else if(!decode && !macro) {
                    text+=tempString;
                }
            }
        }

    }
    return text;
}

string buttonLookup(string dialogAnswer, string lookupTable) {
    if(!~llListFindList(CodingCharacterSet, [llGetSubString(dialogAnswer, 0, 0)])) {
        return dialogAnswer;
    }
    list lookupTableList=llParseStringKeepNulls(lookupTable, [SEPARATOR], []);
    return llList2String(lookupTableList, invisible2Integer(dialogAnswer));
}

list sortButtonsForDialog(list menuButtons, list utilityButtons) {
    //returns a list formatted to that "menuButtons" will start in the top left of a dialog, and "utilityButtons" will start in the bottom right
    list spacers;
    list combined = menuButtons + utilityButtons;
    while (llGetListLength(combined) % 3) {
        spacers += [BLANK];
        combined = menuButtons + spacers + utilityButtons;
    }
    
    return llList2List(combined, 9, 11) + llList2List(combined, 6, 8) + llList2List(combined, 3, 5) + llList2List(combined, 0, 2);
}


list RemoveMenuStride(list menu, integer index) {
    //tell this function the menu you wish to remove, identified by list index
    //it will remove the menu's entry from the list, and return the new list
    //should be called in the listen event, and on menu timeout    
    return llDeleteSubList(menu, index, index + MENUS_STRIDE - 1);
}

CleanList() {
    //loop through Menus, check their timeout times against current time
    //menus of sitting avatars never expire
    //start at end of list and loop down so that indexes don't get messed up as we remove items
    integer currentTime=llGetUnixTime();
    integer length = llGetListLength(Menus);
    integer index = length - MENUS_STRIDE;
    for (; index >= 0; index -= MENUS_STRIDE) {
        key recipient = (key)llList2String(Menus, index);
        if(~llListFindList(Avs, [recipient])) {
            //menus of sitting avatars never expire
            Menus=llListReplaceList(Menus, [currentTime + OptionDialogTimeout], index + MENUS_PARAM_TIMEOUTTIME, index + MENUS_PARAM_TIMEOUTTIME);
        }
        else if(llList2Integer(Menus, index + MENUS_PARAM_TIMEOUTTIME)<currentTime) {
            Menus = RemoveMenuStride(Menus, index);
            llMessageLinked(LINK_SET, DIALOG_TIMEOUT, recipient, llList2Key(Menus, index + MENUS_PARAM_CALLER_ID));
        }
    }
}

default {
    state_entry() {
        Channel = RandomUniqueChannel();
        Avs = SeatedAvs();
        //init our invisible character set
        CodingBase=llGetListLength(ZERO_WIDTH_UTF_CHARACTERS_BASE64);
        integer index;
        for(; index<CodingBase; index++) {
            CodingCharacterSet+=llBase64ToString(llList2String(ZERO_WIDTH_UTF_CHARACTERS_BASE64, index));
        }
    }
    
    changed(integer change) {
        if (change & CHANGED_LINK) {
            Avs = SeatedAvs();
            //loop through dialogs and close any for avs that aren't seated.  except for obj owner
        }
    }

    link_message(integer sender, integer num, string str, key id) {
        if (num == MEMORY_USAGE) {
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit() + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
        else if (num == DIALOG) {
            //give a dialog with the options on the button labels
            //str will be pipe-delimited list with rcpt|prompt|page|backtick-delimited-menu-buttons|backtick-delimited-utility-buttons|path
            list params = llParseStringKeepNulls(str, ["|"], []);
            str="";
            key rcpt = (key)llList2String(params, 0);
            string prompt = llList2String(params, 1);
            integer page = (integer)llList2String(params, 2);
            string path = llList2String(params, 5);
            string lookupTable;
            //get the buttons and create the lookup table
            //MENU_BUTTONS
            list temp=sanitizeButtons(llList2String(params, 3), lookupTable); 
            list menuButtons=llParseString2List(llList2String(temp, 0), [SEPARATOR], []);
            lookupTable=llList2String(temp, 1);
            //Utility buttons
            temp=sanitizeButtons(llList2String(params, 4), lookupTable);
            list utilityButtons=llParseString2List(llList2String(temp, 0), [SEPARATOR], []);
            lookupTable=llList2String(temp, 1);
            //prepare the dialog
            Dialog(rcpt, prompt, menuButtons, utilityButtons, page, id, path, lookupTable);
        }
        else if(num == OPTIONS || num == MACRO) {
            //save new option(s) or macro(s) from LINKMSG
            list optionsToSet = llParseStringKeepNulls(str, ["~","|"], []);
            integer length = llGetListLength(optionsToSet);
            integer index;
            for(; index<length; ++index) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionString = llList2String(optionsItems, 1);
                string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
                integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;
                if(num==MACRO) {
                    integer macroIndex=llListFindList(MacroNames, [optionItem]);
                    if(~macroIndex) {
                        MacroNames=llDeleteSubList(MacroNames, macroIndex, macroIndex);
                        MacroValues=llDeleteSubList(MacroValues, macroIndex, macroIndex);
                    }
                    MacroNames+=[optionItem];
                    MacroValues+=[optionString];
                }
                else if(num==OPTIONS) {
                    if(optionItem == "dialogtimeout") {OptionDialogTimeout = (integer)optionSetting;}
                    if(optionItem == "dialogbackward") {OptionUsePageBackward = optionSettingFlag;}
                }
            }
        }
    }

    listen(integer channel, string name, key id, string message) {
        integer index = llListFindList(Menus, [id]);
        if (~index) {
            key callerId = llList2Key(Menus, index + MENUS_PARAM_CALLER_ID);
            string prompt = llList2String(Menus, index + MENUS_PARAM_PROMPT);
            list menuButtons = llParseString2List(llList2String(Menus, index + MENUS_PARAM_MENU_BUTTONS), [SEPARATOR], []);
            list utilityButtons = llParseString2List(llList2String(Menus, index + MENUS_PARAM_UTILITY_BUTTONS), [SEPARATOR], []);
            integer page = llList2Integer(Menus, index + MENUS_PARAM_PAGE);
            string path = llList2String(Menus, index + MENUS_PARAM_PATH);
            string lookupTable=llList2String(Menus, index + MENUS_PARAM_LOOKUP_TABLE);
            
            Menus = RemoveMenuStride(Menus, index);
            
            if (message == PAGE_FORWARD || message == PAGE_FORWARD_LAST_PAGE) {
                //increase the page num and give new menu
                page++;
                Dialog(id, prompt, menuButtons, utilityButtons, page, callerId, path, lookupTable);
            }
            else if (message == PAGE_BACKWARD || message == PAGE_BACKWARD_FIRST_PAGE) {
                //decrease the page num and give new menu
                page--;
                Dialog(id, prompt, menuButtons, utilityButtons, page, callerId, path, lookupTable);
            }
            else if (message == BLANK) {
                //give the same menu back
                Dialog(id, prompt, menuButtons, utilityButtons, page, callerId, path, lookupTable);
            }
            else {
                if(message == BACK_BUTTON_DISPLAY) {
                    message=BACK_BUTTON_REPORT;
                }
                else {
                    message=buttonLookup(message, lookupTable);
                }
                llMessageLinked(LINK_SET, DIALOG_RESPONSE, (string)page + "|" + message + "|" + (string)id + "|" + path, callerId);
            }
        }
    }
    
    timer() {
        CleanList();
        
        //if list is empty after that, then stop timer
        
        if (!llGetListLength(Menus)) {
            llListenRemove(Listener);
            Listener = -1;
            llSetTimerEvent(0.0);
        }
    }
    on_rez(integer param) {
        llResetScript();
    }
}

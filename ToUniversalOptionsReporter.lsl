//settings
integer USE_OWNER_SAY=TRUE; //llWhispher tends to shuffel the messages more than llOwnerSay, so I suggest to set this to TRUE;

//blacklist filter


//additional informations
list OPTIONS=[
    //format: option, current setting, description
    "permit", "PUBLIC", "This controls the global permission to get the menu. Default permissions is public and options are group and owner.",
    "menuonsit", "off", "Turn this on to give the menu to any new sitter automatically when they sit, off means they must click for menu.",
    "2default", "off", "Turn this on and nPose returns to the DEFAULT pose when everyone stands.",
    "facialexp", "on", "This is a global setting for facial anims. If this option is off, any facial anims set in the build will be ignored.",
    "sit2getmenu", "off", "Turn this on to ensure no one will be able to pull a menu while standing. Everyone must be seated to get a menu.",
    "menudist", 30.0, "Distance away and still click to get menu.",
    "usedisplaynames", "off", "Turn this on to see sitter's display name in ChangeSeats menu.",
    "adjustrefroot", "off", "Turn this on to reference adjusts to the root prim rather than the prim the slave script is in.",
    "quietadjusters", "off", "Turn this on to quiet new position reporting by the adjusters, and also adjuster reporting when clicked. PosDump will still report all positions/rotations."
];

speak(string str) {
    if(USE_OWNER_SAY) {
        llOwnerSay(str);
    }
    else {
        llWhisper(0, str);
    }
}

default {
    
    state_entry() {
        llOwnerSay(llGetScriptName() + " up and running. " + (string)llGetFreeMemory() + " Bytes free.");
    }
    
    link_message(integer sender_num, integer num, string str, key id) {
        if (num == -240) {
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer stop = llGetListLength(optionsToSet);
            integer n;
            for(; n<stop; ++n) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, n), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionSetting = llToLower(llStringTrim(llList2String(optionsItems, 1), STRING_TRIM));
                integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;
                integer x = llListFindList(OPTIONS, [optionItem]);
                if (x != -1) {
                    if(optionItem == "menuonsit") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "permit") {
                        OPTIONS = llListReplaceList(OPTIONS, [llToUpper(optionSetting)], x+1, x+1);
                    }
                    else if(optionItem == "2default") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "sit2getmenu") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "menudist") {
                        OPTIONS = llListReplaceList(OPTIONS, [(float)optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "facialexp") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "usedisplaynames") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "adjustrefroot") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                    else if(optionItem == "quietadjusters") {
                        OPTIONS = llListReplaceList(OPTIONS, [optionSetting], x+1, x+1);
                    }
                }
            }
        }
        if(num == -240 && llToLower(str) == "showoptions") {
            integer stop = llGetListLength(OPTIONS);
            integer n;
            for (n=0; n<stop; n+=3) {
                speak("\n" + llList2String(OPTIONS, n) + "=" + llList2String(OPTIONS, n+1)
                 + "\n" + llList2String(OPTIONS, n+2) + "\n");
            }
        }            
    }
}

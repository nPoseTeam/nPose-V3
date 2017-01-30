/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/
integer UNSIT = -222;
integer MEMORY_TO_BE_USED=58000;

integer SEND_CHATCHANNEL = 1;
integer REZ_ADJUSTERS = 2;
integer ADJUSTER_REPORT = 3;
integer ADJUST = 201;
integer DUMP = 204;
integer STOPADJUST = 205;
integer SYNC = 206;
integer ADJUSTOFFSET = 208;
integer SETOFFSET = 209;
integer OPTIONS = -240;
integer PLUGIN_ACTION = -830;
integer PLUGIN_ACTION_DONE = -831;
integer PLUGIN_MENU = -832;
integer PLUGIN_MENU_DONE = -833;

integer MENU_USAGE = 34334;
integer SEAT_UPDATE = 35353;
integer REQUEST_CHATCHANNEL = 999999;

integer STRIDE = 8;
string MY_PLUGIN_MENU_OFFSET="npose_offset";

float CurrentOffsetDelta = 0.2;

integer Chatchannel;
string Currentanim;
list Lastanim;
integer DoSync = 0;
integer Primcount;
integer Newprimcount;
string LastAnimRunning;
integer Seatcount;
list AvatarOffsets;

list Adjusters = [];
list AnimsList; //[string command, string animation name]  use a list to layer multiple animations.
list Slots;
key ThisAV;
integer Stop;
integer QuietAdjusters;
integer AdjustRefRoot;

string BUTTON_OFFSET_FWD = "forward";
string BUTTON_OFFSET_BKW = "backward";
string BUTTON_OFFSET_LEFT = "left";
string BUTTON_OFFSET_RIGHT = "right";
string BUTTON_OFFSET_UP = "up";
string BUTTON_OFFSET_DOWN = "down";
string BUTTON_OFFSET_ZERO = "reset";
list OFFSET_BUTTONS = [
    BUTTON_OFFSET_FWD, BUTTON_OFFSET_LEFT, BUTTON_OFFSET_UP,
    BUTTON_OFFSET_BKW, BUTTON_OFFSET_RIGHT, BUTTON_OFFSET_DOWN,
    "0.2", "0.1", "0.05",
    "0.01", BUTTON_OFFSET_ZERO
];


//helper
string deleteNodes(string path, integer start, integer end) {
    return llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path, [":"], []), start, end), ":");
}

//helper
string buildParamSet1(string path, integer page, string prompt, list additionalButtons, list pluginParams) {
    //pluginParams are: string pluginLocalPath, string pluginName, string pluginMenuParams, string pluginActionParams
    //We can't use colons in the promt, because they are used as a seperator in other messages
    //so we replace them with a UTF Symbol
    return llDumpList2String([
        path,
        page,
        llDumpList2String(llParseStringKeepNulls(prompt, [","], []), "‚"), // CAUTION: the 2nd "‚" is a UTF sign!
        llDumpList2String(additionalButtons, ",")
    ] + llList2List(pluginParams + ["", "", "", ""], 0, 3), "|");
}

checkMemory() {
    //if memory is low, discard the oldest cache entry
    while(llGetUsedMemory()>MEMORY_TO_BE_USED && llGetListLength(AvatarOffsets)) {
        AvatarOffsets=llDeleteSubList(AvatarOffsets, 0, 1);
    }
}

doSeats(integer slotNum, key avKey) {
    if(DoSync < 1) {
        //we don't need to move the AV cause we have DoSync in process
        vector vpos = appliedOffsets(slotNum);
        MoveLinkedAv(AvLinkNum(avKey), vpos, llList2Rot(Slots, ((slotNum)*8)+2)); 
    }
    if(avKey != "") {
        Stop = llGetListLength(Slots)/8;
        llRequestPermissions(avKey, PERMISSION_TRIGGER_ANIMATION);
    }
}

list SeatedAvs() {
    list avs = [];
    integer n = llGetNumberOfPrims();
    for(; n >= llGetObjectPrimCount(llGetKey()); --n) {
        key id = llGetLinkKey(n);
        if(llGetAgentSize(id) != ZERO_VECTOR) {
            avs = [id] + avs;
        }
    }
    return avs;
}

integer AvLinkNum(key av) {
    integer linkcount = llGetNumberOfPrims();
    while(av != llGetLinkKey(linkcount)) {
        if(llGetAgentSize(llGetLinkKey(linkcount)) == ZERO_VECTOR) {
            return -1;
        }
        linkcount--;
    }
    return linkcount;
}

MoveLinkedAv(integer linknum, vector avpos, rotation avrot) {
    key user = llGetLinkKey(linknum);
    if(user) {  
        vector size = llGetAgentSize(user);
        if(size) {  
            rotation localrot = ZERO_ROTATION;
            vector localpos = ZERO_VECTOR;
            //check if AdjustRefRoot is off and the prim containing this script is in a linked prim
            if(AdjustRefRoot == 0 && llGetLinkNumber() > 1) {  
                localrot = llGetLocalRot();
                localpos = llGetLocalPos();
            }
            avpos.z += 0.4;
            llSetLinkPrimitiveParamsFast(linknum, [PRIM_POSITION, ((avpos - (llRot2Up(avrot) * size.z * 0.02638)) * localrot) + localpos, PRIM_ROTATION, avrot * localrot / llGetRootRotation()]);
        }
    }    
}


vector appliedOffsets(integer n) {
    string slot = llList2String(Slots, n*STRIDE + 4);
    integer avinoffsets = llListFindList(AvatarOffsets, [(key)slot]);
    rotation rot = llList2Rot(Slots, n*STRIDE+2); 
    vector pos = (vector)llList2String(Slots, n*STRIDE+1); 
    if(avinoffsets != -1) {
        vector offset = llList2Vector(AvatarOffsets, avinoffsets+1);
        pos += offset * rot; 
    }
    return pos; 
}

SetAvatarOffset(key avatar, vector offset) { 
    integer avatarOffsetsIndex = llListFindList(AvatarOffsets, [avatar]); 
    if(offset == ZERO_VECTOR && avatarOffsetsIndex >= 0) {
        AvatarOffsets = llDeleteSubList(AvatarOffsets, avatarOffsetsIndex, avatarOffsetsIndex+1);
        llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
        return;
    }
    if(~avatarOffsetsIndex) { 
        offset = llList2Vector(AvatarOffsets, avatarOffsetsIndex+1) + offset;
        AvatarOffsets = llDeleteSubList(AvatarOffsets, avatarOffsetsIndex, avatarOffsetsIndex+1);
    }
    checkMemory();
    //move existing av and offset to the endo of the list for safe keeping
    AvatarOffsets = AvatarOffsets + [avatar, offset];
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
}


RezNextAdjuster(integer slotnum) {
    if(llGetInventoryType("Adjuster") == INVENTORY_OBJECT) {
        integer index = slotnum * STRIDE;
        vector pos = llGetRootPosition() + llList2Vector(Slots, index + 1) * llGetRootRotation();
        rotation rot = llList2Rot(Slots, index + 2) * llGetRootRotation();
        if (!AdjustRefRoot) {
            pos = llGetPos() + llList2Vector(Slots, index + 1) * llGetRot();
            rot = llList2Rot(Slots, index + 2) * llGetRot();
        }
        llRezObject("Adjuster", pos, ZERO_VECTOR, rot, Chatchannel);
    }
    else {
        llSay(Chatchannel, "adjuster_die");
        Adjusters = [];
        llRegionSayTo(llGetOwner(), 0, "Seat Adjustment disabled.  No Adjuster object found in " + llGetObjectName()+ ".");
    }
}

default {
    state_entry() {
        llMessageLinked(LINK_SET, REQUEST_CHATCHANNEL, "", "");
        Primcount = llGetNumberOfPrims();
        Newprimcount = Primcount;
    }
 
    link_message(integer sender, integer num, string str, key id) {
        if(num == SEND_CHATCHANNEL) {  //got chatchannel from the core.
            Chatchannel = (integer)str;
            return;
        }
        else if(num == ADJUSTOFFSET || num == SETOFFSET) {
            SetAvatarOffset(id, (vector)str);
        }
        else if(num == SEAT_UPDATE){
            list seatsavailable = llParseStringKeepNulls(str, ["^"], []);
            str = "";
            integer stop = llGetListLength(seatsavailable)/8;
            Slots = [];
            for(Seatcount = 1; Seatcount <= stop; ++Seatcount) {
                Slots = Slots + [llList2String(seatsavailable, (Seatcount-1)*8), (vector)llList2String(seatsavailable, (Seatcount-1)*8+1), 
                        (rotation)llList2String(seatsavailable, (Seatcount-1)*8+2), llList2String(seatsavailable, (Seatcount-1)*8+3), 
                        (key)llList2String(seatsavailable, (Seatcount-1)*8+4), llList2String(seatsavailable, (Seatcount-1)*8+5),
                        llList2String(seatsavailable, (Seatcount-1)*8+6), llList2String(seatsavailable, (Seatcount-1)*8+7)];
            }
            //we have our new list of AV's and positions so put them where they belong.  fire off the first seated AV and run time will do the rest.
            for(Seatcount = 0; Seatcount < stop; ++Seatcount) {
                if(llList2Key(Slots, Seatcount*8+4) != "") {
                    if(llListFindList(SeatedAvs(), [llList2Key(Slots, Seatcount*8+4)]) != -1) {
                        DoSync = 0;
                        doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                        return;
                    }
                }
            }
        }
        else if(num == UNSIT) {
            key avatarUuid=(key)str;
            if(avatarUuid) {
                if(~llListFindList(SeatedAvs(), [avatarUuid])) {
                    llUnSit(avatarUuid);
                }
            }
        }
        else if(num == SYNC) {
            DoSync = 1;
            integer stop = llGetListLength(Slots)/8;
            //go until we find first sitter and then kick off process of sync
            for(Seatcount = 0; Seatcount < stop; ++Seatcount) {
                if(llList2String(Slots, (Seatcount)*8+4) != "") {
                    doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                    return;
                }
            }
        }
        else if((num == ADJUST) || (num == REZ_ADJUSTERS && str == "RezAdjuster")) { //adjust has been chosen from the menu
            llSay(Chatchannel, "adjuster_die");
            Adjusters = [];
            RezNextAdjuster(0);
        }
        else if(num == STOPADJUST) { //stopadjust has been chosen from the menu
            llMessageLinked(LINK_SET, DUMP, "", "");
            llSay(Chatchannel, "adjuster_die"); 
            Adjusters = [];
        }
        else if(num == OPTIONS) {
            //save new option(s) from LINKMSG
            list optionsToSet = llParseStringKeepNulls(str, ["~","|"], []);
            integer length = llGetListLength(optionsToSet);
            integer index;
            for(; index<length; ++index) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionString = llList2String(optionsItems, 1);
                string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
                integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;

                if(optionItem == "quietadjusters") {
                    QuietAdjusters = optionSettingFlag;
                }
                if(optionItem == "adjustrefroot") {
                    AdjustRefRoot = optionSettingFlag;
                }
            }
        }
        else if(num == ADJUSTER_REPORT) {    //heard from an adjuster so a new position must be used, upate Slots and chat out new position.
            integer index = llListFindList(Adjusters, [id]);
            if(index != -1) {
                string primName = llGetObjectName();
                llSetObjectName(llGetLinkName(1));
                list params = llParseString2List(str, ["|"], []);
                vector newpos = ((vector)llList2String(params, 0) - llGetRootPosition()) / llGetRootRotation();
                rotation newrot = (rotation)llList2String(params, 1) / llGetRootRotation();
                if (!AdjustRefRoot) {
                    newpos = ((vector)llList2String(params, 0) - llGetPos()) / llGetRot();
                    newrot = (rotation)llList2String(params, 1) / llGetRot();
                }
                integer slotsindex = index * STRIDE;
                Slots = llListReplaceList(Slots, [newpos, newrot], slotsindex + 1, slotsindex + 2);
                if (!QuietAdjusters) {
                    list temp=llParseStringKeepNulls(llList2String(Slots, slotsindex+7), ["§"], []);
                    string seatName;
                    if(llList2String(temp, 0)) {
                        seatName = llList2String(temp, 0);
                    }
                    llRegionSayTo(llGetOwner(), 0, "SCHMOE and SCHMO lines will be reported as ANIM.  Be sure to replace if needed.");
                    llRegionSayTo(llGetOwner(), 0, "\nANIM|" + llList2String(Slots, slotsindex) + "|" + (string)newpos + "|" +
                        (string)(llRot2Euler(newrot) * RAD_TO_DEG) + "|" + llList2String(Slots, slotsindex + 3) + "|" + seatName);
                }
                llSetObjectName(primName);
                llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
                //gotta send a message back to the core other than with SEAT_UPDATE so the core knows it came from here and updates Slots list there.
                llMessageLinked(LINK_SET, (SEAT_UPDATE + 2000000), llDumpList2String(Slots, "^"), NULL_KEY);                
            }
        }
        else if(num == DUMP) {
            integer n;
            string primName = llGetObjectName();
            llSetObjectName(llGetLinkName(1));
            llRegionSayTo(llGetOwner(), 0, "SCHMOE and SCHMO lines will be reported as ANIM.  Be sure to replace if needed.");
            for(n = 0; n < llGetListLength(Slots)/8; ++n) {
                list temp=llParseStringKeepNulls(llList2String(Slots, n*8+7), ["§"], []);
                string seatName;
                if(llList2String(temp, 0)) {
                    seatName = llList2String(temp, 0);
                }
                list slice = llList2List(Slots, n*STRIDE, n*STRIDE + 3);
                slice = llListReplaceList(slice, [RAD_TO_DEG * llRot2Euler(llList2Rot(slice, 2))], 2, 2);
                string sendSTR = "ANIM|" + llDumpList2String(slice, "|") + "|" + seatName;
                llRegionSayTo(llGetOwner(), 0, "\n"+sendSTR);
            }
            llRegionSay(Chatchannel, "posdump");
            llSetObjectName(primName);
        }
        else if(num==PLUGIN_ACTION || num==PLUGIN_MENU) {
            //offset menu
            list params=llParseStringKeepNulls(str, ["|"], []);
            string path=llList2String(params, 0);
            integer page=(integer)llList2String(params, 1);
            string prompt=llList2String(params, 2);
            string additionalButtons=llList2String(params, 3);
            string pluginLocalPath=llList2String(params, 4);
            string pluginName=llList2String(params, 5);
            string pluginMenuParams=llList2String(params, 6);
            string pluginActionParams=llList2String(params, 7);

            if(pluginName==MY_PLUGIN_MENU_OFFSET) {
                //this is the offset menu. It can be move to any other script easily.
                if(num==PLUGIN_ACTION) {
                    // 1) Do the action if needed
                    // 2) correct the path if needed
                    // 3) finish with a PLUGIN_ACTION_DONE call
                    if(pluginLocalPath!="") {
                        vector direction;
                        if(pluginLocalPath == BUTTON_OFFSET_FWD) {direction=<1, 0, 0>;}
                        else if(pluginLocalPath == BUTTON_OFFSET_BKW) {direction=<-1, 0, 0>;}
                        else if(pluginLocalPath == BUTTON_OFFSET_LEFT) {direction=<0, 1, 0>;}
                        else if(pluginLocalPath == BUTTON_OFFSET_RIGHT) {direction=<0, -1, 0>;}
                        else if(pluginLocalPath == BUTTON_OFFSET_UP) {direction=<0, 0, 1>;}
                        else if(pluginLocalPath == BUTTON_OFFSET_DOWN) {direction=<0, 0, -1>;}
                        else if((float)pluginLocalPath) {CurrentOffsetDelta = (float)pluginLocalPath;}
                        if(direction!=ZERO_VECTOR || pluginLocalPath==BUTTON_OFFSET_ZERO) {
                            SetAvatarOffset(id, direction * CurrentOffsetDelta);
                        }
                        //one level back
                        path=deleteNodes(path, -1, -1);
                    }
                    llMessageLinked(LINK_SET, PLUGIN_ACTION_DONE, buildParamSet1(path, 0, prompt, [], []), id);
                }
                else if(num==PLUGIN_MENU) {
                    // 1) set a prompt if needed
                    // 2) generate your buttons if needed
                    // 3) finish with a PLUGIN_MENU_DONE call
                    string prompt="Adjust by " + (string)CurrentOffsetDelta+ "m, or choose another distance.";
                    llMessageLinked(LINK_SET, PLUGIN_MENU_DONE, buildParamSet1(path, page, prompt, OFFSET_BUTTONS, []), id);
                }
            }
        }
        else if(num == MENU_USAGE) {
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
                 + ",Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }
 

    run_time_permissions(integer perm) {
        ThisAV = llGetPermissionsKey();
        //get the current requested animation from list Slots.
        integer avIndex = llListFindList(Slots, [ThisAV]);
        Currentanim = llList2String(Slots, avIndex - 4);
        //we also need to know the last animation running.  
        //Lastanim is a 2 stride list [ThisAV, last active animation name]
        //index ThisAV as a string in the list and then we can find the last animation.
        integer thisAvIndex = llListFindList(Lastanim, [(string)ThisAV]);
        if(DoSync < 1) {
            //skip this if we in DoSync process. this is for changing animations
            if(thisAvIndex != -1) {
                //Not New Sitter!
                LastAnimRunning = llList2String(Lastanim, thisAvIndex+1);
            }
            else {
                //New Sitter!
                //New Sitter isn't in our list yet so give the list some beef
//                    llStartAnimation("Sit");
                LastAnimRunning = "Sit";
                Lastanim += [(string)ThisAV, "Sit"];
            }
            //now we know which animation to stop so go ahead and stop it.
            if(LastAnimRunning != "") {
                llStopAnimation(LastAnimRunning);
//                }
            }
            thisAvIndex = llListFindList(Lastanim, [(string)ThisAV]);
            //now that we have the name of the last animation running, we can update the list with current animation.
            Lastanim = llListReplaceList(Lastanim, [(string)ThisAV, Currentanim], thisAvIndex, thisAvIndex+1);
            if(avIndex != -1) {
                if(llListFindList(SeatedAvs(), [ThisAV]) != -1) {
                    llStartAnimation(Currentanim);
                }
            }
        }
        else if(llListFindList(SeatedAvs(), [ThisAV]) != -1) {
            //this else region is for sync
            if(DoSync == 1) {
                //here we need to run through all the seats and stop animations
                llStopAnimation(Currentanim);
                llStartAnimation("Sit");
            }
            else if(DoSync == 2) {
                llStartAnimation(Currentanim);
                llStopAnimation("Sit");
            }
        }
        //check all the Slots for next seated AV, call for next seated AV to move and animate.
        for(; Seatcount < Stop-1; ) {
            Seatcount += 1;
            if(llList2Key(Slots, Seatcount*8+4) != "") {
                doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                return;
            }
        }
        if(DoSync == 1) {
            //TODO: we should use a llSleep instead of a counter for lower CPU time impact
            integer counter;
            integer stop = 1500;
            for( ; counter<stop; ++counter) { }
            DoSync = 2;
            for (Seatcount = 0; Seatcount < Stop; ++Seatcount){
                if(llList2String(Slots, (Seatcount)*8+4) != "") {
                    doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                    return;
                }
            }
        }
    }


    object_rez(key id) {
        if(llKey2Name(id) == "Adjuster") {
            Adjusters += [id];
            integer adjLen = llGetListLength(Adjusters);
            if(adjLen < (llGetListLength(Slots)/8)) { 
                RezNextAdjuster(adjLen);
            }
        }
    }

    changed(integer change) {
        if(change & CHANGED_LINK) {
            integer newPrimCount1 = llGetNumberOfPrims();
            if(Newprimcount>newPrimCount1) {
                //we have lost a sitter so find out who and remove them from the list.
                integer n;
                integer stop = llGetListLength(Lastanim)/2;
                for(; n<stop; ++n) {
                    if(AvLinkNum((key)llList2String(Lastanim, n*2)) == -1) {
                        integer index = llListFindList(AnimsList, [(key)llList2String(Lastanim, n*2)]);
                        if(index != -1) {
                            AnimsList = llDeleteSubList(AnimsList, index, index + 2);
                        }
                        Lastanim = llDeleteSubList(Lastanim, n*2, n*2+1);
                    }
                }
            }
            Newprimcount = newPrimCount1;
            if(Newprimcount == Primcount) {
                //no AV's seated so clear the Lastanim list.  done so we can detect LL's default Sit when reseating.
                Lastanim = [];
                Currentanim = "";
                LastAnimRunning = "";
            }
        }
    }
}

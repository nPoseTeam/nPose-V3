/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/
integer UNSIT = -222;
integer LAYER_POSE = -218;

integer SEND_CHATCHANNEL = 1;
integer REZ_ADJUSTERS = 2;
integer ADJUSTER_REPORT = 3;
integer ADJUST = 201;
integer DUMP = 204;
integer STOPADJUST = 205;
integer SYNC = 206;
integer ADJUSTOFFSET = 208;
integer SETOFFSET = 209;
integer DOPOSE_READER = 222;
integer OPTIONS = -240;
integer PLUGIN_ACTION = -830;
integer PLUGIN_ACTION_DONE = -831;
integer PLUGIN_MENU = -832;
integer PLUGIN_MENU_DONE = -833;

integer MENU_USAGE = 34334;
integer SEAT_UPDATE = 35353;
integer REQUEST_CHATCHANNEL = 999999;

string NC_READER_CONTENT_SEPARATOR="%&§";
integer STRIDE = 8;
string MY_PLUGIN_MENU_OFFSET="npose_offset";

float CurrentOffsetDelta = 0.2;

integer Chatchannel;
string Currentanim;
list Lastanim;
list Faceanims;
integer DoingFaceAnim = 0;
integer GotFaceAnim = 0;
integer DoSync = 0;
integer Primcount;
integer Newprimcount;
string LastAnimRunning;
integer Seatcount;
integer NextAvatarOffset;
integer AVATAR_OFFSETS_LENGTH = 20;
list AvatarOffsets;

list Adjusters = [];
list AnimsList; //[string command, string animation name]  use a list to layer multiple animations.
list FaceTimes = [];
list Slots;
key ThisAV;
integer Stop;
integer FacialEnable = TRUE;
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

doSeats(integer slotNum, key avKey) {
    llSetTimerEvent(0.0);
    if(DoSync !=1) {
        vector vpos = appliedOffsets(slotNum);
        MoveLinkedAv(AvLinkNum(avKey), vpos, llList2Rot(Slots, ((slotNum)*8)+2)); 
    }
    if(avKey != "") {
        DoingFaceAnim = 0;
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
    if(avatarOffsetsIndex < 0) { 
        avatarOffsetsIndex = NextAvatarOffset; 
        NextAvatarOffset = (NextAvatarOffset + 2) % AVATAR_OFFSETS_LENGTH;
    }
    else { 
        offset = llList2Vector(AvatarOffsets, avatarOffsetsIndex+1) + offset;
    }
    AvatarOffsets = llListReplaceList(AvatarOffsets, [avatar, offset], avatarOffsetsIndex, avatarOffsetsIndex+1);
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
}


RezNextAdjuster(integer slotnum) {
    if(llGetInventoryType("Adjuster") == INVENTORY_OBJECT) {
        integer index = slotnum * STRIDE;
        vector posToUse;
        rotation rotToUse;
        if (AdjustRefRoot) {
            posToUse = llGetRootPosition();
            rotToUse = llGetRootRotation();
        }
        else {
            posToUse = llGetPos();
            rotToUse = llGetRot();
        }
        vector pos = posToUse + llList2Vector(Slots, index + 1) * rotToUse;
        rotation rot = llList2Rot(Slots, index + 2) * rotToUse;

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
        }
        if(num == LAYER_POSE) {
            key av;
            list tempList = llParseString2List(str, ["/"], []);
            if(llListFindList(SeatedAvs(), [(key)llList2String(tempList, 0)]) != -1) {
                av = (key)llList2String(tempList, 0);
            }
            if(av) {
                llRequestPermissions(av, PERMISSION_TRIGGER_ANIMATION);
                av = llGetPermissionsKey();
                list tempList1 = llParseString2List(llList2String(tempList, 1), ["~"], []);
                integer instruction;
                integer layerStop = llGetListLength(tempList1);
                for(instruction = 0; instruction < layerStop; ++instruction) {
                    tempList = llParseString2List(llList2String(tempList1, instruction), [","],[]);
                    if(llList2String(tempList,0)=="stopAll") {
                        AnimsList = [av, llList2String(tempList, 0), llList2String(tempList, 1)] + AnimsList;
                    }
                    else {
                        integer index = llListFindList(AnimsList, [llList2String(tempList, 1)]);
                        if(index>=1 & (key)llList2String(AnimsList, index - 2) == av) {
                            AnimsList = llDeleteSubList(AnimsList, index-2, index);
                        }
                        AnimsList += [av, llList2String(tempList, 0), llList2String(tempList, 1)];
                    }
                }
                integer n;
                layerStop = llGetListLength(AnimsList)/3;
                for(n=0; n<layerStop; ++n) {
                    if((key)llList2String(AnimsList, n*3) == av) {
                       if(llList2String(AnimsList, n*3+1) == "stopAll") {
                           AnimsList = llDeleteSubList(AnimsList, n*3, n*3+2);
                           n-=1;
                           layerStop-=1;
                            integer x;
                            integer animsStop = llGetListLength(AnimsList)/3;
                            if(animsStop > 0) {
                                for(x = 0; x<animsStop; ++x) {
                                    if ((key)llList2String(AnimsList, x*3) == av && llList2String(AnimsList, x*3+2) != ""){
                                        llStopAnimation(llList2String(AnimsList, x*3+2));
                                        AnimsList = llDeleteSubList(AnimsList, x*3, x*3+2);
                                        x-=1;
                                        animsStop-=1;
                                    }
                                }
                            }
                        }
                        else if(llList2String(AnimsList, n*3+1) == "start" && llList2String(AnimsList, n*3) == av
                         && llList2String(AnimsList, n*3+2) != "") {
                            if(llGetPermissions() & PERMISSION_TRIGGER_ANIMATION) {
                                llStartAnimation(llList2String(AnimsList, n*3+2));
                            }
                        }
                        else if(llList2String(AnimsList, n*3+1) == "stop") {
                            if (llGetPermissions() & PERMISSION_TRIGGER_ANIMATION){
                                llStopAnimation(llList2String(AnimsList, n*3+2));
                                AnimsList = llDeleteSubList(AnimsList, n*3, n*3+2);
                                n-=1;
                                layerStop-=1;
                            }
                        }
                    }
                }
            }
//            llSay(0, "anim list:\n" + llList2CSV(llGetAnimationList(av)));
        }
        else if(num == ADJUSTOFFSET || num == SETOFFSET) {
            SetAvatarOffset(id, (vector)str);
        }
        else if(num == SEAT_UPDATE){
            list seatsavailable = llParseStringKeepNulls(str, ["^"], []);
            str = "";
            integer stop = llGetListLength(seatsavailable)/8;
            Slots = [];
            FaceTimes = [];
            GotFaceAnim = 0;
//            string faces = "";
            for(Seatcount = 1; Seatcount <= stop; ++Seatcount) {
                integer seatNum = (integer)llGetSubString(llList2String(seatsavailable, (Seatcount-1)*8+7), 4,-1);
                Slots = Slots + [llList2String(seatsavailable, (Seatcount-1)*8), (vector)llList2String(seatsavailable, (Seatcount-1)*8+1), 
                        (rotation)llList2String(seatsavailable, (Seatcount-1)*8+2), llList2String(seatsavailable, (Seatcount-1)*8+3), 
                        (key)llList2String(seatsavailable, (Seatcount-1)*8+4), llList2String(seatsavailable, (Seatcount-1)*8+5),
                        llList2String(seatsavailable, (Seatcount-1)*8+6), llList2String(seatsavailable, (Seatcount-1)*8+7)];
                if(llList2String(seatsavailable, (Seatcount-1)*8+3) != "") {
                    //we need a list consisting of sitter key followed by each face anim and the associated time of each
                    //put face anims for this slot in a list
                    list faceanimsTemp = llParseString2List(llList2String(seatsavailable, (Seatcount-1)*8+3), ["~"], []); 
                    integer facecount = llGetListLength(faceanimsTemp);   
                    list faces = []; 
                    integer nFace;
                    integer hasNewFaceTime = 0;
                    for(nFace=0; nFace<facecount; ++nFace) {
                        //parse this face anim for anim name and time
                        list temp = llParseString2List(llList2String(faceanimsTemp, nFace), ["="], []);
                        //time must be optional so we will make default a zero
                        //queue on zero to revert to older stuff
                        if(llList2String(temp, 1)) {
                            //collect the name of the anim and the time
                            faces += [llList2String(temp, 0), (integer)llList2String(temp, 1)];
                            hasNewFaceTime = 1;
                        }
                        else {
                            faces += [llList2String(temp, 0), -1];
                        }
                    }
                    GotFaceAnim=1;
                    //add sitter key and flag if timer defined followed by a stride 2 list containing face anim name and associated time
                    FaceTimes += [(key)llList2String(seatsavailable, (Seatcount-1)*8+4), hasNewFaceTime, facecount] + faces;
                }
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
            for(Seatcount = 0; Seatcount < stop; ++Seatcount) {
                doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                return;
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
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer stop = llGetListLength(optionsToSet);
            integer n;
            for(; n<stop; ++n) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, n), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionSetting = llToLower(llStringTrim(llList2String(optionsItems, 1), STRING_TRIM));
                integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;
                if(optionItem == "quietadjusters") {
                    QuietAdjusters = optionSettingFlag;
                }
                if(optionItem == "adjustrefroot") {
                    AdjustRefRoot = optionSettingFlag;
                }
                else if(optionItem == "facialexp") {
                    FacialEnable = optionSettingFlag;
                }
            }
        }
        else if(num == ADJUSTER_REPORT) {    //heard from an adjuster so a new position must be used, upate Slots and chat out new position.
            integer index = llListFindList(Adjusters, [id]);
            if(index != -1) {
                string primName = llGetObjectName();
                llSetObjectName(llGetLinkName(1));
                list params = llParseString2List(str, ["|"], []);
                vector posToUse;
                rotation rotToUse;
                if (AdjustRefRoot) {
                    posToUse = llGetRootPosition();
                    rotToUse = llGetRootRotation();
                }
                else {
                    posToUse = llGetPos();
                    rotToUse = llGetRot();
                }
                vector newpos = (vector)llList2String(params, 0) - posToUse;
                newpos = newpos / rotToUse;
                integer slotsindex = index * STRIDE;
                rotation newrot = (rotation)llList2String(params, 1) / rotToUse;
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
            string pluginName=llList2String(params, 4);
            string pluginLocalPath=llList2String(params, 5);
            string pluginStaticParams=llList2String(params, 6);

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
                        path=deleteNode(path, -1, -1);
                    }
                    llMessageLinked(LINK_SET, PLUGIN_ACTION_DONE, buildParamSet1(path, 0, "", [], "", "", ""), id);
                }
                else if(num==PLUGIN_MENU) {
                    // 1) set a prompt if needed
                    // 2) generate your buttons if needed
                    // 3) finish with a PLUGIN_MENU_DONE call
                    string prompt="Adjust by " + (string)CurrentOffsetDelta+ "m, or choose another distance.";
                    llMessageLinked(LINK_SET, PLUGIN_MENU_DONE, buildParamSet1(path, 0, prompt, OFFSET_BUTTONS, "", "", ""), id);
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
        if(DoingFaceAnim != 1) {
            //get the current requested animation from list Slots.
            integer avIndex = llListFindList(Slots, [ThisAV]);
            Currentanim = llList2String(Slots, avIndex - 4);
            //we also need to know the last animation running.  
            //Lastanim is a 2 stride list [ThisAV, last active animation name]
            //index ThisAV as a string in the list and then we can find the last animation.
            integer thisAvIndex = llListFindList(Lastanim, [(string)ThisAV]);
            if(DoSync !=1) {
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
                llStopAnimation(Currentanim);
                llStartAnimation("sit");
                llSleep(0.05);
                llStopAnimation("sit");
                llStartAnimation(Currentanim);
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
        //start timer if we have face anims for any slot
        if(GotFaceAnim==1) {
            llSetTimerEvent(1.0);
            DoingFaceAnim=1;
        }
        else {
            llSetTimerEvent(0.0);
            DoingFaceAnim=0;
        }
    }

    timer() {        
        integer n;
        integer stop = llGetListLength(Slots)/8;
        key av;
        integer facecount;
        integer faceindex;
        if(FacialEnable) {
            for(n=0; n<stop; ++n) {
                //doing each seat
                av = (key)llList2String(Slots, n*8+4);
                faceindex = 0;
                //locate our stride in FaceTimes list
                integer keyHasFacial = llListFindList(FaceTimes, [av]);
                //get number of face anims for this seat
                integer newFaceTimeFlag = llList2Integer(FaceTimes, keyHasFacial+1);
                
                if(newFaceTimeFlag == 0) {
                //need to know if someone seated in this seat, if not we won't do any facials
                    if(av != "") {
                        Faceanims = llParseString2List(llList2String(Slots, n*8+3), ["~"], []);
                        facecount = llGetListLength(Faceanims);
                        if(facecount > 0 && (llListFindList(SeatedAvs(), [ThisAV]) != -1)) {//modified cause face anims were being imposed after AV stands.
                            DoingFaceAnim=1;
                            ThisAV = llGetPermissionsKey();
                            llRequestPermissions(av, PERMISSION_TRIGGER_ANIMATION);
                        }
                    }
                    integer x;
                    for(x=0; x<facecount; ++x){
                        if (facecount>0) {
                            if(faceindex < facecount) {
                                if(AvLinkNum(av) != -1) {
                                    llStartAnimation(llList2String(Faceanims, faceindex));
                                }
                            }            
                            faceindex++;
                        }
                    }
                }
                else if(av != ""){
                //need to know if someone seated in this seat, if not we won't do any facials
                //do our stuff with defined facial times
                    facecount = llList2Integer(FaceTimes, keyHasFacial+2);
                    //if we have facial anims make sure we have permissions for this av
                    if((facecount > 0) && (llListFindList(SeatedAvs(), [ThisAV]) != -1)) {  //modified cause face anims were being imposed after AV stands.
                        DoingFaceAnim=1;
                        ThisAV = llGetPermissionsKey();
                        llRequestPermissions(av, PERMISSION_TRIGGER_ANIMATION);
                    }
                        integer x;
                    for(x=1; x<=facecount; ++x) {
                        //non looping we check if anim has run long enough
                        if(faceindex < facecount) {
                            integer faceStride = keyHasFacial+1+(x*2);
                            string animName = llList2String(FaceTimes, faceStride);
                            if(llList2Integer(FaceTimes, faceStride+1) > 0) {
                                FaceTimes = llListReplaceList(FaceTimes, [llList2Integer(FaceTimes, faceStride+1)-1],
                                 faceStride+1, faceStride+1);
                            }
                            if(facecount>0) {
                                if(AvLinkNum(av) != -1 && llList2Integer(FaceTimes, faceStride+1) > 0) {
                                    llStartAnimation(animName);
                                }
                                else if(AvLinkNum(av) != -1 && llList2Integer(FaceTimes, faceStride+1) == -1) {
                                    llStartAnimation(animName);
                                }
                                faceindex++;
                            }
                        }
                    }
                
                }
            }
            if(llGetListLength(SeatedAvs())<1) {
                llSetTimerEvent(0.0);
                DoingFaceAnim=0;
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
//            AnimsList=[]; 
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
//                AnimsList=[];
                Lastanim = [];
                Currentanim = "";
                LastAnimRunning = "";
            }
        }
        else if(change & CHANGED_OWNER) {
            llResetScript();
        }
    }
}

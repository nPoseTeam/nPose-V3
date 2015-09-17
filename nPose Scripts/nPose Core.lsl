/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/


//define block start
#define ADMIN_HUD_NAME "npose admin hud"
#define STRIDE 8
#define SLOT_UPDATE 34333
#define MEMORY_USAGE 34334
#define SEAT_UPDATE 35353
#define REQUEST_CHATCHANNEL 999999
#define DEFAULT_PREFIX "DEFAULT:"
#define CARD_PREFIX "SET:"
#define SEND_CHATCHANNEL 1
#define REZ_ADJUSTERS 2
#define ADJUSTER_REPORT 3
#define DOPOSE 200
#define ADJUST 201
#define SWAP 202
#define DUMP 204
#define STOPADJUST 205
#define SYNC 206
#define DOACTION 207
#define ADJUSTOFFSET 208
#define SWAPTO 210
#define DOPOSE_READER 222
#define DOACTION_READER 223
#define CORERELAY 300
#define UNSIT -222
#define OPTIONS -240
#define DOMENU_ACCESSCTRL -801
#define HUD_REQUEST -999
//define block end

integer slotMax;
//integer curPrimCount;
//integer lastPrimCount;
integer lastStrideCount = 12;
integer rezadjusters;
//integer listener;
integer chatchannel;
integer explicitFlag;
key hudId;
string lastAssignSlotsCardName;
key lastAssignSlotsCardId;
key lastAssignSlotsAvatarId;
list slots;  //one STRIDE = [animationName, posVector, rotVector, facials, sitterKey, SATMSG, NOTSATMSG, seatName]
//list propsRezzing;

string curmenuonsit = "off"; //default menuonsit option

string NC_READER_CONTENT_SEPARATOR="%&§";

integer FindEmptySlot() {
    integer n;
    for(; n < slotMax; ++n) {
        if(llList2String(slots, n*STRIDE+4) == "") {
            return n;
        }
    }
    return -1;
}

list SeatedAvs(){
    list avs = [];
    integer n = llGetNumberOfPrims();
    for(; n >= llGetObjectPrimCount(llGetKey()); --n) {
        //only check link numbers greater than the number of actual prims, these will be the AV link numbers.
        key id = llGetLinkKey(n);
        if(llGetAgentSize(id) != ZERO_VECTOR) {
            avs = [id] + avs;
        }
    }
    return avs;
}

assignSlots(){
    list avqueue = SeatedAvs();
    /*clean up the slots list with regard to AV key's in the list by
    removing extra AV keys from the slots list, they are no longer seated.
    */
    integer x;
    integer n;
    for(; x < slotMax; ++x) {
        //look in the avqueue for the key in the slots list
        if(!~llListFindList(avqueue, [llList2Key(slots, x*STRIDE+4)])) {
            //if the key is not in the avqueue, remove it from the slots list
            slots = llListReplaceList(slots, [""], x*STRIDE+4, x*STRIDE+4);
        }
    }
    //we need to check if less seats are available, more seats would not need slots assigned at this point, they just empty seats.
    if(slotMax < lastStrideCount) {
        //new pose set has less seats available
        //AV's that were in a available seats are already assigned so leave them be
        for(x = slotMax; x <= lastStrideCount; ++x) {//only need to worry about the 'extra' slots so limit the count
            if(llList2Key(slots, x*STRIDE+4) != "") {
                //this is a 'now' extra sitter
                integer emptySlot = FindEmptySlot();//find an empty slot for them if available
                if((emptySlot >= 0) && (emptySlot < slotMax)) {
                    //if a real seat available, seat them
                    slots = llListReplaceList(slots, [llList2Key(slots, x*STRIDE+4)], emptySlot*STRIDE+4, emptySlot*STRIDE+4);
                }
            }
        }
        //remove the 'now' extra seats from slots list
        slots = llDeleteSubList(slots, (slotMax)*STRIDE, -1);
        //unsit extra seated AV's
        for(; n<llGetListLength(avqueue); ++n) {
            if(!~llListFindList(slots, [llList2Key(avqueue, n)])) {
                llMessageLinked(LINK_SET, UNSIT, llList2String(avqueue, n), NULL_KEY);
            }
        }
    }
    //step through the avqueue list and check if everyone is accounted for
    //newest sitters last in avqueue list so step through increamentally
    integer nn;
    for(; nn<llGetListLength(avqueue); ++nn) {
        key thisKey = llList2Key(avqueue, nn);
        integer index = llListFindList(slots, [llList2Key(avqueue, nn)]);
        integer emptySlot = FindEmptySlot();
        if(!~index) {
            //this AV not in slots list
            key newAvatar;
            //check if they on a numbered seat
            integer slotNum=-1;
            for(n = 1; n <= llGetObjectPrimCount(llGetKey()); ++n) {
                //find out which prim this new AV is seated on and grab the slot number if it's a numbered prim.
                integer x = (integer)llGetSubString(llGetLinkName(n), 4, -1);
                if((x > 0) && (x <= slotMax)) {
                    if(llAvatarOnLinkSitTarget(n) == thisKey) {
                        if(llList2String(slots, (x-1)*STRIDE+4) == "") {
                            slotNum = (integer)llGetLinkName(n);
                            slots = llListReplaceList(slots, [thisKey], (slotNum-1)*STRIDE+4, (slotNum-1)*STRIDE+4);
                            newAvatar=thisKey;
                        }
                    }
                }
            }
            if(!~llListFindList(slots, [thisKey])) {
                if(~emptySlot) {
                    //they not on numbered seat so grab the lowest available seat for them, we have one available
                    slots = llListReplaceList(slots, [thisKey], (emptySlot * STRIDE) + 4, (emptySlot * STRIDE) + 4);
                    newAvatar=thisKey;
                }
                else {
                    llMessageLinked(LINK_SET, UNSIT, thisKey, NULL_KEY);
                }
            }
            if(newAvatar) {
                if(curmenuonsit == "on") {
                    llMessageLinked(LINK_SET, DOMENU_ACCESSCTRL, "", newAvatar);
                }
            }
        }
    }
    lastStrideCount = slotMax;
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(slots, "^"), NULL_KEY);
}

SwapTwoSlots(integer currentseatnum, integer newseatnum) {
    if(newseatnum <= slotMax) {
        integer slotNum;
        integer OldSlot;
        integer NewSlot;
        for(; slotNum < slotMax; ++slotNum) {
            integer z = llSubStringIndex(llList2String(slots, slotNum*8+7), "§");
            string strideSeat = llGetSubString(llList2String(slots, slotNum * 8+7), z+1,-1);
            if(strideSeat == "seat" + (string)(currentseatnum)) {
                OldSlot= slotNum;
            }
            if(strideSeat == "seat" + (string)(newseatnum)) {
                NewSlot= slotNum;
            }
        }

        list curslot = llList2List(slots, NewSlot*STRIDE, NewSlot*STRIDE+3)
                + [llList2Key(slots, OldSlot*STRIDE+4)]
                + llList2List(slots, NewSlot*STRIDE+5, NewSlot*STRIDE+7);
        slots = llListReplaceList(slots, llList2List(slots, OldSlot*STRIDE, OldSlot*STRIDE+3)
                + [llList2Key(slots, NewSlot*STRIDE+4)]
                + llList2List(slots, OldSlot*STRIDE+5, OldSlot*STRIDE+7), OldSlot*STRIDE, (OldSlot+1)*STRIDE-1);

        slots = llListReplaceList(slots, curslot, NewSlot*STRIDE, (NewSlot+1)*STRIDE-1);
    }
    else {
        llRegionSayTo(llList2Key(slots, llListFindList(slots, ["seat"+(string)currentseatnum])-4),
             0, "Seat "+(string)newseatnum+" is not available for this pose set");
    }
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(slots, "^"), NULL_KEY);
}

ProcessLine(string sLine, key av, string ncName, string menuName) {
    list paramsOriginal = llParseStringKeepNulls(sLine, ["|"], []);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%AVKEY%"], []), av);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%CARDNAME%"], []), ncName);
//    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%MENUNAME%"], []), menuName);
    list params = llParseStringKeepNulls(sLine, ["|"], []);
    string action = llList2String(params, 0);
    integer slotNumber;
    if(action == "ANIM") {
        if(slotMax<lastStrideCount) {
            slots = llListReplaceList(slots, [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), llList2Key(slots, (slotMax)*STRIDE+4),
                 "", "",llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(slotMax+1)], (slotMax)*STRIDE, (slotMax)*STRIDE+7);
        }
        else {
            slots += [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), "", "", "",
                llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(slotMax+1)]; 
        }
        slotMax++;
    }
    else if (action == "SCHMO" || action == "SCHMOE") {
        /*This changes the animation of a single sitter without affectiong any of the other animations.

        The syntax is as follows:
        SCHMO|seat#[|animation[|<0,0,0>[|<0,0,0>[|facial[|seat name]]]]]
        SCHMOE|seat#[|animation[|<0,0,0>[|<0,0,0>[|facial[|seat name]]]]]

        seat# = number value of the seat to be replaced.
        animation = inventory name of animation
        seat name = How the seat is named in the change seat menu if no one is sitting in that spot
        
        Since this function only replaces seats and does not add them there should be a DEFAULT: set defining the amount of seats available.
        When multiple SCHMO lines are in the same notecard, only the menu users' seats will change.
        When multiple SCHMOE lines are in the same notecard, all seats will change.
        */
        integer slotNumber = (integer)llList2String(params,1)-1;
        if(slotNumber * STRIDE < llGetListLength(slots)) { //sanity
            if(action == "SCHMOE" || (action == "SCHMO" && llList2Key(slots, slotNumber * STRIDE + 4) == av)) {
                integer index=2;
                integer length=llGetListLength(params);
                for(; index<length; index++) {
                    if(index==2) {
                        slots=llListReplaceList(slots, [llList2String(params, index)],
                         slotNumber * STRIDE, slotNumber * STRIDE);
                        //Clear out the SATMSG/NOTSATMSG. If we need them, we must add them back in the NC
                        slots=llListReplaceList(slots, ["",""],
                         slotNumber * STRIDE + 5, slotNumber * STRIDE + 6);
                    }
                    else if(index==3) {
                        slots=llListReplaceList(slots, [(vector)llList2String(params, index)],
                         slotNumber * STRIDE + 1, slotNumber * STRIDE + 1);
                    }
                    else if(index==4) {
                        slots=llListReplaceList(slots, [llEuler2Rot((vector)llList2String(params, index) * DEG_TO_RAD)],
                         slotNumber * STRIDE + 2, slotNumber * STRIDE + 2);
                    }
                    if(index==5) {
                        slots=llListReplaceList(slots, [llList2String(params, index)],
                         slotNumber * STRIDE + 3, slotNumber * STRIDE + 3);
                    }
                    else if(index==6) {
                        slots=llListReplaceList(slots, [llList2String(params, index) + "§seat" + (string)(slotNumber+1)],
                         slotNumber * STRIDE + 7, slotNumber * STRIDE + 7);
                    }
                }
            }
        }
        slotMax = lastStrideCount;
    }
    else if (action == "PROP") {
        string obj = llList2String(params, 1);
        if(llGetInventoryType(obj) == INVENTORY_OBJECT) {
            list strParm2 = llParseString2List(llList2String(params, 2), ["="], []);
            if(llList2String(strParm2, 1) == "die") {
                llRegionSay(chatchannel,llList2String(strParm2,0)+"=die");
            }
            else {
                explicitFlag = 0;
                if(llList2String(params, 4) == "explicit") {
                    explicitFlag = 1;
                }
                //This flag will keep the prop from chatting out it's moves. Some props should move but not spam owner.
                if(llList2String(params, 5) == "quiet") {
                    explicitFlag += 2;
                }
//                propsRezzing += [explicitFlag];
                vector vDelta = (vector)llList2String(params, 2);
                vector pos = llGetPos() + (vDelta * llGetRot());
                rotation rot = llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD) * llGetRot();
                if(llVecMag(vDelta) > 9.9) {
                    //too far to rez it direct.  need to do a prop move
                    llRezAtRoot(obj, llGetPos(), ZERO_VECTOR, rot, (chatchannel << 2) + explicitFlag);
                    llSleep(1.0);
                    llRegionSay(chatchannel, llDumpList2String(["MOVEPROP", obj, (string)pos], "|"));
                }
                else {
                    llRezAtRoot(obj, llGetPos() + ((vector)llList2String(params, 2) * llGetRot()),
                     ZERO_VECTOR, rot, (chatchannel << 2) + explicitFlag);
                }
            }
        }
    }
    else if(action=="PAUSE") {
        llSleep((float)llList2String(params, 1));
    }
    else if(action == "LINKMSG") {
        integer num = (integer)llList2String(params, 1);
        key lmid;
        if((key)llList2String(params, 3) != "") {
            lmid = (key)llList2String(params, 3);
        }
        else {
            lmid = av;
        }
        llMessageLinked(LINK_SET, num, llList2String(params, 2), lmid);
        llSleep((float)llList2String(params, 4));
        llRegionSay(chatchannel, llDumpList2String(["LINKMSG",num,llList2String(params, 2),lmid], "|"));
    }
    else if (action == "SATMSG") {
        integer index = (slotMax - 1) * STRIDE + 5;
        if((integer)llList2String(paramsOriginal, 4) >= 1) {
            index = (((integer)llList2String(paramsOriginal, 4) + -1) * STRIDE + 5);
        }
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|")], "§")], index, index);
    }
    else if (action == "NOTSATMSG") {
        integer index = (slotMax - 1) * STRIDE + 6;
        if((integer)llList2String(paramsOriginal, 4) >= 1) {
            index = (((integer)llList2String(paramsOriginal, 4) + -1) * STRIDE + 6);
        }
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|")], "§")], index, index);
    }
}

default{
    state_entry() {
        integer n;
        for(; n<=llGetNumberOfPrims(); ++n) {
           llLinkSitTarget(n,<0.0,0.0,0.5>,ZERO_ROTATION);
        }
        chatchannel = (integer)("0x7F" + llGetSubString((string)llGetKey(), 0, 4));
//        chatchannel = (integer)("0x" + llGetSubString((string)llGetKey(), 0, 7));
        llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
        integer listener = llListen(chatchannel, "", "", "");
        //the nPose Menu will do the same, so this should basically only run if there is no nPose menu script in this build
        //but currently we don't check this, so at the startup the DOPOSE|DEFAULT will happen twice
        integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
        for(n = 0; n < stop; n++) {
            string cardName = llGetInventoryName(INVENTORY_NOTECARD, n);
            if((llSubStringIndex(cardName, DEFAULT_PREFIX) == 0) || (llSubStringIndex(cardName, CARD_PREFIX) == 0)) {
                llSleep(1.0); //be sure that the NC reader script finished resetting
                llMessageLinked(LINK_SET, DOPOSE, cardName, NULL_KEY);
                return;
            }
        }
    }
    link_message(integer sender, integer num, string str, key id) {
        if(num == REQUEST_CHATCHANNEL) {//slave has asked me to reset so it can get the chatchannel from me.
            llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
        }
        else if(num == DOPOSE_READER || num == DOACTION_READER) {
            list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
            str = "";
            //allData: [ncName, alias, placeholder (currenly not used), contentLine1, contentLine2, ...]
            string ncName=llList2String(allData, 0);
            string menuName=llList2String(allData, 1);
            
            if(num==DOPOSE_READER) {
                lastStrideCount = slotMax;
                slotMax = 0;
                llRegionSay(chatchannel, "die");
            }
            integer length=llGetListLength(allData);
            integer index=3;
            integer run_assignSlots;
            for(; index<length; index++) {
                string data = llList2String(allData, index);
                if(num==DOACTION_READER && (llSubStringIndex(data, "ANIM") != 0)) {
                    ProcessLine(llList2String(allData, index), id, ncName, menuName);
                    if(!llSubStringIndex(data, "SCHMOE") || !llSubStringIndex(data, "SCHMO")) {
                        run_assignSlots = TRUE;
                    }
//                }else if ((num==DOPOSE_READER) && (llSubStringIndex(data, "SCHMO") != 0 || llSubStringIndex(data, "SCHMOE") != 0)) {
                }
                else if (num==DOPOSE_READER) {
                    ProcessLine(llList2String(allData, index), id, ncName, menuName);
                    run_assignSlots = TRUE;
                }
            }
            if(run_assignSlots) {
                assignSlots();
                if (llGetInventoryType(ncName) == INVENTORY_NOTECARD){ //sanity
                    lastAssignSlotsCardName=ncName;
                    lastAssignSlotsCardId=llGetInventoryKey(lastAssignSlotsCardName);
                    lastAssignSlotsAvatarId=id;
                }
                if(rezadjusters) {
                    //card has been read and we want to have adjusters, send message to slave script.
                    llMessageLinked(LINK_SET, REZ_ADJUSTERS, "RezAdjuster", "");
                }
            }
        }
        else if(num == ADJUST) { 
            rezadjusters = TRUE;
        }
        else if(num == STOPADJUST) { 
            rezadjusters = FALSE;
        }
        else if(num == CORERELAY) {
            list msg = llParseString2List(str, ["|"], []);
            if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
            llRegionSay(chatchannel,llDumpList2String(["LINKMSG", num, (string)llList2String(msg, 0),
                llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
        }
        else if (num == SWAP) {
            //swap the two slots
            //usage LINKMSG|202|1,2
            if(llGetListLength(slots)/STRIDE >= 2) {
                list seats2Swap = llCSV2List(str);
                SwapTwoSlots((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
            }
        }
        else if(num == SWAPTO) {
            //move clicker to a new seat#
            //new seat# occupant will then occupy the old seat# of menu user.
            //usage:  LINKMSG|210|3  Will swap menu user to seat3 and seat3 occupant moves to existing menu user's seat#
            //this is intended as an internal call for ChangeSeat button but can be used by any plugin, LINKMSG, or SAT/NOTSATMSG
            integer slotIndex = llListFindList(slots, [id]);
            integer z = llSubStringIndex(llList2String(slots, slotIndex + 3), "§");
            string strideSeat = llGetSubString(llList2String(slots, slotIndex + 3), z+1,-1);
            integer oldseat = (integer)llGetSubString(strideSeat, 4,-1);
            if (oldseat <= 0) {
                llWhisper(0, "avatar is not assigned a slot: " + (string)id);
            }else{ 
                    SwapTwoSlots(oldseat, (integer)str); 
            }
        }
        else if (num == (SEAT_UPDATE + 2000000)) {
            //slave sent slots list after adjuster moved the AV.  we need to keep our slots list up to date. replace slots list
            list tempList = llParseStringKeepNulls(str, ["^"], []);
            integer listStop = llGetListLength(tempList)/STRIDE;
            integer slotNum;
            for(; slotNum < listStop; ++slotNum) {
                slots = llListReplaceList(slots, [llList2String(tempList, slotNum*STRIDE), (vector)llList2String(tempList, slotNum*STRIDE+1),
                 (rotation)llList2String(tempList, slotNum*STRIDE+2), llList2String(tempList, slotNum*STRIDE+3),
                 (key)llList2String(tempList, slotNum*STRIDE+4), llList2String(tempList, slotNum*STRIDE+5), 
                 llList2String(tempList, slotNum*STRIDE+6), llList2String(tempList, slotNum*STRIDE+7)], slotNum*STRIDE, slotNum*STRIDE + 7);
            }
            slotMax = listStop;
        }
        else if(num == HUD_REQUEST) {
            if(llGetInventoryType(ADMIN_HUD_NAME)!=INVENTORY_NONE && str == "RezHud") {
                llRezObject(ADMIN_HUD_NAME, llGetPos() + <0,0,1>, ZERO_VECTOR, llGetRot(), chatchannel);
            }
            else if(num == HUD_REQUEST && str == "RemoveHud") {
                llRegionSayTo(hudId, chatchannel, "/die");
            }
        }
        else if(num==OPTIONS) {
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer length = llGetListLength(optionsToSet);
            integer index;
            for(; index<length; index++) {
                list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionSetting = llStringTrim(llList2String(optionsItems, 1), STRING_TRIM);
                if(optionItem == "menuonsit") {
                    curmenuonsit = optionSetting;
                }
            }
        }
        else if(num == MEMORY_USAGE) {
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
             + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
//        list details = llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME]));
        llSay(0, "running script time for all scripts in this nPose object are consuming " 
         + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0)*1000.0) + " ms of cpu time");
        }
    }

    object_rez(key id) {
        if(llKey2Name(id) == ADMIN_HUD_NAME) {
            hudId = id;
            llSleep(2.0);
            llRegionSayTo(hudId, chatchannel, "parent|"+(string)llGetKey());
        }
    }

    listen(integer channel, string name, key id, string message) {
        list temp = llParseString2List(message, ["|"], []);
        if(name == "Adjuster") {
            llMessageLinked(LINK_SET, ADJUSTER_REPORT, message, id);
        }
        else if(llGetListLength(temp) >= 2 || llGetSubString(message,0,4) == "ping" || llGetSubString(message,0,8) == "PROPRELAY") {
            if(llGetOwnerKey(id) == llGetOwner()) {
                if(message == "ping") {
//                    explicitFlag = llList2Integer(propsRezzing, 0);
//                    propsRezzing = llDeleteSubList(propsRezzing, 0, 0);
                    llRegionSayTo(id, chatchannel, "pong|"+(string)explicitFlag + "|" + (string)llGetPos());
                }
                else if(llGetSubString(message,0,8) == "PROPRELAY") {
                    list msg = llParseString2List(message, ["|"], []);
                    llMessageLinked(LINK_SET,llList2Integer(msg,1),llList2String(msg,2),llList2Key(msg,3));
                }
                else if(name == "pos_adjuster_hud") {
                }
                else {
                    list params = llParseString2List(message, ["|"], []);
                    vector newpos = (vector)llList2String(params, 0) - llGetPos();
                    newpos = newpos / llGetRot();
                    rotation newrot = (rotation)llList2String(params, 1) / llGetRot();
                    llRegionSayTo(llGetOwner(), 0, "\nPROP|" + name + "|" + (string)newpos + "|" + (string)(llRot2Euler(newrot) * RAD_TO_DEG)
                     + "|" + llList2String(params, 2));
                    llMessageLinked(LINK_SET, SLOT_UPDATE, "PROP|" + name + "|" + (string)newpos + "|" +
                        (string)(llRot2Euler(newrot) * RAD_TO_DEG), NULL_KEY); 

                }
            }
        }
        else if(name == llKey2Name(hudId)) {
            //need to process hud commands
            if(message == "adjust") {
                llMessageLinked(LINK_SET, ADJUST, "", "");
            }
            else if(message == "stopadjust") {
                llMessageLinked(LINK_SET, STOPADJUST, "", "");
            }
            else if(message == "posdump") {
                llMessageLinked(LINK_SET, DUMP, "", "");
            }
            else if(message == "hudsync") {
                llMessageLinked(LINK_SET, SYNC, "", "");
            }
        }
    }

    changed(integer change) {
        if(change & CHANGED_INVENTORY) {
            if(llGetInventoryType(lastAssignSlotsCardName) == INVENTORY_NOTECARD) {
                if(lastAssignSlotsCardId!=llGetInventoryKey(lastAssignSlotsCardName)) {
                    //the last used nc changed, "redo" the nc
                    llSleep(1.0); //be sure that the NC reader script finished resetting
                    llMessageLinked(LINK_SET, DOPOSE, lastAssignSlotsCardName, lastAssignSlotsAvatarId); 
                }
                else {
                    llResetScript();
                }
            }
            else {
                llResetScript();
            }
        }
        if(change & CHANGED_LINK) {
            llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
            assignSlots();
        }
        if(change & CHANGED_REGION) {
            llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(slots, "^"), NULL_KEY);
        }
    }
    
    on_rez(integer param) {
        llResetScript();
    }
}

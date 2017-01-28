/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/

string INIT_CARD_NAME=".init";
string DefaultCardName;

//define block start
#define ADMIN_HUD_NAME "npose admin hud"
#define STRIDE 8
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
#define PREPARE_MENU_STEP3_READER 221
#define DOPOSE_READER 222
#define DOBUTTON_READER 223
#define CORERELAY 300
#define PLUGIN_COMMAND_REGISTER 310
#define UNKNOWN_COMMAND 311
#define UNSIT -222
#define OPTIONS -240
#define DEFAULT_CARD -242
#define ON_PROP_REZZED -790
#define DOMENU -800
#define UDPBOOL -804
#define UDPLIST -805
#define MACRO -807
#define PLUGIN_MENU_REGISTER -810
#define MENU_SHOW -815
#define PREPARE_MENU_STEP1 -820
#define PREPARE_MENU_STEP2 -821

#define PLUGIN_ACTION_DONE -831
#define DIALOG_TIMEOUT -902
#define HUD_REQUEST -999
//define block end

integer SlotMax;
integer LastStrideCount = 12;
integer RezAdjusters;
integer ChatChannel;
integer ExplicitFlag;
key HudId;
string LastAssignSlotsCardName;
key LastAssignSlotsCardId;
key LastAssignSlotsAvatarId;
list Slots;  //one STRIDE = [animationName, posVector, rotVector, facials, sitterKey, SATMSG, NOTSATMSG, seatName]

integer CurMenuOnSit; //default menuonsit option
integer Cur2default;  //default action to revert back to default pose when last sitter has stood

string NC_READER_CONTENT_SEPARATOR="%&§";

list PluginCommands=[
    "PLUGINCOMMAND", PLUGIN_COMMAND_REGISTER,
    "DEFAULTCARD", DEFAULT_CARD,
    "OPTION", OPTIONS,
    "UDPBOOL", UDPBOOL,
    "UDPLIST", UDPLIST,
    "MACRO", MACRO
];


integer FindEmptySlot() {
    integer n;
    for(; n < SlotMax; ++n) {
        if(llList2String(Slots, n*STRIDE+4) == "") {
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
    /*clean up the Slots list with regard to AV key's in the list by
    removing extra AV keys from the Slots list, they are no longer seated.
    */
    integer x;
    integer n;
    for(; x < SlotMax; ++x) {
        //look in the avqueue for the key in the Slots list
        if(!~llListFindList(avqueue, [llList2Key(Slots, x*STRIDE+4)])) {
            //if the key is not in the avqueue, remove it from the Slots list
            Slots = llListReplaceList(Slots, [""], x*STRIDE+4, x*STRIDE+4);
        }
    }
    //we need to check if less seats are available, more seats would not need slots assigned at this point, they just empty seats.
    if(SlotMax < LastStrideCount) {
        //new pose set has less seats available
        //AV's that were in a available seats are already assigned so leave them be
        for(x = SlotMax; x <= LastStrideCount; ++x) {//only need to worry about the 'extra' slots so limit the count
            if(llList2Key(Slots, x*STRIDE+4) != "") {
                //this is a 'now' extra sitter
                integer emptySlot = FindEmptySlot();//find an empty slot for them if available
                if((emptySlot >= 0) && (emptySlot < SlotMax)) {
                    //if a real seat available, seat them
                    Slots = llListReplaceList(Slots, [llList2Key(Slots, x*STRIDE+4)], emptySlot*STRIDE+4, emptySlot*STRIDE+4);
                }
            }
        }
        //remove the 'now' extra seats from Slots list
        Slots = llDeleteSubList(Slots, (SlotMax)*STRIDE, -1);
        //unsit extra seated AV's
        for(; n<llGetListLength(avqueue); ++n) {
            if(!~llListFindList(Slots, [llList2Key(avqueue, n)])) {
                llMessageLinked(LINK_SET, UNSIT, llList2String(avqueue, n), NULL_KEY);
            }
        }
    }
    //step through the avqueue list and check if everyone is accounted for
    //newest sitters last in avqueue list so step through increamentally
    integer nn;
    for(; nn<llGetListLength(avqueue); ++nn) {
        key thisKey = llList2Key(avqueue, nn);
        integer index = llListFindList(Slots, [llList2Key(avqueue, nn)]);
        integer emptySlot = FindEmptySlot();
        if(!~index) {
            //this AV not in Slots list
            key newAvatar;
            //check if they on a numbered seat
            integer slotNum=-1;
            for(n = 1; n <= llGetObjectPrimCount(llGetKey()); ++n) {
                //find out which prim this new AV is seated on and grab the slot number if it's a numbered prim.
                integer x = (integer)llGetSubString(llGetLinkName(n), 4, -1);
                if((x > 0) && (x <= SlotMax)) {
                    if(llAvatarOnLinkSitTarget(n) == thisKey) {
                        if(llList2String(Slots, (x-1)*STRIDE+4) == "") {
                            slotNum = (integer)llGetLinkName(n);
                            Slots = llListReplaceList(Slots, [thisKey], (slotNum-1)*STRIDE+4, (slotNum-1)*STRIDE+4);
                            newAvatar=thisKey;
                        }
                    }
                }
            }
            if(!~llListFindList(Slots, [thisKey])) {
                if(~emptySlot) {
                    //they not on numbered seat so grab the lowest available seat for them, we have one available
                    Slots = llListReplaceList(Slots, [thisKey], (emptySlot * STRIDE) + 4, (emptySlot * STRIDE) + 4);
                    newAvatar=thisKey;
                }
                else {
                    llMessageLinked(LINK_SET, UNSIT, thisKey, NULL_KEY);
                }
            }
            if(newAvatar) {
                if(CurMenuOnSit) {
                    llMessageLinked(LINK_SET, DOMENU, "", newAvatar);
                }
            }
        }
    }
    LastStrideCount = SlotMax;
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
}

SwapTwoSlots(integer currentseatnum, integer newseatnum) {
    if(newseatnum <= SlotMax) {
        integer slotNum;
        integer OldSlot;
        integer NewSlot;
        for(; slotNum < SlotMax; ++slotNum) {
            integer z = llSubStringIndex(llList2String(Slots, slotNum*8+7), "§");
            string strideSeat = llGetSubString(llList2String(Slots, slotNum * 8+7), z+1,-1);
            if(strideSeat == "seat" + (string)(currentseatnum)) {
                OldSlot= slotNum;
            }
            if(strideSeat == "seat" + (string)(newseatnum)) {
                NewSlot= slotNum;
            }
        }

        list curslot = llList2List(Slots, NewSlot*STRIDE, NewSlot*STRIDE+3)
                + [llList2Key(Slots, OldSlot*STRIDE+4)]
                + llList2List(Slots, NewSlot*STRIDE+5, NewSlot*STRIDE+7);
        Slots = llListReplaceList(Slots, llList2List(Slots, OldSlot*STRIDE, OldSlot*STRIDE+3)
                + [llList2Key(Slots, NewSlot*STRIDE+4)]
                + llList2List(Slots, OldSlot*STRIDE+5, OldSlot*STRIDE+7), OldSlot*STRIDE, (OldSlot+1)*STRIDE-1);

        Slots = llListReplaceList(Slots, curslot, NewSlot*STRIDE, (NewSlot+1)*STRIDE-1);
    }
    else {
        llRegionSayTo(llList2Key(Slots, llListFindList(Slots, ["seat"+(string)currentseatnum])-4),
             0, "Seat "+(string)newseatnum+" is not available for this pose set");
    }
    llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
}

string insertPlaceholder(string sLine, key av, string ncName, string path, integer page) {
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%CARDNAME%"], []), ncName);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%AVKEY%"], []), av);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%PATH%"], []), path);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%PAGE%"], []), (string)page);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%DISPLAYNAME%"], []), llGetDisplayName(av));
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%USERNAME%"], []), llGetUsername(av));
    return sLine;
}

ProcessLine(string sLine, key av, string ncName, string path, integer page) {
    list paramsOriginal = llParseStringKeepNulls(sLine, ["|"], []);
    sLine=insertPlaceholder(sLine, av, ncName, path, page);
    list params = llParseStringKeepNulls(sLine, ["|"], []);
    string action = llList2String(params, 0);
    integer slotNumber;
    if(action == "ANIM") {
        if(SlotMax<LastStrideCount) {
            Slots = llListReplaceList(Slots, [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), llList2Key(Slots, (SlotMax)*STRIDE+4),
                 "", "",llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(SlotMax+1)], (SlotMax)*STRIDE, (SlotMax)*STRIDE+7);
        }
        else {
            Slots += [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), "", "", "",
                llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(SlotMax+1)]; 
        }
        SlotMax++;
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
        if(slotNumber * STRIDE < llGetListLength(Slots)) { //sanity
             if(action == "SCHMOE" || (action == "SCHMO" && llList2Key(Slots, slotNumber * STRIDE + 4) == av)) {
                integer index=2;
                integer length=llGetListLength(params);
                for(; index<length; index++) {
                    if(index==2) {
                        Slots=llListReplaceList(Slots, [llList2String(params, index)],
                            slotNumber * STRIDE, slotNumber * STRIDE);
                        //Clear out the SATMSG/NOTSATMSG. If we need them, we must add them back in the NC
                        Slots=llListReplaceList(Slots, ["",""],
                        slotNumber * STRIDE + 5, slotNumber * STRIDE + 6);
                    }
                    else if(index==3) {
                        Slots=llListReplaceList(Slots, [(vector)llList2String(params, index)],
                            slotNumber * STRIDE + 1, slotNumber * STRIDE + 1);
                    }
                    else if(index==4) {
                        Slots=llListReplaceList(Slots, [llEuler2Rot((vector)llList2String(params, index) * DEG_TO_RAD)],
                            slotNumber * STRIDE + 2, slotNumber * STRIDE + 2);
                    }
                    if(index==5) {
                        Slots=llListReplaceList(Slots, [llList2String(params, index)],
                            slotNumber * STRIDE + 3, slotNumber * STRIDE + 3);
                    }
                    else if(index==6) {
                        Slots=llListReplaceList(Slots, [llList2String(params, index) + "§seat" + (string)(slotNumber+1)],
                            slotNumber * STRIDE + 7, slotNumber * STRIDE + 7);
                    }
                }
            }
        }
        SlotMax = LastStrideCount;
    }
    else if (action == "PROP") {
        string obj = llList2String(params, 1);
        if(llGetInventoryType(obj) == INVENTORY_OBJECT) {
            list strParm2 = llParseString2List(llList2String(params, 2), ["="], []);
            if(llList2String(strParm2, 1) == "die") {
                llRegionSay(ChatChannel,llList2String(strParm2,0)+"=die");
            }
            else {
                ExplicitFlag = 0;
                if(llList2String(params, 4) == "explicit") {
                    ExplicitFlag = 1;
                }
                //This flag will keep the prop from chatting out it's moves. Some props should move but not spam owner.
                if(llList2String(params, 5) == "quiet") {
                    ExplicitFlag += 2;
                }
                vector vDelta = (vector)llList2String(params, 2);
                vector pos = llGetPos() + (vDelta * llGetRot());
                rotation rot = llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD) * llGetRot();
                integer sendToPropChannel = (ChatChannel << 8);
                sendToPropChannel = sendToPropChannel | ExplicitFlag;
                if(llVecMag(vDelta) > 9.9) {
                    //too far to rez it direct.  need to do a prop move
                    llRezAtRoot(obj, llGetPos(), ZERO_VECTOR, rot, sendToPropChannel);
                    llSleep(1.0);
                    llRegionSay(ChatChannel, llDumpList2String(["MOVEPROP", obj, (string)pos], "|"));
                }
                else {
                    llRezAtRoot(obj, llGetPos() + ((vector)llList2String(params, 2) * llGetRot()),
                     ZERO_VECTOR, rot, sendToPropChannel);
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
        llRegionSay(ChatChannel, llDumpList2String(["LINKMSG",num,llList2String(params, 2),lmid], "|"));
    }
    else if (action == "SATMSG") {
        //set index for normal (we building Slots list) cards containing ANIM or SCHMOE lines
        integer index = (SlotMax - 1) * STRIDE + 5;
        //change that index if we have SCHMO lines
        if((integer)llList2String(paramsOriginal, 4) >= 1) {
            index = (((integer)llList2String(paramsOriginal, 4) + -1) * STRIDE + 5);
        }
        Slots = llListReplaceList(
            Slots,
            [llDumpList2String([llList2String(Slots,index), llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|")], "§")],
            index,
            index
        );
    }
    else if (action == "NOTSATMSG") {
        //set index for normal (we building Slots list) cards containing ANIM or SCHMOE lines
        integer index = (SlotMax - 1) * STRIDE + 6;
        //change that index if we have SCHMO lines
        if((integer)llList2String(paramsOriginal, 4) >= 1) {
            index = (((integer)llList2String(paramsOriginal, 4) + -1) * STRIDE + 6);
        }
        Slots = llListReplaceList(
            Slots,
            [llDumpList2String([llList2String(Slots,index), llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|")], "§")],
            index,
            index
        );
    }
    else if(action == "PLUGINMENU") {
        llMessageLinked(LINK_SET, PLUGIN_MENU_REGISTER, llDumpList2String(llListReplaceList(params, [path], 0, 0), "|"), "");
    }
    else {
        integer index=llListFindList(PluginCommands, [action]);
        if(~index) {
            integer num=llList2Integer(PluginCommands, index+1);
            llMessageLinked(LINK_SET, num, llDumpList2String(llDeleteSubList(params, 0, 0), "|"), "");
        }
        else {
            llMessageLinked(LINK_SET, UNKNOWN_COMMAND, sLine, av);
        }
    }
}

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


default{
    state_entry() {
        integer n;
        for(; n<=llGetNumberOfPrims(); ++n) {
           llLinkSitTarget(n,<0.0,0.0,0.5>,ZERO_ROTATION);
        }
        ChatChannel = (integer)("0x7F" + llGetSubString((string)llGetKey(), 0, 5));
        //let our scripts know the chat channel for props and adjusters
        llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)ChatChannel, NULL_KEY);
        integer listener = llListen(ChatChannel, "", "", "");
        
        if(llGetInventoryType(INIT_CARD_NAME)==INVENTORY_NOTECARD) {
            llSleep(1.0); //be sure that the NC reader script finished resetting
            llMessageLinked(LINK_SET, DOPOSE, INIT_CARD_NAME, NULL_KEY);
        }
        else {
            //this is the old default notcard detection.
            integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
            for(n = 0; n < stop; n++) {
                string cardName = llGetInventoryName(INVENTORY_NOTECARD, n);
                if((llSubStringIndex(cardName, DEFAULT_PREFIX) == 0) || (llSubStringIndex(cardName, CARD_PREFIX) == 0)) {
                    llSleep(1.0); //be sure that the NC reader script finished resetting
                    llMessageLinked(LINK_SET, DEFAULT_CARD, cardName, NULL_KEY);
                    return;
                }
            }
        }
    }
    link_message(integer sender, integer num, string str, key id) {
        if(num == REQUEST_CHATCHANNEL) {//slave has asked me to reset so it can get the ChatChannel from me.
            //let our scripts know the chat channel for props and adjusters
            llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)ChatChannel, NULL_KEY);
        }
        else if(num == DOPOSE_READER || num == DOBUTTON_READER || num==PREPARE_MENU_STEP3_READER) {
            list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
            str = "";
            //allData: [ncName, paramSet1, "", contentLine1, contentLine2, ...]
            string ncName=llList2String(allData, 0);
            list paramSet1List=llParseStringKeepNulls(llList2String(allData, 1), ["|"], []);
            string path=llList2String(paramSet1List, 0);
            integer page=(integer)llList2String(paramSet1List, 1);
            string prompt=llList2String(paramSet1List, 2);
            
            //parse the NC content
            integer length=llGetListLength(allData);
            integer index=3;
            integer run_assignSlots;
            integer slotResetFinished;
            for(; index<length; index++) {
                string data = llList2String(allData, index);
                if(num!=PREPARE_MENU_STEP3_READER) {
                    if(!llSubStringIndex(data, "ANIM") && !slotResetFinished) {
                        //reset the slots
                        LastStrideCount = SlotMax;
                        SlotMax = 0;
                        //handle the Adjuster
                        llRegionSay(ChatChannel, "die");
                        slotResetFinished=TRUE;
                        run_assignSlots = TRUE;
                    }
                    if(!llSubStringIndex(data, "SCHMO")) { //finds SCHMO and SCHMOE
                        run_assignSlots = TRUE;
                    }
                    ProcessLine(llList2String(allData, index), id, ncName, path, page);
                }
                else {
                    //get all menu relevant data
                    if(!llSubStringIndex(data, "MENU")) {
                        list parts=llParseStringKeepNulls(insertPlaceholder(data, id, ncName, path, page), ["|"], []);
                        string cmd=llList2String(parts, 0);
                        if(cmd=="MENUPROMPT") {
                            prompt=llList2String(parts, 1);
                            //"\n" are escaped in NC content
                            prompt=llDumpList2String(llParseStringKeepNulls(prompt, ["\\n"], []), "\n");
                        }
                    }
                }
            }
            if(run_assignSlots) {
                assignSlots();
                if (llGetInventoryType(ncName) == INVENTORY_NOTECARD){ //sanity
                    LastAssignSlotsCardName=ncName;
                    LastAssignSlotsCardId=llGetInventoryKey(LastAssignSlotsCardName);
                    LastAssignSlotsAvatarId=id;
                }
                if(RezAdjusters) {
                    //card has been read and we want to have adjusters, send message to slave script.
                    llMessageLinked(LINK_SET, REZ_ADJUSTERS, "RezAdjuster", "");
                }
            }
            if(path!="") {
                //only try to remenu if there are parameters to do so
                string paramSet1=buildParamSet1(path, page, prompt, [llList2String(paramSet1List, 3)], llList2List(paramSet1List, 4, 7));
                if(num==PREPARE_MENU_STEP3_READER) {
                    //we are ready to show the menu
                    llMessageLinked(LINK_SET, MENU_SHOW, paramSet1, id);
                }
                else if(num==DOPOSE_READER || DOBUTTON_READER) {
                    llMessageLinked(LINK_SET, PREPARE_MENU_STEP1, paramSet1, id);
                }
            }
        }
        else if(num==PLUGIN_ACTION_DONE) {
            //only relay through the core to keep messages in sync
            llMessageLinked(LINK_SET, PREPARE_MENU_STEP2, str, id);
        }
        else if(num == ADJUST) { 
            RezAdjusters = TRUE;
        }
        else if(num == STOPADJUST) { 
            RezAdjusters = FALSE;
        }
        else if(num == CORERELAY) {
            list msg = llParseString2List(str, ["|"], []);
            if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
            llRegionSay(ChatChannel,llDumpList2String(["LINKMSG", (string)llList2String(msg, 0),
                llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
        }
        else if (num == SWAP) {
            //swap the two slots
            //usage LINKMSG|202|1,2
            if(llGetListLength(Slots)/STRIDE >= 2) {
                list seats2Swap = llCSV2List(str);
                SwapTwoSlots((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
            }
        }
        else if(num == SWAPTO) {
            //move clicker to a new seat#
            //new seat# occupant will then occupy the old seat# of menu user.
            //usage:  LINKMSG|210|3  Will swap menu user to seat3 and seat3 occupant moves to existing menu user's seat#
            //this is intended as an internal call for ChangeSeat button but can be used by any plugin, LINKMSG, or SAT/NOTSATMSG
            integer slotIndex = llListFindList(Slots, [id]);
            integer z = llSubStringIndex(llList2String(Slots, slotIndex + 3), "§");
            string strideSeat = llGetSubString(llList2String(Slots, slotIndex + 3), z+1,-1);
            integer oldseat = (integer)llGetSubString(strideSeat, 4,-1);
            if (oldseat <= 0) {
                llWhisper(0, "avatar is not assigned a slot: " + (string)id);
            }
            else{ 
                SwapTwoSlots(oldseat, (integer)str); 
            }
        }
        else if (num == (SEAT_UPDATE + 2000000)) {
            //slave sent Slots list after adjuster moved the AV.  we need to keep our Slots list up to date. replace Slots list
            list tempList = llParseStringKeepNulls(str, ["^"], []);
            str = "";
            integer listStop = llGetListLength(tempList)/STRIDE;
            integer slotNum;
            for(; slotNum < listStop; ++slotNum) {
                Slots = llListReplaceList(Slots, [llList2String(tempList, slotNum*STRIDE), (vector)llList2String(tempList, slotNum*STRIDE+1),
                 (rotation)llList2String(tempList, slotNum*STRIDE+2), llList2String(tempList, slotNum*STRIDE+3),
                 (key)llList2String(tempList, slotNum*STRIDE+4), llList2String(tempList, slotNum*STRIDE+5), 
                 llList2String(tempList, slotNum*STRIDE+6), llList2String(tempList, slotNum*STRIDE+7)], slotNum*STRIDE, slotNum*STRIDE + 7);
            }
            SlotMax = listStop;
        }
        else if(num == HUD_REQUEST) {
            if(llGetInventoryType(ADMIN_HUD_NAME)!=INVENTORY_NONE && str == "RezHud") {
                llRezObject(ADMIN_HUD_NAME, llGetPos() + <0,0,1>, ZERO_VECTOR, llGetRot(), ChatChannel);
            }
            else if(num == HUD_REQUEST && str == "RemoveHud") {
                llRegionSayTo(HudId, ChatChannel, "/die");
            }
        }
        else if(num == DEFAULT_CARD) {
            DefaultCardName=str;
            llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, id);
        }
        else if(num == PLUGIN_COMMAND_REGISTER) {
            list parts=llParseString2List(str, ["|"], []);
            string action=llList2String(parts, 0);
            integer index=llListFindList(PluginCommands, [action]);
            if(!~index) {
                PluginCommands+=[action, (integer)llList2String(parts, 1)];
            }
        }
        else if(num == DIALOG_TIMEOUT) {
            if(Cur2default && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()) && (DefaultCardName != "")) {
                llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, NULL_KEY);
            }
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

                if(optionItem == "menuonsit") {
                    CurMenuOnSit = optionSettingFlag;
                }
                else if(optionItem == "2default") {
                    Cur2default = optionSettingFlag;
                }
            }
        }
        else if(num == MEMORY_USAGE) {
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
             + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
        llSay(0, "running script time for all scripts in this nPose object are consuming " 
         + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0)*1000.0) + " ms of cpu time");
        }
    }

    object_rez(key id) {
        if(llKey2Name(id) == ADMIN_HUD_NAME) {
            HudId = id;
            llSleep(2.0);
            llRegionSayTo(HudId, ChatChannel, "parent|"+(string)llGetKey());
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
                    llRegionSayTo(id, ChatChannel, "pong|" + (string)llGetPos());
                    llMessageLinked(LINK_SET, ON_PROP_REZZED, llDumpList2String([name, id, channel], "|"), NULL_KEY);
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
                }
            }
        }
        else if(name == llKey2Name(HudId)) {
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
            if(llGetInventoryType(LastAssignSlotsCardName) == INVENTORY_NOTECARD) {
                if(LastAssignSlotsCardId!=llGetInventoryKey(LastAssignSlotsCardName)) {
                    //the last used nc changed, "redo" the nc
                    llSleep(1.0); //be sure that the NC reader script finished resetting
                    llMessageLinked(LINK_SET, DOPOSE, LastAssignSlotsCardName, LastAssignSlotsAvatarId); 
                }
            }
        }
        if(change & CHANGED_LINK) {
            llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)ChatChannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
            assignSlots();
            if(Cur2default && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()) && (DefaultCardName != "")) {
                llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, NULL_KEY);
            }
        }
        if(change & CHANGED_REGION) {
            llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
        }
    }
    
    on_rez(integer param) {
        llResetScript();
    }
}

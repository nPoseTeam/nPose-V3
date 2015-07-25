/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/


//define block start
#define adminHudName "npose admin hud"
#define stride 8
#define slotupdate 34333
#define memusage 34334
#define seatupdate 35353
#define defaultprefix "DEFAULT:"
#define cardprefix "SET:"
#define SYNC 206
#define SWAPTO 210
#define SWAP 202
#define STOPADJUST 205
#define DUMP 204
#define DOPOSE 200
#define DOACTION 207
#define DOPOSE_READER 222
#define DOACTION_READER 223
#define CORERELAY 300
#define ADJUSTOFFSET 208
#define ADJUST 201
#define OPTIONS -240
#define DOMENU_ACCESSCTRL -801
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
string lastDoPoseCardName;
string lastDoPoseAlias;
string lastDoPosePlaceholder;
key lastDoPoseCardId;
key lastDoPoseAvatarId;
list slots;  //one stride = [animationName, posVector, rotVector, facials, sitterKey, SATMSG, NOTSATMSG, seatName]

string curmenuonsit = "off"; //default menuonsit option

string NC_READER_CONTENT_SEPARATOR="℥";

integer FindEmptySlot() {
    integer n;
    for (; n < slotMax; ++n) {
        if (llList2String(slots, n*stride+4) == ""){
            return n;
        }
    }
    return -1;
}

list SeatedAvs(){
    list avs = [];
    integer n = llGetNumberOfPrims();
    for (; n >= llGetObjectPrimCount(llGetKey()); --n){
        //only check link numbers greater than the number of actual prims, these will be the AV link numbers.
        key id = llGetLinkKey(n);
        if (llGetAgentSize(id) != ZERO_VECTOR){
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
    for (; x < slotMax; ++x){
        //look in the avqueue for the key in the slots list
        if (!~llListFindList(avqueue, [llList2Key(slots, x*stride+4)])) {
            //if the key is not in the avqueue, remove it from the slots list
            slots = llListReplaceList(slots, [""], x*stride+4, x*stride+4);
        }
    }
    //we need to check if less seats are available, more seats would not need slots assigned at this point, they just empty seats.
    if (slotMax < lastStrideCount){
        //new pose set has less seats available
        //AV's that were in a available seats are already assigned so leave them be
        for (x = slotMax; x <= lastStrideCount; ++x){//only need to worry about the 'extra' slots so limit the count
            if (llList2Key(slots, x*stride+4) != ""){
                //this is a 'now' extra sitter
                integer emptySlot = FindEmptySlot();//find an empty slot for them if available
                if ((emptySlot >= 0) && (emptySlot < slotMax)){
                    //if a real seat available, seat them
                    slots = llListReplaceList(slots, [llList2Key(slots, x*stride+4)], emptySlot*stride+4, emptySlot*stride+4);
                }
            }
        }
        //remove the 'now' extra seats from slots list
        slots = llDeleteSubList(slots, (slotMax)*stride, -1);
        //unsit extra seated AV's
        for (; n<llGetListLength(avqueue); ++n){
            if (!~llListFindList(slots, [llList2Key(avqueue, n)])){
                llMessageLinked(LINK_SET, -222, llList2String(avqueue, n), NULL_KEY);
            }
        }
    }
    //step through the avqueue list and check if everyone is accounted for
    //newest sitters last in avqueue list so step through increamentally
    integer nn;
    for (; nn<llGetListLength(avqueue); ++nn){
        key thisKey = llList2Key(avqueue, nn);
        integer index = llListFindList(slots, [llList2Key(avqueue, nn)]);
        integer emptySlot = FindEmptySlot();
        if (!~index){
            //this AV not in slots list
            key newAvatar;
            //check if they on a numbered seat
            integer slotNum=-1;
            for (n = 1; n <= llGetObjectPrimCount(llGetKey()); ++n){
                //find out which prim this new AV is seated on and grab the slot number if it's a numbered prim.
                integer x = (integer)llGetSubString(llGetLinkName(n), 4, -1);
                if ((x > 0) && (x <= slotMax)){
                    if (llAvatarOnLinkSitTarget(n) == thisKey){
                        if (llList2String(slots, (x-1)*stride+4) == ""){
                            slotNum = (integer)llGetLinkName(n);
                            slots = llListReplaceList(slots, [thisKey], (slotNum-1)*stride+4, (slotNum-1)*stride+4);
                            newAvatar=thisKey;
                        }
                    }
                }
            }
            if (!~llListFindList(slots, [thisKey])){
                if (~emptySlot){
                    //they not on numbered seat so grab the lowest available seat for them, we have one available
                    slots = llListReplaceList(slots, [thisKey], (emptySlot * stride) + 4, (emptySlot * stride) + 4);
                    newAvatar=thisKey;
                }else{
                    llMessageLinked(LINK_SET, -222, thisKey, NULL_KEY);
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
    llMessageLinked(LINK_SET, seatupdate, llDumpList2String(slots, "^"), NULL_KEY);
}

SwapTwoSlots(integer currentseatnum, integer newseatnum) {
    if (newseatnum <= slotMax){
        integer slotNum;
        integer OldSlot;
        integer NewSlot;
        for (; slotNum < slotMax; ++slotNum){
            integer z = llSubStringIndex(llList2String(slots, slotNum*8+7), "§");
            string strideSeat = llGetSubString(llList2String(slots, slotNum * 8+7), z+1,-1);
            if (strideSeat == "seat" + (string)(currentseatnum)){
                OldSlot= slotNum;
            }
            if (strideSeat == "seat" + (string)(newseatnum)){
                NewSlot= slotNum;
            }
        }

        list curslot = llList2List(slots, NewSlot*stride, NewSlot*stride+3)
                + [llList2Key(slots, OldSlot*stride+4)]
                + llList2List(slots, NewSlot*stride+5, NewSlot*stride+7);
        slots = llListReplaceList(slots, llList2List(slots, OldSlot*stride, OldSlot*stride+3)
                + [llList2Key(slots, NewSlot*stride+4)]
                + llList2List(slots, OldSlot*stride+5, OldSlot*stride+7), OldSlot*stride, (OldSlot+1)*stride-1);

        slots = llListReplaceList(slots, curslot, NewSlot*stride, (NewSlot+1)*stride-1);
    }else{
        llRegionSayTo(llList2Key(slots, llListFindList(slots, ["seat"+(string)currentseatnum])-4),
             0, "Seat "+(string)newseatnum+" is not available for this pose set");
    }
    llMessageLinked(LINK_SET, seatupdate, llDumpList2String(slots, "^"), NULL_KEY);
}

ProcessLine(string sLine, key av, string ncName, string menuName){
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%AVKEY%"], []), av);
    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%CARDNAME%"], []), ncName);
//    sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%MENUNAME%"], []), menuName);
    list params = llParseStringKeepNulls(sLine, ["|"], []);
    string action = llList2String(params, 0);
    integer slotNumber;
    if (action == "ANIM"){
        if (slotMax<lastStrideCount){
            slots = llListReplaceList(slots, [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), llList2Key(slots, (slotMax)*stride+4),
                 "", "",llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(slotMax+1)], (slotMax)*stride, (slotMax)*stride+7);
        }else{
            slots += [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), "", "", "",
                llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(slotMax+1)]; 
        }
        slotMax++;
    }else if (action == "SCHMO" || action == "SCHMOE"){
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
        if(slotNumber * stride < llGetListLength(slots)) { //sanity
            if(action == "SCHMOE" || (action == "SCHMO" && llList2Key(slots, slotNumber * stride + 4) == av)) {
                integer index=2;
                integer length=llGetListLength(params);
                for(; index<length; index++) {
                    if(index==2 || index==5) {
                        slots=llListReplaceList(slots, [llList2String(params, index)],
                         slotNumber * stride + index - 2, slotNumber * stride + index - 2);
                    }
                    else if(index==3) {
                        slots=llListReplaceList(slots, [(vector)llList2String(params, index)],
                         slotNumber * stride + 1, slotNumber * stride + 1);
                    }
                    else if(index==4) {
                        slots=llListReplaceList(slots, [llEuler2Rot((vector)llList2String(params, index) * DEG_TO_RAD)],
                         slotNumber * stride + 2, slotNumber * stride + 2);
                    }
                    else if(index==6) {
                        slots=llListReplaceList(slots, [llList2String(params, index) + "§seat" + (string)(slotNumber+1)],
                         slotNumber * stride + 7, slotNumber * stride + 7);
                    }
                }
            }
        }
        slotMax = lastStrideCount;
    }else if (action == "PROP"){
        string obj = llList2String(params, 1);
        if (llGetInventoryType(obj) == INVENTORY_OBJECT){
            list strParm2 = llParseString2List(llList2String(params, 2), ["="], []);
            if (llList2String(strParm2, 1) == "die"){
                llRegionSay(chatchannel,llList2String(strParm2,0)+"=die");
            }else{
                explicitFlag = 0;
                if (llList2String(params, 4) == "explicit"){
                    explicitFlag = 1;
                }
                vector vDelta = (vector)llList2String(params, 2);
                vector pos = llGetPos() + (vDelta * llGetRot());
                rotation rot = llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD) * llGetRot();
                 if (llVecMag(vDelta) > 9.9){
                    //too far to rez it direct.  need to do a prop move
                    llRezAtRoot(obj, llGetPos(), ZERO_VECTOR, rot, chatchannel);
                    llSleep(1.0);
                    llRegionSay(chatchannel, llDumpList2String(["MOVEPROP", obj, (string)pos], "|"));
                }else{
                    llRezAtRoot(obj, llGetPos() + ((vector)llList2String(params, 2) * llGetRot()), ZERO_VECTOR, rot, chatchannel);
                }
            }
        }
    }else if(action=="PAUSE") {
        llSleep((float)llList2String(params, 1));
    }else if (action == "LINKMSG"){
        integer num = (integer)llList2String(params, 1);
        key lmid;
        if ((key)llList2String(params, 3) != ""){
            lmid = (key)llList2String(params, 3);
        }else{
            lmid = (key)llList2String(slots, (slotMax-1)*stride+4);
        }
        llMessageLinked(LINK_SET, num, llList2String(params, 2), lmid);
        llSleep((float)llList2String(params, 4));
        llRegionSay(chatchannel, llDumpList2String(["LINKMSG",num,llList2String(params, 2),lmid], "|"));
    }else if (action == "SATMSG"){
        integer index = (slotMax - 1) * stride + 5;
        if ((integer)llList2String(params, 4) >= 1){
            index = (((integer)llList2String(params, 4) + -1) * stride + 5);
        }
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(params, 0, 0), "|")], "§")], index, index);
    }else if (action == "NOTSATMSG"){
        integer index = (slotMax - 1) * stride + 6;
        if ((integer)llList2String(params, 4) >= 1){
            index = (((integer)llList2String(params, 4) + -1) * stride + 6);
        }
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(params, 0, 0), "|")], "§")], index, index);
    }
}

default{
    state_entry(){
        integer n;
        for (; n<=llGetNumberOfPrims(); ++n){
           llLinkSitTarget(n,<0.0,0.0,0.5>,ZERO_ROTATION);
        }
        chatchannel = (integer)("0x" + llGetSubString((string)llGetKey(), 0, 7));
        llMessageLinked(LINK_SET, 1, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
        integer listener = llListen(chatchannel, "", "", "");
        //the nPose Menu will do the same, so this should basically only run if there is no nPose menu script in this build
        //but currently we don't check this, so at the startup the DOPOSE|DEFAULT will happen twice
        integer stop = llGetInventoryNumber(INVENTORY_NOTECARD);
        for (n = 0; n < stop; n++){
            string cardName = llGetInventoryName(INVENTORY_NOTECARD, n);
            if ((llSubStringIndex(cardName, defaultprefix) == 0) || (llSubStringIndex(cardName, cardprefix) == 0)){
                llSleep(1.0); //be sure that the NC reader script finished resetting
                llMessageLinked(LINK_SET, DOPOSE, cardName + NC_READER_CONTENT_SEPARATOR + cardName, NULL_KEY);
                return;
            }
        }
    }
    link_message(integer sender, integer num, string str, key id){
        if (num == 999999){//slave has asked me to reset so it can get the chatchannel from me.
            llMessageLinked(LINK_SET, 1, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
        }else if (num == DOPOSE_READER || num == DOACTION_READER){
            list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
            //allData: [ncName, alias, placeholder (currenly not used), contentLine1, contentLine2, ...]
            string ncName=llList2String(allData, 0);
            string menuName=llList2String(allData, 1);
            
            if (num==DOPOSE_READER){
                lastStrideCount = slotMax;
                slotMax = 0;
                llRegionSay(chatchannel, "die");
                llRegionSay(chatchannel, "adjuster_die");
            }
            integer length=llGetListLength(allData);
            integer index=3;
            integer run_assignSlots;
            for (; index<length; index++) {
                string data = llList2String(allData, index);
                if (num==DOACTION_READER && (llSubStringIndex(data, "ANIM") != 0)) {
                    ProcessLine(llList2String(allData, index), id, ncName, menuName);
                    if (!llSubStringIndex(data, "SCHMOE") || !llSubStringIndex(data, "SCHMO")){
                        run_assignSlots = TRUE;
                    }
//                }else if ((num==DOPOSE_READER) && (llSubStringIndex(data, "SCHMO") != 0 || llSubStringIndex(data, "SCHMOE") != 0)) {
                }else if (num==DOPOSE_READER) {
                    ProcessLine(llList2String(allData, index), id, ncName, menuName);
                    run_assignSlots = TRUE;
                }
            }
            if (num==DOPOSE_READER){
                if (llGetInventoryType(ncName) == INVENTORY_NOTECARD){ //sanity
                    lastDoPoseCardName=ncName;
                    lastDoPoseAlias=llList2String(allData, 1);
                    lastDoPosePlaceholder=llList2String(allData, 2);
                    lastDoPoseCardId=llGetInventoryKey(lastDoPoseCardName);
                    lastDoPoseAvatarId=id;
                }
                if (rezadjusters){
                    llMessageLinked(LINK_SET, 2, "RezAdjuster", "");    //card has been read and we have adjusters, send message to slave script.
                }
            }
            if (run_assignSlots){
                assignSlots();
            }
        }else if (num == ADJUST){ 
            rezadjusters = TRUE;
        }else if (num == STOPADJUST){ 
            rezadjusters = FALSE;
        }else if(num == CORERELAY){
            list msg = llParseString2List(str, ["|"], []);
            if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
            llRegionSay(chatchannel,llDumpList2String(["LINKMSG", num, (string)llList2String(msg, 0),
                llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
        }else if (num == SWAP){
            //swap the two slots
            //usage LINKMSG|202|1,2
            if (llGetListLength(slots)/stride >= 2){
                list seats2Swap = llCSV2List(str);
                SwapTwoSlots((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
            }
        }else if (num == SWAPTO) {
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
        }else if (num == (seatupdate + 2000000)){
            //slave sent slots list after adjuster moved the AV.  we need to keep our slots list up to date. replace slots list
            list tempList = llParseStringKeepNulls(str, ["^"], []);
            integer listStop = llGetListLength(tempList)/stride;
            integer slotNum;
            for (; slotNum < listStop; ++slotNum){
                slots = llListReplaceList(slots, [llList2String(tempList, slotNum*stride), (vector)llList2String(tempList, slotNum*stride+1),
                 (rotation)llList2String(tempList, slotNum*stride+2), llList2String(tempList, slotNum*stride+3),
                 (key)llList2String(tempList, slotNum*stride+4), llList2String(tempList, slotNum*stride+5), 
                 llList2String(tempList, slotNum*stride+6), llList2String(tempList, slotNum*stride+7)], slotNum*stride, slotNum*stride + 7);
            }
            slotMax = listStop;
        }else if (num == -999){
            if (llGetInventoryType(adminHudName)!=INVENTORY_NONE && str == "RezHud"){
                llRezObject(adminHudName, llGetPos() + <0,0,1>, ZERO_VECTOR, llGetRot(), chatchannel);
            }else if (num == -999 && str == "RemoveHud"){
                llRegionSayTo(hudId, chatchannel, "/die");
            }
        }else if (num==OPTIONS) {
            list optionsToSet = llParseStringKeepNulls(str, ["~"], []);
            integer length = llGetListLength(optionsToSet);
            integer index;
            for (; index<length; index++){
                list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
                string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
                string optionSetting = llStringTrim(llList2String(optionsItems, 1), STRING_TRIM);
                if (optionItem == "menuonsit") {
                    curmenuonsit = optionSetting;
                }
            }        }else if (num == memusage){
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
             + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
//        list details = llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME]));
        llSay(0, "running script time for all scripts in this nPose object are consuming " 
         + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0)*1000.0) + " ms of cpu time");
        }
    }

    object_rez(key id){
        if(llKey2Name(id) == adminHudName){
            hudId = id;
            llSleep(2.0);
            llRegionSayTo(hudId, chatchannel, "parent|"+(string)llGetKey());
        }
    }

    listen(integer channel, string name, key id, string message){
        list temp = llParseString2List(message, ["|"], []);
        if (name == "Adjuster"){
                llMessageLinked(LINK_SET, 3, message, id);
        }else if (llGetListLength(temp) >= 2 || llGetSubString(message,0,4) == "ping" || llGetSubString(message,0,8) == "PROPRELAY"){
            if (llGetOwnerKey(id) == llGetOwner()){
                if (message == "ping"){
                    llRegionSay(chatchannel, "pong|"+(string)explicitFlag + "|" + (string)llGetPos());
                }else if (llGetSubString(message,0,8) == "PROPRELAY"){
                    list msg = llParseString2List(message, ["|"], []);
                    llMessageLinked(LINK_SET,llList2Integer(msg,1),llList2String(msg,2),llList2Key(msg,3));
                }else if (name == "pos_adjuster_hud"){
                }else{
                    list params = llParseString2List(message, ["|"], []);
                    vector newpos = (vector)llList2String(params, 0) - llGetPos();
                    newpos = newpos / llGetRot();
                    rotation newrot = (rotation)llList2String(params, 1) / llGetRot();
                    llRegionSayTo(llGetOwner(), 0, "\nPROP|" + name + "|" + (string)newpos + "|" + (string)(llRot2Euler(newrot) * RAD_TO_DEG)
                     + "|" + llList2String(params, 2));
                    llMessageLinked(LINK_SET, slotupdate, "PROP|" + name + "|" + (string)newpos + "|" +
                        (string)(llRot2Euler(newrot) * RAD_TO_DEG), NULL_KEY); 

                }
            }
        }else if(name == llKey2Name(hudId)){
            //need to process hud commands
            if (message == "adjust"){
                llMessageLinked(LINK_SET, ADJUST, "", "");
            }else if (message == "stopadjust"){
                llMessageLinked(LINK_SET, STOPADJUST, "", "");
            }else if (message == "posdump"){
                llMessageLinked(LINK_SET, DUMP, "", "");
            }else if (message == "hudsync"){
                llMessageLinked(LINK_SET, SYNC, "", "");
            }
        }
    }

    changed(integer change){
        if(change & CHANGED_INVENTORY) {
            if(llGetInventoryType(lastDoPoseCardName) == INVENTORY_NOTECARD) {
                if(lastDoPoseCardId!=llGetInventoryKey(lastDoPoseCardName)) {
                    //the last used nc changed, "redo" the nc
                    llSleep(1.0); //be sure that the NC reader script finished resetting
                    llMessageLinked(LINK_SET, DOPOSE, llList2CSV([lastDoPoseCardName, lastDoPoseAlias, lastDoPosePlaceholder]), lastDoPoseAvatarId); 
                }
                else {
                    llResetScript();
                }
            }
            else {
                llResetScript();
            }
        }
        if (change & CHANGED_LINK){
            llMessageLinked(LINK_SET, 1, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
            assignSlots();
        }
        if (change & CHANGED_REGION){
            llMessageLinked(LINK_SET, seatupdate, llDumpList2String(slots, "^"), NULL_KEY);
        }
    }
    
    on_rez(integer param){
        llResetScript();
    }
}

/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/
string adminHudName = "npose admin hud";
key ownerinit;
integer stride = 8;
integer slotMax = 0;
integer slotupdate = 34333;
integer memusage = 34334;
list slots;
integer curPrimCount = 0;
integer lastPrimCount = 0;
integer lastStrideCount = 12;
integer seatupdate = 35353;//we gonna do satmsg and notsatmsg
integer rezadjusters;
integer listener;
integer line;
string defaultprefix = "DEFAULT:";
key dataid;
key clicker;
integer chatchannel;
string cardprefix = "SET:";
key cardid;
string card;
integer btnline;
key btnid;
string btncard;
integer SYNC = 206;

integer x;
integer n;
integer stop;
list adjusters;
integer SWAPTO = 210;
integer SWAP = 202;
integer STOPADJUST = 205;
key hudId;
integer DUMP = 204;
integer DOPOSE = 200;
integer DOACTIONS = 207;
integer CORERELAY = 300;
//integer BOFflag = 0;
integer ADJUSTOFFSET = 208;
integer ADJUST = 201;
integer explicitFlag = 0;

string str_replace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str = "") + str, [search], []), replace);
}

integer FindEmptySlot() {
    for (n=0; n < slotMax; ++n) {
        if (llList2String(slots, n*stride+4) == ""){
            return n;
        }
    }
    return -1;
}

list SeatedAvs(){
    list avs = [];
    integer linkcount = llGetNumberOfPrims();
    for (n = linkcount; n >= 0; n--){
        key id = llGetLinkKey(n);
        if (llGetAgentSize(id) != ZERO_VECTOR){
            avs = [id] + avs;
        }
    }
    return avs;
}

assignSlots(){
    list avqueue = SeatedAvs();
    stop = llGetListLength(avqueue);
    if (slotMax < lastStrideCount){
        //AV's that were in a 'real' seat are already assigned so leave them be
        for (x=slotMax; x<=lastStrideCount; ++x){//only need to worry about the 'extra' slots so limit the count
            if (llList2Key(slots, x*stride+4) != ""){//check this slot for a seated AV
                integer emptySlot = FindEmptySlot();//user functions are memory expensive and only used once. suggest put that code here
                if ((emptySlot >=0) && (emptySlot < slotMax)){
                    //if AV in a 'now' extra seat and if a real seat available, seat them
                    slots = llListReplaceList(slots, [llList2Key(slots, x*stride+4)], emptySlot*stride+4, emptySlot*stride+4);
                }
            }
        }
        //remove the 'now' extra seats from slots list
        slots = llDeleteSubList(slots, (slotMax)*stride, -1);
        //unsit extra seated AV's
        for (n=0; n<stop; ++n){
            if (llListFindList(slots, [llList2Key(avqueue, n)]) < 0){
                llMessageLinked(LINK_SET, -222, llList2String(avqueue, n), NULL_KEY);
            }
        }
    }else if (slotMax > lastStrideCount){
        //nothing to do as it is already done by processLine routine
    }else if (slotMax == lastStrideCount){
        //nothing to do as it is already done by processLine routine
    }
    
    if (curPrimCount > lastPrimCount){
        //we have a new AV, if a seat is available then seat them
        //if not, unseat them
        //numbered seats take priority so check if new AV is on a numbered prim
        //find the new seated AV, will be the first one in the avqueue list
        key thisKey=llList2Key(avqueue,stop-1);
        //step through the prims to see if our new AV has a numbered seat
        integer primcount = llGetObjectPrimCount(llGetKey());
        integer slotNum=-1;
        for (n= 1; n <= primcount; ++n){//find out which prim this new AV is seated on and grab the slot number if it's a numbered prim.
            integer x = (integer)llGetSubString(llGetLinkName(n), 4, -1);
            if ((x>0) && (x<=slotMax)){
                if (llAvatarOnLinkSitTarget(n) == thisKey){
                    if (llList2String(slots, (x-1)*stride+4) == ""){
                        slotNum = (integer)llGetLinkName(n);
                    }
                }
            }
        }
        integer nn;
        for (nn= 1; nn <= primcount; ++nn){
            if (slotNum != -1  && llListFindList(slots, [thisKey]) == -1){
                //AV is seated on a numbered prim so give them the correct seat
                if (slotNum <= slotMax){
                    slots = llListReplaceList(slots, [thisKey], (slotNum-1)*stride+4, (slotNum-1)*stride+4);
                }else{
                    //sitter is on a numbered prim not incluced in this pose set so find first open slot for them.
                    integer y = FindEmptySlot();
                    if (y != -1){
                        //we have a spot.. seat them
                        slots = llListReplaceList(slots, [thisKey], (y)*stride+4, (y)*stride+4);
                    }else if (llListFindList(SeatedAvs(), [thisKey]) != -1){
                        //no open slots, so unseat them
                        llMessageLinked(LINK_SET, -222, (string)thisKey, NULL_KEY);
                    }
                }
            }
            if (llListFindList(slots, [thisKey]) == -1){//AV not on a numbered prim or seat is taken.
                integer y = FindEmptySlot();
                if (y != -1){
                    //we have a spot.. seat them
                    slots = llListReplaceList(slots, [thisKey], (y)*stride+4, (y)*stride+4);
                }else if (llListFindList(SeatedAvs(), [thisKey]) != -1){
                    //no open slots, so unseat them
                    llMessageLinked(LINK_SET, -222, (string)thisKey, NULL_KEY);
                }
            }
            
        }
    }else if (curPrimCount < lastPrimCount){//we lost a seated AV
        //remove this AV key from the slots list
        for (x=0; x < slotMax; ++x) {
            //look in the avqueue for the key in the slots list
            if (llListFindList(avqueue, [llList2Key(slots, x*stride+4)]) < 0) {
                //if the key is not in the avqueue, remove it from the slots list
                slots = llListReplaceList(slots, [""], x*stride+4, x*stride+4);
            }
        }
    }
    lastPrimCount = curPrimCount;
    lastStrideCount = slotMax;
    llMessageLinked(LINK_SET, seatupdate, llDumpList2String(slots, "^"), NULL_KEY);
}

SwapTwoSlots(integer currentseatnum, integer newseatnum) {
    if (newseatnum <= slotMax){
        integer OldSlot=llListFindList(slots, ["seat"+(string)currentseatnum])/stride;
        integer NewSlot=llListFindList(slots, ["seat"+(string)newseatnum])/stride;

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



SwapAvatarInto(key avatar, string newseat) { 
    
    integer oldseat = (integer)llGetSubString(llList2String(slots, llListFindList(slots, [avatar])+3), 4,-1); 
    if (oldseat <= 0) {
        llWhisper(0, "avatar is not assigned a slot: " + (string)avatar);
    }else{ 
            SwapTwoSlots(oldseat, (integer)newseat); 
    }
}

ReadCard(){
    lastStrideCount = slotMax;
    slotMax = 0;
    llRegionSay(chatchannel, "die");
    llRegionSay(chatchannel, "adjuster_die");
    adjusters = [];
    line = 0;
    cardid = llGetInventoryKey(card);
    dataid = llGetNotecardLine(card, line);
}


ProcessLine(string line, key av){
    line = llStringTrim(line, STRING_TRIM);
    list params = llParseString2List(line, ["|"], []);
    string action = llList2String(params, 0);
    if (action == "ANIM"){
        if (slotMax<lastStrideCount){
            slots = llListReplaceList(slots, [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), llList2Key(slots, (slotMax)*stride+4),
                 "", "","seat"+(string)(slotMax+1)], (slotMax)*stride, (slotMax)*stride+7);
        }else{
            slots += [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), "", "", "","seat"+(string)(slotMax+1)]; 
        }
        slotMax++;
    }else if (action == "SINGLE"){
        //this pose is for a single sitter within the slots list
        //got to find out which slot and then replace the entire slot
        integer posIndex = llListFindList(slots, [(vector)llList2String(params, 2)]);
        if ((posIndex == -1) || ((posIndex != -1) && llList2String(slots, posIndex-1) != llList2String(params, 1))){
            integer slotindex = llListFindList(slots, [clicker])-4;
            slots = llListReplaceList(slots, [llList2String(params, 1), (vector)llList2String(params, 2),
                llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD), llList2String(params, 4), llList2Key(slots,
                     slotindex+4), "", "",llList2String(slots, slotindex+7)], slotindex, slotindex + 7);
        }
        slotMax = llGetListLength(slots)/stride;
        lastStrideCount = slotMax;
    }else if (action == "PROP"){
        string obj = llList2String(params, 1);
        if (llGetInventoryType(obj) == INVENTORY_OBJECT){
            list strParm2 = llParseString2List(llList2String(params, 2), ["="], []);
            if (llList2String(strParm2, 1) == "die"){
                llRegionSay(chatchannel,llList2String(strParm2,0)+"=die");
            }else{
                if (llList2String(params, 4) == "explicit"){
                    explicitFlag = 1;
                }else{
                    explicitFlag = 0;
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
    }else if (action == "LINKMSG"){
        integer num = (integer)llList2String(params, 1);
        string line1 = str_replace(line, "%AVKEY%", av);
        list params1 = llParseString2List(line1, ["|"], []);
        key lmid;
        if ((key)llList2String(params1, 3) != ""){
            lmid = (key)llList2String(params1, 3);
        }else{
            lmid = (key)llList2String(slots, (slotMax-1)*stride+4);
        }
        string str = llList2String(params1, 2);
        llMessageLinked(LINK_SET, num, str, lmid);
            llSleep(1.0);
            llRegionSay(chatchannel, llDumpList2String(["LINKMSGQUE",num,str,lmid], "|"));
    }else if (action == "SATMSG"){
        integer index = (slotMax-1) * stride + 5;
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(params, 0, 0), "|")], "§")], index, index);
    }else if (action == "NOTSATMSG"){
        integer index = (slotMax-1) * stride + 6;
        slots = llListReplaceList(slots, [llDumpList2String([llList2String(slots,index),
            llDumpList2String(llDeleteSubList(params, 0, 0), "|")], "§")], index, index);
    }
}

default{
    state_entry(){
        curPrimCount = llGetNumberOfPrims();
        for (n=0; n<=curPrimCount; ++n){
           llLinkSitTarget(n,<0.0,0.0,0.5>,ZERO_ROTATION);
        }
        chatchannel = (integer)("0x" + llGetSubString((string)llGetKey(), 0, 7));
        llMessageLinked(LINK_SET, 1, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
        ownerinit = llGetOwner();
        curPrimCount = llGetNumberOfPrims();
        lastPrimCount = curPrimCount;
        listener = llListen(chatchannel, "", "", "");
        stop = llGetInventoryNumber(INVENTORY_NOTECARD);
        for (n = 0; n < stop; n++){
            card = llGetInventoryName(INVENTORY_NOTECARD, n);
            if ((llSubStringIndex(card, defaultprefix) == 0) || (llSubStringIndex(card, cardprefix) == 0)){
                llMessageLinked(LINK_SET, DOPOSE, card, NULL_KEY);
                return;
            }else{
                card = "";
            }
        }
    }
    link_message(integer sender, integer num, string str, key id){
        if (num == 999999){//slave has asked me to reset so it can get the chatchannel from me.
            llResetScript();
        }
        if (num == DOPOSE){
            card = str;
            clicker = id;
            ReadCard();
        }else if (num == DOACTIONS){
            btncard = str;
            clicker = id;
            btnline = 0;
            btnid = llGetNotecardLine(btncard, btnline);
        }else if (num == ADJUST){ 
            adjusters = [];
            rezadjusters = TRUE;
        }else if (num == STOPADJUST){ 
            adjusters = [];
            rezadjusters = FALSE;
        }else if(num == CORERELAY){
            list msg = llParseString2List(str, ["|"], []);
            if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
            llRegionSay(chatchannel,llDumpList2String(["LINKMSG",(string)llList2String(msg, 0),
                llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
        }else if (num == SWAP){
            if (llGetListLength(slots)/stride >= 2){
                list seats2Swap = llParseString2List(str, [","],[]);
                SwapTwoSlots((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
            }
        }else if (num == SWAPTO) {
            SwapAvatarInto(id, str);
        }else if (num == (seatupdate + 2000000)){
            //slave sent slots list after adjuster moved the AV.  we need to keep our slots list up to date. replace slots list
            list tempList = llParseStringKeepNulls(str, ["^"], []);
            integer listStop = llGetListLength(tempList)/stride;
            integer slotNum;
            for (slotNum = 0; slotNum < listStop; ++slotNum){
                slots = llListReplaceList(slots, [llList2String(tempList, slotNum*stride), (vector)llList2String(tempList, slotNum*stride+1),
                 (rotation)llList2String(tempList, slotNum*stride+2), llList2String(tempList, slotNum*stride+3),
                 (key)llList2String(tempList, slotNum*stride+4), llList2String(tempList, slotNum*stride+5), 
                 llList2String(tempList, slotNum*stride+6), llList2String(tempList, slotNum*stride+7)], slotNum*stride, slotNum*stride + 7);
            }
        }else if (num == -999 && str == "RezHud"){
            if (llGetInventoryType(adminHudName)!=INVENTORY_NONE){
                llRezObject(adminHudName, llGetPos() + <0,0,1>, ZERO_VECTOR, llGetRot(), chatchannel);
            }
        }else if (num == -999 && str == "RemoveHud"){
            llRegionSayTo(hudId, chatchannel, "/die");
        }else if (num == memusage){
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit() + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }

    object_rez(key id){
        if (llKey2Name(id) == "Adjuster"){
            adjusters += [id];
        }else if(llKey2Name(id) == adminHudName){
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
            if (llGetOwnerKey(id) == ownerinit){
                if (message == "ping"){
                    llRegionSay(chatchannel, "pong|"+(string)explicitFlag + "|" + (string)llGetPos());
                }else if (llGetSubString(message,0,8) == "PROPRELAY"){
                        list msg = llParseString2List(message, ["|"], []);
                    llMessageLinked(LINK_SET,llList2Integer(msg,1),llList2String(msg,2),llList2Key(msg,3));
                }else{
                    list params = llParseString2List(message, ["|"], []);
                    vector newpos = (vector)llList2String(params, 0) - llGetPos();
                    newpos = newpos / llGetRot();
                    rotation newrot = (rotation)llList2String(params, 1) / llGetRot();
                    llRegionSayTo(ownerinit, 0, "\nPROP|" + name + "|" + (string)newpos + "|" + (string)(llRot2Euler(newrot) * RAD_TO_DEG)
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

    dataserver(key id, string data){
        if (id == dataid){
            if (data == EOF){
                assignSlots();
                if (rezadjusters){
                    adjusters = [];
                    llMessageLinked(LINK_SET, 2, "RezAdjuster", "");    //card has been read and we have adjusters, send message to slave script.
                }
            }else{
                ProcessLine(data, clicker);
                line++;
                dataid = llGetNotecardLine(card, line);
            }
        }else if (id == btnid){
            if (data != EOF){
                ProcessLine(data, clicker);
                btnline++;
                btnid = llGetNotecardLine(btncard, btnline);
            }
        }
    }

    changed(integer change){
        if (change & CHANGED_LINK){
            llMessageLinked(LINK_SET, 1, (string)chatchannel, NULL_KEY); //let our scripts know the chat channel for props and adjusters
            lastPrimCount = curPrimCount;
            curPrimCount = llGetNumberOfPrims();
            assignSlots();
        }
        if (change & CHANGED_INVENTORY){
            if (card != ""){
                if (llGetInventoryType(card) == INVENTORY_NOTECARD){
                    if (cardid != llGetInventoryKey(card)){
                        ReadCard();
                    }
                }else{
                        llResetScript();
                }
            }else{
                llResetScript();
            }
        }
        if (change & CHANGED_REGION){
            llMessageLinked(LINK_SET, seatupdate, llDumpList2String(slots, "^"), NULL_KEY);
        }
        if (change & CHANGED_OWNER ){
            ownerinit = llGetOwner();
        }
    }
    
    on_rez(integer param){
        llResetScript();
    }
}
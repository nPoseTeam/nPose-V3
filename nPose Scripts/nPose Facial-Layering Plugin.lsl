/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/
integer LAYER_POSE = -218;
list AnimsList; //[string command, string animation name]  use a list to layer multiple animations.
list Lastanim;
integer Primcount;
integer Newprimcount;
list Faceanims;
integer GotFaceAnim = 0;
integer Seatcount;

integer OPTIONS = -240;
integer SEAT_UPDATE = 35353;
integer MENU_USAGE = 34334;
list FaceTimes = [];
list Slots;
key ThisAV;
integer Stop;
integer FACIALS_FLAG = -241;
integer FacialEnable = 1;



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

doSeats(integer slotNum, key avKey) {
    llSetTimerEvent(0.0);
    if(avKey != "") {
        Stop = llGetListLength(Slots)/8;
        llRequestPermissions(avKey, PERMISSION_TRIGGER_ANIMATION);
    }
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

default {
    state_entry() {
        Primcount = llGetNumberOfPrims();
        Newprimcount = Primcount;
    }

    link_message(integer sender, integer num, string str, key id) {
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
        else if(num == SEAT_UPDATE){
            list seatsavailable = llParseStringKeepNulls(str, ["^"], []);
            str = "";
            integer stop = llGetListLength(seatsavailable)/8;
            Slots = [];
            FaceTimes = [];
            GotFaceAnim = 0;
            for(Seatcount = 1; Seatcount <= stop; ++Seatcount) {
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
                        doSeats(Seatcount, llList2String(Slots, (Seatcount)*8+4));
                        return;
                    }
                }
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
                if(optionItem == "facialexp") {
                    FacialEnable = optionSettingFlag;
                }
            }
        }
    }
    
    run_time_permissions(integer perm) {
        ThisAV = llGetPermissionsKey();
        //start timer if we have face anims for any slot
        if(GotFaceAnim==1) {
            llSetTimerEvent(1.0);
        }
        else {
            llSetTimerEvent(0.0);
        }
    }

    timer() {        
        integer n;
        integer SlotStop = llGetListLength(Slots)/8;
        key av;
        integer facecount;
        integer faceindex;
        if(FacialEnable) {
            for(n=0; n<SlotStop; ++n) {
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
            }
        }
    }

    changed(integer change) {
        if(change & CHANGED_LINK) {
            integer newPrimCount1 = llGetNumberOfPrims();
            if(Newprimcount>newPrimCount1) {
                //we have lost a sitter so find out who and remove them from the list.
                integer n;
                integer LaStop = llGetListLength(Lastanim)/2;
                for(; n<LaStop; ++n) {
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
        }
    }
}

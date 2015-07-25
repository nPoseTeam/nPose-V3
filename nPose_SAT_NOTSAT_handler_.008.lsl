/*
The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:

The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
    - If you distribute the nPose scripts, you must leave them full perms.
    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.

"Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
*/

list slots;
integer chatchannel;
integer seatupdate = 35353;//we gonna do satmsg and notsatmsg
integer stride = 8;
integer memusage = 34334;

string str_replace(string str, string search, string replace) {
    return llDumpList2String(llParseStringKeepNulls((str = "") + str, [search], []), replace);
}

//Returns an integer TRUE if the lists are equal, FALSE if not.
integer ListCompare(list a, list b) {
    integer aL = a != [];
    if (aL != (b != [])) return 0;
    if ((aL == 0) && (b == [])) return 1;
 
    return !llListFindList((a = []) + a, (b = []) + b);
}

default
{
    state_entry()
    {
        
    }
    
    link_message(integer sender, integer num, string str, key id){
        if (num == 1){  //got chatchannel from the core.
            chatchannel = (integer)str;
        }
        if (num == seatupdate){
            list oldSlots = slots;
            slots = llParseStringKeepNulls(str, ["^"], []);
            list oldstride;
            list currentstride;
        //notsatmsg things
            integer n;
            integer stop = llGetListLength(oldSlots)/stride;
            for (n = 0; n < stop; ++n){
                oldstride = llList2List(oldSlots, n*stride, n*stride+6);
                currentstride = llList2List(slots, n*stride, n*stride+8);
                //check if we have an existing NOTSATMSG and if there was a sitter in this seat
                if ((llList2String(oldstride, 6) != "" && llList2String(oldstride, 4) != "")){
                    integer curStrideIndex = llListFindList(slots, [llList2String(oldstride, 4)])-4;
                    currentstride = llList2List(slots, curStrideIndex, curStrideIndex+6);
                    //if this sitter is no longer in this seat
                    // or the pose set has changed
                    if ((curStrideIndex == -1) || (curStrideIndex != -1 && llList2CSV(oldstride) != llList2CSV(currentstride))){
                        integer ndx;
                        string nsm = llList2String(oldstride, 6);
                        nsm = str_replace(nsm, "%AVKEY%", (key)llList2String(oldstride, 4));
                        list smsgs=llParseString2List(nsm, ["§"], []);
                        integer msgcnt = llGetListLength(smsgs);
                        for (ndx = 0; ndx < msgcnt; ndx++){
                            list parts = llParseString2List(llList2String(smsgs,ndx), ["|"], []);
                            llMessageLinked(LINK_SET, (integer)llList2String(parts, 0), llList2String(parts, 1),
                                (key)llList2String(oldstride, 4));
//                            llRegionSayTo(llGetOwner(), 0,llDumpList2String(["LINKMSG",(string)llList2String(parts, 0),
//                                llList2String(parts, 1), llList2String(oldstride, 4)], "|"));
                            llRegionSay(chatchannel,llDumpList2String(["LINKMSG",(string)llList2String(parts, 0),
                                llList2String(parts, 1), llList2String(oldstride, 4)], "|"));
                        }
                    }
                }
            }//finished looping all strides
            stop = llGetListLength(slots)/stride;
            for (n = 0; n < stop; ++n){
                //this is a slot change so do some work
                oldstride = llList2List(oldSlots, n*stride, n*stride+8);
                currentstride = llList2List(slots, n*stride, n*stride+8);
                //if existing sitter and new pose set and has SATMSG
                // or if new sitter and same pose set and SATMSG
                integer listsEqual = ListCompare(oldstride, currentstride);
                //only run SATMSG section if this seat has a SATMSG to run in new pose set
                if (llList2String(currentstride, 5) != ""){
                    //if we have a SATMSG in this seat we need to check a couple more conditions
                    //if same sitter and has new pose set
                    // or new sitter (don't care if new pose set or not, still run SATMSGs)
                    if ((llList2String(currentstride, 4) == llList2String(oldstride, 4) && llList2String(currentstride, 4) != ""
                      && listsEqual == FALSE)
                     || (llList2String(currentstride, 4) != llList2String(oldstride, 4) && llList2String(currentstride, 4) != "")){
                    
            //satmsg things
                        //we have a sitter and satmsg so add it to the current list
                        integer ndx;
                        string sm = llList2String(currentstride, 5);
                        sm = str_replace(sm, "%AVKEY%", (key)llList2String(currentstride, 4));
                        list smsgs=llParseString2List(sm, ["§"], []);
                        integer msgcnt = llGetListLength(smsgs);
                        for (ndx = 0; ndx < msgcnt; ndx++){
                            list parts = llParseString2List(llList2String(smsgs,ndx), ["|"], []);
                            llMessageLinked(LINK_SET, (integer)llList2String(parts, 0), llList2String(parts, 1),
                                (key)llList2String(slots, n*stride + 4));
                            llSleep(1.5);
    //                        llRegionSayTo(llGetOwner(), 0, llDumpList2String(["LINKMSG",(string)llList2String(parts, 0),
    //                            llList2String(parts, 1), (string)llList2String(slots, n*stride + 4)], "|"));
                            llRegionSay(chatchannel, llDumpList2String(["LINKMSG",(string)llList2String(parts, 0),
                                llList2String(parts, 1), (string)llList2String(slots, n*stride + 4)], "|"));
                        }
                    }
                }
            }
        }else if (num == memusage){
            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
             + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
        }
    }
}
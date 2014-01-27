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

string str_replace(string src, string from, string to){
    integer len = (~-(llStringLength(from)));
    if(~len){
        string  buffer = src;
        integer b_pos = -1;
        integer to_len = (~-(llStringLength(to)));
        @loop;
        integer to_pos = ~llSubStringIndex(buffer, from);
        if(to_pos){
            buffer = llGetSubString(src = llInsertString(llDeleteSubString(src, b_pos -= to_pos, b_pos + len),
                b_pos, to), (-~(b_pos += to_len)), 0x8000);
            jump loop;
        }
    }
    return src;
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
                if ((llList2String(oldstride, 6) != "" && llList2String(oldstride, 4) != "")){
                    integer curStrideIndex = llListFindList(slots, [llList2String(oldstride, 4)])-4;
                    currentstride = llList2List(slots, curStrideIndex, curStrideIndex+6);
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
                if ((llList2String(oldstride, 4) == "")  && (llList2String(currentstride, 4) != "") && (llList2String(currentstride, 5) != "")
                 || (llList2String(currentstride, 4) != "" && llList2String(currentstride, 5) != "")){
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
                        llSleep(0.1);
                        llRegionSay(chatchannel, llDumpList2String(["LINKMSG",(string)llList2String(parts, 0),
                            llList2String(parts, 1), (string)llList2String(slots, n*stride + 4)], "|"));
                    }
                }
            }
        }else if (num == memusage){
//            llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit() + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
            llOwnerSay(llGetScriptName() + " Memory slated for garbage collection: " + (string)(llGetMemoryLimit() - (llGetFreeMemory() + llGetUsedMemory())));
        }
    }
}
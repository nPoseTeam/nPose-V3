integer chatchannel = 0;
integer slotid = 0;
integer iMoved;

float timeout = 0.1;
vector pos = ZERO_VECTOR;
rotation rot = ZERO_ROTATION;

key parent = NULL_KEY;

default
{
    on_rez(integer param)
    {
        if (param)
        {
            chatchannel = (integer)((0x00FFFFFF & (param >> 8)) + 0x7F000000);
            iMoved = param & 0x000000FF;
            pos = llGetPos();
            rot = llGetRot();
            llListen(chatchannel, "", "", "");
            llSetTimerEvent(timeout);
        }
    }

    touch_start(integer total_number){
        llSay(chatchannel, (string)pos + "|" + (string)rot);
    }

    listen(integer channel, string name, key id, string message)
    {
        list msg = llParseString2List(message, ["|"], []);
        string cmd = llList2String(msg,0);
        vector vDelta = (vector)llList2String(msg, 1);
        //only pay attention of obj owner is my owner
        if (llGetOwnerKey(id) == llGetOwner())
        {
            list params = llParseString2List(message, ["|"], []);
            //prevent crosstalk
            if ((key)llList2String(params, 0) == llGetKey())
            {
                parent = id;
                string msg = llList2String(params, 1);
                if (msg == "posrot")
                {
                    pos = (vector)llList2String(params, 2);
                    rot = (rotation)llList2String(params, 3);
                    llSetPos(pos);
                    llSetRot(rot);
                } else if (msg = "slotid") {
                    llSetObjectDesc(llList2String(params, 2));
                }
            }
            else if (message == "adjuster_die")
            {
                llDie();
            }            
        }
        if (cmd == "MOVEPROP" ){
            if (llList2String(msg,1) == llGetObjectName() && (llVecMag(vDelta) < 0.1)){
                if (iMoved == 0){
                    // move it
                    vector vPosition =  (vector)llList2String(msg,2);
                    llSetRegionPos( vPosition );
                    pos = llGetPos();
                    rot = llGetRot();
                }
                iMoved = 1;
            }
        }
    }
    
    timer()
    {
        if (parent != NULL_KEY)
        {
            if (llKey2Name(parent) == "")
            {
                //parent has died.  do likewise
                llDie();
            }
        }
        
        integer chat_out = FALSE;
        if (llGetPos() != pos)
        {
            pos = llGetPos();
            chat_out = TRUE;
        }
        
        if (llGetRot() != rot)
        {
            rot = llGetRot();
            chat_out = TRUE;
        }
        
        if (chat_out)
        {
            llRegionSay(chatchannel, (string)pos + "|" + (string)rot);
        }
    }
}

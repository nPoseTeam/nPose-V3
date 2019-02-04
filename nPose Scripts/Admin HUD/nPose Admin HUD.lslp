
vector touchedposZ;
vector touchedpos;
string seatNumOut="seat1";
integer posRotFlag = 1;
key parentID;
float moveMultiplier = 1.0;
integer freeLockedFlag = 1;
integer chatchannel;
integer attachPoint = 35;
float YPos;
float XPos;




dobuttons(float xPos, float yPos, key id){
	if (yPos>.75){
		llRegionSayTo(parentID, chatchannel, "adjust");
	}else if (yPos>.5 && yPos<.74999){
		llRegionSayTo(parentID, chatchannel, "stopadjust");
	}else if (yPos>.25 && yPos<.4999){
		llRegionSayTo(parentID, chatchannel, "posdump");
	}else if (yPos<.24999){
		llRegionSayTo(parentID, chatchannel, "hudsync");
	}
}

default
{
	state_entry()
	{
		llMinEventDelay(0.05);
		touchedpos=ZERO_VECTOR;
		llListen(chatchannel, "", "", "");
	}

	touch_start(integer total_number)
	{
		touchedpos = llDetectedTouchST(0);
		XPos = touchedpos.x;
		YPos = touchedpos.y;
		if (XPos>0.5){
//		if ((YPos<0.08) || (YPos>0.85) || (XPos>0.91)){
			dobuttons(XPos, YPos, llDetectedKey(0));
		}else if (YPos<.5 && XPos<.24999){
			llRegionSayTo(parentID, chatchannel, "stopadjust");
			llSleep(1.0);
			llDetachFromAvatar();
		}
	}
	listen(integer channel, string name, key id, string message)
	{
		if (channel == chatchannel){
			if (llGetOwnerKey(id) == llGetOwner()){
				list params = llParseStringKeepNulls(message, ["|"], []);
				if (llList2String(params, 0) == "/die"){
					 llDetachFromAvatar();
				}else if (llList2String(params, 0) == "parent"){
					parentID = (key)llList2String(params, 1);
				}
			}
		}
	}

	on_rez(integer param)
	{
		if (param)
		{
			llSetTimerEvent(60.0);
			chatchannel = param;
			llListen(chatchannel, "", "", "");
			llRequestPermissions(llGetOwner(), PERMISSION_ATTACH | PERMISSION_TRACK_CAMERA);
		}
	}
	changed(integer change){
		if (change & CHANGED_OWNER ){
			key ownerinit = llGetOwner();
		}
	}
	run_time_permissions(integer vBitPermissions){
		if( vBitPermissions & PERMISSION_ATTACH ){
			 if(!llGetAttached()){
				llAttachToAvatarTemp(attachPoint);
			}
		}else{
			llOwnerSay("Permission to attach denied");
			llDie();
		}
	}
	timer(){
		llSetTimerEvent(0.0);
		if (!llGetAttached()){
			llDie();
		}
	}
}


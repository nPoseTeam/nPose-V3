key MyParentId;
integer ChatChannel;
integer ATTACH_POINT = ATTACH_HUD_TOP_RIGHT;
float TIMEOUT=60.0;
string MY_OBJECT_NAME="nPose Admin HUD*";

integer ADJUST = 201;
integer DUMP = 204;
integer STOPADJUST = 205;
integer SYNC = 206;

string SOUND_NAME="nPose Button Feedback";
integer FeedbackSoundAvailable;

integer permissionRequestMode; //0: nothing; 1:attach; 2:detach

sayToCore(string text) {
	llRegionSayTo(MyParentId, ChatChannel, text);
}

buttonFeedback() {
	llPlaySound(SOUND_NAME, 0.9);
}

doDetach(key avatar) {
	if(llGetPermissionsKey()==avatar && (llGetPermissions() & PERMISSION_ATTACH)) {
		llDetachFromAvatar();
	}
	else {
		permissionRequestMode=2;
		llRequestPermissions(avatar, PERMISSION_ATTACH);
	}
}

doAttachTemp(key avatar, integer attachmentPoint) {
	if(llGetPermissionsKey()==avatar && (llGetPermissions() & PERMISSION_ATTACH)) {
		llAttachToAvatarTemp(attachmentPoint);
	}
	else {
		permissionRequestMode=1;
		llRequestPermissions(avatar, PERMISSION_ATTACH);
	}
}

doButtons(float xPos, float yPos, key id) {
	if(xPos<0.02) {
		//nothing
	}
	else if(xPos<0.5) {
		//maybe left side buttons
		if(yPos<0.04) {
			//nothing
		}
		else if(yPos<0.38) {
			//Lower left Button: Sync Animations
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "LINKMSG|" + (string)SYNC]));
		}
		else if(yPos<0.52) {
			//Middle left Button: Mute Adjusters
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "OPTION|quietAdjusters=1"]));
		}
		else if(yPos<0.76) {
			//Upper left Button: Start Adjust
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "LINKMSG|" + (string)ADJUST]));
		} 
	}
	else if(xPos<0.976) {
		//maybe right side buttons
		if(yPos<0.04) {
			//nothing
		}
		else if(yPos<0.38) {
			//Lower right Button: Dump Poses
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "LINKMSG|" + (string)DUMP]));
		}
		else if(yPos<0.52) {
			//Middle right Button: Unmute Adjusters
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "OPTION|quietAdjusters=0"]));
		}
		else if(yPos<0.76) {
			//Upper right Button: Stop Adjust
			buttonFeedback();
			sayToCore(addCommand("", ["PC_DO", llGetOwner(), "LINKMSG|" + (string)STOPADJUST]));
		}
		else if(yPos<0.83) {
			//nothing
		}
		else if(yPos<0.93) {
			//maybe close button
			if(xPos>0.91 && xPos<0.97) {
				//close Button
				buttonFeedback();
				string cmd;
//				cmd=addCommand(cmd, ["PC_DO", llGetOwner(), "LINKMSG|" + (string)DUMP]);
				cmd=addCommand(cmd, ["PC_DO", llGetOwner(), "LINKMSG|" + (string)STOPADJUST]);
				sayToCore(cmd);
				doDetach(llGetOwner());
			}
		}
	}
}

execute(list msg, key id) {
	string cmd=llList2String(msg, 0);
	if(cmd=="PROPDIE" || cmd=="CP_DIE") {
		// PROPDIE[|propNameList[|propGroupList]]
		if(llList2String(msg, 1)==MY_OBJECT_NAME) {
			doDetach(llGetOwner());
		}
	}
}

string addCommand(string commands, list commandWithParamList) {
	if(commands=="") {
		return llList2Json(JSON_ARRAY, [llList2Json(JSON_ARRAY, commandWithParamList)]);
	}
	else {
		return llList2Json(JSON_ARRAY, llJson2List(commands) + [llList2Json(JSON_ARRAY, commandWithParamList)]);
	}
}


default {
	touch_start(integer num_detected) {
		vector touchedPos = llDetectedTouchST(0);
		doButtons(touchedPos.x, touchedPos.y, llDetectedKey(0));
	}

	listen(integer channel, string name, key id, string message) {
		if(id==MyParentId) {
			//check if the message is in JSON format (JSON Format should be used always)
			if(llJsonValueType(message, [])==JSON_ARRAY) {
				list commandLines=llJson2List(message);
				while(llGetListLength(commandLines)) {
					list commandParts=llJson2List(llList2String(commandLines, 0));
					execute(commandParts, id);
					commandLines=llDeleteSubList(commandLines, 0, 0);
				}
			}
		}
	}

	on_rez(integer param) {
		llSetTimerEvent(0.0);
		FeedbackSoundAvailable=llGetInventoryType(SOUND_NAME)==INVENTORY_SOUND;
		MyParentId=llList2Key(llGetObjectDetails(llGetKey(), [OBJECT_REZZER_KEY]), 0);
		if(llGetAgentSize(MyParentId)) {
			//rezzed by avatar
		}
		else {
			//rezzed by object
			ChatChannel=(integer)("0x7F" + llGetSubString((string)MyParentId, 0, 5));
			llListen(ChatChannel, "", "", "");
			sayToCore(addCommand("", ["PC_REZZED"]));
			doAttachTemp(llGetOwner(), ATTACH_POINT);
			llSetTimerEvent(TIMEOUT);
		}
	}

	run_time_permissions(integer perm){
		if(perm & PERMISSION_ATTACH) {
			 if(!llGetAttached()) {
				llAttachToAvatarTemp(ATTACH_POINT);
				llSetTimerEvent(0.0);
			}
		}
		else {
			llOwnerSay("Permission to attach denied.");
			llDie();
		}
	}
	timer(){
		if (!llGetAttached()) {
			llDie();
		}
	}
	changed(integer change) {
		if(change & CHANGED_INVENTORY) {
			FeedbackSoundAvailable=llGetInventoryType(SOUND_NAME)==INVENTORY_SOUND;
		}
	}
}
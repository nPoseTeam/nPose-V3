//settings
integer SHOW_DESCRIPTIONS=FALSE;
integer SHOW_SENDER_NUM=FALSE;
integer SHOW_UNKNOW_NUM=TRUE;
integer USE_OWNER_SAY=TRUE; //llWhispher tends to shuffel the messages more than llOwnerSay, so I suggest to set this to TRUE;

//blacklist filter
list BLACKLIST_SENDER_NUM=[];
list BLACKLIST_NUM=[];
list BLACKLIST_STR=[];
list BLACKLIST_ID=[];

//additional informations
list REPLACE_SENDER_NUM=[];
list REPLACE_NUM=[
	//format: number, numberName, description
	//INTERNAL TO nPose BASIC SCRIPTS
	1, "SEND_CHATCHANNEL", "core sent out chatChannel", 
	2, "REZ_ADJUSTERS", "menu sending a request to slave to rez all adjusters", 
	3, "ADJUSTER_REPORT", "core got info from adjuster and is forwarding it to the slave for reporting", 
	
	200, "DOPOSE", "core is generated in the core when notecard or data from data store line starts with ANIM", 
	201, "ADJUST", "menu to core.  The core rezzes adjuster prims.", 
	202, "SWAP", "menu to core.  This triggers the swap of AV's.", 
	203, "KEYBOARD_CONTROL", "TODO: need to look at this", 
	204, "DUMP", "menu to core to have core chat out in local the current pose set data.  This is used to trigger the core event which saves current in memory data", 
	205, "STOPADJUST", "menu to core as a menu selection to stop adjusting.  The core send out chat to kill the adjusters.", 
	206, "SYNC", "menu sends out used by the core and linked out to slaves.  The slaves do the actual sync.", 
	207, "DOBUTTON", "core sends out this when a link message is found in notecard or in memory data for current pose set.  Mostly applies to BTN notecards.", 
	208, "ADJUSTOFFSET", "menu to core call used only for adjusting offsets to correct AV size.", 
	209, "SETOFFSET", "menu to core call used only for adjusting offsets to correct AV size.", 
	210, "SWAPTO", "menu to core to change seats.", 
	212, "DUMPALL", "menu call to core used to signal in memory data dump of all saved pose sets to owner's local chat. This chat is used to permanently update the .config notecard.", 
	220, "DOREMENU", "This message is sent to the NC Reader to initiate a remenu operation",
	221, "DOREMENU_READER", "This message is sent from the NC Reader to the core to initiate a remenu operation",
	222, "DOPOSE_READER", "With the addition of 'nPose NC Reader' script for cache of pose set button selections, this is used to send the pose command to the core.", 
	223, "DOBUTTON_READER", "With the addition of 'nPose NC Reader' script for cache of pose set button selections, this is used to send the button command to the core.", 
	224, "NC_READER_REQUEST", "Used by NC Reader script.  Someone sent a request to use the Reader", 
	225, "NC_READER_RESPONSE", "Used by NC Reader script.  Script is returning the data requested by NC_READER_REQUEST", 
	300, "CORERELAY", " to the core. This triggers chat to props directly from the core.  There must be a custom receiver script in the props to interpret and act on this message.", 
	
	34333, "SLOT_UPDATE (deprecated)", "from the core when PosDump is clicked to save new positions to memory of the in memory plugin.", 
	34334, "MEMORY_USAGE", "Sends out a request to all script so they can report their memory stats.", 
	35353, "SEAT_UPDATE", " core sends out to update everyone when the slots list has changed in any way.  changed seats or new pose.", 
	35354, "SEAT_BUTTONS", "menu received seat buttons list", 
	999999, "REQUEST_CHATCHANNEL", "slave sent request to core to get chatChannel", 
	69696969, "myChannel", "adjuster hud is on this channel and communicates with the receiver/sender script in the adjuster prim.", 
	
	-240, "OPTIONS", "a global option string", 
	-241, "FACIALS_FLAG", "any string received by the slave with arb number -241 will be assigned to the permissions.  This should either be 'on' or 'off'.", 
	-800, "DOMENU", "call to menu to pull menu dialog.", 
	-801, "DOMENU_ACCESSCTRL", "all to menu to check authorizations currently from the core", 
	-802, "arbNum (Deprecated)", "used to send out the current path to be used when a plugin menu returns to nPose menu.  This path can be used to bring back the same menu that called the plugin's menu in the beginning.", 
	-803, "DOMENU_CORE", "to keep things in sync it is sometimes necessary to relay a DOMENU message through the core",
	-804, "PREPARE_REMENU", "used as a message to the menu script during the remenu process",
	-806, "USER_PERMISSION_UPDATE", "Used by menu script. A plugin such as RLV can send a list used for button permissions.",
	-810, "PLUGIN_MENU_REGISTER", "A method to inject menus created by a plugin into the nPose menu tree.",
	-811, "PLUGIN_MENU_SHOW", "The improved DOMENU call for plugins.",
	-812, "PLUGIN_MENU_RESPONSE", "The Menu response for use in menu plugins.",
	-815, "MENU_SHOW", "The improved DOMENU call. Used internally. Use the DOMENU for calling from NCs. Use PLUGIN_MENU_SHOW for calling from a menu plugin.",
	-888, "EXTERNAL_UTIL_REQUEST", "menu functions such as ChangeSeats, Sync, Offsets, Admin menu.  See Utilities notecards for usage.", 
	-900, "DIALOG", "dialog script call  to and from menu", 
	-901, "DIALOG_RESPONSE", "dialog script call to menu to deliver user clicked response", 
	-902, "DIALOG_TIMEOUT", "dialog call to menu when dialog has timed out with no response from user", 
	-999, "HUD_REQUEST", "rez or detach admin hud",
	
	//PLUGIN SPECIFIC
	1334, "nPose Giver Script:LnkMsgNo", "giver plugin used for sending information to use the giver",
	1337, "RLV Timer Plugin (deprecated):RLV Timer Release", "LINKMSG|1337|10|%AVKEY%  where 10 is the number of minutes before releasing a captured victim",
	1338, "RLV Timer Plugin (deprecated):???", "",
	1444, "nPose plugin AnimSoundOnce:???", "",
	2732, "nPose LM/LG chains plugin (plugin_lockmeister_lockguard):gCMD_SET_CHAINS", "",
	2733, "nPose LM/LG chains plugin (plugin_lockmeister_lockguard):gCMD_REM_CHAINS", "",
	2734, "nPose LM/LG chains plugin:???", "TODO: slmember1",
	7200, "nPose Chain Point Plugin:STARTCHAIN", "channel relayed out to chain point to start chains.", 
	7201, "nPose Chain Point Plugin:STOPCHAIN", "channel relayed out to chain point to stop chains.", 
	27130, "plugin_movePrims:gCMD_GET_PRIMS", "",
	27131, "plugin_movePrims:gCMD_SET_PRIMS", "",
	98132, "morph plugin:arbNum", "Used to send notecard name to the morph plugin",

	-123, "Rygel sequencer plugin:MENU_LINK", "used for menu", 
	-125, "Rygel sequencer plugin:MENU_LINK", "used to let core know it is time for next sequence",
	-233, "RLV:SENSOR_START (deprecated)", "",
	-234, "RLV:SENSOR_END (deprecated)", "",
	-237, "RLV:SEND_CURRENT_VICTIMS (deprecated)", "",
	-238, "RLV:VICTIMS_LIST (deprecated)", "old RLV plugin sent the victims list to the menu.", 
	-239, "RLV:???(change current victim)(deprecated)", "",
	
	-1011, "vehicle plugin:SIT_BUTTON", "", 
	-1012, "vehicle plugin:STAND_BUTTON", "", 
	-1200, "vehicle plugin:SPEED_SET", "signal speed change", 
	-1201, "vehicle plugin:VEHICLETYPE", "used to select vehicle type", 
	-2241, "nPose Sequencer:???", "",
	-2344, "sound plugin:arbNum", "message to stop sound",
	-2345, "sound plugin:arbNum", "message to start sound",
	-6000, "Updater:listenChannel", "channel used by the updater to chat with the updater script within the nPose update target",
	-6001, "giver relay plugin:listenChannel", "link message to giver relay plugin and used as the channel to chat with item to temp attach",
	-6002, "TempAttach plugin:listenChannel", "listen channel for the TempAttach plugin menu dialog selection.", 
	//-8000 - -8050 reserverd for Leona (slmember1 Resident)
	-8000, "RLV+:RLV_MENU_COMMAND", "https://github.com/LeonaMorro/nPose-RLV-Plugin/wiki/Link-messages", 
	-8010, "RLV+:RLV_CORE_COMMAND", "https://github.com/LeonaMorro/nPose-RLV-Plugin/wiki/Link-messages", 
	-8012, "RLV+:RLV_CHANGE_SELECTED_VICTIM", "https://github.com/LeonaMorro/nPose-RLV-Plugin/wiki/Link-messages", 
	-8013, "RLV+:RLV_VICTIMS_LIST_UPDATE", "https://github.com/LeonaMorro/nPose-RLV-Plugin/wiki/Link-messages", 
	-8040, "Xcite! Plugin:XCITE_COMMAND", "https://github.com/LeonaMorro/nPose-Xcite-plugin/wiki/Link-messages", 
	//
	-888888, "tip jar plugin:arb number", "exclusive to the tip jar to send parameters needed in this plugin.", 
	-22452987, "color/texture changer plugin:arbNum", "The plugin uses this to identify when it is supposed to act on the message.  It accepts the message and relays out to prims using this number as a listen channel.  This same script located in props receives the info and does the retexturing of prims.", 
	-1812221819, "RLV plugin (deprecated):relaychannel", "RLV channel"
];

list REPLACE_STR=[];
list REPLACE_ID=[
	NULL_KEY, "NULL_KEY"
];

speak(string str) {
	if(USE_OWNER_SAY) {
		llOwnerSay(str);
	}
	else {
		llWhisper(0, str);
	}
}

default {
	state_entry() {
		llOwnerSay(llGetScriptName() + " up and running. " + (string)llGetFreeMemory() + " Bytes free.");
	}
	link_message(integer sender_num, integer num, string str, key id) {
		if(!~llListFindList(BLACKLIST_NUM, [num])) {
			if(!~llListFindList(BLACKLIST_ID, [(string)id])) {
				if(!~llListFindList(BLACKLIST_SENDER_NUM, [sender_num])) {
					if(!~llListFindList(BLACKLIST_STR, [str])) {
						integer isKnownNum;
						string sSender_num=(string)sender_num;
						string sNum=(string)num;
						string sStr=(string)str;
						string sId=(string)id;
						string sDesc;
						integer index;
						if(~(index=llListFindList(REPLACE_SENDER_NUM, [sender_num]))) {
							sSender_num=llList2String(REPLACE_SENDER_NUM, index+1);
						}
						if(~(index=llListFindList(REPLACE_NUM, [num]))) {
							sNum=llList2String(REPLACE_NUM, index+1) + " (" + sNum + ")";
							sDesc=llList2String(REPLACE_NUM, index+1) + " " + llList2String(REPLACE_NUM, index+2);
							isKnownNum=TRUE;
						}
						if(~(index=llListFindList(REPLACE_STR, [str]))) {
							sStr=llList2String(REPLACE_STR, index+1);
						}
						if(~(index=llListFindList(REPLACE_ID, [(string)id]))) {
							sId=llList2String(REPLACE_ID, index+1);
						}
						if(SHOW_UNKNOW_NUM || isKnownNum) {
							if(SHOW_SENDER_NUM) {
								speak("\n#>" + llDumpList2String([sSender_num, sNum, sStr, sId], "\n#>"));
							}
							else {
								speak("\n#>" + llDumpList2String([sNum, sStr, sId], "\n#>"));
							}
							if(SHOW_DESCRIPTIONS) {
								speak("\n" + sDesc);
							}
						}
					}
				}
			}
		}
	}
}

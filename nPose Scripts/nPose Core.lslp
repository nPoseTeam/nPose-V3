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
string DEFAULT_PREFIX="SET";
integer STRIDE=8;
integer MEMORY_USAGE=34334;
integer SEAT_UPDATE=35353;
integer DOPOSE=200;
integer SWAP=202;
integer SWAPTO=210;
integer DO=220;
integer PREPARE_MENU_STEP3_READER=221;
integer DOPOSE_READER=222;
integer PLUGIN_COMMAND_REGISTER_NO_OVERWRITE=309;
integer PLUGIN_COMMAND_REGISTER=310;
integer UNKNOWN_COMMAND=311;
integer UNSIT=-222;
integer OPTIONS=-240;
integer DEFAULT_CARD=-242;
integer DOMENU=-800;
integer UDPBOOL=-804;
integer UDPLIST=-805;
integer MACRO=-807;
integer PLUGIN_MENU_REGISTER=-810;
integer MENU_SHOW=-815;
integer PREPARE_MENU_STEP1=-820;
integer PREPARE_MENU_STEP2=-821;

integer PLUGIN_ACTION_DONE=-831;
integer DIALOG_TIMEOUT=-902;

integer PROP_PLUGIN=-500;
//define block end

string LastAssignSlotsCardName;
key LastAssignSlotsCardId;
key LastAssignSlotsAvatarId;
list Slots;  //one STRIDE = [animationName, posVector, rotVector, facials, sitterKey, SATMSG, NOTSATMSG, seatName§seatX§action§ncName]
list OldSitters; //a list which stores the Avatar uuids on a Slots list reset

integer CurMenuOnSit; //default menuonsit option
integer Cur2default;  //default action to revert back to default pose when last sitter has stood
vector ScaleRef; //perhaps we want to do rezzing etc. relative to the current scale of the object. If yes: we need a reference scale.
string SeatAssignList="a";
//SeatAssignList contains a list (separated by ",") with seatnumbers and keyword. //a(scending), d(escending), r(andom)


string NC_READER_CONTENT_SEPARATOR="%&§";

//PluginCommands=[string name, integer num, integer sendToProps, integer sendUntouchedParams]
list PluginCommandsDefault=[
	"PLUGINCOMMAND", PLUGIN_COMMAND_REGISTER, 0,
	"DEFAULTCARD", DEFAULT_CARD, 0,
	"OPTION", OPTIONS, 0,
	"OPTIONS", OPTIONS, 0,
	"UDPBOOL", UDPBOOL, 0,
	"UDPLIST", UDPLIST, 0,
	"MACRO", MACRO, 0,
	"DOCARD", DOPOSE, 0,
	"TIMER", -600, 1, //If ON_(UN)SIT is known without registration
	"TIMER_REMOVE", -601, 0 //then we also should know the TIMER(_REMOVE) commands
];
list PluginCommands;
integer PLUGIN_COMMANDS_NAME=0;
integer PLUGIN_COMMANDS_NUM=1;
integer PLUGIN_COMMANDS_SEND_UNTOUCHED=2;
integer PLUGIN_COMMANDS_STRIDE=3;

UpdateDefaultCard() {
	if(llGetInventoryType(INIT_CARD_NAME)==INVENTORY_NOTECARD) {
		llMessageLinked(LINK_SET, DOPOSE, INIT_CARD_NAME, NULL_KEY);
	}
	else {
		//this is the old default notcard detection.
		integer index;
		integer length = llGetInventoryNumber(INVENTORY_NOTECARD);
		for(index=0; index < length; index++) {
			string cardName = llGetInventoryName(INVENTORY_NOTECARD, index);
			if((llSubStringIndex(cardName, DEFAULT_PREFIX + ":") == 0)) {
				llMessageLinked(LINK_SET, DEFAULT_CARD, cardName, NULL_KEY);
				return;
			}
		}
	}
}

integer FindEmptySlot(integer preferredSlotNumber) {
	integer index;
	integer length=llGetListLength(Slots);
	list slotNumbers;
	for(index=4; index < length; index+=STRIDE) {
		if(llList2String(Slots, index)=="") {
			slotNumbers+=index/STRIDE;
		}
	}
	if(!llGetListLength(slotNumbers)) {
		return -1;
	}
	if(~llListFindList(slotNumbers, [preferredSlotNumber])) {
		return preferredSlotNumber;
	}
	list parts=llCSV2List(SeatAssignList);
	while(llGetListLength(parts)) {
		string item=llList2String(parts, 0);
		if(item=="a") {
			return llList2Integer(slotNumbers, 0);
		}
		if(item=="d") {
			return llList2Integer(slotNumbers, -1);
		}
		else if(item=="r") {
			return llList2Integer(llListRandomize(slotNumbers, 1), 0);
		}
		else if(~llListFindList(slotNumbers, [(integer)item - 1])) {
			return (integer)item - 1;
		}
		parts=llDeleteSubList(parts, 0, 0);
	}
	return -1;
}

assignSlots(string cardName) {
	//Get the seated Avs and the named seat they are sitting on
	list validSitters; // stride: [sitterKey, (integer)namedSeatNumber]
	integer index;
	for(index = llGetNumberOfPrims(); index>1; index--) {
		key id=llGetLinkKey(index);
		if(llGetAgentSize(id) != ZERO_VECTOR) {
			//is an Avatar
			validSitters = [id, 0] + validSitters;
		}
		else {
			//is a prim
			key sitter=llAvatarOnLinkSitTarget(index);
			if(sitter) {
				integer indexValidSitters=llListFindList(validSitters, [sitter]);
				if(~indexValidSitters) {
					validSitters=llListReplaceList(validSitters, [(integer)llGetLinkName(index)], indexValidSitters+1, indexValidSitters+1);
				}
			}
		}
	}
	//check if all Avatars in our Slots list are valid
	integer length=llGetListLength(Slots);
	for(index=4; index<length; index+=STRIDE) {
		if(llGetListLength(validSitters)) {
			integer indexValidSitters=llListFindList(validSitters, [llList2Key(Slots, index)]);
			if(~indexValidSitters) {
				validSitters=llDeleteSubList(validSitters, indexValidSitters, indexValidSitters+1);
			}
			else {
				Slots=llListReplaceList(Slots, [""], index, index);
			}
		}
		else {
			Slots=llListReplaceList(Slots, [""], index, index);
		}
	}
	//our Slots list is now valid and the validSitters list contains "extra" sitters from a Slots list change
	//and new sitter(s). The list is sorted by the time they sit down
	//so all we have to do is trying to place them in the Slots list
	//if they are sitting on a numbered seat we should first try to sit them in the corresponding slot.
	while(llGetListLength(validSitters)) {
		key id=llList2Key(validSitters, 0);
		integer emptySlot=FindEmptySlot(llList2Integer(validSitters, 1)-1);
		if(~emptySlot) {
			Slots=llListReplaceList(Slots, [id], emptySlot*STRIDE+4, emptySlot*STRIDE+4);
			//check if the menu should be displayed
			if(CurMenuOnSit) {
				if(!llGetListLength(OldSitters) || !(~llListFindList(OldSitters, [id]))) {
					llMessageLinked(LINK_SET, DOMENU, "", id);
				}
			}
		}
		else {
			llMessageLinked(LINK_SET, UNSIT, id, NULL_KEY);
		}
		validSitters=llDeleteSubList(validSitters, 0 , 1);
	}
	OldSitters=[];
	llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), cardName);
}

SwapTwoAvatars(integer seatNumber1, integer seatNumber2) {
	integer index1=(seatNumber1 - 1) * STRIDE + 4;
	integer index2=(seatNumber2 - 1) * STRIDE + 4;
	if(index1>=0 && index2>=0 && index1 < llGetListLength(Slots) && index2 < llGetListLength(Slots)) { //sanity
		Slots=llListReplaceList(llListReplaceList(Slots, [llList2Key(Slots, index2)], index1, index1), [llList2Key(Slots, index1)], index2, index2);
		llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
	}
}

string insertPlaceholder(string sLine, key avKey, integer avSeat, string ncName, string path, integer page) {
	if(~llSubStringIndex(sLine, "%")) {
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%CARDNAME%"], []), ncName);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%AVKEY%"], []), (string)avKey);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%AVSEAT%"], []), (string)avSeat);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%PATH%"], []), path);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%PAGE%"], []), (string)page);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%DISPLAYNAME%"], []), llGetDisplayName(avKey));
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%USERNAME%"], []), llGetUsername(avKey));
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%SCALECUR%"], []), (string)llList2Vector(llGetLinkPrimitiveParams((integer)(llGetNumberOfPrims()>1), [PRIM_SIZE]), 0));
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%SCALEREF%"], []), (string)ScaleRef);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%POSITION%"], []), (string)llGetRootPosition());
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%ROTATION%"], []), (string)llGetRootRotation());

		integer index;
		integer length=llGetListLength(Slots);
		if(~llSubStringIndex(sLine, ".KEY%")) {
			sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%OWNER.KEY%"], []), llGetOwner());
			for(index=0; index<length; index+=STRIDE) {
				sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%" + (string)(index/STRIDE+1) + ".KEY%"], []), (string)llList2Key(Slots, index + 4));
			}
		}
		if(~llSubStringIndex(sLine, ".USERNAME%")) {
			for(index=0; index<length; index+=STRIDE) {
				sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%" + (string)(index/STRIDE+1) + ".USERNAME%"], []), llGetUsername(llList2Key(Slots, index + 4)));
			}
		}
		if(~llSubStringIndex(sLine, ".DISPLAYNAME%")) {
			for(index=0; index<length; index+=STRIDE) {
				sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%" + (string)(index/STRIDE+1) + ".DISPLAYNAME%"], []), llGetDisplayName(llList2Key(Slots, index + 4)));
			}
		}
	}
	return sLine;
}

ProcessLine(string sLine, key avKey, integer avSeat, string ncName, string path, integer page) {
	list paramsOriginal = llParseStringKeepNulls(sLine, ["|"], []);
	sLine=insertPlaceholder(sLine, avKey, avSeat, ncName, path, page);
	list params = llParseStringKeepNulls(sLine, ["|"], []);
	string action = llList2String(params, 0);
	string perms;
	list temp=llParseString2List(action, ["{", "}"], []);
	if(llGetListLength(temp)>1) {
		action=llList2String(temp, 0);
		perms=llToLower(llStringTrim(llList2String(temp, 1), STRING_TRIM));
	}
	//check the permissions, could be equal to the isAllowed function in the menu script, but we currently don't have enough script space
	//so we only check for single integer values
	// any integer counts as a seatNumber:
	//		TRUE if the (menu) user sits on the seat with the given number
	if(perms!="") {
		if((string)((integer)perms) == perms) {
			//is an single integer (seat number)
			if(avSeat!=(integer)perms) {
				return;
			}
		}
	}

	if(action == "ANIM") {
		Slots += [
			llList2String(params, 1),
			(vector)llList2String(params, 2),
			llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD),
			llList2String(params, 4),
			llList2Key(OldSitters, 0),
			"",
			"",
			llGetSubString(llList2String(params, 5), 0, 12) + "§" + "seat"+(string)(llGetListLength(Slots)/STRIDE+1) + "§" + action + "§" + ncName
		];
		OldSitters=llDeleteSubList(OldSitters, 0, 0);
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
		// Note: "SCHMO|1|..." is the same as "SCHMOE{1}|1|...."
		
		integer slotNumber = (integer)llList2String(params,1)-1;
		if(slotNumber>=0 && slotNumber * STRIDE < llGetListLength(Slots)) { //sanity
			 if(action == "SCHMOE" || (action == "SCHMO" && llList2Key(Slots, slotNumber * STRIDE + 4) == avKey)) {
				integer index;
				integer length=llGetListLength(params);
				string seatName=llList2String(llParseStringKeepNulls(llList2String(params, 7), ["§"], []), 0);
				for(index=2; index<length; index++) {
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
						seatName=llList2String(params, index);
					}
				}
				Slots=llListReplaceList(Slots,
					[
						llDumpList2String([seatName, "seat"+ (string)(slotNumber+1), action, ncName], "§")
					],
						slotNumber * STRIDE + 7, slotNumber * STRIDE + 7);
			}
		}
	}
	else if(action=="PAUSE") {
		llSleep((float)llList2String(params, 1));
	}
	else if(action == "LINKMSG") {
		//notice: LINKMSG will not fire inside the props anymore, use PROP_DO|propName|propGroup|LINKMSG....
		//reason: waste of CPU time
		//notice: LINKMSG doesn't support the pause parameter anymore
		//reason: the pause was evil
		integer num = (integer)llList2String(params, 1);
		key lmid;
		if((key)llList2String(params, 3) != "") {
			lmid = (key)llList2String(params, 3);
		}
		else {
			lmid = avKey;
		}
		llMessageLinked(LINK_SET, num, llList2String(params, 2), lmid);
//		llMessageLinked(LINK_SET, PROP_CHANNEL, "PROP_DO|*|*|" + sLine, avKey);
	}
	else if (action == "ON_SIT" || action == "ON_UNSIT") {
		//Syntax: ON_SIT|seatNumber|any command ...
		//example
		//  ON_SIT|1|LINKMSG|1234|This is a test|%AVKEY%
		//if you want to set the ON_SIT command only for the menu user (like the SCHMO command) then use the new command permissions:
		//example:
		//  ON_SIT{2}|2|PROP_REZ|propName|<0,0,0>|<0,0,0>
		//  ON_UNSIT{2}|2|PROP_DIE|propName

		integer index=((integer)llList2String(params, 1)-1) * STRIDE + 5 + (action == "ON_UNSIT");
		if(index>=0 && index < llGetListLength(Slots)) { //sanity
			string msg=llList2String(Slots, index);
			if(llStringLength(msg)) {
				msg+=NC_READER_CONTENT_SEPARATOR;
			}
			Slots = llListReplaceList(
				Slots,
				[msg + llDumpList2String(llDeleteSubList(paramsOriginal, 0, 1), "|")],
				index,
				index
			);
		}
	}
	else if(action == "PLUGINMENU") {
		llMessageLinked(LINK_SET, PLUGIN_MENU_REGISTER, llDumpList2String(llListReplaceList(params, [path], 0, 0), "|"), "");
	}
	else if(action=="PROPDIE") {
		//PROPDIE is deprecated and should be replaced by: PROP_DO|propName|propGroup|DIE
		llMessageLinked(LINK_SET, PROP_PLUGIN, llDumpList2String(["PROP_DO"] + llDeleteSubList(params, 0, 0) + ["DIE"], "|"), avKey);
	}
	else if(action=="PROP" || action=="PROP_DO"  || action=="PROP_DO_ALL" || action=="PARENT_DO" || action=="PARENT_DO_ALL" || action=="DIE" || action=="TEMPATTACH" || action=="ATTACH") {
		//Prop related
		llMessageLinked(LINK_SET, PROP_PLUGIN, sLine, avKey);
	}
	else {
		integer index=llListFindList(PluginCommands + PluginCommandsDefault, [action]);
		if(~index) {
			integer num=llList2Integer(PluginCommands + PluginCommandsDefault, index + PLUGIN_COMMANDS_NUM);
			string str=llDumpList2String(llDeleteSubList(params, 0, 0), "|");
			if(llList2Integer(PluginCommands + PluginCommandsDefault, index + PLUGIN_COMMANDS_SEND_UNTOUCHED)) {
				str=llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|");
			}
			llMessageLinked(LINK_SET, num, str, avKey);
		}
		else {
			llMessageLinked(LINK_SET, UNKNOWN_COMMAND, sLine, avKey);
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
		integer index;
		for(index=0; index<=llGetNumberOfPrims(); ++index) {
		   llLinkSitTarget(index, <0.0,0.0,0.5>, ZERO_ROTATION);
		}
		llSleep(1.0); //wait for other scripts
		UpdateDefaultCard();
	}
	link_message(integer sender, integer num, string str, key id) {
		if(num == DOPOSE_READER || num==PREPARE_MENU_STEP3_READER || num==DO) {
			list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
			str = "";
			if(num==DO) {
				allData=["", "", ""] + allData;
			}
			//allData: [ncName, paramSet1, "", contentLine1, contentLine2, ...]
			string ncName=llList2String(allData, 0);
			if(ncName==DefaultCardName && num == DOPOSE_READER) {
				//props (propGroup 0) die when the default card is read
				llMessageLinked(LINK_SET, PROP_PLUGIN, "PROP_DO|*|0|DIE", id);
			}
			list paramSet1List=llParseStringKeepNulls(llList2String(allData, 1), ["|"], []);
			string path=llList2String(paramSet1List, 0);
			integer page=(integer)llList2String(paramSet1List, 1);
			string prompt=llList2String(paramSet1List, 2);
			
			integer avSeat=(llListFindList(Slots, [id]) + 8) / 8;
			//parse the NC content
			integer length=llGetListLength(allData);
			integer index;
			integer run_assignSlots;
			integer slotResetFinished;
			for(index=3; index<length; index++) {
				string data = llList2String(allData, index);
				if(num!=PREPARE_MENU_STEP3_READER) {
					if(!llSubStringIndex(data, "ANIM") && !slotResetFinished) {
						//reset the slots
						OldSitters=llList2ListStrided(llDeleteSubList(Slots, 0, 3), 0, -1, STRIDE);
						Slots=[];
						slotResetFinished=TRUE;
						run_assignSlots = TRUE;
						//props (propGroup 0) die if there is an ANIM line inside the NC
						llMessageLinked(LINK_SET, PROP_PLUGIN, "PROP_DO|*|0|DIE", id);
					}
					if(!llSubStringIndex(data, "SCHMO")) { //finds SCHMO and SCHMOE
						run_assignSlots = TRUE;
					}
					ProcessLine(llList2String(allData, index), id, avSeat, ncName, path, page);
				}
				else {
					//get all menu relevant data
					if(!llSubStringIndex(data, "MENU")) {
						list parts=llParseStringKeepNulls(insertPlaceholder(data, id, avSeat, ncName, path, page), ["|"], []);
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
				assignSlots(ncName);
				if (llGetInventoryType(ncName) == INVENTORY_NOTECARD){ //sanity
					LastAssignSlotsCardName=ncName;
					LastAssignSlotsCardId=llGetInventoryKey(LastAssignSlotsCardName);
					LastAssignSlotsAvatarId=id;
				}
				//card has been read. rerezz adjusters, send message to slave script.
				//llMessageLinked(LINK_SET, REREZ_ADJUSTERS, "", "");
			}
			if(path!="") {
				//only try to remenu if there are parameters to do so
				string paramSet1=buildParamSet1(path, page, prompt, [llList2String(paramSet1List, 3)], llList2List(paramSet1List, 4, 7));
				if(num==PREPARE_MENU_STEP3_READER) {
					//we are ready to show the menu
					llMessageLinked(LINK_SET, MENU_SHOW, paramSet1, id);
				}
				else if(num==DOPOSE_READER) {
					llMessageLinked(LINK_SET, PREPARE_MENU_STEP1, paramSet1, id);
				}
			}
		}
		else if(num==PLUGIN_ACTION_DONE) {
			//only relay through the core to keep messages in sync
			llMessageLinked(LINK_SET, PREPARE_MENU_STEP2, str, id);
		}
/*
		// CORERELAY not longer supported, use llMessageLinked(LINK_SET, PROP_PLUGIN(-500), "PROP_DO|*|*|LINKMSG..."
		else if(num == CORERELAY) {
			list msg = llParseString2List(str, ["|"], []);
			if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
			llRegionSay(ChatChannel,llDumpList2String(["LINKMSG", (string)llList2String(msg, 0),
				llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
		}
*/
		else if (num == SWAP) {
			//swap the two seats
			//usage LINKMSG|202|1,2
			list seats2Swap = llCSV2List(str);
			SwapTwoAvatars((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
		}


		else if(num == SWAPTO) {
			//move clicker to a new seat#
			//new seat# occupant will then occupy the old seat# of menu user.
			//usage:  LINKMSG|210|3|%AVKEY%  Will swap the user with the id %AVKEY% to seat3 and seat3 occupant moves to existing %AVKEY%'s seat#
			//this is intended as an internal call for ChangeSeat button but can be used by any plugin, LINKMSG, or SAT/NOTSATMSG
			SwapTwoAvatars((integer)str, llListFindList(Slots, [id])/STRIDE + 1);
		}
		else if(num == DEFAULT_CARD) {
			DefaultCardName=str;
			llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, id);
		}
		else if(num==PLUGIN_COMMAND_REGISTER || num==PLUGIN_COMMAND_REGISTER_NO_OVERWRITE) {
			//old Format (remove in nPose V5): PLUGINCOMMAND|name|num|[sendToProps[|sendUntouchedParams]]
			//new Format: PLUGINCOMMAND|name, num[, sendUntouchedParams][|name...]...
			if(!~llSubStringIndex(str, ",")) {
				//old Format:convert to new format
				str=llList2CSV(llDeleteSubList(llParseStringKeepNulls(str, ["|"], []), 2, 2));
			}
			list parts=llParseString2List(str, ["|"], []);
			while(llGetListLength(parts)) {
				list subParts=llCSV2List(llList2String(parts, 0));
				parts=llDeleteSubList(parts, 0, 0);
				string action=llList2String(subParts, PLUGIN_COMMANDS_NAME);
				integer index=llListFindList(PluginCommands, [action]);
				if(num==PLUGIN_COMMAND_REGISTER && ~index) {
					PluginCommands=llDeleteSubList(PluginCommands, index, index + PLUGIN_COMMANDS_STRIDE - 1);
				}
				if(num==PLUGIN_COMMAND_REGISTER || !~index) {
					PluginCommands+=[
						action,
						(integer)llList2String(subParts, PLUGIN_COMMANDS_NUM),
						(integer)llList2String(subParts, PLUGIN_COMMANDS_SEND_UNTOUCHED)
					];
				}
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
			for(index=0; index<length; ++index) {
				list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
				string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
				string optionString = llList2String(optionsItems, 1);
				string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
				integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;

				if(optionItem == "menuonsit") {CurMenuOnSit = optionSettingFlag;}
				else if(optionItem == "2default") {Cur2default = optionSettingFlag;}
				else if(optionItem == "scaleref") {ScaleRef = (vector)optionString;}
				else if(optionItem == "seatassignlist") {SeatAssignList = optionSetting;}
			}
		}
		else if(num == MEMORY_USAGE) {
			llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
			 + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
		llSay(0, "running script time for all scripts in this nPose object are consuming " 
		 + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0)*1000.0) + " ms of cpu time");
		}
	}

	changed(integer change) {
		if(change & CHANGED_INVENTORY) {
			llSleep(0.5); //be sure that the NC reader is ready
			if(llGetInventoryType(LastAssignSlotsCardName) == INVENTORY_NOTECARD) {
				if(LastAssignSlotsCardId!=llGetInventoryKey(LastAssignSlotsCardName)) {
					//the last used nc changed, "redo" the nc
					llMessageLinked(LINK_SET, DOPOSE, LastAssignSlotsCardName, LastAssignSlotsAvatarId); 
				}
				else {
					UpdateDefaultCard();
				}
			}
			else {
				UpdateDefaultCard();
			}
		}
		if(change & CHANGED_LINK) {
			assignSlots(LastAssignSlotsCardName);
			if(Cur2default && (llGetObjectPrimCount(llGetKey()) == llGetNumberOfPrims()) && (DefaultCardName != "")) {
				llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, NULL_KEY);
			}
		}
	}
	
	on_rez(integer param) {
		llResetScript();
	}
}

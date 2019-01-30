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
string ADMIN_HUD_NAME="npose admin hud";
integer STRIDE=8;
integer MEMORY_USAGE=34334;
integer SEAT_UPDATE=35353;
integer REQUEST_CHATCHANNEL=999999;
integer SEND_CHATCHANNEL=1;
//integer REREZ_ADJUSTERS=2;
//integer ADJUSTER_REPORT=3;
integer DOPOSE=200;
integer ADJUST=201;
integer SWAP=202;
integer DUMP=204;
integer STOPADJUST=205;
integer SYNC=206;
integer DOBUTTON=207;
integer ADJUSTOFFSET=208;
integer SWAPTO=210;
integer DO=220;
integer PREPARE_MENU_STEP3_READER=221;
integer DOPOSE_READER=222;
integer DOBUTTON_READER=223;
integer CORERELAY=300;
integer PLUGIN_COMMAND_REGISTER=310;
integer UNKNOWN_COMMAND=311;
integer UNSIT=-222;
integer OPTIONS=-240;
integer DEFAULT_CARD=-242;
integer ON_PROP_REZZED=-790;
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
integer HUD_REQUEST=-999;
//define block end

integer ChatChannel;
integer ExplicitFlag;
key HudId;
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
list PluginCommands=[
	"PLUGINCOMMAND", PLUGIN_COMMAND_REGISTER, 0, 0,
	"DEFAULTCARD", DEFAULT_CARD, 0, 0,
	"OPTION", OPTIONS, 0, 0,
	"OPTIONS", OPTIONS, 0, 0,
	"UDPBOOL", UDPBOOL, 0, 0,
	"UDPLIST", UDPLIST, 0, 0,
	"MACRO", MACRO, 0, 0,
	"DOCARD", DOBUTTON, 0, 0
];

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
	if(llGetListLength(Slots)) {
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
	}
	OldSitters=[];
	llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), cardName);
}
/*
assignSlots(string cardName){
	//Get the seated Avs
	list avqueue;
	integer n = llGetNumberOfPrims();
	for(; n >= llGetObjectPrimCount(llGetKey()); --n) {
		//only check link numbers greater than the number of actual prims, these will be the AV link numbers.
		key id = llGetLinkKey(n);
		if(llGetAgentSize(id) != ZERO_VECTOR) {
			avqueue = [id] + avqueue;
		}
	}
	// clean up the Slots list with regard to AV key's in the list by
	// removing extra AV keys from the Slots list, they are no longer seated.
	integer x;
	for(; x < SlotMax; ++x) {
		//look in the avqueue for the key in the Slots list
		if(!~llListFindList(avqueue, [llList2Key(Slots, x*STRIDE+4)])) {
			//if the key is not in the avqueue, remove it from the Slots list
			Slots = llListReplaceList(Slots, [""], x*STRIDE+4, x*STRIDE+4);
		}
	}
	//we need to check if less seats are available, more seats would not need slots assigned at this point, they just empty seats.
	if(SlotMax < LastStrideCount) {
		//new pose set has less seats available
		//AV's that were in a available seats are already assigned so leave them be
		for(x = SlotMax; x <= LastStrideCount; ++x) {//only need to worry about the 'extra' slots so limit the count
			if(llList2Key(Slots, x*STRIDE+4) != "") {
				//this is a 'now' extra sitter
				integer emptySlot = FindEmptySlot();//find an empty slot for them if available
				if((emptySlot >= 0) && (emptySlot < SlotMax)) {
					//if a real seat available, seat them
					Slots = llListReplaceList(Slots, [llList2Key(Slots, x*STRIDE+4)], emptySlot*STRIDE+4, emptySlot*STRIDE+4);
				}
			}
		}
		//remove the 'now' extra seats from Slots list
		Slots = llDeleteSubList(Slots, (SlotMax)*STRIDE, -1);
		//unsit extra seated AV's
		for(n=0; n<llGetListLength(avqueue); ++n) {
			if(!~llListFindList(Slots, [llList2Key(avqueue, n)])) {
				llMessageLinked(LINK_SET, UNSIT, llList2String(avqueue, n), NULL_KEY);
			}
		}
	}
	//step through the avqueue list and check if everyone is accounted for
	//newest sitters last in avqueue list so step through increamentally
	integer nn;
	for(; nn<llGetListLength(avqueue); ++nn) {
		key thisKey = llList2Key(avqueue, nn);
		integer index = llListFindList(Slots, [llList2Key(avqueue, nn)]);
		integer emptySlot = FindEmptySlot();
		if(!~index) {
			//this AV not in Slots list
			key newAvatar;
			//check if they on a numbered seat
			integer slotNum=-1;
			for(n = 1; n <= llGetObjectPrimCount(llGetKey()); ++n) {
				//find out which prim this new AV is seated on and grab the slot number if it's a numbered prim.
				integer x = (integer)llGetSubString(llGetLinkName(n), 4, -1);
				if((x > 0) && (x <= SlotMax)) {
					if(llAvatarOnLinkSitTarget(n) == thisKey) {
						if(llList2String(Slots, (x-1)*STRIDE+4) == "") {
							slotNum = (integer)llGetLinkName(n);
							Slots = llListReplaceList(Slots, [thisKey], (slotNum-1)*STRIDE+4, (slotNum-1)*STRIDE+4);
							newAvatar=thisKey;
						}
					}
				}
			}
			if(!~llListFindList(Slots, [thisKey])) {
				if(~emptySlot) {
					//they not on numbered seat so grab the lowest available seat for them, we have one available
					Slots = llListReplaceList(Slots, [thisKey], (emptySlot * STRIDE) + 4, (emptySlot * STRIDE) + 4);
					newAvatar=thisKey;
				}
				else {
					llMessageLinked(LINK_SET, UNSIT, thisKey, NULL_KEY);
				}
			}
			if(newAvatar) {
				if(CurMenuOnSit) {
					llMessageLinked(LINK_SET, DOMENU, "", newAvatar);
				}
			}
		}
	}
	LastStrideCount = SlotMax;
	llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), cardName);
}
*/

/*
SwapTwoSlots(integer currentseatnum, integer newseatnum) {
	if(newseatnum <= SlotMax) {
		integer slotNum;
		integer OldSlot;
		integer NewSlot;
		for(; slotNum < SlotMax; ++slotNum) {
			list tempSeat = llParseStringKeepNulls(llList2String(Slots, slotNum*STRIDE+7), ["§"], []);
			string strideSeat = llList2String(tempSeat, 1);
			tempSeat =[];
			if(strideSeat == "seat" + (string)(currentseatnum)) {
				OldSlot= slotNum;
			}
			if(strideSeat == "seat" + (string)(newseatnum)) {
				NewSlot= slotNum;
			}
		}

		list curslot = llList2List(Slots, NewSlot*STRIDE, NewSlot*STRIDE+3)
				+ [llList2Key(Slots, OldSlot*STRIDE+4)]
				+ llList2List(Slots, NewSlot*STRIDE+5, NewSlot*STRIDE+7);
		Slots = llListReplaceList(Slots, llList2List(Slots, OldSlot*STRIDE, OldSlot*STRIDE+3)
				+ [llList2Key(Slots, NewSlot*STRIDE+4)]
				+ llList2List(Slots, OldSlot*STRIDE+5, OldSlot*STRIDE+7), OldSlot*STRIDE, (OldSlot+1)*STRIDE-1);

		Slots = llListReplaceList(Slots, curslot, NewSlot*STRIDE, (NewSlot+1)*STRIDE-1);
	}
	else {
		llRegionSayTo(llList2Key(Slots, llListFindList(Slots, ["seat"+(string)currentseatnum])-4),
			 0, "Seat "+(string)newseatnum+" is not available for this pose set");
	}
	llMessageLinked(LINK_SET, SEAT_UPDATE, llDumpList2String(Slots, "^"), NULL_KEY);
}
*/
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
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%SCALECUR%"], []), (string)llGetScale());
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%SCALEREF%"], []), (string)ScaleRef);
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%POSITION%"], []), (string)llGetPos());
		sLine = llDumpList2String(llParseStringKeepNulls(sLine, ["%ROTATION%"], []), (string)llGetRot());
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
	else if (action == "PROP") {
		string obj = llList2String(params, 1);
		if(llGetInventoryType(obj) == INVENTORY_OBJECT) {
			//the old die command for explicit props. should be removed soon.
			list strParm2 = llParseString2List(llList2String(params, 2), ["="], []);
			if(llList2String(strParm2, 1) == "die") {
				llRegionSay(ChatChannel,llList2String(strParm2,0)+"=die");
			}
			else {
				//the rezzing
				string propGroupString=llList2String(params, 4);
				integer propGroup=(integer)propGroupString;
				if(propGroupString=="explicit") {
					propGroup=1;
				}
				//This flag will keep the prop from chatting out it's moves. Some props should move but not spam owner.
				integer quietMode;
				if(llList2String(params, 5) == "quiet") {
					quietMode=TRUE;
				}
				//calculate pos and rot of the prop
				vector vDelta = (vector)llList2String(params, 2);
				vector pos = llGetPos() + (vDelta * llGetRot());
				rotation rot = llEuler2Rot((vector)llList2String(params, 3) * DEG_TO_RAD) * llGetRot();
				
				//build the rez paremeter. Upper 3 Bytes for the chatchannel, lower Byte for data
				integer rezParam = (ChatChannel << 8);
				rezParam=rezParam | (quietMode << 1) | ((propGroup & 0x2F) << 2);
				if(llVecMag(vDelta) > 9.9) {
					//too far to rez it direct.  need to do a prop move
					llRezAtRoot(obj, llGetPos(), ZERO_VECTOR, rot, rezParam);
					llSleep(1.0);
					llRegionSay(ChatChannel, llDumpList2String(["MOVEPROP", obj, (string)pos], "|"));
				}
				else {
					llRezAtRoot(obj, pos, ZERO_VECTOR, rot, rezParam);
				}
			}
		}
	}
	else if(action=="PROPDIE") {
		llRegionSay(ChatChannel, llList2Json(JSON_ARRAY, [llList2Json(JSON_ARRAY, params)]));
	}
	else if(action=="PAUSE") {
		llSleep((float)llList2String(params, 1));
	}
	else if(action == "LINKMSG") {
		integer num = (integer)llList2String(params, 1);
		key lmid;
		if((key)llList2String(params, 3) != "") {
			lmid = (key)llList2String(params, 3);
		}
		else {
			lmid = avKey;
		}
		llMessageLinked(LINK_SET, num, llList2String(params, 2), lmid);
		llSleep((float)llList2String(params, 4));
		llRegionSay(ChatChannel, llDumpList2String(["LINKMSG",num,llList2String(params, 2),lmid], "|"));
	}
	else if (action == "ON_SIT" || action == "ON_UNSIT") {
		//Syntax: ON_SIT|seatNumber|any command ...
		//example
		//  ON_SIT|1|LINKMSG|1234|This is a test|%AVKEY%
		//if you want to set the ON_SIT command only for the menu user (like the SCHMO command) then use the new command permissions:
		//example:
		//  ON_SIT{2}|2|PROP|propName|<0,0,0>|<0,0,0>
		//  ON_UNSIT{2}|2|PROPDIE|propName

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
	else if (action == "SATMSG" || action == "NOTSATMSG") {
		//DEPRECATED use ON_SIT
		//set index for normal (we building Slots list) cards containing ANIM or SCHMOE lines
		integer index = llGetListLength(Slots) - STRIDE + 5 + (action == "NOTSATMSG");
		//change that index if we have SCHMO lines
		if((integer)llList2String(paramsOriginal, 4) >= 1) {
			index = ((integer)llList2String(params, 4)-1) * STRIDE + 5 + (action == "NOTSATMSG");
		}
		if(index>=0 && index < llGetListLength(Slots)) { //sanity
			Slots = llListReplaceList(
				Slots,
				[llDumpList2String([llList2String(Slots,index), llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|")], "§")],
				index,
				index
			);
		}
	}
	else if(action == "PLUGINMENU") {
		llMessageLinked(LINK_SET, PLUGIN_MENU_REGISTER, llDumpList2String(llListReplaceList(params, [path], 0, 0), "|"), "");
	}
	else {
		integer index=llListFindList(PluginCommands, [action]);
		if(~index) {
			integer num=llList2Integer(PluginCommands, index+1);
			string str=llDumpList2String(llDeleteSubList(params, 0, 0), "|");
			if(llList2Integer(PluginCommands, index+3)) {
				str=llDumpList2String(llDeleteSubList(paramsOriginal, 0, 0), "|");
			}
			llMessageLinked(LINK_SET, num, str, avKey);
			if(llList2Integer(PluginCommands, index+2)) {
				//this should also be send to props
				llRegionSay(ChatChannel, llList2Json(JSON_ARRAY, [llList2Json(JSON_ARRAY, ["LINKMSG", num, str, avKey])]));
			}
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
		ChatChannel = (integer)("0x7F" + llGetSubString((string)llGetKey(), 0, 5));
		//let our scripts know the chat channel for props and adjusters
		integer listener = llListen(ChatChannel, "", "", "");
		llSleep(1.5); //wait for other scripts
		llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)ChatChannel, NULL_KEY);
		UpdateDefaultCard();
	}
	link_message(integer sender, integer num, string str, key id) {
		if(num == REQUEST_CHATCHANNEL) {//slave has asked me to reset so it can get the ChatChannel from me.
			//let our scripts know the chat channel for props and adjusters
			llMessageLinked(LINK_SET, SEND_CHATCHANNEL, (string)ChatChannel, NULL_KEY);
		}
		else if(num == DOPOSE_READER || num == DOBUTTON_READER || num==PREPARE_MENU_STEP3_READER || num==DO) {
			list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
			str = "";
			if(num==DO) {
				allData=["", "", ""] + allData;
			}
			//allData: [ncName, paramSet1, "", contentLine1, contentLine2, ...]
			string ncName=llList2String(allData, 0);
			if(ncName==DefaultCardName && num == DOPOSE_READER) {
				//props (propGroup 0) die when the default card is read
				llRegionSay(ChatChannel, "die");
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
						llRegionSay(ChatChannel, "die");
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
				else if(num==DOPOSE_READER || DOBUTTON_READER) {
					llMessageLinked(LINK_SET, PREPARE_MENU_STEP1, paramSet1, id);
				}
			}
		}
		else if(num==PLUGIN_ACTION_DONE) {
			//only relay through the core to keep messages in sync
			llMessageLinked(LINK_SET, PREPARE_MENU_STEP2, str, id);
		}
		else if(num == CORERELAY) {
			list msg = llParseString2List(str, ["|"], []);
			if(id != NULL_KEY) msg = llListReplaceList((msg = []) + msg, [id], 2, 2);
			llRegionSay(ChatChannel,llDumpList2String(["LINKMSG", (string)llList2String(msg, 0),
				llList2String(msg, 1), (string)llList2String(msg,2)], "|"));
		}
		else if (num == SWAP) {
			//swap the two slots
			//usage LINKMSG|202|1,2
			list seats2Swap = llCSV2List(str);
			SwapTwoAvatars((integer)llList2String(seats2Swap, 0), (integer)llList2String(seats2Swap, 1));
		}

/*
		else if(num == SWAPTO) {
			//move clicker to a new seat#
			//new seat# occupant will then occupy the old seat# of menu user.
			//usage:  LINKMSG|210|3  Will swap menu user to seat3 and seat3 occupant moves to existing menu user's seat#
			//this is intended as an internal call for ChangeSeat button but can be used by any plugin, LINKMSG, or SAT/NOTSATMSG
			integer slotIndex = llListFindList(Slots, [id])/STRIDE;
			list tempSeat = llParseStringKeepNulls(llList2String(Slots, slotIndex*STRIDE+7), ["§"], []);
			string strideSeat = llList2String(tempSeat, 1);
			tempSeat =[];

			integer oldseat = (integer)llGetSubString(strideSeat, 4,-1);
			if (oldseat <= 0) {
				llWhisper(0, "avatar is not assigned a slot: " + (string)id);
			}
			else{ 
				SwapTwoAvatars(oldseat, (integer)str); 
			}
		}
*/

		else if(num == SWAPTO) {
			//move clicker to a new seat#
			//new seat# occupant will then occupy the old seat# of menu user.
			//usage:  LINKMSG|210|3|%AVKEY%  Will swap the user with the id %AVKEY% to seat3 and seat3 occupant moves to existing %AVKEY%'s seat#
			//this is intended as an internal call for ChangeSeat button but can be used by any plugin, LINKMSG, or SAT/NOTSATMSG
			SwapTwoAvatars((integer)str, llListFindList(Slots, [id])/STRIDE + 1);
		}
		/*
		else if (num == (SEAT_UPDATE + 2000000)) {
			//slave sent Slots list after adjuster moved the AV.  we need to keep our Slots list up to date. replace Slots list
			Slots=llParseStringKeepNulls(str, ["^"], []);
			str = "";
			integer index;
			integer length=llGetListLength(Slots);
			for(index=0; index<length; index+=STRIDE) {
				Slots=llListReplaceList(Slots, [
					(vector)llList2String(Slots, index+1), (rotation)llList2String(Slots, index+2),
					llList2String(Slots, index+3), (key)llList2String(Slots, index+4)
				], index+1, index + 4);
			}
		}
		*/
		else if(num == HUD_REQUEST) {
			if(llGetInventoryType(ADMIN_HUD_NAME)!=INVENTORY_NONE && str == "RezHud") {
				llRezObject(ADMIN_HUD_NAME, llGetPos() + <0,0,1>, ZERO_VECTOR, llGetRot(), ChatChannel);
			}
			else if(num == HUD_REQUEST && str == "RemoveHud") {
				llRegionSayTo(HudId, ChatChannel, "/die");
			}
		}
		else if(num == DEFAULT_CARD) {
			DefaultCardName=str;
			llMessageLinked(LINK_SET, DOPOSE, DefaultCardName, id);
		}
		else if(num == PLUGIN_COMMAND_REGISTER) {
			list parts=llParseString2List(str, ["|"], []);
			string action=llList2String(parts, 0);
			integer index=llListFindList(PluginCommands, [action]);
			if(~index) {
				PluginCommands=llDeleteSubList(PluginCommands, index, index+3);
			}
			PluginCommands+=[action, (integer)llList2String(parts, 1), (integer)llList2String(parts, 2), (integer)llList2String(parts, 3)];
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
				else if(optionItem == "seatassignlist") {SeatAssignList = optionString;}
			}
		}
		else if(num == MEMORY_USAGE) {
			llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
			 + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
		llSay(0, "running script time for all scripts in this nPose object are consuming " 
		 + (string)(llList2Float(llGetObjectDetails(llGetKey(), ([OBJECT_SCRIPT_TIME])), 0)*1000.0) + " ms of cpu time");
		}
	}

	object_rez(key id) {
		if(llKey2Name(id) == ADMIN_HUD_NAME) {
			HudId = id;
			llSleep(2.0);
			llRegionSayTo(HudId, ChatChannel, "parent|"+(string)llGetKey());
		}
	}

	listen(integer channel, string name, key id, string message) {
		list temp = llParseString2List(message, ["|"], []);
		if(llGetListLength(temp) >= 2 || llGetSubString(message,0,4) == "ping" || llGetSubString(message,0,8) == "PROPRELAY") {
			if(llGetOwnerKey(id) == llGetOwner()) {
				if(message == "ping") {
					llRegionSayTo(id, ChatChannel, "pong|" + (string)llGetPos());
					llMessageLinked(LINK_SET, ON_PROP_REZZED, llDumpList2String([name, id, channel], "|"), NULL_KEY);
				}
				else if(llGetSubString(message,0,8) == "PROPRELAY") {
					list msg = llParseString2List(message, ["|"], []);
					llMessageLinked(LINK_SET,llList2Integer(msg,1),llList2String(msg,2),llList2Key(msg,3));
				}
				else if(name == "pos_adjuster_hud") {
				}
				else {
					list params = llParseString2List(message, ["|"], []);
					vector newpos = (vector)llList2String(params, 0) - llGetPos();
					newpos = newpos / llGetRot();
					rotation newrot = (rotation)llList2String(params, 1) / llGetRot();
					llRegionSayTo(llGetOwner(), 0, "\nPROP|" + name + "|" + (string)newpos + "|" + (string)(llRot2Euler(newrot) * RAD_TO_DEG)
					 + "|" + llList2String(params, 2));
				}
			}
		}
		else if(name == llKey2Name(HudId)) {
			//need to process hud commands
			if(message == "adjust") {
				llMessageLinked(LINK_SET, ADJUST, "", "");
			}
			else if(message == "stopadjust") {
				llMessageLinked(LINK_SET, STOPADJUST, "", "");
			}
			else if(message == "posdump") {
				llMessageLinked(LINK_SET, DUMP, "", "");
			}
			else if(message == "hudsync") {
				llMessageLinked(LINK_SET, SYNC, "", "");
			}
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

integer SEAT_UPDATE = 35353;//we gonna do satmsg and notsatmsg
integer MEMORY_USAGE = 34334;
integer OPTIONS = -240;

//generic message numbers
integer ON_SAT=-700;
integer ON_NOT_SAT=-701;
integer ON_NEW=-702;
integer ON_CHANGE=-703;
integer ON_LOST=-704;
integer ON_EMPTY=-705;
integer ON_NOT_EMPTY=-706;
integer ON_FULL=-707;
integer ON_NOT_FULL=-708;
integer ON_INVALID=-719;

//generic event report has to be activated
//once activated it can't be deactivated
integer ENABLE_EVENT_ON_SAT=0x1;
integer ENABLE_EVENT_ON_NOT_SAT=0x2;
integer ENABLE_EVENT_ON_NEW=0x4;
integer ENABLE_EVENT_ON_CHANGE=0x8;
integer ENABLE_EVENT_ON_LOST=0x10;
integer ENABLE_EVENT_ON_EMPTY=0x20;
integer ENABLE_EVENT_ON_NOT_EMPTY=0x40;
integer ENABLE_EVENT_ON_FULL=0x80;
integer ENABLE_EVENT_ON_NOT_FULL=0x100;
integer ENABLE_EVENT_ON_INVALID=0x80000000;
integer EnabledEvents;

integer ChatChannel;
integer SEND_CHATCHANNEL = 1;
integer REQUEST_CHATCHANNEL = 999999;

integer SLOTS_OFFSET_AVATAR=4;
integer SLOTS_OFFSET_SATMSG=5;
integer SLOTS_OFFSET_NOTSATMSG=6;
integer SLOTS_STRIDE=8;

list SlotsAvatar; 
list MsgOnSat;
list MsgOnNotSat;


debug(list message){
	llOwnerSay((((llGetScriptName() + "\n##########\n#>") + llDumpList2String(message,"\n#>")) + "\n##########"));
}

onSat(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_SAT) {
		sendMessage(ON_SAT, (string)(slotNumber+1), avatar);
	}
	sendUserDefinedMessage(avatar, llList2String(MsgOnSat, slotNumber));
}
onNotSat(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_NOT_SAT) {
		sendMessage(ON_NOT_SAT, (string)(slotNumber+1), avatar);
	}
	sendUserDefinedMessage(avatar, llList2String(MsgOnNotSat, slotNumber));
}
onNew(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_NEW) {
		sendMessage(ON_NEW, (string)(slotNumber+1), avatar);
	}
}
onChange(key avatar, integer oldSlotNumber, integer newSlotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_CHANGE) {
		sendMessage(ON_CHANGE, (string)(oldSlotNumber+1) + "," + (string)(newSlotNumber+1), avatar);
	}
}
onLost(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_LOST) {
		sendMessage(ON_LOST, (string)(slotNumber+1), avatar);
	}
}
onEmpty() {
	if(EnabledEvents & ENABLE_EVENT_ON_EMPTY) {
		sendMessage(ON_EMPTY, "", NULL_KEY);
	}
}
onNotEmpty() {
	if(EnabledEvents & ENABLE_EVENT_ON_NOT_EMPTY) {
		sendMessage(ON_NOT_EMPTY, "", NULL_KEY);
	}
}
onFull() {
	if(EnabledEvents & ENABLE_EVENT_ON_FULL) {
		sendMessage(ON_FULL, "", NULL_KEY);
	}
}
onNotFull() {
	if(EnabledEvents & ENABLE_EVENT_ON_NOT_FULL) {
		sendMessage(ON_NOT_FULL, "", NULL_KEY);
	}
}
onInvalid() {
	if(EnabledEvents & ENABLE_EVENT_ON_INVALID) {
		sendMessage(ON_INVALID, "", NULL_KEY);
	}
}

sendUserDefinedMessage(key avatar, string msg) {
	if(msg!="") {
		msg=llDumpList2String(llParseStringKeepNulls(msg, ["%AVKEY%"], []), avatar);
		list msgParts=llParseString2List(msg, ["§"], []);
		integer index;
		integer length=llGetListLength(msgParts);
		for(; index<length; index++) {
			list msgAtoms=llParseString2List(msg, ["|"], []);
			sendMessage((integer)llList2String(msgAtoms, 0), llList2String(msgAtoms, 1), (key)llList2String(msgAtoms, 2));
		}
	}
}

sendMessage(integer num, string str, key id) {
	llMessageLinked(LINK_SET, num, str, id);
	if(ChatChannel) {
		llRegionSay(ChatChannel, llDumpList2String(["LINKMSG", num, str, id], "|"));
	}
}

default {
	state_entry() {
		llMessageLinked(LINK_SET, REQUEST_CHATCHANNEL, "", "");
	}
	link_message(integer sender_num, integer num, string str, key id) {
		if(num == SEND_CHATCHANNEL) {  //got ChatChannel from the core.
			ChatChannel = (integer)str;
		}
		else if(num==SEAT_UPDATE) {
			//Leona:
			//this function may have a problem if:
			//  avatars change between the slots AND (the number of slots changes OR the (NOT)SATMSGs changes)
			//The problem also exists in the old nPose SAT-NOTSAT handler
			//but (normally) this don't happen
			//To get totally rid of the problem, we need to know WHY a SEAT_UPDATE occurs, but that is currently impossible
			//Suggestion: Inside the Core: Split up the Slots list to several lists with lesser informtions and send the smaller lists with its own linknumber
			
			//get avatars from Slots list
			list slots = llParseStringKeepNulls(str, ["^"], []);
			str="";
			list oldSlotsAvatar=SlotsAvatar;
			SlotsAvatar=[];
			MsgOnSat=[];
			MsgOnNotSat=[];
			integer index;
			integer length=llGetListLength(slots);
			for(; index<length; index+=SLOTS_STRIDE) {
				SlotsAvatar+=(key)llList2String(slots, index + SLOTS_OFFSET_AVATAR);
				MsgOnSat+=llList2String(slots, index + SLOTS_OFFSET_SATMSG);
				MsgOnNotSat+=llList2String(slots, index + SLOTS_OFFSET_NOTSATMSG);
			}
			//check if someone leaves a slot (NOTSATMSG related)
			//check if we lost sitter
			//check if someone changed the slot
			length=llGetListLength(oldSlotsAvatar);
			integer oldEmpty=TRUE;
			integer oldFull=TRUE;
			for(index=0; index<length; index++) {
				key avatar=llList2Key(oldSlotsAvatar, index);
				if(avatar!=NULL_KEY && avatar!="") {
					oldEmpty=FALSE;
					if(avatar!=llList2Key(SlotsAvatar, index)) {
						//this avatar leaves a slot (NOTSATMSG related)
						onNotSat(avatar, index);
						if(!~llListFindList(SlotsAvatar, [avatar])) {
							//we lost this avatar
							onLost(avatar, index);
						}
					}
				}
				else {
					oldFull=FALSE;
				}
			}
			//check if someone enters a slot (SATMSG related)
			//check if we have a new sitter
			length=llGetListLength(SlotsAvatar);
			integer empty=TRUE;
			integer full=TRUE;
			for(index=0; index<length; index++) {
				key avatar=llList2Key(SlotsAvatar, index);
				if(avatar!=NULL_KEY && avatar!="") {
					empty=FALSE;
					if(avatar!=llList2Key(oldSlotsAvatar, index)) {
						//this avatar enters a slot (SATMSG related)
						onSat(avatar, index);
						integer oldSlot=llListFindList(oldSlotsAvatar, [avatar]);
						if(~oldSlot) {
							//this avatar changed the slot
							onChange(avatar, oldSlot, index);
						}
						else {
							//we have a new sitter
							onNew(avatar, index);
						}
					}
				}
				else {
					full=FALSE;
				}
			}
			if(empty && full) {
				//invalid slot list
				onInvalid();
			}
			else {
				if(empty && !oldEmpty) {
					//changed to empty
					onEmpty();
				}
				if(!empty && oldEmpty) {
					//changed to not empty
					onNotEmpty();
				}
				if(full && !oldFull) {
					//changed to full
					onFull();
				}
				if(!full && oldFull) {
					//changed to not full
					onNotFull();
				}
			}
		}
		else if(num == OPTIONS) {
			//save new option(s) or macro(s) or userdefined permissions from LINKMSG
			list optionsToSet = llParseStringKeepNulls(str, ["~","|"], []);
			integer length = llGetListLength(optionsToSet);
			integer index;
			for(; index<length; ++index) {
				list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
				string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
				string optionString = llList2String(optionsItems, 1);
				string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
				integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;

				if(optionItem == "enableevents") {EnabledEvents = EnabledEvents | (integer)optionSetting;}
			}
		}
		else if(num == MEMORY_USAGE) {
			llSay(0,"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + " of " + (string)llGetMemoryLimit()
			 + ", Leaving " + (string)llGetFreeMemory() + " memory free.");
		}
	}
	on_rez(integer params) {
		llResetScript();
	}
}
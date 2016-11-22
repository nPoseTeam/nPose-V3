integer SEAT_UPDATE = 35353;//we gonna do satmsg and notsatmsg
integer MEMORY_USAGE = 34334;
integer OPTIONS = -240;

//generic message numbers
integer ON_ENTER=-700; //triggers if someone enters a slot. Reported data: slotNumber and avatarUUID
integer ON_EXIT=-701; //triggers if someone leaves a slot. Reported data: slotNumber and avatarUUID
integer ON_NEW=-702; //triggers if someone sits on the object. Reported data: slotNumber and avatarUUID
integer ON_CHANGE=-703; //triggers if someone changed the slot. Reported data: oldSlotNumber, newSlotNumber and avatarUUID
integer ON_LOST=-704; //triggers if someone unsits from the object. Reported data: slotNumber and avatarUUID
integer ON_EMPTY=-705; //triggers if the Slots list was not empty but is empty now.
integer ON_NOT_EMPTY=-706; //triggers if the Slots list was empty but is not empty anymore.
integer ON_FULL=-707; //triggers if the Slots list was not full but is full now.
integer ON_NOT_FULL=-708; //triggers if the Slots list was full but is not full anymore.
integer ON_INVALID=-719; //there is no valid Slots list

//generic event report has to be activated
//once activated it can't be deactivated
integer ENABLE_EVENT_ON_ENTER=0x1;
integer ENABLE_EVENT_ON_EXIT=0x2;
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

integer SLOTS_OFFSET_ANIMATION_NAME=0;
integer SLOTS_OFFSET_ANIMATION_POS=1;
integer SLOTS_OFFSET_ANIMATION_ROT=2;
integer SLOTS_OFFSET_FACIAL=3;
integer SLOTS_OFFSET_AVATAR=4;
integer SLOTS_OFFSET_SATMSG=5;
integer SLOTS_OFFSET_NOTSATMSG=6;
integer SLOTS_STRIDE=8;

list SlotsAnimationDetails; //name, pos, rot
integer SLOTS_ANIMATION_DETAILS_STRIDE=3;
list SlotsFacial;
list SlotsAvatar; 
list MsgSat;
list MsgNotSat;


debug(list message){
	llOwnerSay((((llGetScriptName() + "\n##########\n#>") + llDumpList2String(message,"\n#>")) + "\n##########"));
}

onEnter(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_ENTER) {
		sendMessage(ON_ENTER, (string)(slotNumber+1), avatar);
	}
}
onExit(key avatar, integer slotNumber) {
	if(EnabledEvents & ENABLE_EVENT_ON_EXIT) {
		sendMessage(ON_EXIT, (string)(slotNumber+1), avatar);
	}
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
			string msgPart=llList2String(msgParts, index);
			if(msgPart) {
				list msgAtoms=llParseString2List(msgPart, ["|"], []);
				string idString=llList2String(msgAtoms, 2);
				key id=(key)idString;
				if(idString=="") {
					id=avatar;
				}
				sendMessage((integer)llList2String(msgAtoms, 0), llList2String(msgAtoms, 1), id);
			}
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
			list oldSlotsAnimationDetails=SlotsAnimationDetails;
			SlotsAnimationDetails=[];
			list oldSlotsFacial=SlotsFacial;
			SlotsFacial=[];
			MsgSat=[];
			list oldMsgNotSat=MsgNotSat;
			MsgNotSat=[];

			integer index;
			integer length=llGetListLength(slots);
			for(; index<length; index+=SLOTS_STRIDE) {
				SlotsAvatar+=(key)llList2String(slots, index + SLOTS_OFFSET_AVATAR);
				SlotsAnimationDetails+=llList2String(slots, index + SLOTS_OFFSET_ANIMATION_NAME);
				SlotsAnimationDetails+=(vector)llList2String(slots, index + SLOTS_OFFSET_ANIMATION_POS);
				SlotsAnimationDetails+=(vector)llList2String(slots, index + SLOTS_OFFSET_ANIMATION_ROT);
				SlotsFacial+=llList2String(slots, index + SLOTS_OFFSET_FACIAL);
				MsgSat+=llList2String(slots, index + SLOTS_OFFSET_SATMSG);
				MsgNotSat+=llList2String(slots, index + SLOTS_OFFSET_NOTSATMSG);
			}
			//check if someone leaves a slot
			//check for NOTSATMSG
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
						//this avatar leaves a slot
						onExit(avatar, index);
						if(!~llListFindList(SlotsAvatar, [avatar])) {
							//we lost this avatar
							onLost(avatar, index);
						}
					}
					if(
						//NOTSATMSG detection
						avatar!=llList2Key(SlotsAvatar, index) ||
						llList2String(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE)!=llList2String(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE) ||
						llList2Vector(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+1)!=llList2Vector(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+1) ||
						llList2Vector(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+2)!=llList2Vector(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+2) ||
						llList2String(oldSlotsFacial, index)!=llList2String(SlotsFacial, index)
					) {
						sendUserDefinedMessage(avatar, llList2String(oldMsgNotSat, index));
						
					}
				}
				else {
					oldFull=FALSE;
				}
			}
			//check if someone enters a slot
			//check for SATMSG
			//check if we have a new sitter
			length=llGetListLength(SlotsAvatar);
			integer empty=TRUE;
			integer full=TRUE;
			for(index=0; index<length; index++) {
				key avatar=llList2Key(SlotsAvatar, index);
				if(avatar!=NULL_KEY && avatar!="") {
					empty=FALSE;
					if(avatar!=llList2Key(oldSlotsAvatar, index)) {
						//this avatar enters a slot
						onEnter(avatar, index);
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
					if(
						//SATMSG detection
						llList2Key(oldSlotsAvatar, index)!=avatar ||
						llList2String(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE)!=llList2String(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE) ||
						llList2Vector(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+1)!=llList2Vector(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+1) ||
						llList2Vector(oldSlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+2)!=llList2Vector(SlotsAnimationDetails, index*SLOTS_ANIMATION_DETAILS_STRIDE+2) ||
						llList2String(oldSlotsFacial, index)!=llList2String(SlotsFacial, index)
					) {
						sendUserDefinedMessage(avatar, llList2String(MsgSat, index));
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
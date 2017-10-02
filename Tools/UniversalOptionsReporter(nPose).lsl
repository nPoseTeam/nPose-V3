//settings
integer USE_OWNER_SAY=TRUE; //llWhispher tends to shuffel the messages more than llOwnerSay, so I suggest to set this to TRUE;
integer SHOW_TYPE=TRUE;
integer SHOW_DESCRIPTIONS=FALSE;
integer SHOW_OPTIONS_ON_CHANGE=TRUE;
integer SHOW_ALL_OPTIONS_LINK_MESSAGE_NUMBER=34334;
integer SHOW_ONLY_OPTIONS_WITH_NON_DEFAULT_VALUES=FALSE;
integer INITIAL_LIST_SORT=TRUE;



//blacklist filter


//additional informations
integer OPTION_TYPE_FLAG=0;
integer OPTION_TYPE_INTEGER=1;
integer OPTION_TYPE_FLOAT=2;
integer OPTION_TYPE_STRING=3;


list Options=[
	//format: optionName, optionType, optionDefaultValue, description
//nPose
	"permit", OPTION_TYPE_STRING, "public", "Deprecated: Use Button Permissions instead. This controls the global permission to get the menu. Default permissions is public and options are group and owner.",
	"menuOnSit", OPTION_TYPE_FLAG, "0", "Turn this on to give the menu to any new sitter automatically when they sit, off means they must click for menu.",
	"2Default", OPTION_TYPE_FLAG, "0", "Turn this on and nPose returns to the DEFAULT pose when everyone stands.",
	"scaleRef", OPTION_TYPE_STRING, "<0.0, 0.0, 0.0>", "the placeholder %SCALEREF% is replaced with this value.",
	"facialExp", OPTION_TYPE_FLAG, "1", "This is a global setting for facial anims. If this option is off, any facial anims set in the build will be ignored.",
	"sit2GetMenu", OPTION_TYPE_FLAG, "0", "Deprecated: Use Button Permissions instead. Turn this on to ensure no one will be able to pull a menu while standing. Everyone must be seated to get a menu.",
	"menuDist", OPTION_TYPE_FLOAT, "30.0", "Distance away and still click to get menu.",
	"useDisplayNames", OPTION_TYPE_FLAG, "1", "Turn this on to see sitter's display name in ChangeSeats menu.",
	"adjustRefRoot", OPTION_TYPE_FLAG, "0", "Turn this on to reference adjusts to the root prim rather than the prim the slave script is in.",
	"quietAdjusters", OPTION_TYPE_FLAG, "0", "Turn this on to quiet new position reporting by the adjusters, and also adjuster reporting when clicked. PosDump will still report all positions/rotations.",
	"dialogTimeout", OPTION_TYPE_INTEGER, "120", "If a menu user is not sitting on the nPose Object, the Menu will timeout after the specified number of seconds.",
	"dialogBackward", OPTION_TYPE_FLAG, "0", "enables a backward button inside a multi paged menu",
	"autoLanguage", OPTION_TYPE_FLAG, "1", "enables automatic language selection",
	"defaultLanguagePrefix", OPTION_TYPE_STRING, "SET" , "Sets the prefix for the default language. Mainly for debugging purposes."
	"seatAssignList", OPTION_TYPE_STRING, "a", "Determines which seat a new sitter will get.",
//nPose SAT_NOTSAT plugin
	"enableEvents", OPTION_TYPE_INTEGER, "0", "Turns on the generic event linkMessages. See script 'nPose SAT-NOTSAT Handler'.",
//nPose RLV+
	"RLV_grabRange", OPTION_TYPE_FLOAT, "10.0", "The range within an Avatar could be captured via menu. Set to 0 to disable the feature.",
	"RLV_grabTimer", OPTION_TYPE_INTEGER, "0", "0: No Timer, any other value will set a timer on grab to an RLV_enabledSeat.",
	"RLV_trapRange", OPTION_TYPE_FLOAT, "0.0", "A value grater than 0 means that an Avatar within the range will be trapped automatically.",
	"RLV_trapTimer", OPTION_TYPE_INTEGER, "0", "0: No Timer, any other value will set a timer on sitting voluntary or through the autoTrap on an RLV_enabledSeat.",
	"RLV_enabledSeats", OPTION_TYPE_STRING, "*", "seat numbers, separated by a slash '/'. Sitting on a RLV_enabledSeat means that the RlVBaseRestrictions are applied to you.",
	"RLV_collisionTrap", OPTION_TYPE_FLAG, "0", "0: Disables the collision trap, 1: enables the collision trap.",
	"RLV_cooldownTimer", OPTION_TYPE_INTEGER, "60", "0: No Timer, any other value will enable the timer. Anyone who just stand up can only be trapped after this timer is expired."
];



integer OPTIONS_NICE_NAME=0;
integer OPTIONS_TYPE=1;
integer OPTIONS_DEFAULT_VALUE=2;
integer OPTIONS_DESCIPTION=3;
integer OPTIONS_STRIDE=4;

list OptionNames;
list OptionValues;

speak(string str) {
	if(USE_OWNER_SAY) {
		llOwnerSay(str);
	}
	else {
		llWhisper(0, str);
	}
}

string Utf8Trim(string s, integer iLen) {
	// This trims a string to iLen bytes interpreted as utf8 (not utf16).
	// The string returned will be utf16, but when interpreted as utf8,
	// it will be iLen bytes (not characters) or shorter.  Also, because
	// of the use of base64, it's best if iLen is a multiple of 3.  If
	// it's not, it will be rounded down to a multiple of 3 if trimming
	// is needed.  If trimming isn't needed, it will be unchanged regardless
	// of original length.
	string s2 = llStringToBase64(s);
	iLen = (iLen / 3) * 4; // This winds up being a multiple of 4, rounded down.
	if (llStringLength(s2) > iLen) {
		return llBase64ToString(llGetSubString(s2, 0, --iLen));
	}
	return s;
}

string getTextByIndex(integer index) {
	string str="\n";
	str+=llList2String(Options, index * OPTIONS_STRIDE + OPTIONS_NICE_NAME);
	str+="=";
	str+=llList2String(OptionValues, index);
	if(SHOW_TYPE) {
		integer type=llList2Integer(Options, index * OPTIONS_STRIDE + OPTIONS_TYPE);
		if(type==OPTION_TYPE_FLAG) {str+=" (flag/bool)";}
		else if(type==OPTION_TYPE_INTEGER) {str+=" (integer)";}
		else if(type==OPTION_TYPE_FLOAT) {str+=" (float)";}
		else if(type==OPTION_TYPE_STRING) {str+=" (string)";}
	}
	if(SHOW_DESCRIPTIONS) {
		string description=llList2String(Options, index * OPTIONS_STRIDE + OPTIONS_DESCIPTION);
		if(description) {
			str+="; //" + description;
		}
	}
	return str;
}

showText(list text) {
	string textToShow;
	while(llGetListLength(text)) {
		string line=llList2String(text, 0);
		if(Utf8Trim(textToShow + line, 1024)!=textToShow + line) {
			speak(textToShow);
			textToShow="";
		}
		textToShow+=line;
		text=llDeleteSubList(text, 0, 0);
	}
	if(textToShow) {
		speak(textToShow);
	}
}

integer hasChanged(integer optionType, string oldValue, string newValue) {
//	integer type=llList2Integer(Options, index * OPTIONS_STRIDE + OPTIONS_TYPE);
//	string oldValue=llList2String(Options, index * OPTIONS_STRIDE + OPTIONS_DEFAULT_VALUE);
//	string newValue=llList2String(OptionValues, index);
	if(optionType==OPTION_TYPE_FLAG || optionType==OPTION_TYPE_INTEGER) {
		return (integer)oldValue!=(integer)newValue;
	}
	if(optionType==OPTION_TYPE_FLOAT) {
		return (float)oldValue!=(float)newValue;
	}
	if(optionType==OPTION_TYPE_STRING) {
		return oldValue!=newValue;
	}
	return -1;
}

default {
	state_entry() {
		if(INITIAL_LIST_SORT) {
			Options=llListSort(Options, OPTIONS_STRIDE, TRUE);
		}
		integer index;
		integer length=llGetListLength(Options);
		for(; index<length; index+=OPTIONS_STRIDE) {
			OptionNames+=llToLower(llList2String(Options, index + OPTIONS_NICE_NAME));
			OptionValues+=llList2String(Options, index + OPTIONS_DEFAULT_VALUE);
		}
		llOwnerSay(llGetScriptName() + " up and running. " + (string)llGetFreeMemory() + " Bytes free.");
	}
	
	link_message(integer sender_num, integer num, string str, key id) {
		if (num == -240) {
			//save new option(s) from LINKMSG
			list optionsToSet = llParseStringKeepNulls(str, ["~","|"], []);
			integer length = llGetListLength(optionsToSet);
			integer index;
			list text;
			for(; index<length; ++index) {
				list optionsItems = llParseString2List(llList2String(optionsToSet, index), ["="], []);
				string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
				string optionString = llList2String(optionsItems, 1);
				string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
				integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;
				
				integer optionIndex=llListFindList(OptionNames, [optionItem]);
				if(~optionIndex) {
					integer optionType=llList2Integer(Options, optionIndex * OPTIONS_STRIDE + OPTIONS_TYPE);
					string newValue;
					string oldValue=llList2String(OptionValues, optionIndex);
					integer hasChanged;
					if(optionType==OPTION_TYPE_FLAG) {
						newValue=(string)optionSettingFlag;
					}
					else if(optionType==OPTION_TYPE_INTEGER) {
						newValue=(string)((integer)optionSetting);
					}
					else if(optionType==OPTION_TYPE_FLOAT) {
						newValue=(string)((float)optionSetting);
					}
					else if(optionType==OPTION_TYPE_STRING) {
						newValue=optionSetting;
					}
					if(hasChanged(optionType, oldValue, newValue)) {
						OptionValues=llListReplaceList(OptionValues, [newValue], optionIndex, optionIndex);
						if(SHOW_OPTIONS_ON_CHANGE) {
							text+=getTextByIndex(optionIndex);
						}
					}
				}
				else {
					optionIndex=llGetListLength(OptionNames);
					Options+=["UNKNOWN: " + llStringTrim(llList2String(optionsItems, 0), STRING_TRIM), OPTION_TYPE_STRING, "", "This option is currently unknown. Maybe there is a typo."];
					OptionNames+=optionItem;
					OptionValues+=optionString;
					if(SHOW_OPTIONS_ON_CHANGE) {
						text+=getTextByIndex(optionIndex);
					}
				}
			}
			showText(text);
		}
		if(num && num==SHOW_ALL_OPTIONS_LINK_MESSAGE_NUMBER) {
			integer length=llGetListLength(OptionNames);
			integer index;
			list text;
			for (; index<length; index++) {
				if(SHOW_ONLY_OPTIONS_WITH_NON_DEFAULT_VALUES) {
					if(hasChanged(
						llList2Integer(Options, index * OPTIONS_STRIDE + OPTIONS_TYPE),
						llList2String(Options, index * OPTIONS_STRIDE + OPTIONS_DEFAULT_VALUE),
						llList2String(OptionValues, index)
					)) {
						text+=getTextByIndex(index);
					}
				}
				else {
					text+=getTextByIndex(index);
				}
			}
			showText(text);
		}
	}
}

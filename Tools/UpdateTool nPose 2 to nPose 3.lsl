//This tool should help you to update from nPose 2.x to nPose X.x
//Usage:
// 1) Copy this script into an Object with the nPose 2.x scripts. Note that it will not work if it can't use the nPose NC Reader
// 2) follow the instructions given in the chat
//NOTE:
// 1) USE AT YOUR OWN RISK
// 2) SOME FUNCTIONS ARE UNTESTED


integer NC_READER_REQUEST=224;
integer NC_READER_RESPONSE=225;
string NC_READER_CONTENT_SEPARATOR="%&§";


string INIT_CARD_NAME=".init";
string DEFAULT_PREFIX="DEFAULT";
string SET_CARD_PREFIX="SET";
string BTN_CARD_PREFIX="BTN";
string NEW_PREFIX="SET";

integer NUM_OPTIONS=-240;
integer NUM_EXTERNAL_UTIL_REQUEST=-888;
integer NUM_DOMENU=-800;
integer NUM_DOMENU_ACCESSCTRL=-801;
integer NUM_DOPOSE=200;
integer NUM_SYNC=206;
integer NUM_DOBUTTON=207;
integer NUM_USER_PERMISSION_UPDATE=-806;
integer NUM_UDPBOOL=-804;
integer NUM_UDPLIST=-805;

string DefaultCardName;
key MyId;
list CardsList;
list FinishedCardsList;

string deleteNode(string path, integer start, integer end) {
	return llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path, [":"], []), start, end), ":");
}

debug(list message){
	llOwnerSay((((llGetScriptName() + "\n##########\n#>") + llDumpList2String(message,"\n#>")) + "\n##########"));
}

pleaseChange(string ncName, integer lineNumber, string old, string new) {
	llOwnerSay(
		"Please change the line " + (string)(lineNumber) + 
		" of the NC " + ncName + " from:\n" + 
		old +
		"\nto\n" +
		new
	);
}
pleaseDelete(string ncName, integer lineNumber, string old) {
	llOwnerSay(
		"Please delete the line " + (string)(lineNumber) + ":\n" + old + "\nof the NC " + ncName
	);
}
deleteIf(string ncName, integer lineNumber, string old, string pluginName) {
	llOwnerSay(
		"If you use the following line in conjuction with " + pluginName + ", you may delete the line and the plugin because it will not work anymore.\n" +
		ncName + "\n line: " + (string)lineNumber + "\n" + old
	);
}

default {
	state_entry() {
		llSleep(1.0); //be sure that the NC reader script finished resetting
		state stage10;
	}
}

//stage 10
//add .init file
state stage10 {
	state_entry() {
		llOwnerSay("Step1 (Default card analysis) ...");
		MyId=llGetInventoryKey(llGetScriptName());
		
		//check if there is .init card already
		if(llGetInventoryType(INIT_CARD_NAME)==INVENTORY_NOTECARD) {
			llMessageLinked(LINK_SET, NC_READER_REQUEST, INIT_CARD_NAME, MyId);
			return;
		}
		
		//get the current default card
		string prefix;
		integer length = llGetInventoryNumber(INVENTORY_NOTECARD);
		integer index;
		while(index<length && prefix=="") {
			string cardName = llGetInventoryName(INVENTORY_NOTECARD, index);
			if(llSubStringIndex(cardName, DEFAULT_PREFIX + ":") == 0) {
				prefix=DEFAULT_PREFIX + ":";
			}
			else if(llSubStringIndex(cardName, SET_CARD_PREFIX + ":") == 0) {
				prefix=SET_CARD_PREFIX + ":";
			}
			if(prefix!="") {
				DefaultCardName=cardName;
			}
			index++;
		}
		
		//there isn't a default card
		if(prefix=="") {
			state stage20;
		}
		else {
			//make a suggestion for renaming the default card
			string newDefaultCardName=".default";
			if(llStringLength(DefaultCardName)>llStringLength(prefix)) {
				string temp=llDeleteSubString(DefaultCardName, 0, llStringLength(prefix)-1);
				if(llGetSubString(temp, 0, 0)!=":") {
					newDefaultCardName=NEW_PREFIX + ":"+temp;
				}
			}
			llOwnerSay(
				"Please create a NC with the name " + INIT_CARD_NAME + " and add the following line:\n"+
				"DEFAULTCARD|" + newDefaultCardName
			);
			if(DefaultCardName!=newDefaultCardName) {
				llOwnerSay(
					"Then rename the card " + DefaultCardName + " to " + newDefaultCardName + 
					"\n Click when finished."
				);
			}
		}
	}
	touch_start(integer num_detected) {
		llResetScript();
	}
	
	link_message(integer sender_num, integer num, string str, key id) {
		if(num==NC_READER_RESPONSE && id==MyId) {
			list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
			str = "";
			//allData: [ncName, paramSet1, "", contentLine1, contentLine2, ...]
			//parse the NC content
			integer length=llGetListLength(allData);
			integer index=3;
			for(; index<length; index++) {
				string data = llList2String(allData, index);
				if(!llSubStringIndex(data, "DEFAULTCARD|")) {
					string temp=llGetSubString(data, 12, -1);
					if(llGetInventoryType(temp)!=INVENTORY_NOTECARD) {
						llOwnerSay(
							"\nError: The card " + temp + " which you referenced in the " + INIT_CARD_NAME + " doesn't exists." +
							"\n Please correct it and click when finished."
						);
					}
					else {
						DefaultCardName=temp;
						state stage20;
					}
				}
			}
		}
	}
	state_exit() {
		llOwnerSay("Step 1 finished");
	}
	on_rez(integer start_param) {
		llResetScript();
	}
}

state stage20 {
	state_entry() {
		llOwnerSay("Step2 (Card renaming) ...");
		integer errors;
		integer initalMessageDone;
		integer length=llGetInventoryNumber(INVENTORY_NOTECARD);
		integer index;
		for(; index<length; ++index) {//step through the notecards
			string name = llGetInventoryName(INVENTORY_NOTECARD, index);
			list pathParts = llParseStringKeepNulls(name, [":"], []);
			string prefix = llList2String(pathParts, 0);
			pathParts = llDeleteSubList(pathParts, 0, 0);
			if(!initalMessageDone && (prefix==DEFAULT_PREFIX || prefix==BTN_CARD_PREFIX)) {
				llOwnerSay("There will be only the notecard type " + NEW_PREFIX + " in the future. Please rename all BTN notecards to " + NEW_PREFIX + ". The cards you should rename are:");
				initalMessageDone=TRUE;
			}
			if(prefix==DEFAULT_PREFIX) {
				//This shouldn't happen because we checked it in step1
				llOwnerSay(name);
				errors++;
			}
			else if(prefix==BTN_CARD_PREFIX) {
				llOwnerSay(name);
				errors++;
			}
		}
		if(!errors) {
			state stage30;
		}
		llOwnerSay("\n Click when finished.");
	}
	touch_start(integer num_detected) {
		llResetScript();
	}
	state_exit() {
		llOwnerSay("Step 2 finished");
	}
	on_rez(integer start_param) {
		llResetScript();
	}
}

state stage30 {
	state_entry() {
		llOwnerSay("Step3 (NC content) ...");
		integer length=llGetInventoryNumber(INVENTORY_NOTECARD);
		integer index;
		for(; index<length; ++index) {//step through the notecards
			string name = llGetInventoryName(INVENTORY_NOTECARD, index);
			if(!llSubStringIndex(name, NEW_PREFIX+":")) {
				CardsList+=name;
			}
		}
		if(DefaultCardName!="" && !~llListFindList(CardsList, [DefaultCardName])) {
			CardsList=DefaultCardName + CardsList;
		}
		if(CardsList) {
			llMessageLinked(LINK_SET, NC_READER_REQUEST, llList2String(CardsList, 0), MyId);
			CardsList=llDeleteSubList(CardsList, 0, 0);
		}
		else {
			state stage40;
		}
	}
	link_message(integer sender_num, integer num, string str, key id) {
		if(num==NC_READER_RESPONSE && id==MyId) {
			list allData=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
			str = "";
			//allData: [ncName, paramSet1, "", contentLine1, contentLine2, ...]
			//parse the NC content
			string ncName=llList2String(allData, 0);
llOwnerSay("Parsing: " + ncName);
			integer length=llGetListLength(allData);
			integer index=3;
			for(; index<length; index++) {
				string data = llList2String(allData, index);
				list parts=llParseStringKeepNulls(data, ["|"], []);
				string cmd=llList2String(parts, 0);
				if(cmd=="LINKMSG" || cmd=="SATMSG" || cmd=="NOTSATMSG") {
					integer linkmsgNum=(integer)llList2String(parts, 1);
					if(linkmsgNum==NUM_OPTIONS) {
						//options
						list newOptions;
						list unknownOptions;
						integer newButtonPermissionSeated;
						integer newButtonPermissionPermit;
						list optionsToSet = llParseStringKeepNulls(llList2String(parts, 2), ["~"], []);
						integer optionsLength = llGetListLength(optionsToSet);
						integer optionsIndex;
						for(; optionsIndex<optionsLength; ++optionsIndex) {
							list optionsItems = llParseString2List(llList2String(optionsToSet, optionsIndex), ["="], []);
							string optionItem = llToLower(llStringTrim(llList2String(optionsItems, 0), STRING_TRIM));
							string optionString = llList2String(optionsItems, 1);
							string optionSetting = llToLower(llStringTrim(optionString, STRING_TRIM));
							integer optionSettingFlag = optionSetting=="on" || (integer)optionSetting;
							if(optionItem=="sit2getmenu") {
								if(optionSettingFlag) {
									newButtonPermissionSeated=TRUE;
								}
								else {
									newButtonPermissionSeated=FALSE;
								}
							}
							else if(optionItem=="permit") {
								if(optionSetting=="group") {
									newButtonPermissionPermit=1;
								}
								else if(optionSetting=="owner") {
									newButtonPermissionPermit=2;
								}
								else {
									newButtonPermissionPermit=0;
								}
							}
							else if(optionItem=="rlvbaser") {
							}
							else if(optionItem=="2default") {
								newOptions+="2default=" + (string)optionSettingFlag;
							}
							else if(optionItem=="menuonsit") {
								newOptions+="menuOnSit=" + (string)optionSettingFlag;
							}
							else if(optionItem=="facialexp") {
								newOptions+="facialExp=" + (string)optionSettingFlag;
							}
							else if(optionItem=="menudist") {
								newOptions+="menuDist=" + optionSetting;
							}
							else if(optionItem=="usedisplaynames") {
								newOptions+="useDisplayNames=" + (string)optionSettingFlag;
							}
							else if(optionItem=="adjustrefroot") {
								newOptions+="adjustRefRoot=" + (string)optionSettingFlag;
							}
							else if(optionItem=="quietadjusters") {
								newOptions+="quietAdjusters=" + (string)optionSettingFlag;
							}
							else {
								unknownOptions+=llStringTrim(llList2String(optionsItems, 0), STRING_TRIM) + "=" + optionSetting;
							}
						}
						if(cmd=="LINKMSG") {
							if(newButtonPermissionSeated || newButtonPermissionPermit) {
								list temp;
								if(newButtonPermissionSeated) {
									temp+="seated";
								}
								if(newButtonPermissionPermit==1) {
									temp+="group";
								}
								if(newButtonPermissionPermit==2) {
									temp+="owner";
								}
								llOwnerSay("The global options 'permit' and 'sit2getmenu' are marked as deprecated. If you only use them once in your object your may add an empty NC with the name\n" + NEW_PREFIX + "{" + llDumpList2String(temp, " & ") + "}\nIf you want to switch between them you should use a macro.");
							}
							if(newOptions+unknownOptions) {
								pleaseChange(ncName, index-2, data, "OPTION|" + llDumpList2String(newOptions+unknownOptions, "|"));
								if(unknownOptions) {
									llOwnerSay("Please note that we don't know the option(s): " + llDumpList2String(unknownOptions, ", "));
								}
							}
							else {
								pleaseDelete(ncName, index-2, data);
							}
						}
						else {
							llOwnerSay("TODO: Leona: I have to think about options in SATMSG/NOTSATMSG");
						}
					}
					else if(linkmsgNum==NUM_EXTERNAL_UTIL_REQUEST) {
						string subCmd=llList2String(parts, 2);
						string pluginName;
						string newLine;
						if(subCmd=="admin") {
							llOwnerSay(
								"The Admin menu is no longer generated by a script. Please delete the NC " +
								ncName +
								" and add the corresponding NCs from the nPose Utility Folder."
							);
							//pluginName="npose_admin";
						}
						else if(subCmd=="ChangeSeat") {
							pluginName="npose_changeseat";
						}
						else if(subCmd=="offset") {
							pluginName="npose_offset";
						}
						else if(subCmd=="sync") {
							newLine=llDumpList2String(llListReplaceList(parts, [(string)NUM_SYNC, ""], 1, 2), "|");
						}
						if(newLine) {
							pleaseChange(ncName, index-2, data, newLine);
						}
						if(cmd=="LINKMSG") {
							if(pluginName) {
								pleaseChange(ncName, index-2, data, "PLUGINMENU|"+pluginName);
							}
						}
						else {
							llOwnerSay("TODO: Leona: I have to think about EXTERNAL_UTIL_REQUEST in SATMSG/NOTSATMSG ..."); 
						}
					}
					else if(linkmsgNum==NUM_DOMENU || linkmsgNum==NUM_DOMENU_ACCESSCTRL) {
						string param=llList2String(parts, 2);
						if(!llSubStringIndex(llToUpper(param), "PATH=")) {
							param=llDeleteSubString(param, 0, 4);
						}
						string newLine=llDumpList2String(llListReplaceList(parts, [(string)NUM_DOMENU, param], 1, 2), "|");
						if(newLine!=data) {
							pleaseChange(ncName, index-2, data, newLine);
						}
					}
					else if(linkmsgNum==NUM_DOBUTTON || linkmsgNum==NUM_DOPOSE) {
						string param=llList2String(parts, 2);
						if(~llListFindList(FinishedCardsList, [param]) && ~llListFindList(CardsList, [param])) {
							CardsList+=param;
						}
						if(linkmsgNum==NUM_DOBUTTON) {
							string newLine=llDumpList2String(llListReplaceList(parts, [(string)NUM_DOPOSE], 1, 1), "|");
							pleaseChange(ncName, index-2, data, newLine);
						}
					}
					else if(linkmsgNum==-802) {
						pleaseDelete(ncName, index-2, data);
					}
					else if(linkmsgNum==NUM_USER_PERMISSION_UPDATE) {
						list params=llCSV2List(llList2String(parts, 2));
						integer paramsLength=llGetListLength(params);
						integer paramsIndex;
						list boolValues;
						list listValues;
						for(; paramsIndex<paramsLength; paramsIndex+=3) {
							if(llList2String(params, paramsIndex+1)=="bool") {
								boolValues+=llList2String(params, paramsIndex) + "=" + llList2String(params, paramsIndex);
							}
							else {
								listValues+=llList2String(params, paramsIndex) + "=" + llList2String(params, paramsIndex);
							}
						}
						string newLine;
						if(boolValues) {
							newLine+="\nUDPBOOL|"+llDumpList2String(boolValues, "|");
						}
						if(listValues) {
							newLine+="\nUDPLIST|"+llDumpList2String(listValues, "|");
						}
						if(cmd=="LINKMSG") {
							pleaseChange(ncName, index-2, data, newLine);
						}
						else {
							llOwnerSay("TODO: Leona: I have to think about UDPx in SATMSG/NOTSATMSG ..."); 
						}
					}
					//old RLV plugin
					else if(linkmsgNum==-233 || linkmsgNum==-234 || linkmsgNum==-237 || linkmsgNum==-238 || linkmsgNum==-239 || linkmsgNum==-1812221819) {
						deleteIf(ncName, index-2, data, "the old RLV plugin");
					}
					//old RLV timer
					else if(linkmsgNum==1337 || linkmsgNum==1338) {
						deleteIf(ncName, index-2, data, "the old RLV timer plugin");
					}
				}
			}
			if(CardsList) {
				FinishedCardsList+=ncName;
				llMessageLinked(LINK_SET, NC_READER_REQUEST, llList2String(CardsList, 0), MyId);
				CardsList=llDeleteSubList(CardsList, 0, 0);
			}
			else {
				state stage40;
			}
		}
	}
	state_exit() {
		llOwnerSay("Step 3 finished");
	}
	on_rez(integer start_param) {
		llResetScript();
	}
}
state stage40{
	state_entry() {
		llOwnerSay("FINISHED");
	}
}
//stage 99
//rename NCs

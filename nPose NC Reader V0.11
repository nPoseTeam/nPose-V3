// The nPose scripts are licensed under the GPLv2 (http://www.gnu.org/licenses/gpl-2.0.txt), with the following addendum:
//
// The nPose scripts are free to be copied, modified, and redistributed, subject to the following conditions:
//   - If you distribute the nPose scripts, you must leave them full perms.
//    - If you modify the nPose scripts and distribute the modifications, you must also make your modifications full perms.
//
// "Full perms" means having the modify, copy, and transfer permissions enabled in Second Life and/or other virtual world platforms derived from Second Life (such as OpenSim).  If the platform should allow more fine-grained permissions, then "full perms" will mean the most permissive possible set of permissions allowed by the platform.
//
// Documentation:
// https://github.com/LeonaMorro/nPose-NC-Reader/wiki
// Report Bugs to:
// https://github.com/LeonaMorro/nPose-NC-Reader/issues
// or IM slmember1 Resident (Leona)

string NC_READER_CONTENT_SEPARATOR="℥";
integer MEMORY_TO_BE_USED=60000;

integer DOPOSE=200;
integer DOACTIONS=207;
integer DOPOSE_READER=222;
integer DOACTION_READER=223;
integer NC_READER_REQUEST=224;
integer NC_READER_RESPONSE=225;
integer MEM_USAGE=34334;

list cacheNcNames;
list cacheContent;
//the cache lists contains only fully read (valid) content

list ncReadStackNcNames;
list ncReadStack;
//this is the working list, it contains partly read content
integer NC_READ_STACK_LINE_ID=0;
integer NC_READ_STACK_CURRENT_LINE=1;
integer NC_READ_STACK_CONTENT=2;
integer NC_READ_STACK_STRIDE=3;

list responseStack;
//this is used to ensure that the requests are servered in the right order
integer RESPONSE_STACK_NC_NAME=0;
integer RESPONSE_STACK_MENU_NAME=1;
integer RESPONSE_STACK_PLACEHOLDER=2;
integer RESPONSE_STACK_AVATAR_KEY=3;
integer RESPONSE_STACK_TYPE=4;
integer RESPONSE_STACK_STRIDE=5;

integer cacheMiss; //only used for statistical data
integer requests; //only used for statistical data

checkMemory() {
	//if memory is low, discard the oldest cache entry
	while(llGetUsedMemory()>MEMORY_TO_BE_USED) {
		cacheNcNames=llDeleteSubList(cacheNcNames, 0, 0);
		cacheContent=llDeleteSubList(cacheContent, 0, 0);
	}
}

//pragma inline
//debug(list message) {
//	llOwnerSay(llGetScriptName() + "\n#>" + llDumpList2String(message, "\n#>"));
//}

fetchNcContent(string str, key id, integer type) {
	//we can also use the expanded DOPOSE/DOACTIONS format:
	//str (separated by "℥"): cardname, menuname, placeholder
	list parts=llParseStringKeepNulls(str, [NC_READER_CONTENT_SEPARATOR], []);
	string ncName=llList2String(parts, 0);
	string menuName=llList2String(parts, 1);
	string placeholder=llList2String(parts, 2);
	if(llGetInventoryType(ncName) == INVENTORY_NOTECARD) {
		requests++;
		responseStack+=[ncName, menuName, placeholder, id, type];
		processResponseStack();
		checkMemory();
	}
}

processResponseStack() {
	do{
		if(!llGetListLength(responseStack)) {
			//there are no pending Requests: nothing to do
			return;
		}
		string ncName=llList2String(responseStack, RESPONSE_STACK_NC_NAME);
		if(~llListFindList(ncReadStackNcNames, [ncName])) {
			// the reader is running, we cant do anything
			return;
		}
		integer index=llListFindList(cacheNcNames, [ncName]);
		if(~index) {
			//The data is in the cache (and therefore valid and fully read) .. send the response
			//data Format:
			//str (separated by the CONTENT_SEPARATOR: ncName, menuName, placeholder(currently not used), content
			llMessageLinked(
				LINK_SET,
				llList2Integer(responseStack, RESPONSE_STACK_TYPE),
				llDumpList2String(llList2List(responseStack, 0, 2), NC_READER_CONTENT_SEPARATOR) + llList2String(cacheContent, index),
				llList2Key(responseStack, RESPONSE_STACK_AVATAR_KEY)
			);
			//we serverd the response, so we can delete it from the stack and check if there is more to do
			responseStack=llDeleteSubList(responseStack, 0, RESPONSE_STACK_STRIDE - 1);
			//sort it to the end to keep it for a longer time
			cacheNcNames=llDeleteSubList(cacheNcNames, index, index) + llList2List(cacheNcNames, index, index);
			cacheContent=llDeleteSubList(cacheContent, index, index) + llList2List(cacheContent, index, index);
		}
		else {
			//we need to start the reader
			cacheMiss++;
			ncReadStackNcNames+=[ncName];
			ncReadStack+=[llGetNotecardLine(ncName, 0), 0, ""];
			return;
		}
	}
	while(TRUE);
}

default {
	link_message(integer sender, integer num, string str, key id) {
		if(num==DOPOSE) {
			//str (separated by "℥"): ncName, menuName, placeholder(currently not used)
			//id: toucher
			fetchNcContent(str, id, DOPOSE_READER);
		}
		else if(num==DOACTIONS) {
			//str (separated by "℥"): ncName, menuName, placeholder(currently not used)
			//id: toucher
			fetchNcContent(str, id, DOACTION_READER);
		}
		else if(num==NC_READER_REQUEST) {
			//str (separated by "℥"): cardname, userDefinedData1, userDefinedData2
			//id: userDefinedKey
			fetchNcContent(str, id, NC_READER_RESPONSE);
		}
		else if (num == MEM_USAGE){
			float hitRate;
			if(requests) {
				hitRate=100.0 - (float)cacheMiss / (float)requests * 100.0;
			}
			llSay(0,
				"Memory Used by " + llGetScriptName() + ": " + (string)llGetUsedMemory() + 
				" of " + (string)llGetMemoryLimit() + 
				", Leaving " + (string)llGetFreeMemory() + " memory free.\nWe served " +
				(string)requests + " requests with a cache hit rate of " + 
				(string)llRound(hitRate) + "%."
			);
		}
	}
	dataserver(key queryid, string data) {
		integer ncReadStackIndex=llListFindList(ncReadStack, [queryid]);
		if(~ncReadStackIndex) {
			//its for us
			checkMemory();
			string ncName=llList2String(ncReadStackNcNames, ncReadStackIndex);
			if(data==EOF) {
				//move the stuff to the cache and process the response stack
				cacheNcNames+=ncName;
				cacheContent+=llList2String(ncReadStack, ncReadStackIndex + NC_READ_STACK_CONTENT);
				ncReadStackNcNames=llDeleteSubList(ncReadStackNcNames, ncReadStackIndex, ncReadStackIndex);
				ncReadStack=llDeleteSubList(ncReadStack, ncReadStackIndex, ncReadStackIndex + NC_READ_STACK_STRIDE - 1);
				processResponseStack();
			}
			else {
				data=llStringTrim(data, STRING_TRIM);
				if(!llSubStringIndex(data, "#")) {
					//ignore comments
					data="";
				}
				if(data) {
					data=NC_READER_CONTENT_SEPARATOR + data;
				}
				integer nextLine=llList2Integer(ncReadStack, ncReadStackIndex + NC_READ_STACK_CURRENT_LINE) + 1;
				ncReadStack=llListReplaceList(ncReadStack, [
					llGetNotecardLine(ncName, nextLine),
					nextLine,
					llList2String(ncReadStack, ncReadStackIndex + NC_READ_STACK_CONTENT) + data
				], ncReadStackIndex, ncReadStackIndex + NC_READ_STACK_STRIDE -1);
			}
		} 
	}
	changed(integer change) {
		if(change & CHANGED_INVENTORY) {
			cacheNcNames=[];
			cacheContent=[];
			ncReadStackNcNames=[];
			ncReadStack=[];
			responseStack=[];
		}
	}
}

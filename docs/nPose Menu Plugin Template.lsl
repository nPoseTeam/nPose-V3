integer PLUGIN_ACTION=-830;
integer PLUGIN_ACTION_DONE=-831;
integer PLUGIN_MENU=-832;
integer PLUGIN_MENU_DONE=-833;

integer PARAM_PATH=0;
integer PARAM_PAGE=1;
integer PARAM_PROMPT=2;
integer PARAM_BUTTONS=3;
integer PARAM_PLUGIN_NAME=4;
integer PARAM_PLUGIN_LOCAL_PATH=5;
integer PARAM_PLUGIN_STATIC_PARAMS=6;

//lowercase plugin name
string MY_PLUGIN_NAME="my_testplugin";

string MY_BUTTON_NAME_1="Button 1";
string MY_BUTTON_NAME_2="Button 2";
string MY_BUTTON_NAME_3="Button 3";

//helper
string deleteNode(string path, integer start, integer end) {
	return llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path, [":"], []), start, end), ":");
}

//helper
string buildParamSet1(string path, integer page, string prompt, list additionalButtons, string pluginName, string pluginLocalPath, string pluginStaticParams) {
	//We can't use colons in the promt, because they are used as a seperator in other messages
	//replace them with a UTF Symbol
	prompt=llDumpList2String(llParseStringKeepNulls(prompt, [","], []), "â€š"); // CAUTION: the 2nd "â€š" is a UTF sign!
	string buttons=llDumpList2String(additionalButtons, ",");
	return llDumpList2String([path, page, prompt, buttons, pluginName, pluginLocalPath, pluginStaticParams], "|");
}

string pluginMenu(list params, key id) {
	// 1) set a prompt if needed
	// 2) generate your buttons if needed
	// 3) return the (modified) parameters
	//Example make 3 buttons (button1, button2, button3)

	//extract the parameters from the list
	string path=llList2String(params, PARAM_PATH);
	integer page=(integer)llList2String(params, PARAM_PAGE);
	string prompt=llList2String(params, PARAM_PROMPT);
	string buttons=llList2String(params, PARAM_BUTTONS);
	string pluginName=llList2String(params, PARAM_PLUGIN_NAME);
	string pluginLocalPath=llList2String(params, PARAM_PLUGIN_LOCAL_PATH);
	string pluginStaticParams=llList2String(params, PARAM_PLUGIN_STATIC_PARAMS);
	
	list buttonsList;
	
	if(pluginLocalPath=="") { //root level
		//set a prompt
		prompt = "\nThis page is created by the script '" + llGetScriptName() + "'.\n";
		//generate the buttons
		buttonsList=[MY_BUTTON_NAME_1, MY_BUTTON_NAME_2, MY_BUTTON_NAME_3];
	}
	//return the modified parameters
	return buildParamSet1(path, page, prompt, buttonsList, pluginName, pluginLocalPath, pluginStaticParams);
}

string pluginAction(list params, key id) {
	// 1) Do the action if needed
	// 2) correct the path if needed
	// 3) return the (modified) parameters

	//extract the parameters from the list
	string path=llList2String(params, PARAM_PATH);
	integer page=(integer)llList2String(params, PARAM_PAGE);
	string prompt=llList2String(params, PARAM_PROMPT);
	string buttons=llList2String(params, PARAM_BUTTONS);
	string pluginName=llList2String(params, PARAM_PLUGIN_NAME);
	string pluginLocalPath=llList2String(params, PARAM_PLUGIN_LOCAL_PATH);
	string pluginStaticParams=llList2String(params, PARAM_PLUGIN_STATIC_PARAMS);

	//Do the action
	string displayname=llGetDisplayName(id);
	
	if(pluginLocalPath==MY_BUTTON_NAME_1) {
		llSay(0, "Button1 pressed by " + displayname);
	}
	else if(pluginLocalPath==MY_BUTTON_NAME_2) {
		llSay(0, "Well done, " + displayname + "! You pressed the second button.");
	}
	else if(pluginLocalPath==MY_BUTTON_NAME_3) {
		llSay(0, "Congatulations! This was the last button in this row.");
	}

	//correct the path
	if(pluginLocalPath!="") {
		//back one level
		path=deleteNode(path, -1, -1);
		page=0;
	}

	//return the modified parameters
	return buildParamSet1(path, page, prompt, [buttons], pluginName, pluginLocalPath, pluginStaticParams);
}



default {
	link_message(integer sender_num, integer num, string str, key id) {
		if(num==PLUGIN_ACTION || num==PLUGIN_MENU) {
			list params=llParseStringKeepNulls(str, ["|"], []);
			string pluginName=llList2String(params, PARAM_PLUGIN_NAME);
			if(pluginName==MY_PLUGIN_NAME) {
				//it is for me
				if(num==PLUGIN_ACTION) {
					llMessageLinked(LINK_SET, PLUGIN_ACTION_DONE, pluginAction(params, id), id);
				}
				else if(num==PLUGIN_MENU) {
					llMessageLinked(LINK_SET, PLUGIN_MENU_DONE, pluginMenu(params, id), id);
				}
			}
		}
	}
}

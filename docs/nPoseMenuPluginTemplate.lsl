// LSL script generated: docs.nPoseMenuPluginTemplate.lslp Wed Jul  6 16:33:59 Mitteleuropäische Sommerzeit 2016


//lowercase plugin name
string MY_PLUGIN_NAME = "my_testplugin";

string MY_BUTTON_NAME_1 = "Button 1";
string MY_BUTTON_NAME_2 = "Button 2";
string MY_BUTTON_NAME_3 = "Button 3";

//helper
string deleteNode(string path,integer start,integer end){
    return llDumpList2String(llDeleteSubList(llParseStringKeepNulls(path,[":"],[]),start,end),":");
}

//helper
string buildParamSet1(string path,integer page,string prompt,list additionalButtons,string pluginName,string pluginLocalPath,string pluginStaticParams){
    (prompt = llDumpList2String(llParseStringKeepNulls(prompt,[","],[]),"‚"));
    string buttons = llDumpList2String(additionalButtons,",");
    return llDumpList2String([path,page,prompt,buttons,pluginName,pluginLocalPath,pluginStaticParams],"|");
}

string pluginMenu(list params,key id){
    string path = llList2String(params,0);
    integer page = ((integer)llList2String(params,1));
    string prompt = llList2String(params,2);
    string buttons = llList2String(params,3);
    string pluginName = llList2String(params,4);
    string pluginLocalPath = llList2String(params,5);
    string pluginStaticParams = llList2String(params,6);
    list buttonsList;
    if ((pluginLocalPath == "")) {
        (prompt = (("\nThis page is created by the script '" + llGetScriptName()) + "'.\n"));
        (buttonsList = [MY_BUTTON_NAME_1,MY_BUTTON_NAME_2,MY_BUTTON_NAME_3]);
    }
    return buildParamSet1(path,page,prompt,buttonsList,pluginName,pluginLocalPath,pluginStaticParams);
}

string pluginAction(list params,key id){
    string path = llList2String(params,0);
    integer page = ((integer)llList2String(params,1));
    string prompt = llList2String(params,2);
    string buttons = llList2String(params,3);
    string pluginName = llList2String(params,4);
    string pluginLocalPath = llList2String(params,5);
    string pluginStaticParams = llList2String(params,6);
    string displayname = llGetDisplayName(id);
    if ((pluginLocalPath == MY_BUTTON_NAME_1)) {
        llSay(0,("Button1 pressed by " + displayname));
    }
    else  if ((pluginLocalPath == MY_BUTTON_NAME_2)) {
        llSay(0,(("Well done, " + displayname) + "! You pressed the second button."));
    }
    else  if ((pluginLocalPath == MY_BUTTON_NAME_3)) {
        llSay(0,"Congatulations! This was the last button in this row.");
    }
    if ((pluginLocalPath != "")) {
        (path = deleteNode(path,-1,-1));
        (page = 0);
    }
    return buildParamSet1(path,page,prompt,[buttons],pluginName,pluginLocalPath,pluginStaticParams);
}



default {

	link_message(integer sender_num,integer num,string str,key id) {
        if (((num == -830) || (num == -832))) {
            list params = llParseStringKeepNulls(str,["|"],[]);
            string pluginName = llList2String(params,4);
            if ((pluginName == MY_PLUGIN_NAME)) {
                if ((num == -830)) {
                    llMessageLinked(-1,-831,pluginAction(params,id),id);
                }
                else  if ((num == -832)) {
                    llMessageLinked(-1,-833,pluginMenu(params,id),id);
                }
            }
        }
    }
}

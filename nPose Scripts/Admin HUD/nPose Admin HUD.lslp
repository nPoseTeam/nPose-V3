integer ADJUST = 201;
integer DUMP = 204;
integer STOPADJUST = 205;
integer SYNC = 206;

integer PROP_PLUGIN=-500;

string SOUND_NAME="nPose Button Feedback";
integer FeedbackSoundAvailable;

buttonFeedback() {
	if(FeedbackSoundAvailable) {
		llPlaySound(SOUND_NAME, 0.9);
	}
}

doButtons(float xPos, float yPos, key id) {
	if(xPos<0.02) {
		//nothing
	}
	else if(xPos<0.5) {
		//maybe left side buttons
		if(yPos<0.04) {
			//nothing
		}
		else if(yPos<0.38) {
			//Lower left Button: Sync Animations
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|LINKMSG|" + (string)SYNC, id);
		}
		else if(yPos<0.52) {
			//Middle left Button: Mute Adjusters
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|OPTION|quietAdjusters=1", id);
		}
		else if(yPos<0.76) {
			//Upper left Button: Start Adjust
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|LINKMSG|" + (string)ADJUST, id);
		} 
	}
	else if(xPos<0.976) {
		//maybe right side buttons
		if(yPos<0.04) {
			//nothing
		}
		else if(yPos<0.38) {
			//Lower right Button: Dump Poses
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|LINKMSG|" + (string)DUMP, id);
		}
		else if(yPos<0.52) {
			//Middle right Button: Unmute Adjusters
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|OPTION|quietAdjusters=0", id);
		}
		else if(yPos<0.76) {
			//Upper right Button: Stop Adjust
			buttonFeedback();
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|LINKMSG|" + (string)DUMP, id);
			llMessageLinked(LINK_SET, PROP_PLUGIN, "PARENT_DO|LINKMSG|" + (string)STOPADJUST, id);
		}
		else if(yPos<0.83) {
			//nothing
		}
		else if(yPos<0.93) {
			//maybe close button
			if(xPos>0.91 && xPos<0.97) {
				//close Button
				buttonFeedback();
				llMessageLinked(LINK_SET, PROP_PLUGIN, "DIE", id);
			}
		}
	}
}

default {
	touch_start(integer num_detected) {
		vector touchedPos = llDetectedTouchST(0);
		doButtons(touchedPos.x, touchedPos.y, llDetectedKey(0));
	}

	changed(integer change) {
		if(change & CHANGED_INVENTORY) {
			FeedbackSoundAvailable=llGetInventoryType(SOUND_NAME)==INVENTORY_SOUND;
		}
	}
}
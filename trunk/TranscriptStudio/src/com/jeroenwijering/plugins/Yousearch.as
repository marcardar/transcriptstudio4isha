/**
* Show a YouTube searchbar that loads the results into the player.
**/
package com.jeroenwijering.plugins {


import com.jeroenwijering.events.*;

import flash.display.MovieClip;
import flash.events.*;
import flash.text.TextField;


public class Yousearch extends MovieClip implements PluginInterface {


	/** Reference to the graphics. **/
	public var clip:MovieClip;
	/** Reference to the View of the player. **/
	private var view:AbstractView;


	/** Constructor. **/
	public function Yousearch():void {
		clip = this;
	};


	/** Start a search. **/
	private function clickHandler(evt:MouseEvent=null):void {
		var que:String = encodeURI(clip.query.text);
		if(que.length > 3) { 
			view.sendEvent('LOAD','http://gdata.youtube.com/feeds/api/videos?vq='+que+'&format=5');
		}
		clip.query.text = '';
	};


	/** Clear the field on focus. **/
	private function focusHandler(evt:FocusEvent):void {
		if(clip.query.text == '...') {
			clip.query.text = '';
		}
	};


	/** Controlbar button click toggles visibility. **/
	private function buttonHandler(evt:MouseEvent):void { 
		showClip(!clip.visible);
	};


	/** The initialize call is invoked by the player View. **/
	public function initializePlugin(vie:AbstractView):void {
		view = vie;
		view.addModelListener(ModelEvent.STATE,stateHandler);
		view.addControllerListener(ControllerEvent.RESIZE,resizeHandler);
		clip.search.addEventListener(MouseEvent.CLICK,clickHandler);
		clip.query.addEventListener(FocusEvent.FOCUS_IN,focusHandler);
		clip.query.addEventListener(KeyboardEvent.KEY_DOWN,keyHandler);
		clip.search.buttonMode = true;
		clip.search.mouseChildren = false;
		resizeHandler();
		try {
			view.getPlugin('controlbar').addButton(clip.icon,'yousearch',buttonHandler);
		} catch (err:Error) { clip.icon.visible = false; }
	};


	/** Start the search when pressing the enter key. **/
	private function keyHandler(evt:KeyboardEvent):void {
		if(evt.charCode == 13) { 
			clickHandler();
		}
	};


	/** Handle a resize. **/
	private function resizeHandler(evt:ControllerEvent=undefined):void {
		clip.x = view.config['width']/2-140;
		clip.y = view.config['height']/2-20;
	};


	/** Show or hide the clip. **/
	private function showClip(val:Boolean):void {
		clip.visible = val;
		if(val) {
			clip.icon.alpha = 1;
		} else { 
			clip.icon.alpha = 0.3;
		}
	};


	/** Show the searchbox on video completed. **/
	private function stateHandler(evt:ModelEvent):void { 
		switch(evt.data.newstate) {
			case ModelStates.BUFFERING:
			case ModelStates.PLAYING:
			case ModelStates.PAUSED:
				showClip(false);
				break;
			default:
				clip.stage.focus = clip.query;
				showClip(true);
				break;
		}
	};


}


}
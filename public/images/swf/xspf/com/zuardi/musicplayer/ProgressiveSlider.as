/*
Copyright (c) 2005, Fabricio Zuardi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import mx.events.EventDispatcher;

class com.zuardi.musicplayer.ProgressiveSlider extends MovieClip
{

	//EventDispatcher needs these
 	var addEventListener:Function;
 	var removeEventListener:Function;
 	var dispatchEvent:Function;
 	var dispatchQueue:Function;

	//on Stage
	var slider_btn : Button;
	var mask_mc : MovieClip;
	var level_bar_mc : MovieClip;
	var bg_mc : MovieClip;

	//constructor
	function ProgressiveSlider(Void)
	{
		EventDispatcher.initialize(this);
		slider_btn["owner"] = this;
		slider_btn.onPress = function(){
			this["owner"].onMouseMove = this["owner"].onMouseDown = this["owner"].updateLevel;
		}
		slider_btn.onRelease = slider_btn.onReleaseOutside = function(){
			this["owner"].onMouseMove = this["owner"].onMouseDown = null;
		}
	}

	function updateLevel(){
		var percent = (this._xmouse/this._width)*100
		level = percent;
	}
	
	function set off_color(p_color:String){
		var bg_color = new Color(bg_mc)
		bg_color.setRGB(Number("0x"+p_color))
	}
	function set on_color(p_color:String){
		var fg_color = new Color(level_bar_mc)
		fg_color.setRGB(Number("0x"+p_color))
	}
	function set level(p_percent:Number){
		if(p_percent>100)p_percent=100;
		if(p_percent<0)p_percent=0;
		level_bar_mc._xscale = p_percent		
  		var eventObj:Object={target:this,type:"change"}
  		eventObj.level = p_percent;
  		dispatchEvent(eventObj);
	}
	
}
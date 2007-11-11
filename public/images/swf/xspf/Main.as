/*
Copyright (c) 2005, Fabricio Zuardi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

import com.zuardi.musicplayer.MusicButton;

class Main extends MovieClip{

	//movieclips
	var music_button_mc:MusicButton;		//0

	//main
	function Main(Void)
	{
		var button_properties = new Object();
		button_properties.autoload = _root.autoload;
		button_properties.autoplay = _root.autoplay;
		button_properties.repeat = _root.repeat;
		button_properties.first_track = _root.first_track;
		button_properties.playlist_url = _root.playlist_url;
		button_properties.playlist_size = _root.playlist_size;
		button_properties.shuffle = _root.shuffle;
		button_properties.song_url = _root.song_url;
		button_properties.song_title = _root.song_title;
		//skin
		button_properties.b_bgcolor = _root.b_bgcolor;
		button_properties.b_fgcolor = _root.b_fgcolor;
		if(_root.b_colors!=undefined){
			var bcolors_ar:Array = _root.b_colors.split(",")
			button_properties.b_load_color = bcolors_ar[0]
			button_properties.b_play_color = bcolors_ar[1]
			button_properties.b_stop_color = bcolors_ar[2]
			button_properties.b_error_color = bcolors_ar[3]			
		}
		if(_root.buttons!=undefined){
			var buttons_ar:Array = _root.buttons.split(",")
			button_properties.b_load = buttons_ar[0]
			button_properties.b_play = buttons_ar[1]
			button_properties.b_stop = buttons_ar[2]
			button_properties.b_error = buttons_ar[3]			
		}
		Stage.scaleMode = "noscale"
		Stage.align = "LT"
		this.attachMovie("MusicButton","music_button_mc",0,button_properties);
	}
}
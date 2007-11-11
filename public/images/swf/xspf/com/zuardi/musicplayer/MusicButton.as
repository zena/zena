/*
Copyright (c) 2005, Fabricio Zuardi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
import com.zuardi.musicplayer.MusicPlayer;
import com.zuardi.musicplayer.Playlist;
//#FoldMenu
//+
/*
	import com.zuardi.musicplayer.FoldButtonMenu;
*/
//-

class com.zuardi.musicplayer.MusicButton extends MovieClip
{
	//public vars
	var skin_load_timeout:Number;
	var song_load_timeout:Number;
	var autoload:Boolean;
	var autoplay:Boolean;
	var repeat:Boolean;
	var first_track:Number;
	var playlist_url:String;
	var playlist_size:Number;
	var shuffle:Boolean;
	var song_url:String;

	//skin
	var b_bgcolor:String;
	var b_fgcolor:String;
	var b_load_color:String;
	var b_play_color:String;
	var b_stop_color:String;
	var b_error_color:String;
	var b_load:String
	var b_play:String
	var b_stop:String
	var b_error:String

	//#Flash7#
	//+
		var song_title:String;
		var menu:ContextMenu;
	//-
	
	//default values
	private var DEFAULT_SKIN_LOAD_TIMEOUT = 10; //seconds
	private var DEFAULT_SONG_LOAD_TIMEOUT = 30; //seconds
	private var DEFAULT_PLAYLIST_URL = "http://webjay.org/by/hideout/allshows.xspf"	//default playlist

	//movieclips
	private var open_menu_btn : Button			//8
	private var button_btn : Button				//7
	private var load_skin_mc : MovieClip		//6
	private var play_skin_mc : MovieClip		//5
	private var stop_skin_mc : MovieClip		//4
	private var error_skin_mc : MovieClip		//3
	private var bg_skin_mc : MovieClip			//2
	//#FoldMenu
	//+
/*
		private var fold_menu : FoldButtonMenu		//1
*/
	//-
	private var music_player: MusicPlayer;		//0
	
	//private vars
	private var _skin_timeout_error:Boolean;
	private var _last_position:Number;
	private var _playlist:Playlist;
	private var _skin_load_interval:Object;
	//private var _song_load_last_time:Number;
	private var _skin_load_start_time:Number;
	private var _loading_state:Number;
	private var _stopcount:Number;

	//#Flash7#
	//+
		private var my_cm:ContextMenu;
	//-

	//constructor
	function MusicButton(Void)
	{
		_last_position =-1;
		_stopcount = 0;
		this.attachMovie("MusicPlayer","music_player",0);
		music_player["owner"] = this;
		this.attachMovie("invisible_button","button_btn",7)
		button_btn["owner"] = this;
		button_btn._visible=false;
		if(!first_track){
			first_track = 0;
		}else{
			first_track -=  1;
		} 
		if(!skin_load_timeout) skin_load_timeout = DEFAULT_SKIN_LOAD_TIMEOUT;
		if(!song_load_timeout) song_load_timeout = DEFAULT_SONG_LOAD_TIMEOUT;
		alert("song_url="+song_url)
		_skin_timeout_error = false;
		loadDefaultSkin();
		
		//#Flash7
		//+
			//customized menu
			my_cm = new ContextMenu();
			my_cm.customItems.push(new ContextMenuItem("Next", function(obj) {obj.nextTrack()}));
			my_cm.customItems.push(new ContextMenuItem("Previous", function(obj) {obj.prevTrack()}));
			my_cm.customItems.push(new ContextMenuItem("Download:", function(obj){obj.getURL(obj._playlist.tracks[obj._playlist.play_order_table[obj._playlist.current_track]].location)},true));
			my_cm.customItems.push(new ContextMenuItem("Add song to Webjay playlist", function(obj){obj.getURL("http://webjay.org/playthispage?url="+escape(obj._playlist.tracks[obj._playlist.play_order_table[obj._playlist.current_track]].location))}));
			my_cm.customItems.push(new ContextMenuItem("About Hideout", function(obj){obj.getURL("http://www.hideout.com.br")},true));
			my_cm.hideBuiltInItems();
			this.menu = my_cm;
		//-
	}

	//methods
	function onDefaultSkinLoaded(){
		//there are parameters for cutom skin
		alert("default skin loaded")
		if(((b_load!=undefined)||(b_play!=undefined)||(b_stop!=undefined)||(b_error!=undefined))&&(!_skin_timeout_error)){
			alert("loading custom skin..")
			loadSkin(b_load,b_play,b_stop,b_error);
		}else{
			alert("no custom skin, loading playlist...")
			initPlayer()
		}
	}
	function onSkinLoaded(){
		alert("custom skin ok, loading playlist...")
		initPlayer()
	}
	function initPlayer(){
		//adjust the bacgground and hitarea dimensions
		var bg_default_height = bg_skin_mc._height;
		var bg_default_width = bg_skin_mc._width;
		bg_skin_mc._xscale = button_btn._xscale = play_skin_mc._width
		bg_skin_mc._yscale =  button_btn._yscale = play_skin_mc._height
		//#FoldMenu
		//+
/*
			var menu_properties = new Object();
			menu_properties.x = menu_properties.x_offset = bg_skin_mc._width/2;
			menu_properties.y = menu_properties.y_offset = bg_skin_mc._height/2;
			menu_properties.is_active = true;
			menu_properties.owner = this;
			menu_properties.music_player = music_player;
			menu_properties.shuffle = shuffle;
			this.attachMovie("FoldButtonMenu","fold_menu",1,menu_properties);
			this.attachMovie("invisible_button","open_menu_btn",8);
			trace("open_menu_btn._width"+open_menu_btn._width)
			open_menu_btn._xscale = play_skin_mc._width
			open_menu_btn._yscale = play_skin_mc._height
			open_menu_btn["owner"] = this;
			open_menu_btn.onPress = openMenuPressed;
			open_menu_btn.onRollOver = openMenuOver;
*/			
		//-
		setColors()
		loadPlaylist()		
	}

	//#FoldMenu
	//+
/*
		function openMenuPressed (){
			if(this["owner"].stop_skin_mc._visible){
				//is playing = stop music
				this["owner"].stopTrack()
			}else{
				this["owner"].fold_menu.activate(!this["owner"].fold_menu.is_active);
			}
		}
		function openMenuOver (){
			if(this["owner"].stop_skin_mc._visible){
				//is playing = show menu
				this["owner"].fold_menu.activate(true);
			}
		}
		function onVolumeChange(p_eventObj){
			this["owner"].music_player.setMusicVolume(p_eventObj.level)
		}
*/
	//-
	
	function setColors(){
		alert("setColors()")
		var buttons_ar = [load_skin_mc,play_skin_mc,stop_skin_mc,error_skin_mc]
		var b_colors_ar = [b_load_color,b_play_color,b_stop_color,b_error_color]
		if(b_bgcolor.length>0){
			var bgcolor = new Color(bg_skin_mc)
			bgcolor.setRGB(Number("0x"+b_bgcolor))
		}else{
			bg_skin_mc.removeMovieClip()
		}
		//individual color buttons
		for(var i=0;i<b_colors_ar.length;i++){
			if(b_colors_ar[i].length>0){
				var bcolor = new Color(buttons_ar[i])
				bcolor.setRGB(Number("0x"+b_colors_ar[i]))
			}else{
				if(b_fgcolor.length>0){
					var bcolor = new Color(buttons_ar[i])
					bcolor.setRGB(Number("0x"+b_fgcolor))					
				}
			}
		}
	}
	function loadPlaylist(){
		showButton(load_skin_mc)
		_playlist = new Playlist();
		_playlist["owner"] = this;
		if(playlist_size){
			alert("playlist_size="+playlist_size)
			_playlist.playlist_size = playlist_size;
		}else{
			alert("undefined playlist_size="+playlist_size)
		}
		if(shuffle.toString()=="true"){
			alert("shuffle="+shuffle)
			_playlist.shuffle = shuffle;
		}else{
			alert("random="+shuffle)
		}
		_playlist.onPlaylistLoaded = function(p_success){
			this["owner"].alert("onPlaylistLoaded("+p_success)
			if(p_success){
				this.current_track = this["owner"].first_track;
				this["owner"].alert("aaa "+this.tracks[this.current_track].label)
				//#Flash7
				//+
					this["owner"].my_cm.customItems[1].enabled = false;
					if(this.tracks.length<2){
						this["owner"].my_cm.customItems[0].enabled = false;
					}
					this["owner"].my_cm.customItems[2].caption = "Download: "+this.tracks[this.play_order_table[this.current_track]].label;
					/*
					for(var i=0; i<10;i++){
						this["owner"].my_cm.customItems.push(new ContextMenuItem(this.tracks[i].label, function(obj){obj.getURL(obj._playlist.tracks[i].location)}));
					}
					*/
				//-
				this["owner"].button_btn.onPress = function(){
					this["owner"].playTrack()
				}
				if((this["owner"].autoplay.toString()=="true")){
					this["owner"].playTrack()
				}else{
					this["owner"].showButton(this["owner"].play_skin_mc)
				}
			}else{
				this["owner"].alert("error")
				this["owner"].showButton(this["owner"].error_skin_mc)
				this["owner"].onEnterFrame = null;
			}
		}
		//playlists has priority over songs, if a playlist_url parameter is found the song_url is ignored
		//default playlist if none is passed through query string
		if(playlist_url==undefined){
			alert("Empty playlist "+ song_url)
			if(song_url==undefined){
				alert("Empty song_url")
				playlist_url = DEFAULT_PLAYLIST_URL;
				_playlist.loadXSPFPlaylist(playlist_url)
			}else{
				alert("SINGLE MODE")
				var single_music_playlist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><playlist version=\"1\" xmlns = \"http://xspf.org/ns/0/\"><trackList>";
				single_music_playlist += "<track><location>"+song_url+"</location>"
				if(song_title!=undefined) single_music_playlist += "<annotation>"+song_title+"</annotation>";
				single_music_playlist +="</track>"
				single_music_playlist += "</trackList></playlist>"
				_playlist.loadXSPFPlaylist(single_music_playlist,true)
			}
		}else{
			alert("loading playlist...")
			_playlist.loadXSPFPlaylist(playlist_url)
		}
	}
	
	function playTrack(){
		alert("play track ")
		_last_position = -1;
		music_player.onMusicLoaded = function(p_success:Boolean){
			if (p_success) {
				this["owner"].alert("download finished");
				this["owner"]._loading_state = 1
			} else {
				this["owner"].alert("download failed ");
				this["owner"]._loading_state = -1
			}
		}
		music_player.onMusicEnd = function() {
			this["owner"].alert("sound complete");
			this["owner"].nextTrack()
		}
		alert("_playlist = "+_playlist)
		alert("_playlist.current_track = "+_playlist.current_track)
		alert("_playlist.play_order_table = "+_playlist.play_order_table)
		alert("_playlist.play_order_table["+_playlist.current_track+"] = "+_playlist.play_order_table[_playlist.current_track])
		alert("_playlist.tracks[_playlist.play_order_table["+_playlist.current_track+"]] = "+_playlist.tracks[_playlist.play_order_table[_playlist.current_track]])
		alert("loading "+_playlist.tracks[_playlist.play_order_table[_playlist.current_track]].location)
		stopAllSounds()
		_loading_state = 0;
		music_player.loadMusic(_playlist.tracks[_playlist.play_order_table[_playlist.current_track]].location,true);
		this.onEnterFrame = this.buttonBehaviorControl;
	}
	function nextTrack(){
		alert("_playlist.play_order_table.length-1 = "+(_playlist.play_order_table.length-1))
		alert("_playlist.play_order_table[_playlist.play_order_table.length-1] = "+_playlist.play_order_table[_playlist.play_order_table.length-1])
		if(_playlist.current_track!=(_playlist.play_order_table.length-1)){
			alert("next track")
			_playlist.current_track ++;
			//#Flash7
			//+
				my_cm.customItems[2].caption = "Download: "+_playlist.tracks[_playlist.play_order_table[_playlist.current_track]].label
				if(_playlist.current_track>0){
					my_cm.customItems[1].enabled=true;
				}
				if(_playlist.current_track!=(_playlist.play_order_table.length-1)){
					my_cm.customItems[0].enabled=true;
				}else{
					if(repeat.toString()!="true"){
						my_cm.customItems[0].enabled=false;
					}
				}
			//-
			playTrack();
		}else{
			alert("fim")			
			if(repeat.toString()=="true"){
				_playlist.current_track = 0;
				if(shuffle.toString()=="true"){
					_playlist.shuffleOrderTable()
				}
				playTrack();
			}else{
				//default
				stopTrack()
			}
		}
	}
	function prevTrack(){
		if(_playlist.current_track>0){
			alert("prev track")
			_playlist.current_track --;
			//#Flash7
			//+
				my_cm.customItems[2].caption = "Download: "+_playlist.tracks[_playlist.play_order_table[_playlist.current_track]].label
				if(_playlist.current_track<(_playlist.play_order_table.length-1)){
					my_cm.customItems[0].enabled=true;
				}
				if(_playlist.current_track>0){
					my_cm.customItems[1].enabled=true;
				}else{
					my_cm.customItems[1].enabled=false;
				}
			//-
			playTrack();
		}else{
			alert("fim")
		}
	}
	function stopTrack(){
		alert("stop track")
		music_player.stopMusic()
		this.onEnterFrame = null;
		showButton(play_skin_mc)
		button_btn.onPress = function(){
			this["owner"].playTrack();
		}
	}
	function buttonBehaviorControl(){
		var is_cached = false;
		alert("PLAY CHECK")
		if(_last_position != music_player.music_position){
			//song is playing
			alert("song is playing")
			alert("_last_position="+_last_position)
			alert("music_player.music_position="+music_player.music_position)
			alert("music_player.music_duration="+music_player.music_duration)
			showButton(stop_skin_mc)
			button_btn.onPress = function(){
				this["owner"].stopTrack();
			}
		}else{
			alert("make sure the position is stoped "+_stopcount)
			//make sure the position is stoped
			_stopcount++;
			if(_stopcount>3){
				alert("song is stopped")
				_stopcount = 0;
				//song is stopped
				alert("song is stopped")
				if(_loading_state==0){
					//buffering
					alert("buffering: "+music_player.bytes_loaded)
					showButton(load_skin_mc)
					button_btn.onPress = function(){
						this["owner"].stopTrack();
					}
					button_btn._visible=true;
					//TODO check to see if it is a real buffering (position==time) or if other instance stopedAllSounds
					alert("music_player.music_position="+music_player.music_position)
					alert("music_player.music_duration="+music_player.music_duration)
					var remaining = music_player.music_duration - music_player.music_position;
					alert("remaining="+remaining)
					if(music_player.music_position>10){
						if((remaining > 20000)||((music_player.bytes_loaded==music_player.bytes_total))){
							alert("INFLUENCIA EXTERNA")
							if (remaining > 20000){
								//nada
							}else {
								_root.teste_mc.play();	
							}
							stopTrack();
						}
					}else{
						alert("waiting for more downloadin...")
						//TODO Timeout checking
						/*
							if((getTimer()-_song_load_last_time)>song_load_timeout*1000){
								alert("error timeout loading")
							}
						*/
					}
				}else if(_loading_state==1){
					//stoped with the file downloaded 100%
					showButton(load_skin_mc)
					alert("stoped and finished download")
					if(music_player.music_position==0){
						//song wasnt started yet
						alert("_loading_state="+_loading_state)
						alert("song was on cache "+music_player.bytes_loaded)
					}else{
						//some other instance stoped the song in the middle
						if((music_player.bytes_loaded<music_player.bytes_total)){
							//if here is BUG wrong info maybe caused by cache, download is not finished
							_loading_state = 0;
						}else{
							stopTrack();
						}
					}
				}else if(_loading_state==-1){
					//error
					alert("ERROR")
					showButton(error_skin_mc)
					nextTrack()
				}else{
					//bug
					alert("BUG")
				}
			}
		}
		_last_position = music_player.music_position;
	}
	
	function loadDefaultSkin(){
		//default background
		this.attachMovie("default_b_bg","bg_skin_mc",2)
		//default loading
		this.attachMovie("default_loading","load_skin_mc",6)
		//default play
		this.attachMovie("default_play","play_skin_mc",5)
		//default stop
		this.attachMovie("default_stop","stop_skin_mc",4)
		//default error
		this.attachMovie("default_error","error_skin_mc",3)
		onDefaultSkinLoaded()
	}
	//only one button visible
	function showButton(p_button_mc:MovieClip){
		load_skin_mc._visible =
		play_skin_mc._visible =
		stop_skin_mc._visible =
		error_skin_mc._visible =
		false;
		if (p_button_mc==play_skin_mc) 	button_btn._visible=true;
		p_button_mc._visible=true;
	}
	function loadSkin(p_load_skin:String,p_play_skin:String,p_stop_skin:String,p_error_skin:String){
		if(p_load_skin.length>0){
			alert("loading load icon...");
			load_skin_mc.loadMovie(p_load_skin)
		}
		if(p_play_skin.length>0){
			alert("loading play icon...");
			play_skin_mc.loadMovie(p_play_skin)
		}
		if(p_stop_skin.length>0){
			alert("loading stop icon...");
			stop_skin_mc.loadMovie(p_stop_skin)
		}
		if(p_error_skin.length>0){
			alert("loading error icon...");
			error_skin_mc.loadMovie(p_error_skin)
		}
		_skin_load_start_time = getTimer();
		_skin_load_interval = setInterval(this,"checkSkinLoaded",200,this)
	}
	function checkSkinLoaded(p_owner){
		var load_time = getTimer() - p_owner._skin_load_start_time;
		alert(load_time)
		var isloadloaded = false;
		var isplayloaded = false;
		var isstoploaded = false;
		var iserrorloaded = false;
		var skinloaded = false;
		//var timeout = false;
		if((load_skin_mc.getBytesLoaded()>0)&&((load_skin_mc.getBytesLoaded()/load_skin_mc.getBytesTotal())==1)){
			isloadloaded = true;
		}
		alert("a"+isloadloaded+" "+load_skin_mc.getBytesLoaded())
		
		if((play_skin_mc.getBytesLoaded()>0)&&((play_skin_mc.getBytesLoaded()/play_skin_mc.getBytesTotal())==1)){
			isplayloaded = true;
			play_skin_mc._visible = false;
		}
		alert("b"+isplayloaded+" "+play_skin_mc.getBytesLoaded())
		if((stop_skin_mc.getBytesLoaded()>0)&&((stop_skin_mc.getBytesLoaded()/stop_skin_mc.getBytesTotal())==1)){
			isstoploaded = true;
			stop_skin_mc._visible = false;
		}
		alert("c"+isstoploaded+" "+stop_skin_mc.getBytesLoaded())
		if((error_skin_mc.getBytesLoaded()>0)&&((error_skin_mc.getBytesLoaded()/error_skin_mc.getBytesTotal())==1)){
			iserrorloaded = true;
			error_skin_mc._visible = false;
		}
		alert("d"+iserrorloaded+" "+error_skin_mc.getBytesLoaded())

		if(((isloadloaded)&&(isplayloaded)&&(isstoploaded))){
			skinloaded = true;
		}else if(load_time>(p_owner.skin_load_timeout*1000)){
			//timeout
			alert("SKINLOADED TIMEOUT")
			_skin_timeout_error = true;
			p_owner.loadDefaultSkin()
			clearInterval(p_owner._skin_load_interval)
		}
		if(skinloaded){
			alert("skin successfull loaded")
			onSkinLoaded()
			clearInterval(p_owner._skin_load_interval)
		}
	}
	//FOR DEBUG
	function alert(p_msg){
		trace("#my trace# "+p_msg)	
	}
}
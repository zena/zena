/*
Copyright (c) 2005, Fabricio Zuardi
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
    * Neither the name of the author nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

class com.zuardi.musicplayer.Playlist{
	
	//public vars
	var tracks:Array;
	var playlist_size:Number;
	var current_track:Number;
	var shuffle:Boolean;
	var play_order_table:Array;
	//interface
	var onPlaylistLoaded:Function;
	
	//private vars
	private var _xspf:XML;
	private var _delay_interval:Object;
	
	//constructor
	function Playlist(Void)
	{
		tracks = [];
		_xspf = new XML();
		_xspf.ignoreWhite = true;
		current_track=0;
	}
	function loadXSPFPlaylist(p_url:String,p_is_string:Boolean){
		alert("loadXSPFPlaylist("+p_url+","+p_is_string+")")
		var playlistObjPointer = this;
		_xspf.onLoad = function(p_success){
			if(p_success){
				var root_node = this.firstChild;
				for(var node = root_node.firstChild; node != null; node = node.nextSibling){
					if(node.nodeName == "title"){
						var playlist_title = node.firstChild.nodeValue;
					}
					if(node.nodeName == "trackList"){
						//tracks
						var tracks_array = [];
						for(var track_node = node.firstChild; track_node != null; track_node = track_node.nextSibling){
							var track_obj = new Object()
							//track attributes
							for(var track_child = track_node.firstChild; track_child != null; track_child = track_child.nextSibling){
								if(track_child.nodeName=="location"){
									track_obj.location = track_child.firstChild.nodeValue
								}
								if(track_child.nodeName=="image"){
									track_obj.image = track_child.firstChild.nodeValue
								}
								if(track_child.nodeName=="annotation"){
									track_obj.annotation = track_child.firstChild.nodeValue
								}
							}
							track_obj.label = (tracks_array.length+1) +". "+track_obj.annotation;
							tracks_array.push(track_obj)
							if(playlistObjPointer.playlist_size){
								if(tracks_array.length>=playlistObjPointer.playlist_size){
									trace("limit: "+playlistObjPointer.playlist_size)
									break;
								}
							}
						}
					}
				}
				playlistObjPointer.tracks = tracks_array;
				playlistObjPointer.normalOrderTable();
				if(playlistObjPointer.shuffle.toString()=="true"){
					playlistObjPointer.shuffleOrderTable()
				}
				trace("tracks: "+playlistObjPointer.tracks.length)
				trace("playlist loaded"+playlistObjPointer.tracks[0].location)
				playlistObjPointer.onPlaylistLoaded(true)
			}else{
				playlistObjPointer.onPlaylistLoaded(false)
			}
		}
		if(p_is_string){
			trace("single mode = "+p_url)
			_xspf.parseXML(p_url);
			//half second delay
			_delay_interval = setInterval(function(p_xspf,p_target){ 
				trace("DELAY")
				p_xspf.onLoad(true);
				clearInterval(p_target._delay_interval)
			},500,_xspf,this)
		}else{
			_xspf.load(p_url);
		}
	}
	function loadRSSPlaylist(p_url:String){
		//TODO future (podcast support)
	}
	function loadM3UPlaylist(p_url:String){
		//TODO future
	}
	function shuffleOrderTable(){
		for (var i=play_order_table.length-1; i>=0; i--) {
			var rand = random(i);
			var aux = play_order_table[i];
			play_order_table[i] = play_order_table[rand];
			play_order_table[rand] = aux;
		}
		trace("shuffletable= "+play_order_table)
	}
	function normalOrderTable(){
		play_order_table = new Array(tracks.length);
		//generate a ordered table
		for(var i=0;i<play_order_table.length;i++){
			play_order_table[i] = i;
		}
		trace("normalOrderTable() play_order_table[0]"+play_order_table[0])
	}
	function alert(p_msg){
		trace(p_msg)	
	}

}
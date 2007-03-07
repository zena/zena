var Zena = {};

Zena.env = new Array();

// preview content from another window.
Zena.editor_preview = function(element, value) {
	new Ajax.Request('/z/version/preview', {asynchronous:true, evalScripts:true, parameters:'content=' + value})
}

// preview version.
Zena.version_preview = function(version_id) {
	new Ajax.Request('/z/version/preview/' + version_id, {asynchronous:true, evalScripts:true})
}

// preview discussion.
Zena.discussion_show = function(discussion_id) {
	new Ajax.Request('/z/discussion/show/' + discussion_id, {asynchronous:true, evalScripts:true})
}

// update content from another window
Zena.update = function( tag, url ) {
  if (window.is_editor) {
    opener.Zena.update(tag,url);
  } else {
    new Ajax.Updater(tag, url, {asynchronous:true, evalScripts:true, onComplete:function(){ new Effect.Highlight(tag); }});
  }
  return false;
}

// element size follows inside window size
Zena.resizeElement = function(name) {
  var obj = $(name);
  var myWidth = 0, myHeight = 0;
  if( typeof( window.innerWidth ) == 'number' ) {
    //Non-IE
    myWidth  = window.innerWidth;
    myHeight = window.innerHeight;
  } else if( document.documentElement && ( document.documentElement.clientWidth || document.documentElement.clientHeight ) ) {
    //IE 6+ in 'standards compliant mode'
    myWidth = document.documentElement.clientWidth;
    myHeight = document.documentElement.clientHeight;
  } else if( document.body && ( document.body.clientWidth || document.body.clientHeight ) ) {
    //IE 4 compatible
    myWidth = document.body.clientWidth;
    myHeight = document.body.clientHeight;
  }
  var hMargin = obj.offsetLeft;
  var vMargin = obj.offsetTop;
  obj.style.width  = (myWidth  - hMargin - 5) + 'px';
  obj.style.height = (myHeight - vMargin - 5) + 'px';
}
// transfer html from src tag to trgt tag
Zena.transfer = function(src,trgt) {
  target = $(trgt);
  source = $(src);
  target.innerHTML = source.innerHTML;
  if (!target.visible()) {
    Effect.BlindDown(trgt);
  }
}

// get the name of a file from the path
Zena.get_name = function(source, target) {
	if ($(target).value == '') {
		var path = $(source).value;
	  elements = path.split('/');
		$('document_name').value = elements[elements.length - 1];
	}
}

Zena.clear_file = function(input_id) {
  var obj = $(input_id);
  var name = obj.getAttribute('name');
  var parent = obj.parentNode;
  parent.removeChild(obj);
  var newobj = document.createElement('input');
  newobj.setAttribute('id',input_id);
  newobj.setAttribute('type','file');
  parent.appendChild(newobj);
}

Zena.open_cal = function(e, url) {
	var e = e || window.event; // IE
	var tgt = e.target || e.srcElement; // IE
	day = tgt.innerHTML;
	while (tgt && !tgt.cells) {tgt = tgt.parentNode;} // finds tr.
	row = tgt.rowIndex;
	var update_url = unescape(url) + '&day=' + day + '&row=' + row;
	new Ajax.Request(update_url, {asynchronous:true, evalScripts:true, parameters:'notes'});
 	return false;
}

Zena.update_rwp = function(inherit_val,r_index,w_index,p_index,t_index) {
	if (inherit_val == "-1") {
		$("node_rgroup_id").selectedIndex = 0;
		$("node_wgroup_id").selectedIndex = 0;
		$("node_rgroup_id").disabled = true;
		$("node_wgroup_id").disabled = true;
		$("node_template" ).disabled = false;
		if (p_index != '') {
			$("node_pgroup_id").selectedIndex = 0;
			$("node_pgroup_id").disabled = true;
		}
	} else if (inherit_val == "1") {
		$("node_rgroup_id").selectedIndex = r_index;
		$("node_wgroup_id").selectedIndex = w_index;
		$("node_template" ).selectedIndex = t_index;
		$("node_rgroup_id").disabled = true;
		$("node_wgroup_id").disabled = true;
		$("node_template" ).disabled = true;
		if (p_index != '') {
			$("node_pgroup_id").selectedIndex = p_index;
			$("node_pgroup_id").disabled = true;
		}
	} else {
		$("node_rgroup_id").disabled = false;
		$("node_wgroup_id").disabled = false;
		$("node_pgroup_id").disabled = false;
		$("node_template" ).disabled = false;
		if (p_index != '') {
			$("node_pgroup_id").disabled = false;
		}
	}
}

/* fade flashes automatically */
Event.observe(window, 'load', function() { 
  $A(document.getElementsByClassName('flash')).each(function(o) {
    o.opacity = 100.0;
    Effect.Fade(o, {duration: 8.0});
  });
});

var current_form = false;
Zena.get_key = function(e) {
  if (window.event)
     return window.event.keyCode;
  else if (e)
     return e.which;
  else
     return null;
}

Zena.key_press = function(e,obj) {
  var key = Zena.get_key(e);
  var evtobj=window.event? event : e;
  window.status = key;
  switch(key) {
    case 6:
      if (window.current_form) {
        //window.current_form.focus();
        $(window.current_form).focus();
        window.current_form = false;
      }
      else {
        window.current_form = obj;
        $("search").focus();
      }
      break;
  } 
}

Zena.Div_editor = Class.create();
Zena.Div_editor.prototype = {
  moving : false,
  moveY : false,
  moveX : false,
  moveAll : false,
  marker : '',
  clone  : '',
  pos : {
    x : 0,
    y : 0,
    w : 0,
    h : 0,
    offsetx : 0,
    offsety : 0,
    fullw : 0,
    fullh : 0,
    allx : 0,
    ally : 0 
  },
  flds : {
    x : '',
    y : '',
    w : '',
    h : ''
  },
  zoom : 1.0,
  BORDER_WIDTH : 10,
  BORDER_COLOR : 'black',
	initialize: function(img_name, x_name, y_name, w_name, h_name, azoom, left_pos, top_pos) {
	  var img      = $(img_name);
    var img_pos  = Position.positionedOffset(img);
	  this.flds.x = $(x_name);
	  this.flds.y = $(y_name);
	  this.flds.w = $(w_name);
	  this.flds.h = $(h_name);
	  this.zoom  = azoom;
	  
    this.pos.offsetx = left_pos;
    this.pos.offsety = top_pos;
    this.pos.fullw = img.width;
    this.pos.fullh = img.height;
    
    this.clone = document.createElement('div');
    this.mark  = document.createElement('div');
    Element.setStyle(this.clone, {
      width:  this.pos.fullw + 'px',
      height: this.pos.fullh + 'px',
      background: 'url('+img.src+') no-repeat',
      position: 'absolute',
      left: this.pos.offsetx + 'px',
      top:  this.pos.offsety + 'px',
      border: '1px solid grey'
    });
    // register callbacks
    this.clone.onmousedown = this.update_position.bindAsEventListener(this);
    this.clone.onmouseup   = this.end_move.bindAsEventListener(this);
    this.clone.onmousemove = this.do_move.bindAsEventListener(this);
    
    this.flds.x.onchange = this.update_from_inputs.bindAsEventListener(this);
    this.flds.y.onchange = this.update_from_inputs.bindAsEventListener(this);
    this.flds.w.onchange = this.update_from_inputs.bindAsEventListener(this);
    this.flds.h.onchange = this.update_from_inputs.bindAsEventListener(this);
    // inputs onchange = update this.
    
    Element.setStyle(this.mark, {
      border: this.BORDER_WIDTH + 'px solid ' + this.BORDER_COLOR,
      position: 'absolute',
      cursor: 'move'
    });
    this.pos.x = 0;
    this.pos.y = 0;
    this.pos.w = img.width;
    this.pos.h = img.height;
    this.update_sizes();
    img.parentNode.appendChild(this.clone);
    img.parentNode.removeChild(img);
    this.clone.appendChild(this.mark);
  },
  update_from_inputs : function(event) {
    this.pos.x = this.flds.x.value / this.zoom;
    this.pos.y = this.flds.y.value / this.zoom;
    this.pos.w = this.flds.w.value / this.zoom;
    this.pos.h = this.flds.h.value / this.zoom;
    //this.limit_positions();
    this.update_sizes();
  },
  update_sizes: function() {
    this.limit_positions();
    this.flds.x.value = Math.round(this.zoom * this.pos.x);
    this.flds.y.value = Math.round(this.zoom * this.pos.y);
    this.flds.w.value = Math.round(this.zoom * this.pos.w);
    this.flds.h.value = Math.round(this.zoom * this.pos.h);
    Element.setStyle(this.mark, {    
      left: (this.pos.x - this.BORDER_WIDTH) + 'px',
      top:  (this.pos.y - this.BORDER_WIDTH) + 'px',
      width:  this.pos.w + 'px',
      height: this.pos.h + 'px'
    });
  },
  update_position: function(event) {
    var posx = Event.pointerX(event) - this.pos.offsetx;
    var posy = Event.pointerY(event) - this.pos.offsety;
    if (!this.moving) {
      this.moveAll = false;
      this.pos.startx = posx;
      if (Math.abs(this.pos.x - posx) < 15.0) {
        // moving left corners
        this.moveX  = 'left';
        this.moving = true;
      } else if (Math.abs(this.pos.x + this.pos.w - posx) < 15.0) {
        // moving right corners
        this.moveX = 'right';
        this.moving = true;
      } else {
        this.moveX = false;
      }
      if (Math.abs(this.pos.y - posy) < 15.0) {
        // moving top
        this.moveY = 'top';
        this.moving = true;
      } else if (Math.abs(this.pos.y + this.pos.h - posy) < 15.0)  {
        // moving bottom
        this.moveY = 'bottom';
        this.moving = true;
      } else {
        this.moveY = false;
      }
      if (this.moving) {
        // ok
      } else if (posx >= this.pos.x && posy >= this.pos.y && posx <= (this.pos.x + this.pos.w) && posy <= (this.pos.y + this.pos.h) && !(this.pos.w == this.pos.fullw && this.pos.h == this.pos.fullh) ) {
        this.moveAll = true;
        // inside drag
        this.pos.allx = posx - this.pos.x;
        this.pos.ally = posy - this.pos.y;
      } else {
        // start new move
        this.pos.x = posx;
        this.pos.y = posy;
        this.pos.w = 1;
        this.pos.h = 1;
        this.moveX = 'right';
        this.moveY = 'bottom';
      }
      this.moving = true;
    }
    if (posx >= 0 && posy >= 0 && posx <= this.pos.fullw && posy <= this.pos.fullh ) {
      if (this.moveAll) {
        // drag
        this.pos.x = posx - this.pos.allx;
        this.pos.y = posy - this.pos.ally;
      } else {
        if (this.moveX == 'left') {
          this.pos.w = this.pos.x + this.pos.w - posx;
          this.pos.x = posx;
        } else if (this.moveX == 'right') {
          this.pos.w = posx - this.pos.x;
        }
        if (this.moveY == 'top') {
          this.pos.h = this.pos.y + this.pos.h - posy;
          this.pos.y = posy;
        } else if (this.moveY == 'bottom'){
          this.pos.h = posy - this.pos.y;
        }
      }
      if (event.shiftKey) {
        // force square
        if (this.pos.h > this.pos.w) {
          this.pos.w = this.pos.h;
        } else {
          this.pos.h = this.pos.w;
        }
      }
      this.update_sizes();
    }
  },
  limit_positions: function() {
    if (this.pos.x < 0) {
      this.pos.x = 0;
    }
    if (this.pos.y < 0) {
      this.pos.y = 0;
    }
    if (this.pos.w < 0) {
      // swap moving corner
      this.pos.w = -this.pos.w;
      if (this.moveX == 'right') {
        this.moveX = 'left';
      } else {
        this.moveX = 'right';
      }
    }
    if (this.pos.h < 0) {
      // swap moving corner
      this.pos.h = -this.pos.h;
      if (this.moveY == 'top') {
        this.moveY = 'bottom';
      } else {
        this.moveY = 'top';
      }
    }
    if (this.moveAll) {
      if (this.pos.x + this.pos.w > this.pos.fullw) {
        this.pos.x = this.pos.fullw - this.pos.w;
      }
      if (this.pos.y + this.pos.h > this.pos.fullh) {
        this.pos.y = this.pos.fullh - this.pos.h;
      }
    } else {
      if (this.pos.x + this.pos.w > this.pos.fullw) {
        this.pos.w = this.pos.fullw - this.pos.x;
      }
      if (this.pos.y + this.pos.h > this.pos.fullh) {
        this.pos.h = this.pos.fullh - this.pos.y;
      }
    }
    if (this.pos.w > this.pos.fullw) {
      this.pos.w = this.pos.fullw;
    }
    if (this.pos.h > this.pos.fullh) {
      this.pos.h = this.pos.fullh;
    }
  },
  do_move: function(event) {
    if (this.moving) {
      this.update_position(event);
    }
  },
  end_move: function(event) {
    var posx = Event.pointerX(event) - this.pos.offsetx;
    var posy = Event.pointerY(event) - this.pos.offsety;
    this.moving = false;
  }
}


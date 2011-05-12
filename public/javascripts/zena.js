var Zena = {};

Zena.env = new Array();

Zena.editor_setup = function(url) {
  window.current_sel = $('text_sel');
  window.current_tab = $('text_tab');
  var preview = parent ? parent : opener;

  Event.observe(window, 'resize', function() { Zena.resizeElement('node_text'); } );
  Event.observe(window, 'resize', function() { Zena.resizeElement('node_text'); } );
  Zena.resizeElement('node_text');

  if (parent != window) {
    window.editor_window = parent.Zena.new_editor;
    window.editor_window.setTitle(document.title);
  }

  $('node_form').getElements().each(function(input, index) {
      new Form.Element.Observer(input, 3, function(element, value) {
        preview.Zena.editor_preview(url, element, value);
      });
  });
}

Zena.open_window = function(url, id, event, pos_x, pos_y) {
  if (parent != window) {
    // popup open from within popup
    return parent.Zena.open_window(url, id, event, pos_x, pos_y);
  }
                                                   // edit window, not in an iframe
  if (event && (event == true || event.shiftKey || (window == window.parent && window.current_sel))) {
    var popup = window.open(url, name, 'location=0,width=300,height=400,resizable=1');
    if (pos_x && pos_y) {
      popup.moveTo(pos_x, pos_y);
    } else {
      var x = event.screenX;
      var y = event.screenY - 50;
      popup.moveTo(x, y);
    }
    return popup;
  } else {
    if ($(id)) {
      new Effect.Shake(id, {distance:3, duration:0.3});
    } else {

      if (pos_x && pos_y) {
        var width = document.viewport.getWidth();
        var height = document.viewport.getHeight();
        if (pos_x > width - 150) {
          pos_x = width - 150;
        } else if (pos_x < 0) {
          pos_x = 0;
        }

        if (pos_y > height - 100) {
          pos_y = height - 100;
        } else if (pos_y < 0) {
          pos_y = 0;
        }
      } else {
        if (Zena.window_offset) {
          Zena.window_offset = Zena.window_offset + 15;
        } else {
          Zena.window_offset = 15;
        }
        pos_x = Zena.window_offset;
        pos_y = Zena.window_offset;
      }

      var win = new Window({
        url: url,
        id: id,
        className: 'dialog',
        title: "",
        left:pos_x,
        top:pos_y,
        width: 300,
        height:400,
        zIndex:100 + Zena.window_offset,
        showEffect: Element.show, hideEffect: Element.hide,
        destroyOnClose: true
      });

      Zena.new_editor = win;
      win.show();
      return win;
    }
  }
}

// preview content from another window.
Zena.editor_preview = function(url, element, value) {
  var key = element.name;
  var full_url = url + '?key=' + key.slice(5, key.length - 1);
  new Ajax.Request(full_url, {method:'get', asynchronous:true, evalScripts:true, parameters:{content: value }});
}

// preview version.
Zena.version_preview = function(url) {
  var target = opener ? opener : parent;

  if (target.location.href.endsWith(url)) {
    target.location.href = url.gsub(/\/versions\/.*$/,'');
  } else {
    target.location.href = url;
  }
}

// version diff.
Zena.version_diff = function(id, from, to) {
  window.location.href = '/nodes/' + id + '/versions/' + from.innerHTML + '/diff?to=' + to.innerHTML;
}

// save (does not use ajax when there is a file upload)
Zena.save = function(url, form, on_complete, show_url, event) {
  if ($(form).select('[name="attachment"]')[0]) {
    // do not use ajax call
    eval(form.getAttribute('onsubmit'));
    return true;
  } else {
    if (on_complete == 'close') {
      new Ajax.Request(url, {asynchronous:true, evalScripts:true, onLoading:function(request){$('loader').style.visibility = 'visible';}, onComplete:function(request){opener.window.location.href = opener.window.location.href; window.close();}, parameters:Form.serialize(form)});
    } else if (on_complete == 'reload') {
      new Ajax.Request(url, {asynchronous:true, evalScripts:true, onLoading:function(request){$('loader').style.visibility = 'visible';}, onComplete:function(request){opener.window.location.href = opener.window.location.href;}, parameters:Form.serialize(form)});
    } else if (on_complete == 'dettach') {
      var x = event.screenX - Event.pointerX(event);
      var y = event.screenY - Event.pointerY(event) - 50;
      var popup = parent.Zena.open_window('', null, true, x, y);
      new Ajax.Request(url, {asynchronous:true, evalScripts:true, onLoading:function(request){$('loader').style.visibility = 'visible';},
      onComplete:function(request) {
        popup.window.location.href  = show_url;
        parent.window.location.href = parent.window.location.href.gsub(/#/,'');
      },
      parameters:Form.serialize(form)});
    } else if (on_complete == 'attach') {

      var x = event.screenX - Event.pointerX(event) - opener.screenX;
      var y = event.screenY - Event.pointerY(event) - opener.screenY - 140;

      new Ajax.Request(url, {asynchronous:true, evalScripts:true, onLoading:function(request){$('loader').style.visibility = 'visible';}, onComplete:function(request){opener.Zena.open_window(show_url,null,null,x,y); window.close();}, parameters:Form.serialize(form)});
    } else {
      new Ajax.Request(url, {asynchronous:true, evalScripts:true, onLoading:function(request){$('loader').style.visibility = 'visible';}, parameters:Form.serialize(form)});
    }
    return false;
  }
}

Zena.dettach = function(save_url, url, form, event) {
  if (parent != window) {
    // in popup
    Zena.save(save_url, form, 'dettach', url, event);
  } else {
    // popup: attach
    Zena.save(save_url, form, 'attach', url, event);
  }
}

var diff_from = false;
var diff_to   = false;

Zena.diff_select = function(tag) {
  tag_number = parseInt(tag.innerHTML);
  if (tag == diff_from || tag == diff_to) {
    // reset
    if (diff_from) diff_from.style.background = 'none';
    if (diff_to  ) diff_to.style.background   = 'none';
    diff_from = false;
    diff_to   = false;
    opener.window.location.href = '/nodes/' + $('node_zip').innerHTML;
    return;
  } else if (diff_to && diff_from) {
    // update
    if (parseInt(diff_to.innerHTML) - tag_number < tag_number - parseInt(diff_from.innerHTML)) {
      diff_to.style.background = 'none';
      diff_to = tag;
    } else {
      diff_from.style.background = 'none';
      diff_from = tag;
    }
  } else if (!diff_to) {
    diff_to = tag;
  } else {
    if (tag_number > parseInt(diff_to.innerHTML)) {
      diff_from = diff_to;
      diff_to   = tag;
    } else {
      diff_from = tag;
    }
  }

  if (diff_from) diff_from.style.background = '#7A6414';
  if (diff_to)   diff_to.style.background   = '#FAD12A';
  if (diff_from && diff_to) {
    opener.Zena.version_diff($('node_zip').innerHTML, diff_from, diff_to);
  }
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
Zena.get_filename = function(source, target) {
  if ($(target).value == '') {
    var path = $(source).value;
    var elements = path.split(/[\\\/]+/g);
    $(target).value = elements[elements.length - 1];
    if ($(target).check_exists) {
      $(target).check_exists();
    }
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

Zena.update_rwp = function(inherit_val,r_index,w_index,p_index,s_index) {
  if (inherit_val == "-1") {
    $("node_rgroup_id").selectedIndex = 0;
    $("node_wgroup_id").selectedIndex = 0;
    $("node_rgroup_id").disabled = true;
    $("node_wgroup_id").disabled = true;
    $("node_skin_id" ).disabled = false;
    if (p_index != '') {
      $("node_dgroup_id").selectedIndex = 0;
      $("node_dgroup_id").disabled = true;
    }
  } else if (inherit_val == "1") {
    $("node_rgroup_id").selectedIndex = r_index;
    $("node_wgroup_id").selectedIndex = w_index;
    $("node_skin_id" ).selectedIndex     = s_index;
    $("node_rgroup_id").disabled = true;
    $("node_wgroup_id").disabled = true;
    $("node_skin_id" ).disabled = true;
    if (p_index != '') {
      $("node_dgroup_id").selectedIndex = p_index;
      $("node_dgroup_id").disabled = true;
    }
  } else {
    $("node_rgroup_id").disabled = false;
    $("node_wgroup_id").disabled = false;
    $("node_dgroup_id").disabled = false;
    $("node_skin_id" ).disabled = false;
    if (p_index != '') {
      $("node_dgroup_id").disabled = false;
    }
  }
}

/* fade flashes automatically */
Event.observe(window, 'load', function() {
  $A(document.getElementsByClassName('auto_fade')).each(function(o) {
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
    startx: 0,
    starty: 0,
    fullw : 0,
    fullh : 0
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
  MARGIN: 40,
  initialize: function(img_name, x_name, y_name, w_name, h_name, azoom, left_pos, top_pos) {
    var img      = $(img_name);
    var img_pos  = Position.positionedOffset(img);
    this.flds.x = $(x_name);
    this.flds.y = $(y_name);
    this.flds.w = $(w_name);
    this.flds.h = $(h_name);
    this.zoom  = azoom;

    this.pos.offsetx = left_pos + this.MARGIN;
    this.pos.offsety = top_pos  + this.MARGIN;
    this.pos.fullw = img.width;
    this.pos.fullh = img.height;

    this.clone = document.createElement('div');
    this.mark  = document.createElement('div');
    Element.setStyle(this.clone, {
      width:  (2 * this.MARGIN + this.pos.fullw) + 'px',
      height: (2 * this.MARGIN + this.pos.fullh) + 'px',
      background: 'grey url(' + img.src + ') no-repeat ' + this.MARGIN + 'px ' + this.MARGIN + 'px',
      position: 'absolute',
      left: this.pos.offsetx - this.MARGIN + 'px',
      top:  this.pos.offsety - this.MARGIN + 'px'
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
      left: (this.pos.x - this.BORDER_WIDTH + this.MARGIN) + 'px',
      top:  (this.pos.y - this.BORDER_WIDTH + this.MARGIN) + 'px',
      width:  this.pos.w + 'px',
      height: this.pos.h + 'px'
    });
  },
  update_position: function(event) {
    var posx = Math.max(0,Event.pointerX(event) - this.pos.offsetx);
    var posy = Math.max(0,Event.pointerY(event) - this.pos.offsety);
    if (!this.moving) {
      this.moveAll = false;
      if ((Math.abs(this.pos.x - posx) < 15.0) && (posy > this.pos.y - 15) && (posy < this.pos.y + this.pos.h + 15)) {
        // moving left corners
        this.moveX  = 'left';
        this.moving = true;
        this.pos.startx = posx - this.pos.x;
      } else if ((Math.abs(this.pos.x + this.pos.w - posx) < 15.0) && (posy > this.pos.y - 15) && (posy < this.pos.y + this.pos.h + 15)) {
        // moving right corners
        this.moveX = 'right';
        this.moving = true;
        this.pos.startx = posx - this.pos.x - this.pos.w;
      } else {
        this.moveX = false;
      }
      if ((Math.abs(this.pos.y - posy) < 15.0) && (posx > this.pos.x - 15) && (posx < this.pos.x + this.pos.h + 15)) {
        // moving top
        this.moveY = 'top';
        this.moving = true;
        this.pos.starty = posy - this.pos.y;
      } else if ((Math.abs(this.pos.y + this.pos.h - posy) < 15.0) && (posx > this.pos.x - 15) && (posx < this.pos.x + this.pos.h + 15))  {
        // moving bottom
        this.moveY = 'bottom';
        this.moving = true;
        this.pos.starty = posy - this.pos.y - this.pos.h;
      } else {
        this.moveY = false;
      }
      if (this.moving) {
        // ok
      } else if (posx >= this.pos.x && posy >= this.pos.y && posx <= (this.pos.x + this.pos.w) && posy <= (this.pos.y + this.pos.h) && !(this.pos.w == this.pos.fullw && this.pos.h == this.pos.fullh) ) {
        this.moveAll = true;
        // inside drag
        this.pos.startx = posx - this.pos.x;
        this.pos.starty = posy - this.pos.y;
      } else {
        // start new move
        this.pos.x = Math.max(0, Math.min(this.pos.fullw, posx));
        this.pos.y = Math.max(0, Math.min(this.pos.fullh, posy));
        this.pos.w = 1;
        this.pos.h = 1;
        this.moveX = 'right';
        this.moveY = 'bottom';
      }
      this.moving = true;
    }
    // remove clic offset
    posx = Math.max(0, posx - this.pos.startx);
    posy = Math.max(0, posy - this.pos.starty);

    if (this.moveAll) {
      // drag
      this.pos.x = posx;
      this.pos.y = posy;
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
    if (event.shiftKey && this.moveX && this.moveY) {
      // force square
      if (this.moveY == 'top') {
        // update top-left corner
        if (this.pos.h > this.pos.w) {
          this.pos.x = this.pos.x - this.pos.h + this.pos.w;
          this.pos.w = this.pos.h;
        } else {
          this.pos.y = this.pos.y - this.pos.w + this.pos.h;
          this.pos.h = this.pos.w;
        }
      } else {
        // update bottom-right corner
        if (this.pos.h > this.pos.w) {
          this.pos.w = this.pos.h;
        } else {
          this.pos.h = this.pos.w;
        }
      }
    }
    this.update_sizes();
    return false;
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
    this.pos.startx = 0;
    this.pos.starty = 0;
    this.moving = false;
  }
}

Zena.draggable = function(dom_id, drag_handle, revert) {
  revert = revert == undefined ? true : revert;
  if (drag_handle) {
    if ($(dom_id).select('.' + drag_handle) == []) {
      // insert span
      $(dom_id).insert({top: "<span class='" + drag_handle + "'>&nbsp;</span>"});
    }
  }
  new Draggable(dom_id, {ghosting:true, revert:revert, handle:drag_handle});
}

Zena.select_tab = function(name) {
  if (name == 'custom' && custom_loaded == false) {
    custom_loaded = true;
    load_custom_tab();
  }
  current_sel.className = '';
  current_tab.style.display = 'none';
  current_sel = $(name+'_sel');
  current_tab = $(name+'_tab');
  current_sel.className = 'selected';
  current_tab.style.display = '';
}

Zena.reloadAndClose = function() {
  if (opener && !opener.is_editor) {
    opener.window.location.href = opener.window.location.href;
    window.close();
  } else if (parent != window) {
    parent.window.location.href = parent.window.location.href;
  } else {
    window.close();
  }
}

// POPUP GALLERY
Zena.popup_gallery = null;

Zena.popup = function(elem) {
  var offsets = elem.positionedOffset();
  var e_left    = offsets[0];
  var e_top     = offsets[1];
  var e_width   = elem.clientWidth;
  var e_height  = elem.clientHeight;
  var config    = elem._popup;

  var cont = $('pg_cont');
  // FIXME copy border style from 'elem'
  var border_width = 1;

  if (!cont) {
    // open popup
    var html_img = "<img onclick='Zena.popup_close();' id='pg_img' style='position:absolute; z-index:10001; border:" + border_width + "px solid grey; top:"+e_top+"px; left:"+e_left+"px; width:"+e_width+"px;height:"+e_height+"px;' src='" + config.src + "'/>"
    Element.insert(document.body, "<div id='pg_cont' style='position:absolute; top:0; left:0;'><div id='pg_mask' onclick='Zena.popup_close();'>&nbsp;</div>" + html_img + "</div>");
    img = $('pg_img');
  } else {
    // next, previous image
    img = $('pg_img');
    img.src = config.src;
  }

  // used when closing
  img._elem_top    = e_top;
  img._elem_left   = e_left;
  img._elem_width  = e_width;
  img._elem_height = e_height;

  var view   = document.viewport.getDimensions();
  var offset = document.viewport.getScrollOffsets();
  config.left  = (view.width  -  config.width)/2 + offset[0];
  config.top   = (view.height - config.height)/2 + offset[1];
  config.klass = elem.className;

  // get next/previous elements
  if (config.navigation) {
    var gallery;
    if (false && !this.popup_gallery) {
      document.observe('keydown', function(e, el) {
        if (!$('pg_info')) {
          e.stop();
          this.popup_gallery = null;
        } else if (e.keyCode == 37) {
          if (gallery.prev) {
            Zena.popup(gallery.prev);
          } else {
            Zena.popup(gallery.list[gallery.list.size()-1]);
          }
        } else if (e.keyCode == 39) {
          if (gallery.next) {
            Zena.popup(gallery.next);
          } else {
            Zena.popup(gallery.list[0]);
          }
        } else {
          e.stop();
          this.popup_gallery = null;
          Zena.popup_close();
        }
      });
    }
    if (!this.popup_gallery || this.popup_gallery.klass != config.klass) {
      this.popup_gallery = {
        klass: config.klass,
        list: elem.up('div').select('img.' + config.klass)
      };
    }
    this.popup_gallery.current = elem;
    this.popup_gallery.index = this.popup_gallery.list.indexOf(elem);
    gallery = this.popup_gallery;
  }

  if (!config.pg_info_style) {
    config.pg_info_style = 'top:' + (config.top-10) + 'px; left:' + (config.left-10) + 'px; width:' + (config.width+20) + 'px; padding-top:' + (config.height+20) + 'px;';
    if (config.keys.size() == 0 && config.navigation) {
      config.pg_info_style += ' min-height:30px;';
    }
  }

  if ($('pg_info')) {
    Zena.popup_wrap(img, config);
    new Effect.Morph(img, {
      style: 'width:'+config.width+'px; height:'+config.height+'px; top:'+config.top+'px; left:'+config.left+'px;',
      duration: 0.2
      });
    new Effect.Morph('pg_info', {
      style: config.pg_info_style,
      duration: 0.2
      });
    $(img).appear();
  } else {
    new Effect.Morph(img, {
      style: 'width:'+config.width+'px; height:'+config.height+'px; top:'+config.top+'px; left:'+config.left+'px;',
      duration: 0.5,
      afterFinishInternal: function(effect) {
        Zena.popup_wrap(img, config);
      }
    });
  }
}

Zena.popup_wrap = function(img, config) {
  cont = $('pg_cont');
  var content = '';
  var border_width = 1;
  gallery = this.popup_gallery;

  config.keys.each(function(key, index) {
    if (key == 'navigation') {
      var index = gallery.index;
      gallery.prev  = gallery.list[index - 1];
      gallery.next  = gallery.list[index + 1];

      if (gallery.prev) content += "<a id='pg_prev' href='#' onclick='Zena.popup($(\""+gallery.prev.id+"\"));return false;' title='previous image'>&nbsp;</a>";
      if (gallery.next) content += "<a id='pg_next' href='#' onclick='Zena.popup($(\""+gallery.next.id+"\"));return false;' title='next image'>&nbsp;</a>";
    } else {
      content += "<div class='"+key+"'>" + config.fields[key] + "</div>";
    }
  });

  if ($('pg_info')) {
    if (content != '') {
      $('pg_info').update(content);
    } else {
      $('pg_info').remove();
    }
  } else if (content != '') {
    cont.insert("<div id='pg_info' class='" + config.klass + "' style='position:absolute; " + config.pg_info_style + "'>" + content + "</div>");
  }
}

Zena.popup_close = function() {
  var cont = $('pg_cont');
  if (cont) {
    var img = $('pg_img');
    var pg_info = $('pg_info');
    if (pg_info) pg_info.remove();
    new Effect.Morph(img, {
      style: 'width:'+(img._elem_width)+'px; height:'+(img._elem_height)+'px; top:'+img._elem_top+'px; left:'+img._elem_left+'px;',
      duration: 0.5,
      afterFinishInternal: function(effect) {
        cont.remove();
      }
    });
  }
}

// Lighter 'put' options for the page.
Zena.put = function(tag) {
  var f = document.createElement('form');
  f.style.display = 'none';
  tag.parentNode.appendChild(f);
  f.method = 'POST';
  f.action = tag.href;
  var m = document.createElement('input');
  m.setAttribute('type', 'hidden');
  m.setAttribute('name', '_method');
  m.setAttribute('value', 'put');
  f.appendChild(m);
  f.submit();
}

Zena.set_toggle = function(dom_id, definition) {
  var elem = $(dom_id);
  var id = dom_id.replace(/^.*_/,'') * 1;
  var list = definition['list'];

  if (!elem.select('input.cb')[0]) {
    Event.observe(elem, 'click', function(event) {
      if (event.findElement().tagName != 'A')
        Zena.toggle(elem, definition, id);
    });

    var target = elem;
    if (elem.tagName == 'TR') {
      target = elem.select('td')[0];
    }
    target.insert({top:"<input type='checkbox' class='cb'/>"});
  }

  if (list.indexOf(id) == -1) {
    // off
    elem.select('input.cb')[0].checked = false;
    elem.removeClassName('on');
    elem.addClassName('off');
  } else {
    // on
    elem.select('input.cb')[0].checked = true;
    elem.removeClassName('off');
    elem.addClassName('on');
  }
}

Zena.toggle = function(elem, definition, id) {
  if (elem.hasClassName('on')) {
    // turn off
    new Ajax.Request(definition['url'], {
      method:'put',
      asynchronous:true,
      evalScripts:true,
      parameters: 'node[' + definition['role'] + '_id]=-' + id,
      onSuccess: function() {
        definition['list'] = definition['list'].without(id);
        Zena.set_toggle(elem.id, definition);
      }
    });
  } else {
    // turn on
    new Ajax.Request(definition['url'], {
      method:'put',
      asynchronous:true,
      evalScripts:true,
      parameters: 'node[' + definition['role'] + '_id]=' + id,
      onSuccess: function() {
        definition['list'].push(id);
        Zena.set_toggle(elem.id, definition);
      }
    });
  }
}

Zena.m_toggle = function(id) {
  var txt_id = 'txt_' + id;
  $('off_'+id, 'on_'+id, txt_id).invoke('toggle');
  if ($(txt_id).style.display != 'none') {
    $$('#' + txt_id + ' iframe').each(function(s) {
      s.src = s.src;
    });
  }
}

var pm_counter = 1;
Zena.plus_minus = function(elem, start, plus, minus) {
  plus  = plus  == undefined ? '[+]' : plus;
  minus = minus == undefined ? '[-]' : minus;

  var tag = elem.tagName;
  pm_counter = pm_counter + 1;
  var id = "m_" + pm_counter;
  var show = start == 'on' ? 'display:none;' : '';
  var hide = start == 'on' ? '' : 'display:none;';
  var trigger_tag = " <a id='off_"+id+"' style='"+show+"' onclick='Zena.m_toggle(\"" + id +"\")' class='plus_btn'>"+plus+"</a><a id='on_"+id+"' style='"+hide+"' onclick='Zena.m_toggle(\"" + id +"\")' class='minus_btn'>"+minus+"</a>";
  var new_tag = "<"+tag+" style='"+hide+"' id='txt_"+id+"' class='txt'>" + elem.innerHTML + "</"+tag+">";
  if (tag.toUpperCase() == 'SPAN' || !elem.previous()) {
    Element.replace(elem, trigger_tag + ' ' + new_tag);
  } else {
    Element.insert(elem.previous(), {bottom:trigger_tag});
    Element.replace(elem, new_tag);
  }
}

Zena.read_cookie = function(name, def) {
  var nameEQ = name + "=";
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++) {
    var c = ca[i];
    while (c.charAt(0)==' ') c = c.substring(1,c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return def;
}

Zena.write_cookie = function(name,value,days) {
  if (days) {
    var date = new Date();
    date.setTime(date.getTime()+(days*24*60*60*1000));
    var expires = "; expires="+date.toGMTString();
  }
  else var expires = "";
  document.cookie = name+"="+value+expires+"; path=/";
}

Zena.delete_cookie = function(name) {
  Zena.write_cookie(name,"",-1);
}
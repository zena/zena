var Zena = {};

Zena.env = new Array();

// preview content from another window. Item_id is for security reasons: to make sure only the window showing item_id is modified.
Zena.editor_preview = function(element, value, v_id) {
  //if (item_id == Zena.env['item_id']) {
    new Ajax.Request('/z/version/preview', {asynchronous:true, evalScripts:true, parameters:'content=' + value})
  //}
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
Zena.get_name = function(path) {
  elements = path.split('/');
  return elements[elements.length - 1];
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
	var update_url = url + '&amp;day=' + day + '&amp;row=' + row;
	new Ajax.Request(update_url, {asynchronous:true, evalScripts:true, parameters:'notes'});
 	return false;
}

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
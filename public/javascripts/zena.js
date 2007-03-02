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
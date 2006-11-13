var Zena = {};

Zena.env = new Array();

// preview content from another window. Item_id is for security reasons: to make sure only the window showing item_id is modified.
Zena.editor_preview = function(element, value, item_id) {
  //if (item_id == Zena.env['item_id']) {
    new Ajax.Request('/z/version/preview', {asynchronous:true, evalScripts:true, parameters:'content=' + value})
  //}
}

// update content from another window
Zena.update = function( tag, url ) {
  new Ajax.Updater(tag, url, {asynchronous:true, evalScripts:true, onComplete:function(){ new Effect.Highlight(tag); }});
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
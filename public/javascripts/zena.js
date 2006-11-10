var zena = new Array();

// preview content from another window. Item_id is for security reasons: to make sure only the window showing item_id is modified.
function editor_preview(element, value, item_id) {
  //if (item_id == zena['item_id']) {
    new Ajax.Request('/z/version/preview', {asynchronous:true, evalScripts:true, parameters:'content=' + value})
  //}
}

// update content from another window
function update( tag, url ) {
  new Ajax.Updater(tag, url, {asynchronous:true, evalScripts:true, onComplete:function(){ new Effect.Highlight(tag); }});
  return false;
}

// transfer html from src tag to trgt tag
function transfer(src,trgt) {
  target = $(trgt);
  source = $(src);
  target.innerHTML = source.innerHTML;
  if (!target.visible()) {
	  Effect.BlindDown(trgt);
	}
}

// get the name of a file from the path
function get_name(path) {
  elements = path.split('/');
  return elements[elements.length - 1];
}
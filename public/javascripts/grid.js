Grid = {
  grids: {},
  grid_c: 0,
};

Grid.log = function(what, msg) {
  var log = $('log')
  log.innerHTML = log.innerHTML + '<br/><b>' + what + '</b> ' + msg
}

Grid.changed = function(cell, value, show) {
  if (value == show) {
    cell.innerHTML = value
  } else {
    cell.innerHTML = show
    cell.setAttribute('data-v', value)
  }
  var row = cell.up('tr')
  var table = row.up('table')
  var grid = table.grid
  if (cell.prev_value == value) return;
  if (cell.orig_value == value) {
    cell.removeClassName('changed')
    if (row.select('.changed').length == 0) {
      row.removeClassName('changed')
    }
  } else {
    cell.addClassName('changed')
    row.addClassName('changed')
  }
  var pos = Grid.pos(cell)

  var attr, id
  if (grid.attr_name) {
    attr = pos;
    id = Grid.pos(row) - 1;
  } else {
    attr = grid.attr[pos];
    id = row.id;
    if (!id) {
      // Prepare for create
      // Set a temporary id
      grid.counter++
      id = 'new_' + grid.id + '_' + grid.counter
      row.id = id
      var base = {
        id: id,
        _new: true
      }
      // Add all attributes
      var cells = row.childElements()
      for (var i = 0; i < cells.length - 1; i++) {
        var cell  = cells[i]
        var a = grid.attr[i]

        base[a] = cell.getAttribute('data-v') || cell.innerHTML
        cell.orig_value = base[a]
      }
      // Add all default attributes
      grid.defaults.each(function(pair) {
        if (base[pair.key] == undefined) {
          base[pair.key] = pair.value
        }
      })
      grid.changes.push(base)
    }
  }

  var change = {
    id: id
  };
  change[attr] = value;
  var table = row.up('table');
  grid.changes.push(change);
}

Grid.closeCell = function(event) {
    var input = event.element();
    var cell = input.up();
    var table = event.findElement('table');
    var pos = Grid.pos(cell);
    cell.removeClassName('input');
    // simple case
    var value, show
    if (input.tagName == 'INPUT') {
      value = input.value
      show  = value
    } else if (input.tagName == 'SELECT') {
      value = input.value
      show  = input.select('option[value="'+value+'"]').first().innerHTML
    }
    Grid.changed(cell, value, show);
    if (table.grid.input) {
        // single attribute table, serialize in input field
        table.grid.input.value = Grid.serialize(table);
    }
}

Grid.pos = function(elem) {
  var sibl = elem.up().childElements();
  for (var i = 0; i < sibl.length; i++) {
    if (sibl[i] === elem) return i;
  }
}

Grid.paste = function(event) {
  var input = event.element();
  var start_cell  = input.up();
  var row   = start_cell.up();
  var table = row.up('table');
  var row_offset = Grid.pos(row);
  var tbody = table.childElements()[0];
  var rows = tbody.childElements();
  var cell_offset = Grid.pos(start_cell);
  // Redirect paste inside the paste textarea
  $(document.body).insert({
    bottom: "<textarea style='position:fixed; top:0; left:10100px;' id='grid_p_" + table.grid.id + "'></textarea>"
  });
  var paster = $("grid_p_" + table.grid.id);
  paster.focus();
  setTimeout(function() {
    var text = paster.value;
    paster.remove();

    var lines = text.strip().split(/\r\n|\r|\n/);
    for (var i = 0; i < lines.length; i++) {
      lines[i] = lines[i].split(/\t/);
    }
    if (lines.length == 1 && lines[0].length == 1) {
      // simple case
      input.value = lines[0][0];
    } else {
      // copy/paste from spreadsheet
      var should_create = table.grid.input && true;
      for (var i = 0; i < lines.length; i++) {
        // foreach line
        // get row
        var row = rows[row_offset + i];
        if (!row) {
          if (!should_create) break;
          // create a new row
          Grid.add_row(table, rows[row_offset + i - 1]);
          rows = tbody.select('tr');
          row = rows[row_offset + i];
        }
        var tabs = lines[i];
        var cells = row.childElements(); cells.pop();
        for (var j = 0; j < tabs.length; j++) {
          // foreach tab
          var cell = cells[cell_offset + j];
          if (!cell) {
            if (!should_create) break;
            // create a new cell
            Grid.add_col(table, cells[cell_offset + j - 1]);
            cells = row.childElements(); cells.pop();
            cell = cells[cell_offset + j];
          }
          Grid.changed(cell, tabs[j], tabs[j]);
        }
      }
    }
    Grid.openCell(start_cell);
  }, 100);
  return true;
}

Grid.keydown = function(event) {
  var input = event.element();
  var key = event.keyCode;
  var cell = input.up();
  if (key == 39 || (key == 9 && !event.shiftKey)) {
    // tab + key right
    var next = cell.nextSiblings()[0];
    if (!next || next.hasClassName('action')) {
      // wrap around on tab
      var row = cell.up('tr').nextSiblings()[0];
      if (!row) {
        row = cell.up('tbody').childElements()[1];
      }
      next = row.childElements()[0];
    }
    Grid.openCell(next);
    event.stop();
  } else if (key == 37 || (key == 9 && event.shiftKey)) {
    // shift-tab + left key
    var prev = cell.previousSiblings()[0];
    if (!prev) {
      // wrap back around on shift+tab
      var row = cell.up('tr').previousSiblings()[0];
      if (!row || row.childElements()[0].tagName == 'TH') {
        row = cell.up('tbody').childElements().last();
      }
      prev = row.childElements().last();
      if (prev.hasClassName('action'))
        prev = prev.previousSiblings()[0];
    }
    Grid.openCell(prev);
    event.stop();
  } else if (key == 40 || key == 13) {
    // down
    if (cell.childElements().first().tagName == 'SELECT' && event.shiftKey) {
      return
    }
    var pos = Grid.pos(cell);
    // go to next row
    var crow = cell.up();
    var row = crow.nextSiblings().first();
    // find elem
    if (!row) {
      // open new row
      Grid.add_row(crow.up(), cell.up());
      row = crow.nextSiblings().first();
      var next = row.childElements()[0];
      setTimeout(function() {
        Grid.openCell(next);      
      }, 100);
    } else {
       next = row.childElements()[pos];
       Grid.openCell(next);
    }
    event.stop();
  } else if (key == 38) {
    // up
    if (cell.childElements().first().tagName == 'SELECT' && event.shiftKey) {
      return
    }
    var row = cell.up();
    if (Grid.pos(row) == 1) {
      // stop
    } else {
      var pos = Grid.pos(cell);
      // move up
      row = row.previousSiblings().first();
      var next = row.childElements()[pos];
      Grid.openCell(next);
    }
    event.stop();
  }
  return false;
}

Grid.openCell = function(cell) {
  if (cell.hasClassName('input')) return;
  var value = cell.getAttribute('data-v') || cell.innerHTML;

  if (!cell.orig_value) cell.orig_value = value;
  cell.prev_value = value;

  var w = cell.getWidth() - 5;
  var h = cell.getHeight() - 5;
  cell.addClassName('input');
  
  // Try to find a form for the cell
  var table = cell.up('table')
  var input
  if (table.grid.forms) {
    var pos = Grid.pos(cell);
    input = table.grid.forms[pos];
    if (input) {
      input = Element.clone(input, true)
      cell.update(input)
      input.value = value
    }
  }
  
  if (!input) {
    // default input field
    cell.innerHTML = "<input type='text' value=''/>";
    input = cell.select('input').first();
    input.value = value;
  }
  input.setStyle({
    width: w + 'px',
    height: h + 'px'
  });
  input.observe('blur', Grid.closeCell);
  input.observe('keydown', Grid.keydown);
  input.observe('paste', Grid.paste);
  input.focus();
  input.select();
}

Grid.click = function(event) {
  var cell = event.findElement('td, th');
  var row = event.findElement('tr');
  if (row.hasClassName('action')) {
    Grid.action(event, cell, row, true);
  } else if (cell.hasClassName('action')) {
    Grid.action(event, cell, row, false);
  } else {
    Grid.openCell(cell);
  }
}

Grid.add_row = function(table, row) {
  // insert row below
  var new_row = '<tr>';
  var cells = row.childElements();
  for (var i = 0; i < cells.length -1; i++) {
    new_row = new_row + '<td></td>';
  }
  new_row = new_row + Grid.Buttons + '</tr>';
  row.insert({
    after: new_row
  });
  var new_row = row.nextSiblings()[0];
  // TODO: rewrite history (+ push event in history for undo)
}

Grid.add_col = function(table, cell) {
  var rows = table.childElements()[0].select('tr');
  var pos = Grid.pos(cell);
  for (var i = 0; i < rows.length; i++) {
    var cells = rows[i].select('th');
    if (i == 0) {
      cells = rows[i].select('td');
      cells[pos].insert({
        after: Grid.ColButtons
      });
    } else if (cells.length > 0) {
      cells[pos].insert({
        after: "<th>[title]</th>"
      });
    } else {
      cells = rows[i].select('td');
      cells[pos].insert({
        after: "<td></td>"
      });
    }
  }
}

Grid.delCol = function(table, cell) {
  var rows = table.childElements()[0].select('tr');
  var pos = Grid.pos(cell);
  for (var i = 0; i < rows.length; i++) {
    var cells = rows[i].select('th');
    if (i == 0) {
      cells = rows[i].select('td');
      cells[pos].remove();
    } else if (cells.length > 0) {
      cells[pos].remove();
    } else {
      cells = rows[i].select('td');
      cells[pos].remove();
    }
  }
}

Grid.action = function(event, cell, row, is_col) {
  var span = event.findElement('span')
  var table = event.findElement('table')
  var grid = table.grid
  if (span.hasClassName('add')) {
    if (is_col) {
      Grid.add_col(table, cell);
    } else {
      Grid.add_row(table, row);
      Grid.openCell(new_row.childElements()[0]);
    }
  } else if (span.hasClassName('del')) {
    if (is_col) {
      Grid.delCol(table, cell);
    } else {
      // remove current row
      if (!grid.attr_name) {
        // We must also clear the changes related to the removed row
        Grid.clearChanges(grid.changes, row.id)
      }
      row.remove();
    }
  } else if (span.hasClassName('copy')) {
    var data = Grid.serialize(table, 'tab');
    var td = span.up();
    td.insert({
      top: "<textarea id='grid_copy_" + grid.id + "'></textarea>"
    });
    var input = $('grid_copy_'+grid.id);
    input.value = data;
    Element.observe($(input), 'blur', function(event) {
      event.element().remove();
    });
    input.focus();
    input.select();
  }
  if (grid.attr_name) {
    grid.input.value = Grid.serialize(table);
  }
}

// map grid position to attribute and reverse.
Grid.makeAttrPos = function(table) {
  var heads = table.childElements()[0].select('th');
  var attr = {};
  var pos = {};
  var forms = {}
  var defaults = {}
  var form_list = $(table.grid.forms_id)
  table.grid.attr = attr
  table.grid.pos = pos
  if (form_list) {
    table.grid.forms = forms;
  }
  if (table.grid.attr_name) {
    for (var i = 0; i < heads.length; i++) {
      attr[i] = i;
      pos[i] = i;
    }
  } else {
    for (var i = 0; i < heads.length; i++) {
      var attr_name = heads[i].getAttribute('data-a');
      attr[i] = attr_name;
      pos[attr_name] = i;
      if (form_list) {
        forms[i] = input = form_list.select('*[name="'+attr_name+'"]').first()
      }
    }
    // get default values
    form_list.select('input,textarea,select').each(function(e) {
      defaults[e.name] = e.value
    })
  }
  table.grid.defaults = $H(defaults)
}

// only used with single attr table
Grid.serialize = function(table, format) {
  var data = [];
  var rows = table.childElements()[0].select('tr');
  for (var i = 1; i < rows.length; i++) {
    var row_data = [];
    var cells = rows[i].childElements();
    for (var j = 0; j < cells.length - 1; j++) {
      var cell = cells[j];
      if (cell.hasClassName('input')) {
        row_data.push(cell.select('input').first().value);
      } else {
        row_data.push(cells[j].innerHTML);
      }
    }
    data.push(row_data);
  }
  if (format == 'tab') {
    var res = '';
    for (var i = 0; i < data.length; i++) {
      var row = data[i];
      var line = '';
      for (var j=0; j < row.length; j++) {
        if (j>0) line = line + '\t';
        line = line + row[j];
      }
      if (i>0) res = res + '\r\n';
      res = res + line;
    }
    return res;
  } else if (data.length == 1 && data[0].length == 1) {
    return '';
  } else {
    return Object.toJSON([{type:'table'}, data]);
  }
}

Grid.Buttons = "<td class='action'><span class='add'>&nbsp;</span> <span class='del'>&nbsp;</span></td>";
Grid.ColButtons = Grid.Buttons;

// only used with single attr table
Grid.addButtons = function(table) {
  var attr_table = table.grid.attr_name
  var data = [];
  var tbody = table.childElements()[0];
  var rows = tbody.select('tr');

  if (attr_table) {
    var col_action = "<tr class='action'><td><span class='add'>&nbsp;</span></td>";
    var cells_length = rows[0].select('th').length;
    for (var i = 1; i < cells_length; i++) {
      col_action = col_action + Grid.ColButtons;
    }
    col_action = col_action + "<td class='action'><span class='copy'>&nbsp;</span></td></tr>";
  }

  for (var i = attr_table ? 0 : 1; i < rows.length; i++) {
    var buttons;
    if (i == 0) {
      buttons = "<td class='action'><span class='add'>&nbsp;</span></td>";
    } else {
      buttons = Grid.Buttons;
    }
    rows[i].insert({
      bottom: buttons
    });
  }
  tbody.insert({
    top: col_action
  });
  return data;
}

Grid.make = function(table, opts) {
  table = $(table)
  if (table.grid) return;
  Grid.grid_c++;
  Grid.grids[Grid.grid_c] = table;
  table.grid = {
    changes: [],
    id: Grid.grid_c,
    forms_id: table.getAttribute('data-forms'),
    fdate: table.getAttribute('data-fdate'),
    counter: 0, // Used to create dom_ids for new objects
    onSuccess: opts.onSuccess,
    onStart: opts.onStart || Grid.onStart,
  };
  
  // Detect type.
  table.grid.attr_name = table.getAttribute('data-a');

  var empty = false;
  if (table.grid.attr_name && table.select('th').length == 0) {
    empty = true;
    var msg = table.getAttribute('data-msg') || "type to edit";
    table.innerHTML = "<tr><th>" + msg + "</th></tr><tr><td></td></tr>";
  }
  
  Grid.makeAttrPos(table);
  Grid.addButtons(table);

  if (table.grid.attr_name) {
    // If we have an attr_name, rows and columns are
    // serialized as json in a single field.
    table.insert({
      after: "<input type='hidden' id='grid_a_" + Grid.grid_c + "' name='" + table.grid.attr_name + "'/>"
    });
    table.grid.input = $("grid_a_" + Grid.grid_c);
    if (!empty) table.grid.input.value = Grid.serialize(table);
  } else {
    // Otherwise each row is a new object and each column
    // corresponds to a different attribute (defined in the 
    // 'th' of the table).
    table.insert({
      after: "<p class='grid_btn'><a class='save' href='javascript:' onclick='Grid.save(" + Grid.grid_c + ")'>save</a> <a class='undo' href='javascript:' onclick='Grid.undo(" + Grid.grid_c + ")'>undo</a></p>"
    });
  }


  table.observe('click', Grid.click);
}

// Default onStart handler
Grid.onStart = function(operations) {
  if (operations.post) {
    return confirm('Create '+operations.post+' nodes ?')
  }
  return true
}

Grid.clearChanges = function(list, id) {
  for (var i = list.length - 1; i >= 0; i--) {
    while (list[i] && list[i].id == id) {
      list.splice(i, 1)
    }
  }
}

Grid.save = function(grid_id) {
  // do not run on GUI thread
  setTimeout(function() {
    var table = Grid.grids[grid_id];
    var data  = $H(Grid.compact(table.grid.changes));
    var todo_count = data.keys().length
    var done_count = 0
    if (table.grid.onStart) {
      var operations = {}
      data.each(function(pair) {
        if (pair.value._new) {
          operations.post = (operations.post || 0) + 1
        } else {
          operations.put = (operations.put || 0) + 1
        }
      })
      if (!table.grid.onStart(operations)) return
    }
    data.each(function(pair) {
      var id = pair.key
      var changes = pair.value
      var attrs = {zjs:true, "opts[format]":table.grid.fdate}
      $H(changes).each(function(pair) {
        if (pair.key != '_new') {
          attrs['node['+pair.key+']'] = pair.value
        }
      })
      if (changes._new) {
        new Ajax.Request('/nodes', {
          parameters: attrs,
          onSuccess: function(transport) {
            done_count++
            var reply = transport.responseText.evalJSON()
            // Change row id: it is no longer a new item
            var old_id = id
            $(id).id = 'id_' + reply.id
            id = 'id_' + reply.id
            var attrs = {}
            attrs[id] = reply
            Grid.notify(table, attrs)
            Grid.clearChanges(table.grid.changes, old_id)
            if (table.grid.onSuccess) {
              table.grid.onSuccess(id, 'post', done_count, todo_count)
            }
          },
          method: 'post'
        });
      } else {
        new Ajax.Request('/nodes/' + id.replace('id_',''), {
          parameters: attrs,
          onSuccess: function(transport) {
            done_count++
            var attrs = {}
            attrs[id] = transport.responseText.evalJSON()
            Grid.notify(table, attrs)
            Grid.clearChanges(table.grid.changes, id)
            if (table.grid.onSuccess) {
              table.grid.onSuccess(id, 'put', done_count, todo_count)
            }
          },
          method: 'put'
        });
      }
    })
  }, 100);
}

Grid.undo = function(grid_id) {
  var table = Grid.grids[grid_id];
  var change = table.grid.changes.pop();
  // TODO: could be optimized
  var state = Grid.compact(table.grid.changes)[change.id] || {};
  for (attr in change) {
    if (attr == 'id') continue;
    var cell = $(change.id).childElements()[table.grid.pos[attr]];
    var value = state[attr] || cell.orig_value;
    cell.innerHTML = value;
    cell.prev_value = value;
    if (value == cell.orig_value) {
      cell.removeClassName('changed');
      var row = cell.up();
      if (row.select('.changed').length == 0) row.removeClassName('changed');
    } else {[cell, cell.up()].invoke('addClassName', 'changed');
    }
    cell.addClassName('undone');
  }
  new PeriodicalExecuter(function(pe) {
    table.select('.undone').invoke('removeClassName', 'undone');
    pe.stop();
  }, 1);
}

Grid.compact = function(list) {
  var res = {};
  for (var i = list.length - 1; i >= 0; i--) {
    var changes = list[i];
    var obj = res[changes.id];
    if (!obj) {
      obj = {};
      res[changes.id] = obj;
    }

    for (var key in changes) {
      if (key != 'id' && !obj[key]) {
        // only take latest change
        obj[key] = changes[key];
      }
    }
  }
  return res;
}

Grid.notify = function(table, changes) {
  var rows = table.childElements()[0].select('tr')
  var pos = table.grid.pos
  for (var obj_id in changes) {
    var row
    if (table.grid.attr_name) {
      // attr table
      row = rows[parseInt(obj_id)+1]
    } else {
      row = $(obj_id)
    }
    var cells = row.childElements()
    var change = changes[obj_id]
    for (var attr in change) {
      if (attr == 'id') continue
      var cell
      var i = pos[attr]
      if (i == undefined) continue
      cell = cells[i]
      cell.removeClassName('changed')
      if (cell.getAttribute('data-v') != change[attr]) {
        cell.innerHTML = change[attr]
      }
      cell.orig_value = change[attr]
      cell.prev_value = undefined
      cell.addClassName('saved')
    }
    if (row.select('.changed').length == 0) {

      row.removeClassName('changed')
    }
  }
  // later
  setTimeout(function() {
    table.select('.saved').invoke('removeClassName', 'saved')
  }, 1500)
}


function submitUploadForm(form, uuid) {
  if ($('progress_bar' + uuid)) return;
  var need_progress = /\w/.exec($('attachment' + uuid).value);
  // create iframe and alter form to submit to an iframe
  if (!$('UploadIFrame')) {
    $(document.body).insert('<iframe id="UploadIFrame" name="UploadIFrame" src="about:blank"></iframe>');
  }
  $(form).target = 'UploadIFrame';
  $(form).submit();
  if (need_progress) {
    UploadProgress.monitor(uuid) ;
	}
}

//
// Prototype extensions
//

PeriodicalExecuter.prototype.registerCallback = function() {
  this.intervalID = setInterval(this.onTimerEvent.bind(this), this.frequency * 1000);
}

PeriodicalExecuter.prototype.stop = function() {
  clearInterval(this.intervalID);
}

//
// Upload Progress class (for use with mongrel_upload_progress & DRb)
//

var UploadProgress = {
  uploading: false,
  period: 1.0,
  morphPeriod: 1.2,
  uuid: '',

  monitor: function(uuid) {
    this.uuid = uuid;
    this.buildProgressBar();
    this.setAsStarting();
    this.watcher = new PeriodicalExecuter(function() {
      if (!UploadProgress.uploading) { return ; }
      new Ajax.Request('/upload_progress?X-Progress-ID=' + uuid, {
        method: 'get',
        onSuccess: function(xhr){
          var upload = xhr.responseText.evalJSON();
          if(upload.state == 'uploading'){
            UploadProgress.update(upload.size, upload.received);
          } else if (upload.state == 'done') {
            UploadProgress.setAsFinished();
          } else {
            UploadProgress.message(upload.state);
          }
        }
      }) ;
    }, this.period) ;
  },


  buildProgressBar: function() {
    $('attachment' + this.uuid).insert({after:'<div class ="progress_shell" id="progress_shell' + this.uuid + '"><div class="progress_text" id="progress_text' + this.uuid + '">&nbsp;</div><div class="progress_bar" id="progress_bar' + this.uuid + '" style="width:0%;">&nbsp;</div></div>'});
    $('attachment' + this.uuid).hide();
  },

  update: function(total, current) {
    if (!this.uploading) { return ; }
		var progress = Math.floor(100 * current / total) ;
		var progressDuration = this.morphPeriod;
		if (progress > 90) progressDuration = 1.5 * progressDuration;
    new Effect.Morph('progress_bar' + this.uuid, {
      style: 'width:' + progress + '%;',
      duration: progressDuration
    });

    $('progress_text' + this.uuid).innerHTML = total.toHumanSize() + ': ' + progress + '%' ;
  },

  message: function(msg) {
    $('progress_text' + this.uuid).innerHTML = msg;
  },

  setAsStarting: function() {
    this.uploading = true ;
    this.processing = false;
	  Effect.Appear('progress_shell' + this.uuid) ;
  },

  setAsFinished: function() {
    this.uploading = false ;
    this.watcher.stop() ;
    new Effect.Morph('progress_bar' + this.uuid, {
      style: 'width: 100%;',
      duration: this.morphPeriod
    });
		$('progress_text' + this.uuid).innerHTML  = 'processing' ;
	  Effect.Fade('progress_shell' + this.uuid, { duration: 2.5 });
	}
}

//
// Number convenience methods
//

Number.prototype.bytes     = function() { return this; };
Number.prototype.kilobytes = function() { return this *  1024; };
Number.prototype.megabytes = function() { return this * (1024).kilobytes(); };
Number.prototype.gigabytes = function() { return this * (1024).megabytes(); };
Number.prototype.terabytes = function() { return this * (1024).gigabytes(); };
Number.prototype.petabytes = function() { return this * (1024).terabytes(); };
Number.prototype.exabytes =  function() { return this * (1024).petabytes(); };

['byte', 'kilobyte', 'megabyte', 'gigabyte', 'terabyte', 'petabyte', 'exabyte'].each(function(meth) {
  Number.prototype[meth] = Number.prototype[meth+'s'];
});

Number.prototype.toPrecision = function() {
  var precision = arguments[0] || 2 ;
  var s         = Math.round(this * Math.pow(10, precision)).toString();
  var pos       = s.length - precision;
  var last      = s.substr(pos, precision);
  return s.substr(0, pos) + (last.match("^0{" + precision + "}$") ? '' : '.' + last);
}

Number.prototype.toHumanSize = function() {
  if(this < (1).kilobyte())  return this + " Bytes";
  if(this < (1).megabyte())  return (this / (1).kilobyte()).toPrecision()  + ' Kb';
  if(this < (1).gigabytes()) return (this / (1).megabyte()).toPrecision()  + ' Mb';
  if(this < (1).terabytes()) return (this / (1).gigabytes()).toPrecision() + ' Gb';
  if(this < (1).petabytes()) return (this / (1).terabytes()).toPrecision() + ' Tb';
  if(this < (1).exabytes())  return (this / (1).petabytes()).toPrecision() + ' Pb';
                             return (this / (1).exabytes()).toPrecision()  + ' Eb';
}

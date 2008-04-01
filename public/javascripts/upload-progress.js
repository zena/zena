//
// NOTE: this code relies on prototype and scriptaclulous...
//

//
// make sure a file is selected before submission
//

function submitUploadForm(form, controller, uuid) {
  if (/\w/.exec($('data').value)) {
    UploadProgress.monitor(controller, uuid) ;
		$(form).submit() ;
	} else {
  	alert('You must choose a file to upload!') ;
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
	
  monitor: function(controller, uuid) {
    this.setAsStarting() ;
    this.watcher = new PeriodicalExecuter(function() {
      if (!UploadProgress.uploading) { return ; }
      new Ajax.Request('/' + controller + '/upload_progress?upload_id=' + uuid) ;
    }, 2) ;
  },

  update: function(total, current) {
    if (!this.uploading) { return ; }
    var progress = current / total ;
		var maxWidth = $('ProgressBarShell').offsetWidth ;
    var newWidth = Math.floor(progress * maxWidth) ;
		$('ProgressBar').setAttribute('width', newWidth + 'px') ;
    $('ProgressBar').style.width = newWidth + 'px' ;
    $('ProgressBarText').innerHTML = total.toHumanSize() + ': ' + progress.toPercentage() ;
  },
  
  setAsStarting: function() {
    this.uploading = true ;
    this.processing = false ;
	  $('ProgressBar').style.width = '0%' ; 
	  $('ProgressBar').className = 'Uploading' ;
		$('ProgressBarText').innerHTML  = '...' ;
	  Effect.Appear('ProgressBarShell') ;
  },
  
  setAsProcessing: function() {
    this.uploading = false ;
    this.watcher.stop() ;
    $('ProgressBar').style.width = 'auto' ;
    $('ProgressBar').className   = 'Processing' ;
		$('ProgressBarText').innerHTML  = '100%' ;
  },

  setAsFinished: function() {
    this.uploading = false ;
    this.watcher.stop() ;
    $('ProgressBar').style.width = 'auto' ;
    $('ProgressBar').className   = 'Finished' ;
		$('ProgressBarText').innerHTML  = '100%' ;
	  Effect.Fade('ProgressBarShell', { duration: 1.5 });
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

Number.prototype.toPercentage = function() {
  return Math.floor(this * 100) + '%';
}

Number.prototype.toHumanSize = function() {
  if(this < (1).kilobyte())  return this + " Bytes";
  if(this < (1).megabyte())  return (this / (1).kilobyte()).toPrecision()  + ' KB';
  if(this < (1).gigabytes()) return (this / (1).megabyte()).toPrecision()  + ' MB';
  if(this < (1).terabytes()) return (this / (1).gigabytes()).toPrecision() + ' GB';
  if(this < (1).petabytes()) return (this / (1).terabytes()).toPrecision() + ' TB';
  if(this < (1).exabytes())  return (this / (1).petabytes()).toPrecision() + ' PB';
                             return (this / (1).exabytes()).toPrecision()  + ' EB';
}

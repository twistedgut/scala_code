/*
 * Wrapper for jQuery Dialog with xTracker hacks
 * @author: Peter Richmond
 */
function xui_dialog(id, options) {

    var oldopenfunc = options.open;

    // HACK: This forces the overlay to have the correct z-index in IE8
    options.open = function() {
        $('.ui-widget-overlay').prependTo($('#content')).css({
            position: 'fixed',
            top: 0,
            right: 0
        });

        if (typeof(oldopenfunc) !== 'undefined') {
            oldopenfunc();
        }
    }

    var popup = $(id).dialog(options);

    // HACK: XTracker's CSS requires us to do this
    $('.ui-dialog').prependTo($('#content'));

    this.open = function() {
        popup.dialog('open');
        return this;
    };

    this.close = function() {
        popup.dialog('close');
        return this;
    };

    return true;
}

/*
 * Simple progres dialog box
 * @author Peter Richmond
 */
function xui_progress_dialog(options) {

    var self = this;
    var xlog = new xui_logger();

    var ticker_length = (options.progressLength ? options.progressLength : 100);
    var ticker_step   = (options.progressStep ? options.progressStep : 1);
    var ticker_pos    = 0;

    var ticker_percentage = function() {
        return ((100/ticker_length) * ticker_pos)
    }


    xlog.debug('Constructing xui_progress_dialog');

    var dialog_msg    = $('<div>').attr('id', 'progress_popup_dialog_msg');
    var pbar          = $('<div>').attr('id', 'progressbar');

    var cancel_button = $('<button>').attr('id', 'progressDialogCancelButton')
                        .css('float', 'right')
                        .addClass('button')
                        .html('Cancel');

    var dialog_div = $('<div>')
                     .hide()
                     .attr('id', 'progressDialog')
                     .append(dialog_msg).append($('<br>'))
                     .append(pbar).append($('<br>'))
                     .append(cancel_button).append($('<br>'))
                     .appendTo($('#content'));

    var progressDialog = new xui_dialog('#progressDialog', {
        autoOpen : false,
        height   : 110,
        width    : 350,
        draggable: false,
        resizable: false,
        closeOnEscape: false,
        modal    : true
    });

    // Methods

    self.reset = function reset() {
        pbar.progressbar({value:0});
        return self;
    }

    self.nextTick = function next() {
        ticker_pos  = (ticker_pos + ticker_step);
        pbar.progressbar('option', {value:ticker_percentage()});
        return self;
    }

    self.prevTick = function prev() {
        ticker_pos  = (ticker_pos - ticker_step);
        pbar.progressbar('option', {value:ticker_percentage()});
        return self;
    }

    self.getProgress = function getProgress() {
        return ticker_pos;
    }

    self.open = function open() {
        xlog.debug('xui_progress_dialog: open');
        $('#progressDialog').parent().find('.ui-dialog-titlebar').remove();
        progressDialog.open();
        return self;
    }

    self.close = function close() {
        progressDialog.close();
        return self;
    }

    self.setDialogMessage = function setDialogMessage(message) {
        $('#progress_popup_dialog_msg').html(message);
    }

    self.showCancelButton = function(enable) {
        if (enable) {
            cancel_button.show();
        }
        else {
            cancel_button.hide();
        }
    }

    // Events

    $(cancel_button).click(function() {
        $(self).trigger('cancel');
    });

    // Reset to default values

    self.reset();
}

function xui_wait_dialog() {

    var self = this;
    var xlog = new xui_logger();

    xlog.debug('Constructing xui_wait_dialog');

    // Build dialog box

    var dialog_msg = $('<div>').attr('id', 'wait_popup_dialog_msg').css('text-align', 'center');
    var spinner    = $('<img>').attr('src', '/images/bigrotation2.gif').css('margin-left', 'auto').css('margin-right', 'auto');

    var dialog_div = $('<div>')
                     .hide()
                     .attr('id', 'waitDialog')
                     .append($('<br>'))
                     .append(spinner).append($('<br>'))
                     .append(dialog_msg).append($('<br>'))
                     .appendTo($('#content'));

    var waitDialog = new xui_dialog('#waitDialog', {
        autoOpen : false,
        height   : 110,
        width    : 350,
        draggable: false,
        resizable: false,
        closeOnEscape: false,
        modal    : true
    });

    self.open = function open() {
        xlog.debug('xui_progress_dialog: open');
        $('#waitDialog').parent().find('.ui-dialog-titlebar').remove();
        waitDialog.open();
        return self;
    }

    self.close = function close() {
        waitDialog.close();
        return self;
    }

    self.setDialogMessage = function setDialogMessage(message) {
        $('#wait_popup_dialog_msg').html(message);
    }

}

/*
 * JavaScript Logger for xTracker
 * @author: Peter Richmond
 */
function xui_logger(log_level) {

    var level = log_level;

    this.debug = function(msg) {
        if (level == 'debug' || level == 'warn') {
            try {
                console.log(msg);
            }
            catch (e) {
                // IE8 has no console
            }
        }
    }

    this.warn = function(msg) {
        if (level == 'warn') {
            try {
                console.log(msg);
            }
            catch (e) {
                // IE8 has no console
            }
        }
    }
}


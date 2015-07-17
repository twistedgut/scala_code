/*
    This is a combination for Darius' work on integrating the
    YUI calendar into XT and my work on Editable.js (making useful objects)

    Chisel Wright
*/

/*
    Example usage:

    <input type="text" name="promotion_start" id="promotion_start" size="12" value="2007-12-25" class="show-cal-icon">
    <div id="calendar_start_date"  class="nap_calendar"></div>

    <script type="text/javascript" src="/path/to/NapCalendar.js"></script>
    <script type="text/javascript">
        var start_cal = new YAHOO.widget.NapCalendar;
        start_cal.config.calDivId  = 'calendar_start_date';
        start_cal.config.textField = 'promotion_start';
        start_cal.init();
    </script>
*/

(function () {
    YAHOO.widget.NapCalendar = function() {
        // object variables
        var calObject, over_cal;

        // object configuration
        this.config = {
            textField:          'target_date',
            calDivId:           'priorityCalContainer',
            calObjectID:        YAHOO.util.Dom.generateId()
        };

        this.init = function() {
            // straight copy and paste!
            try {
                YAHOO.namespace('product.priority');
                this.calObject = new YAHOO.widget.Calendar(this.config.calObjectID,this.config.calDivId);
                this.calObject.selectEvent.subscribe(this.selectEvent, this, true);
                this.calObject.renderEvent.subscribe(this.setupListeners, this, true);
                YAHOO.util.Event.addListener(this.config.textField, 'focus', this.showCal, this);
                YAHOO.util.Event.addListener(this.config.textField, 'blur', this.hideCal, this);
                this.calObject.render();
                this.calObject.hide();
            } catch(e) { alert('** ERROR: ' + e.message); };
        };

        this.selectEvent = function(ev,selected_date) {
            try {
                this.calObject.hide();
                var target_field = YAHOO.util.Dom.get(this.config.textField);
                var calDate = this.calObject.getSelectedDates()[0];
                target_field.value =
                      calDate.getFullYear()
                    + '-'
                    + this.zeroPad(calDate.getMonth() + 1, 2)
                    + '-'
                    + this.zeroPad(calDate.getDate(), 2)
                ;
            } catch(e) { alert('** ERROR: ' + e.message); };
        };

        this.setupListeners = function(ev) {
            try {
                YAHOO.util.Event.addListener(
                    this.config.calDivId,
                    'mouseover',
                    this.overCal,
                    this
                );
                YAHOO.util.Event.addListener(
                    this.config.calDivId,
                    'mouseout', 
                    this.outCal,
                    this
                );
            } catch(e) { alert('** ERROR: ' + e.message); };
        };

        this.overCal = function(ev,o) {
            try {
                o.over_cal = true;
            } catch(e) { alert('** ERROR: ' + e.message); };
        };
        this.outCal = function(ev,o) {
            try {
                o.over_cal = false;
            } catch(e) { alert('** ERROR: ' + e.message); };
        };

        this.setCalDate = function() {
            try {
                var target_field = YAHOO.util.Dom.get(this.config.textField);
                var dateValue    = YAHOO.util.Dom.get(target_field).value;

                if (dateValue) {
                    // initialise a date object
                    var date_bits = dateValue.split('-');
                    var dateObject = new Date();
                    dateObject.setFullYear(date_bits[0], (date_bits[1]-1), date_bits[2]) ;                    
                    // to keep the YUI/JS date functions happy - MDY format, ick!
                    var crappyFormatDateString =
                        (dateObject.getMonth() + 1)
                        + '/'
                        + dateObject.getDate()
                        + '/'
                        + dateObject.getFullYear()
                    ;
                    // set up the calendar
                    this.calObject.cfg.queueProperty("pagedate", dateObject,             false);
                    // I have no idea why we can't pass a dateObject to this if we
                    // just want one day highlighted
                    // (http://developer.yahoo.com/yui/calendar/)
                    this.calObject.cfg.queueProperty("selected", crappyFormatDateString, false);
                    this.calObject.cfg.fireQueue();
                }
                // otherwise default to using Today/Now
                else {
                    this.calObject.cfg.setProperty('selected', '');
                    this.calObject.cfg.setProperty('pagedate', new Date(), true);
                }

                // we need to re-render the calendar
                this.calObject.render();
                    
            } catch(e) { alert('** ERROR: ' + e.message); return; };
        };

        this.showCal = function(ev,o) {
            try {
                // set the selected date for the calendar
                o.setCalDate();
                // show the calendar
                o.calObject.show();
                // set the calendar location
                var target = YAHOO.util.Dom.get(o.config.textField);
                var xy = YAHOO.util.Dom.getXY(target);
                xy[1] = xy[1] + 20;
                YAHOO.util.Dom.setXY(o.config.calDivId, xy);
            } catch(e) { alert('** ERROR: ' + e.message); };
        };

        this.hideCal = function(ev,o) {
            try {
                if (! o.over_cal) {
                    o.calObject.hide();
                }
            } catch(e) { alert('** ERROR: ' + e.message); };
            return true;
        };

        this.zeroPad = function(num, width) {
            num = num.toString();
            while (num.length < width)
            num = "0" + num;
            return num;
        }
    };
})();

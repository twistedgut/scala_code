function EditRuleDialog() {

    var self = this;
    var xlog = new xui_logger();
    var current_rule;
    var edit_window;

    var previous = new Object();   // used to track previous values for conditions

    $(document).ready(function() {
        edit_window = new xui_dialog('#fraudscreen__edit_rule_window', {
            height: 500,
            width: 950,
            resizable: true,
            modal: true,
            autoOpen: false
        });

        $('#fraudscreen__edit_rule_add_button').click(function() {
            if (validateFormFields()) {

                var new_rule            = readFormFields();
                    new_rule.id         = '';
                    new_rule.idx        = '';
                    new_rule.sequence   = '';
                    new_rule.rule_number  = 'NEW';
                    new_rule.status     = rulestatus['New'];
                    new_rule.deleted    = false;

                xlog.debug('Triggering EditRuleDialog::Add event');
                $(self).trigger('new', new_rule);
            }
        });


        $('#fraudscreen__edit_rule_update_button').click(function() {
            if (validateFormFields()) {

                var new_rule            = readFormFields();
                    new_rule.id         = current_rule.id;
                    new_rule.idx        = current_rule.idx;
                    new_rule.sequence   = current_rule.sequence;
                    new_rule.rule_number = current_rule.rule_number;
                    new_rule.status     = rulestatus['Changed'];
                    new_rule.deleted    = false;

                //clean-up persistent unsaved tags
                $('#fraudscreen__edit_rule_tags').find('.tagit-new input').val('').end().find('.tagit-label');

                xlog.debug('Triggering EditRuleDialog::Update event');
                $(self).trigger('update', new_rule);
           }
        });

        $('#fraudscreen__edit_rule_saveasnew_button').click(function() {
            if (validateFormFields({nameChanged:true})) {

                var new_rule            = readFormFields();
                    new_rule.id         = '';
                    new_rule.idx        = '';
                    new_rule.sequence   = '';
                    new_rule.rule_number = 'NEW';
                    new_rule.status     = rulestatus['New'];
                    new_rule.deleted    = false;

                $.each(new_rule.conditions, function(idx, val) {
                    new_rule.conditions[idx].id = '';
                });

                xlog.debug('Triggering EditRuleDialog::SaveAsNew event');
                $(self).trigger('saveAsNew', new_rule);
            }
        });

        $('#fraudscreen__edit_rule_delete_button').click(function() {
            if (confirm('Are you sure you want to delete this rule?')) {

                var new_rule            = readFormFields();
                    new_rule.id         = current_rule.id;
                    new_rule.idx        = current_rule.idx;
                    new_rule.sequence   = current_rule.sequence;
                    new_rule.status     = '';
                    new_rule.deleted    = true;

                xlog.debug('Triggering EditRuleDialog::Delete event');
                $(self).trigger('delete', new_rule);
            }
            else {
                // TODO dunno?
            }
        });

        $('#fraudscreen__edit_rule_cancel_button').click(function() {
            xlog.debug('Triggering EditRuleDialog::Cancel event');
            $('#fraudscreen__edit_rule_tags').tagit("removeAll");

            //clean-up persistent unsaved tags
            $('#fraudscreen__edit_rule_tags').find('.tagit-new input').val('').end().find('.tagit-label');
            $(self).trigger('cancel');
        });

        $('#fraudscreen__edit_rule_add_condition_button').click(function() {
            addBlankCondition();
        });

        $("#fraudscreen__edit_window").on('close', function() {
            self.close();
        });

        $("#fraudscreen__edit_rule_start_date").datepicker({
            defaultDate: "+1w",
            changeMonth: true,
            numberOfMonths: 1,
            dateFormat: 'yy-mm-dd',
            onClose: function( selectedDate ) {
                $("#fraudscreen__edit_rule_end_date")
                    .datepicker("option", "minDate", selectedDate)
                    .datepicker('option', 'dateFormat', 'yy-mm-dd');
            }
        });
        $("#fraudscreen__edit_rule_end_date").datepicker({
            defaultDate: "+1w",
            changeMonth: true,
            numberOfMonths: 1,
            dateFormat: 'yy-mm-dd',
            onClose: function( selectedDate ) {
                $("#fraudscreen__edit_rule_start_date")
                    .datepicker("option", "maxDate", selectedDate)
                    .datepicker('option', 'dateFormat', 'yy-mm-dd');
            }
        });
    });

    /*
     * open(rule)
     */
    this.open = function(rule, ruleset) {

        current_rule = rule;

        if (typeof rule === 'undefined') {
            xlog.debug('Opening popup for new rule');

            $('#fraudscreen__edit_rule_id').val('');
            $('#fraudscreen__edit_rule_idx').val('');
            $('#fraudscreen__edit_rule_sequence').val('');

            $('#fraudscreen__edit_rule_enabled').prop('checked', false);
            $('#fraudscreen__edit_rule_enabled').prop('disabled', true);

            $('#fraudscreen__edit_rule_name').val('');
            $('#fraudscreen__edit_rule_channel').val('');
            //remove tags
            $('#fraudscreen__edit_rule_tags').tagit("removeAll").tagit({
                availableTags: existing_tags,
                autocomplete: {delay: 0, minLength: 0, autoFocus: true}
            }).tagit('option', 'preprocessTag',function(val){
                if (!val) { return ''; }
                return val.toUpperCase();
            });

            $('#fraudscreen__edit_rule_start_date').val('');
            $('#fraudscreen__edit_rule_start_hour').val('');
            $('#fraudscreen__edit_rule_start_minute').val('');

            $('#fraudscreen__edit_rule_end_date').val('');
            $('#fraudscreen__edit_rule_end_hour').val('');
            $('#fraudscreen__edit_rule_end_minute').val('');

            $('#fraudscreen__edit_rule_action').val('');

            $('.fraudscreen__edit_condition_row').remove();

            $('#fraudscreen__edit_rule_add_button').show();
            $('#fraudscreen__edit_rule_update_button').hide();
            $('#fraudscreen__edit_rule_saveasnew_button').hide();
            $('#fraudscreen__edit_rule_delete_button').hide();

            $('#fraudscreen__edit_rule_error_msg').html('');
        }
        else {
            xlog.debug('Opening popup for existing rule');

            $('#fraudscreen__edit_rule_id').val(rule.id);
            $('#fraudscreen__edit_rule_idx').val(rule.idx);
            $('#fraudscreen__edit_rule_sequence').val(rule.sequence);

            $('#fraudscreen__edit_rule_name').val(rule.name);
            $('#fraudscreen__edit_rule_channel').val(rule.channel.id);

            // Tags
            $('.fraudscreen_ruletags').remove();

            $('#fraudscreen__edit_rule_tags').tagit("removeAll");
            $('#fraudscreen__edit_rule_tags').tagit( {
                availableTags: existing_tags,
                autocomplete: {delay: 0, minLength: 0, autoFocus: true}
            });
            $.each(rule.tags, function(idx,tag) {
                $('#fraudscreen__edit_rule_tags').tagit("createTag",tag).tagit(
                    'option','preprocessTag',function(val){
                        if (!val) { return ''; }
                        return val.toUpperCase();
                });
            });

            $('#fraudscreen__edit_rule_start_date').val(rule.start.date);
            $('#fraudscreen__edit_rule_start_hour').val(rule.start.hour);
            $('#fraudscreen__edit_rule_start_minute').val(rule.start.minute);

            $('#fraudscreen__edit_rule_end_date').val(rule.end.date);
            $('#fraudscreen__edit_rule_end_hour').val(rule.end.hour);
            $('#fraudscreen__edit_rule_end_minute').val(rule.end.minute);

            $('#fraudscreen__edit_rule_action').val(rule.action.id);

            $('.fraudscreen__edit_condition_row').remove();

            $.each(rule.conditions, function(idx) {
                loadCondition(rule.conditions[idx]);
            });

            checkRuleEnable();
            $('#fraudscreen__edit_rule_enabled').prop('checked', rule.enabled);

            $('#fraudscreen__edit_rule_add_button').hide();
            $('#fraudscreen__edit_rule_saveasnew_button').show();
            $('#fraudscreen__edit_rule_update_button').show();
            $('#fraudscreen__edit_rule_delete_button').show();

            if (rule.error_msg) {
                $('#fraudscreen__edit_rule_error_msg').html(rule.error_msg.join('; '));
            }
        }

        edit_window.open();
    }

    this.close = function close_popup_window() {
        edit_window.close();
    }

    /*
     * addBlankCondition()
     */
    function addBlankCondition() {

        xlog.debug('Adding condition to rule');

        var new_condition_row = $('#fraudscreen__blank_condition_row').clone();
            new_condition_row.removeAttr('id')
                             .addClass('fraudscreen__edit_condition_row')
                             .insertBefore('#fraudscreen__edit_rule_add_condition');

        var vcell   = new_condition_row.find('.fraudscreen__edit_condition_value_cell');
        var olist   = new_condition_row.find('.fraudscreen__edit_condition_operator_list');
        var cenable = new_condition_row.find('.fraudscreen__edit_condition_enabled');
            cenable.prop('checked', true);

        // Clear the 'previous' object so we can be sure it only contains data for THIS rule

        previous = {};

        // Delete Icon
        new_condition_row.find('.fraudscreen__edit_rule_remove_condition_button').click(function() {
            xlog.debug('Removing condition to rule');
            new_condition_row.hide();
            cenable.prop('checked', false);
            checkRuleEnable();
        })

        // Enable Checkbox
        cenable.change(function() {
            checkRuleEnable();
        })

        // Method Change
        new_condition_row.find('.fraudscreen__edit_condition_method_list').change(function() {

            if ($(this).val() == '') {
                olist.hide();
                olist.html('');
                new_condition_row.find('.fraudscreen__edit_condition_value').hide();
                cenable.prop('checked', false).hide();
            }
            else {
                var method  = methods['method_'+$(this).val()];
                var op_list = operators[method.valueType];

                olist.show();
                olist.html('');
                $.each(op_list, function(index, value) {
                    olist.append(
                        $('<option>')
                            .val(value.id)
                            .html(value.value)
                            .addClass('fraudscreen__edit_condition_operator')
                            .attr('is_list', value.list)
                    );
                });

                if (method.valueType == 'boolean') {
                    vcell.html(
                        $('<select>')
                            .append($('<option>').attr('value', "1").html("True"))
                            .append($('<option>').attr('value', "0").html("False"))
                            .attr('class', 'fraudscreen__edit_condition_value')
                    );
                }
                else if (method.returnValues.length > 0) {
                    var selecttag = $('<select>').addClass('fraudscreen__edit_condition_value');
                    $(method.returnValues).each(function(idx) {
                        selecttag.append($('<option>')
                                 .attr('value', method.returnValues[idx].id)
                                 .html(method.returnValues[idx].description))
                    });
                    vcell.html(selecttag);
                }
                else {
                    vcell.html(
                        $('<input>').addClass('fraudscreen__edit_condition_value')
                                    .attr('type', 'text')
                    );
                }

                cenable.prop('checked', true).show();

                new_condition_row.find('.fraudscreen__edit_condition_value').show();
            }

            checkRuleEnable();
        });

        // Operator Change

        // Copy existing condition and value data if condition is selected
        new_condition_row.find('.fraudscreen__edit_condition_operator_list').focus( function() {
            // Record whether the current operator is a list operator
            var list_operator = $('option:selected', this).attr('is_list');
            previous['list_operator'] = list_operator;

            // record the current condition value
            if ( list_operator == 1 ) {
                previous['list_value'] = new_condition_row.find('.fraudscreen__edit_condition_value').val();
            }
            else {
                previous['non_list_value'] = new_condition_row.find('.fraudscreen__edit_condition_value').val();
            }
        } );

        new_condition_row.find('.fraudscreen__edit_condition_operator_list').change(function() {
            var method = methods['method_'+new_condition_row.find('.fraudscreen__edit_condition_method_list').val()];
            var valuetag = $('<select>').addClass('fraudscreen__edit_condition_value');
            var buttontag;

            if ( $('option:selected', this).attr('is_list') == 1 ) {
                $(method.listValues).each(function(idx) {
                    valuetag.append($('<option>')
                        .attr('value', method.listValues[idx].id)
                        .html(method.listValues[idx].name)
                    );
                });
                buttontag = $('<button>')
                    .html('..')
                    .addClass('fraudscreen__edit_condition_list_popup')
                    .attr('title','Show the contents of the selected list')
                    .click( function() {
                        var selected = $('option:selected', valuetag );
                        list_item_popup( selected.val(), selected.text() );
                    } );

                    // if there is no list then disable selecting
                    if( method.listValues.length == 0 ) {
                        valuetag.append($('<option>')
                            .attr('value', '')
                            .html('No list')
                        );
                        valuetag.prop('disabled', true);
                        buttontag.prop('disabled', true);

                    }

            }
            else {
                if (method.valueType == 'boolean') {
                    valuetag.append($('<option>').attr('value', "1").html("True"))
                             .append($('<option>').attr('value', "0").html("False"))
                             .attr('class', 'fraudscreen__edit_condition_value');
                }
                else if (method.returnValues.length > 0) {
                    $(method.returnValues).each(function(idx) {
                        valuetag.append($('<option>')
                            .attr('value', method.returnValues[idx].id)
                            .html(method.returnValues[idx].description)
                        )
                    });
                } else {
                    valuetag = $('<input>').addClass('fraudscreen__edit_condition_value')
                                    .attr('type', 'text');
                }
            }

            // Assign previous value
            var list_operator = $('option:selected', this).attr('is_list');
            if ( list_operator == 1 ) {
                valuetag.val(previous['list_value']).attr('selected', 'selected');
            }
            else {
                if ( valuetag.attr('type') == 'select' ) {
                    valuetag.val(previous['non_list_value']).attr('selected', 'selected');
                }
                else {
                    valuetag.val(previous['non_list_value']);
                }
            }

            vcell.html('')
                .append(valuetag)
                .append(buttontag);
            new_condition_row.find('.fraudscreen__edit_condition_value').show();
        });

        return new_condition_row;
    }

    /*
     * loadCondition(condition)
     */
    function loadCondition(condition) {

        var new_condition_row = addBlankCondition();

        new_condition_row.find('.fraudscreen__edit_condition_id')
                         .val(condition.id);

        new_condition_row.find('.fraudscreen__edit_condition_method_list')
                         .val(condition.method.id)
                         .trigger('change');

        new_condition_row.find('.fraudscreen__edit_condition_operator_list')
                         .val(condition.operator.id)
                         .trigger('change');

        new_condition_row.find('.fraudscreen__edit_condition_value')
                         .val(condition.value.id);

        new_condition_row.find('.fraudscreen__edit_condition_enabled')
                         .prop('checked', condition.enabled);

        if (condition.error_msg) {
            new_condition_row.find('.fraudscreen__edit_condition_error_msg')
                             .html(condition.error_msg.join('; '))
        }

        if (condition.deleted) {
            new_condition_row.hide();
        }
    }

    /*
     * checkRuleEnable()
     */
    function checkRuleEnable() {
        if ($('#fraudscreen__conditions_table').find('.fraudscreen__edit_condition_enabled:checked').length == 0) {
            $('#fraudscreen__edit_rule_enabled').prop('checked', false);
            $('#fraudscreen__edit_rule_enabled').prop('disabled', true);
        }
        else {
            $('#fraudscreen__edit_rule_enabled').prop('disabled', false);
        }
    }

    /*
     * validateFormFields()
     */
    function validateFormFields(options) {

        xlog.debug('Validating values');

        var confirmed          = true;
        var missing_data_alert = false;

        var options             = options || {};
            options.nameChanged = options.nameChanged || false;

        if ($('#fraudscreen__edit_rule_name').val() == '') {
            alert('Rule has no name. Unable to continue');
            return false;
        }

        // TODO check for name duplicates
        if (options.nameChanged && ($('#fraudscreen__edit_rule_name').val() == current_rule.name)) {
            alert('You must chose a different rule name');
            return false;
        }

        var conditionCount = $('.fraudscreen__edit_condition_row').length;

        if (conditionCount == 0) {
            if (!confirm('There are no conditions added. Are you sure you want to continue?')) {
                return false;
            }
        }

        if ((conditionCount > 0) && ($('.fraudscreen__edit_condition_enabled:checked').length == 0)) {
            if (!confirm('There are no conditions enabled. Are you sure you want to continue?')) {
                return false;
            }
        }

        $('.fraudscreen__edit_condition_row').each(function() {
            var condition = $(this);

            if (condition.find('.fraudscreen__edit_condition_method_list').val() == '') {
                return true; // skip to next condition
            }

            if (condition.find('.fraudscreen__edit_condition_value').val() == '') {
                missing_data_alert = true;
            }
        });

        if (missing_data_alert) {
            alert('Missing data in condition. Unable to continue');
            return false;
        }

        return true;
    }

    /*
     * readFormFields()
     */
    function readFormFields(reset_condition_id) {
        xlog.debug('Extracting values from popup');

        //update existing_tags
        var temp;
        $.each($('#fraudscreen__edit_rule_tags').tagit("assignedTags"), function (idx,val ) {
            if($.inArray(val,existing_tags) == -1 ) {
                existing_tags.push(val);
            }
        });

        var new_rule = {
            name : $('#fraudscreen__edit_rule_name').val(),
            channel  : {
                id : $('#fraudscreen__edit_rule_channel').val(),
                description : $('#fraudscreen__edit_rule_channel :selected').text()
            },
            start : {
                date   : $('#fraudscreen__edit_rule_start_date').val(),
                hour   : $('#fraudscreen__edit_rule_start_hour').val(),
                minute : $('#fraudscreen__edit_rule_start_minute').val()
            },
            end : {
                date   : $('#fraudscreen__edit_rule_end_date').val(),
                hour   : $('#fraudscreen__edit_rule_end_hour').val(),
                minute : $('#fraudscreen__edit_rule_end_minute').val()
            },
            action : {
                id : $('#fraudscreen__edit_rule_action').val(),
                description : $('#fraudscreen__edit_rule_action :selected').text()
            },
            enabled    : $('#fraudscreen__edit_rule_enabled').prop('checked'),
            conditions : [],
            //tags - returns an array of text values of all the tags
            tags    : $("#fraudscreen__edit_rule_tags").tagit("assignedTags")
        }

        $('.fraudscreen__edit_condition_row').each(function() {
            var condition = $(this);

            if (condition.find('.fraudscreen__edit_condition_method_list').val() == '') {
                return true;
            }

            if (condition.find('.fraudscreen__edit_condition_value').val() == '') {
                missing_data_alert = true;
            }

            new_rule.conditions.push({
                id : condition.find('.fraudscreen__edit_condition_id').val(),
                method : {
                    id : condition.find('.fraudscreen__edit_condition_method_list').val(),
                    description : condition.find('.fraudscreen__edit_condition_method_list :selected').text()
                },
                operator : {
                    id : condition.find('.fraudscreen__edit_condition_operator_list').val(),
                    description : condition.find('.fraudscreen__edit_condition_operator_list :selected').text(),
                    list_operator : condition.find('.fraudscreen__edit_condition_operator_list :selected').attr('is_list')
                },
                value : {
                    id : condition.find('.fraudscreen__edit_condition_value').val(),
                    description: (
                        condition.find('.fraudscreen__edit_condition_value :selected').text() ||
                        condition.find('.fraudscreen__edit_condition_value').text() ||
                        condition.find('.fraudscreen__edit_condition_value').val())
                },
                enabled : condition.find('.fraudscreen__edit_condition_enabled').prop('checked'),
                deleted : !condition.is(':visible')
            });
        });

        return new_rule;
    }
}

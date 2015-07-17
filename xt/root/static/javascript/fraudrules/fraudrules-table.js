function RulesTable(rules) {

    var self              = this;
    var existing_rules    = rules;
    var ruleset           = [];
    var next_sequence_idx = 0;
    var xlog              = new xui_logger();

    $(document).ready(function() {
        self.resetRules();
        $('#fraudscreen__table_filter_tags')
            .bind( "keydown", function( event ) {
                if ( event.keyCode === $.ui.keyCode.TAB &&
                    $( this ).data( "ui-autocomplete" ).menu.active ) {
                    event.preventDefault();
                }
            })
            .bind( "keyup", function(){
                this.value = this.value.toUpperCase();
            })
            .autocomplete({
                minLength: 0,
                source: function( request, response ) {
                    // delegate back to autocomplete, but extract the last term
                     response( $.ui.autocomplete.filter(
                     existing_tags, extractLast( request.term ) ) );
                 },
                 focus: function() {
                     // prevent value inserted on focus
                      return false;
                  },
                  select: function( event, ui ){
                    var terms = splitBySpaces( this.value );
                    // remove the current input
                    terms.pop();
                    // add the selected item
                    terms.push( ui.item.value );
                    // add placeholder to get the comma-and-space at the end
                    terms.push( "" );
                    this.value = terms.join( ", " );
                    return false;
                }
            });



        $('#fraudscreen__table_filter_select').change(function() {
            var ch = $(this).val();

            var value = $('#fraudscreen__table_filter_tags').val();
            value = value.replace(/\s+/g,'');

            filterResults(ch,value);
        });

        $('#fraudscreen__table_filter_tags').keypress(function(event){
            var keycode = (event.keyCode ? event.keyCode : event.which);
                if(keycode == '13'){
                    var value = $('#fraudscreen__table_filter_tags').val();
                    value = value.replace(/\s+/g,'');

                    // channel
                    var ch = $('#fraudscreen__table_filter_select').val();
                    filterResults(ch,value);
                }
                event.stopPropagation();
        });
    });



    this.resetRules = function() {

        if (typeof rules !== 'undefined') {

            $('.fraudscreen__rule_row').remove();

            if (rules.length > 0) {
                var info = addSingleTableRow('#dontcare', 'Loading rules...');
                $.each(existing_rules, function(idx) {
                    self.addRule(existing_rules[idx])
                });
            }
            else {
                addSingleTableRow('#dontcare', 'There are no rules created');
            }
        }
    }

    this.addRule = function(rule) {
        xlog.debug("Adding rule '"+rule.name+"'");

        if (rule.sequence == '') {
            rule.sequence = next_sequence_idx;
        }

        rule.idx = ruleset.length;
        rule.deleted = false;
        ruleset.push(rule);

        if ($('.fraudscreen__rule_row').length == 0) {
            $('.fraudscreen__rule_table_info').remove();
        }

        var newRuleRow = $('#fraudscreen__blank_rule_row').clone();
            newRuleRow.attr('id', 'fraudscreen__rule_'+rule.idx)
                      .addClass('fraudscreen__rule_row')
                      .appendTo('#fraudscreen__ruleset_sequence');

        populateRuleRowValues(rule);

        if (rule.sequence >= next_sequence_idx) {
            next_sequence_idx = rule.sequence+1;
        }
    }

    this.updateRule = function(rule) {
        xlog.debug('Updating existing rule');
        var oldrule = ruleset[rule.idx];
        rule.deleted = false;
        ruleset[rule.idx] = rule;
        populateRuleRowValues(rule, oldrule);
    }

    this.deleteRule = function(rule) {
        xlog.debug('Deleting rule');
        ruleset[rule.idx].deleted = true;
        $('#fraudscreen__rule_'+rule.idx).remove();
        $('#fraudscreen__push_to_staging_button').show();
    }

    this.resequenceRules = function() {
        xlog.debug('Resequencing rules');
        $('.fraudscreen__rule_row').each(function(new_sequence) {
            var idx  = $(this).attr('id').replace('fraudscreen__rule_', '');
            ruleset[idx].sequence = new_sequence;
        })
    }

    this.getRuleset = function() {
        return ruleset;
    }

    this.isValidRuleName = function(rule) {
        var is_valid = true;
        $.each(ruleset, function(idx, val) {
            if ((!val.deleted) && ((rule.idx == null) || (rule.idx != val.idx)) && (rule.name == val.name)) {
                is_valid = false;
                return false;
            }
        });
        return is_valid;
    }

    function populateRuleRowValues(rule, oldrule) {

        // Find it
        newRuleRow = $('#fraudscreen__rule_'+rule.idx);

        if (oldrule) {
            newRuleRow.removeClass('fraudscreen__rule_channel_'+(oldrule.channel.id == '' ? 'all' : oldrule.channel.id));
        }
        newRuleRow.addClass('fraudscreen__rule_channel_'+(rule.channel.id == '' ? 'all' : rule.channel.id));
        // remove all tag classes
        newRuleRow.removeClass("#fs__tags_*");
        $.each(rule.tags, function(idx, val) {
            newRuleRow.addClass('fs__tags_'+val.replace(/\s+/g, ''));
        });


        // Condition
        var condition_list = $('<ul>');
        $.each(rule.conditions, function(idx, val) {
            if (!val.deleted) {

                var value_description = $('<span>')
                    .append( val.value.description );

                if ( parseInt( val.operator.list_operator ) == 1 ) {
                // If it's a list, add the class and on click event.
                    value_description
                        .addClass( 'fraudscreen__value_list_name' )
                        .attr('title','Show the contents of this list')
                        .click( function() {
                            list_item_popup( val.value.id, val.value.description );
                        } );
                }

                var line = $('<span>')
                    .append( val.method.description )
                    .append( '&nbsp;' )
                    .append( val.operator.description )
                    .append( '&nbsp;' )
                    .append( value_description );

                if (val.enabled) {
                    $(line).removeClass('fraudscreen__condition_disabled').addClass('fraudscreen__condition_enabled');
                }
                else {
                    $(line).addClass('fraudscreen__condition_disabled').removeClass('fraudscreen__condition_enabled');
                }

                var condition_line = $('<li>').html(line).appendTo(condition_list);

                if (val.error_msg) {
                    $('<ul>').append(
                        $('<li>').append(
                            $('<span>').addClass('fraudscreen__condition_error_msg').html(val.error_msg.join('; ')+'.')
                        )
                    ).appendTo(condition_line);
                }
            }
        });

        // Name
        var name = newRuleRow.find('.fraudscreen__rule_name')
            name.html(rule.name);

        //Tags
        if(rule.tags.length ) {
            name.append("<br><b>Tags</b>: "+rule.tags.join(', '));
        }

        if (rule.error_msg && rule.error_msg.length > 0) {
            name.append('<br>')
                .append(
                    $('<span>').addClass('fraudscreen__name_error_msg')
                               .append('&nbsp;')
                               .append(rule.error_msg.join('; '))
                    );
        }

        name.append(condition_list);

        // Rule Number
        newRuleRow.find('.fraudscreen__rule_number')
                  .html(rule.rule_number).css('font-weight','bold');

        // Start Date
        newRuleRow.find('.fraudscreen__rule_start_date')
                  .html(formatDatetimeString(rule.start));

        // End Date
        newRuleRow.find('.fraudscreen__rule_end_date')
                  .html(formatDatetimeString(rule.end));

        // Channel
        newRuleRow.find('.fraudscreen__rule_channel')
                  .html(rule.channel.description);

        // Action
        newRuleRow.find('.fraudscreen__rule_action')
                  .html(rule.action.description);

        // Enabled
        if (rule.conditions.length == 0) {
            newRuleRow.find('.fraudscreen__rule_enabled')
                      .attr('src', '/images/icons/error.png')
                      .attr('title', 'No Conditions');
        }
        else if (rule.enabled) {
            newRuleRow.find('.fraudscreen__rule_enabled')
                      .attr('src', '/images/icons/tick.png')
                      .attr('title', 'Rule Enabled');
        }
        else {
            newRuleRow.find('.fraudscreen__rule_enabled')
                      .attr('src', '/images/icons/cross.png')
                      .attr('title', 'Rule Disabled');
        }

        // Click Event for Enabled Icon (disbled-peter)
        // TODO: WTF is going on here?? event being fired multiple times!?
        newRuleRow.find('.fraudscreen__rule_enabled').click(function() {
            return false;
            rule.enabled = !rule.enabled;
            populateRuleRowValues(rule);
        })

        // Edit Icon
        if (edit_table_mode) {
            newRuleRow.find('.fraudscreen__rule_edit_button')
                         .click(function() {
                            $(self).trigger('edit', rule)
                         });
        }
    }

    function formatDatetimeString(datetime) {
        var datediv = $('<div>');
        if (datetime.date != '') {
            datediv.append($('<span>').html(datetime.date)
                   .append($('<br>'))
                   .append($('<span>').html('@ '+datetime.hour+':'+datetime.minute)));
        }

        return datediv
    }

    function addSingleTableRow(id, msg) {
        var pmsg = $('<p>').addClass('fraudscreen__single_table_row').html(msg);

        return  $('<tr>').append($('<td>').attr('colspan', '8').html(pmsg))
                         .attr('id', id)
                         .addClass('dividebelow fraudscreen__rule_table_info')
                         .appendTo('#fraudscreen__ruleset_sequence');
    }

    function splitBySpaces( val ) {
        return val.split( /,\s*/ );
    }

    function extractLast( term ) {
        return splitBySpaces( term ).pop();
    }

    function filterResults(ch,tags) {
        if(tags.length == 0 ) {
            if( ch == 'all') {
               $(".fraudscreen__rule_row").show();
             } else {
               $('.fraudscreen__rule_row').hide();
               $('.fraudscreen__rule_channel_all').show();
               $('.fraudscreen__rule_channel_'+ch).show();
             }
            return true;
        }
        //hide all the rows
        $(".fraudscreen__rule_row").hide();

        //split the search input on comma
        var data = tags.split(",");
        var jo = $(".fraudscreen__rule_row");

        // iterate over each input
         $.each(data, function(i, v) {
            if(ch == 'all') {
               jo.filter(".fs__tags_"+v).show();

            } else {
                $('.fraudscreen__rule_channel_all.fs__tags_'+v).show();
                $('.fraudscreen__rule_channel_'+ch+'.fs__tags_'+v).show();

            }
         });
    }
}

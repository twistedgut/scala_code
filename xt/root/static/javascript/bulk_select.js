//function to validate date
function ValidateDate(changeVal) {
    var date =  new Date(changeVal.value.replace(/(\d{2})-(\d{2})-(\d{4})/, "$2/$1/$3") );
    if(isNaN(Date.parse(date))) {
        alert("Invalid date - " + changeVal.value + ". Reverting to old value");
        changeVal.value =changeVal.defaultValue;
    }
}


//function to handle multi select/de-select checkboxes
function MultiSelect ( xthis ) {

    var class_name = $(xthis).attr('class');
    //add multiple select /deselect functionality
    jQuery(xthis).click(function() {
        jQuery('.sub'+ xthis.id).attr('checked', xthis.checked).trigger('update_expiry_date');
        //if class is for bulk expiry date hide or show + and -
        if( class_name.match(/\bselectall_expiry_date_.*?\b/) ) {
            var cust_id = xthis.id.split('_');
            if( $(xthis).is(':checked')) {
                $("a[id='dateadj_"+cust_id[3]+"']").hide();
            } else {
                $("a[id='dateadj_"+cust_id[3]+"']").show();
            }
        }
    });

    //if all checkbox are selected, check the selectall checkbox
    // and viceversa
    var main_id =  xthis.id;
    jQuery('.sub'+xthis.id).click(function () {
        if(jQuery('.sub'+ main_id).length == jQuery('.sub'+main_id+":checked").length) {
            jQuery("#"+main_id).attr("checked", "checked");
            if( class_name.match(/\bselectall_expiry_date_.*?\b/) ) {
                var cust_id = main_id.split('_');
                $("a[id='dateadj_"+cust_id[3]+"']").hide();
            }
        } else {
            jQuery("#"+main_id).removeAttr("checked");
            if( class_name.match(/\bselectall_expiry_date_.*?\b/) ) {
                var cust_id = main_id.split('_');
                $("a[id='dateadj_"+cust_id[3]+"']").show();
            }

        }
    });
}

$(function(){

    //datepicker
    $('.datepicker').each(function(){
        $(this).datepicker({
            showOn: "button",
            buttonImage: "/images/icons/calendar_view_month.png",
            buttonImageOnly: true,
            dateFormat: 'dd-mm-yy',
            onSelect: function(date) {
                $=jQuery;
                // enable multi-select checkboxes
                bulk_date = $(this).val();
                var channel = this.id.replace("bulk_expiry_date_",'');
                jQuery('.bulk_checkboxes_'+ channel).removeAttr('disabled');
                jQuery('.selectall_expiry_date_'+ channel).removeAttr('disabled');
                jQuery('.bulk_expiry__checkbox_'+channel).removeAttr('disabled');

                //loop through all checkboxes
                jQuery('.bulk_checkboxes_'+channel).each(function() {
                    if(this.checked ) {
                        var date_id = this.id.replace("s","single");
                        jQuery("input[id='"+date_id+"']").val(bulk_date);
                    }

                });
            }

        });
    });

    $('input[class^="bulk_checkboxes"]').on( 'update_expiry_date', function () {
        $=jQuery;
        var class_name = $(this).attr('class').match(/\bbulk_checkboxes_.*?\b/);
        var channel = class_name[0].replace('bulk_checkboxes_','');
        var inputID = this.id.replace("s","single");

        if(jQuery(this).is(':checked')) {
            //make input box readonly
            $("input[id='"+inputID+"']").attr("readonly", "readonly");
            $("a[id='"+inputID+"']").hide();
            $("input[id='"+inputID+"']").addClass('disabled');
            //update the value with bulk date
            $("input[id='"+inputID+"']").val($("#bulk_expiry_date_"+ channel).val());

        } else {
            //remove readonly flag
            $("input[id='"+inputID+"']").removeAttr('readonly');
            $("a[id='"+inputID+"']").show();
            $("input[id='"+inputID+"']").removeClass('disabled');
            //reset the original date
            $("input[id='"+inputID+"']").val(existingValues[inputID]);
        }
    });

    $('input[class^="bulk_checkboxes"]').click(function () {
        $=jQuery;
        jQuery(this).trigger('update_expiry_date');
    });


    // on page load disable checkbox
    $('input[class^="bulk_checkboxes"]').prop('disabled', 'disabled');
    $('input[class^="selectall_expiry_date"]').prop('disabled', 'disabled');
    $('input[class^="bulk_expiry__checkbox"]').prop('disabled', 'disabled');




    //multi select/de-select checkboxes
    $('.selectall_checkbox').each(function() {
       MultiSelect( this );
    });
    $('input[class^="selectall_expiry_date"]').each(function() {
       MultiSelect( this );
    });

    $('input[class^="bulk_expiry__checkbox"]').each(function() {
        jQuery(this).click(function() {
            var xwait = new xui_wait_dialog();
            xwait.setDialogMessage('Updating Bulk Date, Please wait...');
            xwait.open();

            var className = this.id;
            className = className.replace('sub','');
            jQuery('.'+ className).attr('checked',this.checked).trigger('click').attr('checked',this.checked);

            xwait.close();
        });


    });

    //multi add/subtract one day to a date
    $('.plusminus_button').each(function(){
        $=jQuery;
        $(this).click(function() {
            var button_id = this.id;
            var operation = this.name;
            jQuery.noConflict();
            jQuery('.'+button_id).each( function() {
            if(! jQuery(this).hasClass('disabled')) {
               var date =  new Date(jQuery(this).val().replace(/(\d{2})-(\d{2})-(\d{4})/, "$2/$1/$3") );
               if(operation == "plus" ) {
                   date.setDate(date.getDate() + 1);
               } else {
                   date.setDate(date.getDate() - 1);
               }
               jQuery(this).val(("0" + date.getDate()).slice(-2) + "-" +  ("0" + (date.getMonth() + 1)).slice(-2) + "-" + date.getFullYear());
            }

            });
        });
    });


    // add/subtract one day to a single date
    $('.singleplusminus_button').each(function() {
        $=jQuery;
        $(this).click(function() {
            var button_id = this.id;
            var operation = this.name;
            var selection_text = jQuery('input[id='+ button_id + ']');
            var date =  new Date(selection_text.val().replace(/(\d{2})-(\d{2})-(\d{4})/, "$2/$1/$3") );
            if(operation == "plus" ) {
                date.setDate(date.getDate() + 1);
            } else {
                date.setDate(date.getDate() - 1);
            }
            selection_text.val(("0" + date.getDate()).slice(-2) + "-" +  ("0" + (date.getMonth() + 1)).slice(-2) + "-" + date.getFullYear());
            });
        });

});


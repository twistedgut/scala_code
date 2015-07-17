// Javascript to build country subdivision dropdown
$(document).ready(function() {

    // Show/Hide dropdown  or TextBox
    $('#select_country_selection').change(function() {
        show_country_subdivision(this.value);
        editaddress_dropdown__show_message($(this));
    });

    // Make sure the country dropdown events all fire on page load, so the
    // form has the correct information and inputs.
    $('#select_country_selection').trigger('change');

});

// Build the DropDown for Country Subdivision
function build_dropdown(countrysubdivision) {

    var dropdown = $('#stateDropdown');
    var in_dropdown = false;
    //sort the keys
    var sorted_keys = Object.keys(countrysubdivision).sort();

    dropdown.append( $('<option></option>')
        .attr('value', "")
        .attr('selected', 'selected')
        .text("----------------"));

    sorted_keys.forEach(function( key, index, value) {
        if(key != 'none' ) {
            dropdown.append($('<optgroup></optgroup>').attr('label', key));
        }

        $.each(countrysubdivision[key], function(idx, val) {
            $.each(val, function ( id, county ) {
                dropdown.append( $('<option></option>')
                    .attr('value', id )
                    .text(county));
                if( current_county &&  current_county.indexOf(county ) >= 0 ) {
                    in_dropdown = true;
                    dropdown.val(current_county);
                }
            });
        });
    });

    // Add county to top of dropdown if it is not from the list
    if( current_county  && ! in_dropdown ) {
        dropdown.prepend( $('<option></option>')
                        .attr('value', current_county)
                        .attr('selected', 'selected')
                        .text(current_county + " - ( Please select correct option)"));
    }
}

function show_country_subdivision( country ) {

    var states = {};
    if(country &&  countrysubdivision ) {
        $.each(countrysubdivision, function(key, value) {
            if(key == country ) {
                states = value;
                return false;
            }
        });

    }
    if( $.isEmptyObject(states) ) {
        $('#stateDropdown').hide();
        $('#stateTextbox').show();
        //disable from form submission
        $('#stateDropdown').attr('disabled','disabled');
        $('#stateTextbox').removeAttr('disabled');
    } else {
        $('#stateDropdown').find('option').remove();
        $('#stateDropdown').find('optgroup').remove();
        build_dropdown(states);
        $('#stateDropdown').show();
        $('#stateTextbox').hide();
        $('#stateTextbox').attr("disabled", "disabled");
        $('#stateDropdown').removeAttr('disabled');
    }

}

// Show messages for each field, for the currently selected country.
function editaddress_dropdown__show_message( country ) {

    // The .data() method returns any attributes that begin with 'data-',
    // contained in an HTML tag, in a simple Key/Value structure, where the
    // prefix is removed from each key.
    //
    // For example:
    //  <option data-one="some data" data-two="some more data">...</option>
    //
    // Would result in:
    //  {
    //      one: "some data",
    //      two: "some more data",
    //  }
    var messages    = country.find(':selected').data();
    var field_names = [
        'first_name',
        'last_name',
        'address_line_1',
        'address_line_2',
        'towncity',
        'county',
        'postcode',
        'country',
    ];

    // Loop over each field name, setting the message to either an empty
    // string or the data stored for that country.
    $.each( field_names, function( index, field_name ) {
        $( '#' + field_name + '_message' ).text(
            messages[ field_name ]
                ? 'NOTE: ' + messages[ field_name ]
                : ''
        );
    });

}

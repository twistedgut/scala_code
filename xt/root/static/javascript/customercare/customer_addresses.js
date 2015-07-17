/*
    NAME:
        customerAddresses - class

    SYNOPYSIS:

        var new_obj = customerAddresses( {
            wrapper_div     : some_div,                 // a <div> where the Addresses will be drawn
            customer_id     : 345,                      // the Customer Id to get the Addresses for
            failure_message : 'No addresses found',     // if no addresses are returned display this message
            exclude_addr_key: "address identifyer",     // optional - if addresses match this key then don't show them
            run_once_done   : some_func,                // optional - when done run this function
            enable_pick_addr: false                     // optional - don't show the 'Use address' radio
                                                        //            button with each Address, default is TRUE
        } );
        new_obj.getAddresses();     // get Addresses and show the results


    REQUIRES:
        jQuery
        jquery/plugin/nap/utilities.js


    DESCRIPTION:

    A JavaScript Class that can get a list of Addresses
    used by the Customer.

    It will make a call to the following API end-point:

        /api/customer/[customerId]/address_list

    It will then draw each Address that is returned and put them in the <div>
    supplied at instantiation.

    It will create a <div> for each Address using the class 'vcard'.


    OPTIONS:

    All 'options' can be overwridden via 'new_obj.options', see code for more info.


    PUBLIC METHODS:

    The following methods are Public look in the code for more details:

        getAddresses:
            make the request and get the Address and show the results

        ajaxSuccess:
            this will be called when the AJAX call is completed sucessfully

        ajaxError:
            this will be called if the AJAX call fails

        ajaxStausCodes:
            this isn't actually a method but a key/value pair object with
            an HTTP Code and a function to call if the AJAX response code
            matches it, used as part of error handling

        show_addresses:
            this method iterates through each Address and draws it

        addAddrRow:
            this is used to draw each Address field along with its label

        checkForAValueThenAddAddrRow:
            this will only draw an Address field if there is a value for the field

        changeAjaxStatus:
            this changes the AJAX status message that is shown while the AJAX call is
            in progress, if the call fails this will also show the failure message

*/

function customerAddresses ( args ) {
    // store the instance of this Class so that it
    // can be used when the value of 'this' represents
    // something else such as an AJAX response
    var this_obj = this;

    // these are the options available to the Class
    // they can be overridden by passing them in 'args'
    this.options = {
        loading_message : 'loading addresses...',
        cache_request   : false,
        exclude_addr_key: '',
        enable_pick_addr: true
    };
    $.extend( this.options, args );

    // list of the Address Fields that will be shown along
    // with usefull attributes to aid with how they will be drawn
    this.addrFieldAttr = {
        'choose_address' : { label : 'Use address' },
        'address_type'   : { label : 'Address Type',     class : 'fn' },
        'name'           : { label : 'Name',             class : 'fn' },
        'address_line_1' : { label : 'Street Address',   class : 'street-address' },
        'address_line_2' : { label : 'Street Address 2', class : 'locality' },
        'towncity'       : { label : 'Town/City',        class : 'region' },
        'postcode'       : { label : 'Postcode',         class : 'postal-code' },
        'country'        : { label : 'Country',          class : 'country-name' },
        'county'         : { label : 'State/County',     class : 'county' }
    };
    // a list of Fields that will only be drawn if they have a Value
    this.showFieldsIfHaveValue = [ 'towncity', 'postcode', 'country', 'county' ];

    // used as part of the error handling
    this.ajaxStatusCodes = {
        400 : function () {
            this_obj.changeAjaxStatus.call( this_obj, 'ajax_img_bad_request', this_obj.options.failure_message );
        },
        401 : function () {
            this_obj.changeAjaxStatus.call( this_obj, 'ajax_img_unauthorised', this_obj.options.failure_message );
        },
        404 : function () {
            this_obj.changeAjaxStatus.call( this_obj, 'ajax_img_not_found', this_obj.options.failure_message );
        },
        500 : function () {
            this_obj.changeAjaxStatus.call( this_obj, 'ajax_img_server_error', this_obj.options.failure_message );
        }
    };

    // this will hold the waiting message that will be
    // displayed whilst the AJAX request is being made
    this.ajax_status = {};
}

customerAddresses.prototype.getAddresses = function () {
    // display a waiting message in the <div>
    this.ajax_status = $('<span>').addClass('ajax_status_message ajax_img_waiting')
                                  .text( this.options.loading_message );
    this.options.wrapper_div.append( this.ajax_status );

    // store this as when the AJAX request does its call-backs
    // 'this' will not be pointing to this 'class anymore
    var this_obj = this;

    $.ajax( {
        type      : 'GET',
        url       : '/api/customer/' + this.options.customer_id + '/address_list',
        dataType  : 'json',
        cache     : this.options.cache_request,
        error     : function () { this_obj.ajaxError.apply( this_obj, arguments ); },
        success   : function () { this_obj.ajaxSuccess.apply( this_obj, arguments ); },
        statusCode: this.ajaxStatusCodes
    } );
};

customerAddresses.prototype.ajaxSuccess = function ( data, textStatus, jqXHR ) {
    if ( this.show_addresses( data ) ) {
        this.ajax_status.remove();
        if ( !$.isUndefinedOrNull( this.options.run_once_done ) )
            this.options.run_once_done();
    }
    else {
        this.changeAjaxStatus( 'ajax_img_none_appropriate', this.options.failure_message );
    }
};

customerAddresses.prototype.ajaxError = function ( jqXHR, textStatus, errorThrown ) {
    var status_code = jqXHR.status || '';

    // if the status code has not been dealt with
    // by the 'statusCode' call-back then show error
    if ( !this.ajaxStatusCodes[ status_code ] ) {
        this.changeAjaxStatus( 'ajax_img_server_unknown_exception', this.options.failure_message );
        this.ajax_status.attr( 'title',
              status_code           + ' - '
            + ( textStatus  || '' ) + ' - '
            + ( errorThrown || '' )
        );
    }
};

customerAddresses.prototype.show_addresses = function ( data ) {
    var main_div         = this.options.wrapper_div;
    var exclude_addr_key = this.options.exclude_addr_key;
    var field_attr       = this.addrFieldAttr;
    var other_fields     = this.showFieldsIfHaveValue;

    var this_obj = this;

    var address_count = 0;
    $.each( data,
        function ( urn, address ) {
            // if the Address matches the one that's been
            // asked to be excluded then don't show it
            if (    !$.isUndefinedOrNull( address.addr_key )
                 && address.addr_key == exclude_addr_key )
                return true;    // continue

            address_count++;

            var div = $('<div>').addClass('vcard');
            var dl  = $('<dl>').addClass('table-display-fixed-height');
            main_div.append( div.append( dl ) );

            // add the 'Use address' radio button if asked to do so
            if ( this_obj.options.enable_pick_addr )
                this_obj.addAddrRow( dl,
                    $('<input>').attr( 'type', 'radio' )
                                .attr( 'name', 'address' )
                                .attr( 'checked', ( address_count == 1 ? 'checked' : null ) )
                                .val( address.addr_key ),
                    field_attr.choose_address
                );

            this_obj.checkForAValueThenAddAddrRow( dl, address.address_type, field_attr.address_type );

            this_obj.addAddrRow( dl, [ address.first_name, address.last_name ], field_attr.name );
            this_obj.addAddrRow( dl, address.address_line_1, field_attr.address_line_1 );
            this_obj.addAddrRow( dl, address.address_line_2, field_attr.address_line_2 );

            // loop round the rest of the fields and draw them if they have a value
            for ( var i=0; i < other_fields.length; i++ ) {
                var field_name  = other_fields[i];
                var field_value = address[ field_name ];
                this_obj.checkForAValueThenAddAddrRow( dl, field_value, field_attr[ field_name ] );
            }
        }
    );

    return address_count;
};

customerAddresses.prototype.addAddrRow = function ( tag, value, field_attr ) {
    tag.append( $('<dt>').text( field_attr.label ) );
    var dd_tag = $('<dd>').addClass( field_attr.class );
    tag.append( dd_tag );

    // make sure 'value' is not null
    value = ( $.isUndefinedOrNull( value ) ? '' : value );

    if ( typeof( value ) == 'object' && !$.isArray( value ) )
        dd_tag.append( value );     // append the tag to the '<dd>' tag
    else {
        // go through the array of values
        // and join them using whitespace
        var value_str = '';
        value = $.returnArrayObj( value );
        for ( var i=0; i < value.length; i++ ) {
            if ( $.isUndefinedOrNull( value[i] ) || value[i] == '' ) continue;
            if ( i > 0 && value_str != '' ) value_str += ' ';
            value_str += value[i];
        }
        // then display the text in the '<dd>' tag
        dd_tag.text( value_str );
    }

    return;
};

customerAddresses.prototype.checkForAValueThenAddAddrRow = function ( tag, value, field_attr ) {
    if ( !$.isUndefinedOrNull( value ) && value != '' )
        this.addAddrRow.apply( this, arguments );
    return;
};

customerAddresses.prototype.changeAjaxStatus = function ( img_class, message ) {
    // remove the 'waiting' class and then add a new class & change the message
    this.ajax_status.removeClass('ajax_img_waiting')
                    .addClass( img_class )
                    .text( message );
    return;
};


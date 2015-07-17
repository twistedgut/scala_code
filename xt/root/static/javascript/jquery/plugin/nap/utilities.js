/*
    NAME:
        jquery/plugin/nap/utilities.js

    REQUIRES:
        jQuery


    DESCRIPTION:

    Adds the following Methods to 'jQuery'. This script has Methods for both
    the '$' function and the '$.fn' function, the latter means the method
    can be accessed by DOM elements.


    METHODS FOR '$.' FUNCTION:

        isUndefinedOrNull:

            boolean = $.isUndefinedOrNull( value );

        Returns TRUE if the Value passed in is either 'null'
        or 'undedfined', use this to stop having to repeatably
        use "typeof( value ) == 'undefined'".

        returnArrayObj:

            array = $.returnArrayObj( value );

        Will return 'value' in an Array Object, if 'value' is
        an Array Object then it will just be returned as is.

        forceExistance:

            $.forceExistance( object, key [, key, key ... n ] );

        Given an Object and a list of 'keys' (or just one key) this will
        force the existance of those keys in the Object. It will iterate
        down from one key to the next and if a key is not found it will
        create it and set it with '{}' (empty hash). See the example below:

            before call to 'forceExistance':
                var an_object = {
                        foo : {}
                    };

                $.forceExistance( an_object, 'foo', 'bar', 'fred' );
                $.forceExistance( an_object, 'alpha', 'beta' );

            after call to 'forceExistance':
                an_object = {
                    foo : {
                        bar : {
                            fred : {}
                        }
                    },
                    alpha : {
                        beta : {}
                    }
                }

        inArrayTypeBlind:

            boolean = $.inArrayTypeBlind( value, array );

        Will return TRUE if the 'value' appears in 'array', use this
        instead of '$.inArray' because inArray requires both the 'value'
        and the values in 'array' to be of the same type, whereas this
        method will stringfy all values and then do the comparaison.

        fieldValuesInList:

            boolean = $.fieldValuesInList( element, array );

        Will return TRUE if an Element's Value (or Values if the Element is
        a set of checkboxes) appears in 'array'.


    METHODS FOR '$.fn.' FUNCTION:

        getAndDeleteProperty:

            value = $(object).getAndDeleteProperty('property');

        Will return the value of 'property' and then delete it from
        the Object.

        valList:
            Inspired by:
            http://forum.jquery.com/topic/get-list-of-values-of-all-selected-same-name-check-boxes-in-a-form

            array = $(element).valList();

        Used with an Element that can have a Value such as <input> or <select> will return the
        value in an Array object. If the element is a Multi-Select of some Checkboxes then it
        will return ALL of the Values selected.

        parseTable:

            object = $(table_element).parseTable();
                    or
            object = $(table_element).parseTable( {
                // optional:
                add_row_number: boolean,
                parse_field   : function() { ... }
            } );

        Use this to parse an HTML table and return an object that contains the following:

            {
                cols: array_of_columns,     // list of Column Headings
                rows: array_of_rows         // array of Rows from the table keyed by the Column Headings
            }

        The HTML table must have 'thead' & 'tbody' sections and the Column Headings must be in 'th' tags,
        also it can only handle tables with a single row of Column Headings.

        Column Headings will be used as a key to identify each field after having any white-space removed,
        also any blank column headings

        Each row will be an Array of objects keyed by the Column headings and the value of
        each field will be in the following structure:

            {
                text: 'field value',        // the 'text' of the field using '$(...).text()'
                obj : jquery_object         // jQuery object of the field using '$(...)'
            }

        There are some optional arguments that can be passed, which are:

            'add_row_number' - if set will add a field in every row called 'row_number' which will
                               contain the number of the row starting with '1' as the first row.
            'parse_field'    - if this is set and contains a function then this will be used to
                               parse the field and set the field's value, this will then override
                               the above default for each field.
*/

$( function ($) {

    $.isUndefinedOrNull = function ( value ) {
        return (
            typeof( value ) == 'undefined' ||
                      value == null
            ? true
            : false
        );
    };

    $.returnArrayObj = function ( value ) {
        return ( $.isArray( value ) ? value : [ value ] );
    };

    $.forceExistance = function ( object ) {
        var obj = object;
        for ( var i = 1; i < arguments.length; i++ ) {
            var key = arguments[ i ];
            if ( $.isUndefinedOrNull( obj[ key ] ) )
                obj[ key ] = {};
            obj = obj[ key ];
        }
    };

    $.inArrayTypeBlind = function ( value, list ) {
        if ( $.isUndefinedOrNull( value ) )
            return 0;

        // convert 'value' to a String
        var value_as_str = value.toString();
        var arr_of_str   = new Array();

        // go through each element in the Array and convert
        // it to a String and push that onto a new Array
        $.each( list,
            function ( idx, list_value ) {
                arr_of_str.push( list_value.toString() );
            }
        );

        // call '$.inArray' with a String value and an Array of Strings
        return ( $.inArray( value_as_str, arr_of_str ) > -1 ? 1 : 0 );
    };

    $.fieldValuesInList = function ( element, want_values ) {
        if ( $.isUndefinedOrNull( element ) )
            return 0;

        var got_values = element.valList();

        for ( var i = 0; i < got_values.length; i++ ) {
            if ( $.inArrayTypeBlind( got_values[i], want_values ) )
                return 1;
        }

        return 0;
    };

    $.fn.getAndDeleteProperty = function ( key ) {
        var options = this.get(0);
        var value = options[key];
        delete options[key];
        return value;
    };

    // Inspired by:
    // http://forum.jquery.com/topic/get-list-of-values-of-all-selected-same-name-check-boxes-in-a-form
    $.fn.valList = function() {
        var arr = $.map( this,
            function (elem) {
                return elem.value;
            }
        );
        return arr;
    };

    // Inspired By:
    // http://encosia.com/use-jquery-to-extract-data-from-html-lists-and-tables/
    $.fn.parseTable = function( options ) {
        var self = this;

        // get column headings
        var empty_heading_counter = 1;
        var columns = self.find('thead th').map(
            function () {
                var display_name = $(this).text();
                var key_name     = display_name.replace( /\s/g, '_' );
                // check if the heading was blank or just had '&nbsp;' in it
                if ( key_name == '' || key_name == '_' ) {
                    key_name     = 'empty_' + empty_heading_counter;
                    display_name = '';
                    empty_heading_counter++;
                }
                return {
                    key_name    : key_name,
                    display_name: display_name
                };
            }
        ).get();    // use .get() to convert the jQuery set to a regular array

        // parse the rows
        var row_number = 1;
        var rows = self.find('tbody tr').map(
            function () {
                var row = {};
                if ( options.add_row_number ) {
                    row['row_number'] = row_number;
                    row_number++;
                }
                $(this).find('td').each(
                    function ( idx ) {
                        var column = columns[idx];
                        if ( $.isFunction( options.parse_field ) )
                            row[ column.key_name ] = options['parse_field'].call( this, column, idx );
                        else
                            row[ column.key_name ] = {
                                text : $(this).text(),
                                obj  : $(this)
                            };
                    }
                );

                return row;
            }
        ).get();    // use .get() to convert the jQuery set to a regular array

        return {
            cols : columns,
            rows : rows
        };
    };

} (jQuery) );

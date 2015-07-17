/*
    This script is used for the Order Search by Designer functionality
    and uses the jQuery jTable plugin to display paginated Search Results.
*/

var result_file;

$(document).ready( function() {

    /*
        This section is for the Search Results page where the Operator can do a new Search
        and see a list of previous searches and then click through to see the Results.
    */
    var search_results_list = $('#search_by_designer_results_wrapper');
    if ( !$.isUndefinedOrNull( search_results_list ) ) {
        // hide the existing HTML table and convert it to a jTable table
        // so that there is a consistant theme for tables on the page
        // that lists previous results and the page that displays the Orders
        $('#search_by_designer_results').hide();
        var jtable_details = convertTableTojTable('search_by_designer_results');
        search_results_list.jtable( {
            title: jtable_details.data.rows.length + ' search results',
            actions: {
                listAction: function () {
                    // just return the table data in the format that jTable wants
                    return {
                        Result          : 'OK',
                        Records         : jtable_details.data.rows,
                        TotalRecordCount: jtable_details.data.rows.length
                    };
                }
            },
            fields: jtable_details.field_definitions
        } );
        if ( jtable_details.data.rows.length )
            search_results_list.jtable('load');
    }

    /*
        This section is used when the Operator clicks on a previous Search
        Result and is then shown the list of Orders that have been found.
    */
    result_file = $('#search_results_file').val();
    if ( !$.isUndefinedOrNull( result_file ) ) {
        // specifiy a list of jTable field definitions
        var field_definitions = {
            shipment_id : {
                // this field won't be shown and is used
                // as the Primary Key for the table
                key: true,
                title: 'Shipment Id',
                edit: false,
                list: false
            },
            order_nr : {
                title: 'Order Nr',
                edit: false,
                display: function ( data ) {
                    return $('<a>')
                            .attr( 'href', '/CustomerCare/OrderSearch/OrderView?order_id=' + data.record.id )
                            .text( data.record.order_nr );
                },
                width: '5%'
            },
            channel_name : {
                title: 'Channel',
                edit: false,
                display: function ( data ) {
                    return $('<span>').addClass( 'title-' + data.record.channel_config_section )
                                      .text( data.record.channel_name );
                },
                width: '10%'
            },
            customer_category : {
                title: 'Category',
                edit: false,
                width: '10%'
            },
            customer_name: {
                title: 'Customer',
                edit: false,
                display: function ( data ) {
                    return data.record.first_name + ' ' + data.record.last_name;
                },
                width: '25%'
            },
            shipment_country: {
                title: 'Country',
                edit: false,
                width: '20%'
            },
            order_date: {
                title: 'Order Date',
                edit: false,
                display: function ( data ) {
                    return data.record.order_date + ' ' + data.record.order_time_mins;
                },
                width: '10%'
            },
            total_value: {
                title: 'Total Value',
                edit: false,
                display: function ( data ) {
                    return data.record.total_value + ' ' + data.record.order_currency;
                },
                width: '10%'
            },
            shipment_status: {
                title: 'Status',
                edit: false,
                width: '10%'
            }
        };

        // if the Search is for a particular Sales Channel then
        // no need to show the Channel column in the Results
        var channel_id_of_search = $('#search_channel_id').val();
        if ( channel_id_of_search != 0 ) {
            delete field_definitions['channel_name'];
            // change the width of other fields using up the free space
            field_definitions['customer_name'].width = '30%';
            field_definitions['order_date'].width    = '15%';
        }

        // use the jTable plugin
        $('#results_list').jtable( {
            title: $('#search_results_title').val(),
            paging: true,
            pageSizeChangeArea: false,
            selecting: false,
            actions: {
                listAction: getResultsList_for_jt
            },
            fields: field_definitions
        } );
        // do this here because jTable doesn't seem to listen
        // when it's in the main set of Options specified above
        $('#results_list').jtable( 'option', 'pageSize', 50 );
        // causes jTable to make the API call to get the first page of data
        $('#results_list').jtable('load');
    }

} );

// parses an HTML table and then returns
// a list of jTable field definitions so that
// a jTable table can be created for it
function convertTableTojTable (table_id ) {
    var table_obj = $( '#' + table_id );

    var data = table_obj.parseTable( {
        add_row_number: 1,      // specify this so that a Primary Key can be given
        // this will mean that the data displayed in the
        // jTable table will be the HTML contents of the
        // existing table cells which will mean amongst
        // other things links will be presevered
        parse_field   : function ( column, field_idx ) {
            return $(this).html();
        }
    } );

    // set the Primay Key for the jTable table
    var field_definitions = {
        row_number: {
            key : true,
            edit: false,
            list: false
        }
    };

    // go through each field and just specifiy the minimum
    // required for jTable to display the columns
    for ( var i = 0; i < data.cols.length; i++ ) {
        var col = data.cols[i];
        var field_key_name = col.key_name;
        field_definitions[ field_key_name ] = {
            title  : col.display_name,
            edit   : false
        };
    }

    return {
        data             : data,
        field_definitions: field_definitions
    };
}

// this is called by jTable to get the data to show the Orders found
// for a particular Designer. This also gets called for each page
// of data requested when the Operator uses the pagination function
// of jTable.
function getResultsList_for_jt ( postData, jtParams ) {

    // convert the Start Index that jTable passes to
    // this function into the Page Number the API wants
    var page_number = ( jtParams.jtStartIndex / jtParams.jtPageSize ) + 1;

    // the data the API is expected to be passed
    var data = {
        'page'           : page_number,
        'number_of_rows' : jtParams.jtPageSize
    };

    // return a Deferred object back to jTable
    return $.Deferred(
        function ( deferred_obj ) {
            return $.ajax( {
                type      : 'GET',
                url       : '/CustomerCare/OrderSearchbyDesigner/Results/' + result_file + '/list',
                dataType  : 'json',
                data      : data,
                success   : function () {
                    var arg_list = Array.prototype.slice.call( arguments );
                    arg_list.unshift( deferred_obj );
                    return getResultsListSuccess_for_jt.apply( null, arg_list );
                },
                error     : function () {
                    var arg_list = Array.prototype.slice.call( arguments );
                    arg_list.unshift( deferred_obj );
                    return getResultsListError_for_jt.apply( null, arg_list );
                }
            } );
        }
    );

    return;
}

// this is called when the call to the API is successful
// and just converts the data returned by the API into
// the format that jTable wants.
function getResultsListSuccess_for_jt ( deferred_obj, data, textStatus, jqXHR ) {
    var data_out = {
        'Result'           : 'OK',
        'Records'          : data.data,
        'TotalRecordCount' : data.meta.total_records
    };
    // mark the Deferred Object has having completed
    // so jTable knows the API call has finished
    deferred_obj.resolve( data_out );
}

// this gets called when the call to the API fails
function getResultsListError_for_jt ( deferred_obj, jqXHR, textStatus, errorThrown ) {
    // mark the Deferred Object as Failed and Completed
    // so jTable knows the API call has finished
    deferred_obj.reject();
}


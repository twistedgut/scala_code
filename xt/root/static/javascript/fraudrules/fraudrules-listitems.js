function list_item_popup( id, description ) {

    popup = new xui_dialog("#fraudscreen__list_items", {
        height:    200,
        width:     400,
        resizable: true,
        autoOpen:  false,
    });

    var tbody = $('#fraudscreen__list_items table tbody').html('');

    $('#fraudscreen__list_items_title').html(description);

    $.each(list_items[id], function(i, item) {
        var tr = $('<tr>');
        $('<td>').html(item).appendTo(tr);
        tbody.append(tr)
    });

    popup.open();

}

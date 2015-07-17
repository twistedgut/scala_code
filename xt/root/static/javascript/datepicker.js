// A thin wrapper around the datepicker plugin that lives in the jquery repo
$(function(){

    $('.jq_calendar').datepicker({
        showOn: "button",
        buttonImage: "/images/icons/calendar_view_month.png",
        buttonImageOnly: true,
        dateFormat: 'yy-mm-dd'
    });
});

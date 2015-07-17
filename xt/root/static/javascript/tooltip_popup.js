$(document).ready(function() {
    var a = $('.helptooltip');
    if ( a.length ) {
        $('body').append('<div id="anchorTitle"></div>');
        a.data('title', a.attr('title'))
        .removeAttr('title')
        .hover(
            function() { showAnchorTitle(a, a.data('title')); },
            function() { hideAnchorTitle(); }
        );
    }
});
function showAnchorTitle(element, text) {
    var offset = element.offset();
    $('#anchorTitle')
    .css({
        'top'  : (offset.top + element.outerHeight() + 4) + 'px',
        'left' : offset.left + 'px'
    })
    .html(text)
    .show();
}
function hideAnchorTitle() {
    $('#anchorTitle').hide();
}

function switchClass(which,what){

        if (!document.layers) {

                if (document.all) { switchObj = eval('document.all.' + which + ''); }

                else { switchObj = document.getElementById(''+which+''); }

                switchObj.className = what;
        }
}

function MM_findObj(n, d) { // v4.01  

  var p,i,x;  if(!d) d=document;  
  if((p=n.indexOf("?"))>0&&parent.frames.length) {
      d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);} 
  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) 
      x=d.forms[i][n];  
  for(i=0;!x&&d.layers&&i<d.layers.length;i++)  
      x=MM_findObj(n,d.layers[i].document);  
  if(!x && d.getElementById) x=d.getElementById(n); return x;  
}



function MM_swapImage() { //v3.0
  var i,j=0,x,a=MM_swapImage.arguments; document.MM_sr=new Array; for(i=0;i<(a.length-2);i+=3)
   if ((x=MM_findObj(a[i]))!=null){document.MM_sr[j++]=x; if(!x.oSrc) x.oSrc=x.src; x.src=a[i+2];}
}

function MM_swapImgRestore() { //v3.0
  var i,x,a=document.MM_sr; for(i=0;a&&i<a.length&&(x=a[i])&&x.oSrc;i++) x.src=x.oSrc;
}

function init() {
	type = chk();	
}

function chk(){

   var brow = 0;
   if (document.getElementById){ brow = 0; } // dom
   else if (document.all) { brow = 2; } // ie < 6 + quirks
   else if (document.layers) { brow = 1; } // ns < 6 quirks
   else { brow = 0; }
   return brow;
}

function layObj(type,div,nest,nest2){

   if (type == 2) {this.ref = eval('document.all.' + div + '.style');}
   else if (type == 1) {
		if (nest!=null){
		 if (nest2!=null){this.ref = eval('document.layers.'+nest2+'.document.layers.'+nest+'.document.'+div);}
		 else{this.ref = eval('document.layers.' + nest + '.document.' + div);}
		}
		else{this.ref = eval('document.' + div);}
	} // eval('document.layers[div]');} seems to be wrong??
   else { this.ref = document.getElementById(div).style;} // default to dom  
}

init();

function showDiv(which){

	layobj = new layObj(type,which);
	layobj.ref.visibility = "visible";
}

function hideDiv(which){

	layobj = new layObj(type,which);
	layobj.ref.visibility = "hidden";
}

function showLayer(which){
	layobj = new layObj(type,which);

	layobj.ref.visibility = "visible";

    $('#'+which).css('margin-top', $(window).scrollTop());
}


function hideLayer(which){

	layobj = new layObj(type,which);	
	layobj.ref.visibility = "hidden";
}

function tableruler(){

 if (document.getElementById && document.createTextNode){
   var tables=document.getElementsByTagName('table');
   for (var i=0;i<tables.length;i++){
    if(tables[i].className=='ruler'){
     var trs=tables[i].getElementsByTagName('tr');
     for(var j=0;j<trs.length;j++){
      if(trs[j].parentNode.nodeName=='TBODY' && trs[j].parentNode.nodeName!='TFOOT'){
       trs[j].onmouseover=function(){this.className='ruled';return false}
       trs[j].onmouseout=function(){this.className='';return false}
     }
    }
   }
  }
 }
}

function variant_ruler( vtable ) {
  if (document.getElementById && document.createTextNode){
    if(vtable.className=='ruler'){
      var trs=vtable.getElementsByTagName('tr');
	  for(var j=0;j<trs.length;j++){
		if(trs[j].parentNode.nodeName=='TBODY' && trs[j].parentNode.nodeName!='TFOOT'){
		   trs[j].onmouseover=function(){this.className='ruled';return false}
		   trs[j].onmouseout=function(){this.className='';return false}
	    }
	  }
	}
  }
}

function update_checked(formname, item) {

   var obj = eval('document.' + formname + '.update_' + item);
   obj.checked = true; 
}

function checked_search(field) {

   var obj = eval('document.search.' + field);
   obj.checked = true; 
}

function details(prod) {

   var features = 'location=0, statusbar=0, menubar=0, width=400, height=300 ';
   var loc = '/StockTracker/Product/Details/' + prod;
   var target = '_blank';
   var win = window.open(loc, target, features);  
   win.focus();
   return win;
}

function hist(variant) {

   var features = 'location=0, statusbar=0, menubar=0, width=400, height=300 ';
   var loc = '/StockTracker/Inventory/LocHistory/' + variant;
   var target = 'history';
   var win = window.open(loc, target, features);
   win.focus();
   return win;
}

function init_upload_date( fobj,incl_last_year,y,m,d ) {
	var today = new Date();

	var dd = d || today.getDate();
	var mm = m!=null?m-1:today.getMonth();
	var yy = y || today.getFullYear();
	var nday = num_day(yy,mm);

	var obj = fobj.day;
	obj.options.length=0;
	for( var n=1;n<=nday;n++ ) 
		obj.options[n-1] = new Option(n);
	obj.selectedIndex = dd-1;

	obj = fobj.month;
	obj.options.length=0;
	for( var n=1;n<=12;n++ ) 
		obj.options[n-1] = new Option(n);
	obj.selectedIndex = mm;

	var this_year = today.getFullYear();
	obj = fobj.year;
	obj.options.length=0;
	if (incl_last_year)
		obj.options[0] = new Option(this_year-1);
	obj.options[obj.options.length] = new Option(this_year);
	obj.options[obj.options.length] = new Option(this_year+1);
	obj.selectedIndex = yy - this_year + (incl_last_year?1:0);
}

function adj_date(form) {
	var d = form.day.options.selectedIndex+1;
	var m = form.month.options.selectedIndex;
	var y = form.year.options[form.year.options.selectedIndex].text;	
	
	var nday = num_day(y,m);
	
	var obj = form.day;
	if( d!=nday ) {
		obj.options.length=0;
		for( var n=1;n<=nday;n++ ) 
			obj.options[n-1] = new Option(n);
	}
	obj.selectedIndex = d>nday?nday-1:d-1;
}

function num_day( y, m ) {
    var next_m = new Date( y, m+1, 1);
    next_m.setHours(next_m.getHours() - 3);
    return next_m.getDate();
}


function launchPopup( url) {
    window.open(url, 'PopWindow', 'location=0,status=0,toolbar=0,resizable=1,width=750,height=600,scrollbars=1');
    return false;
}

$(function(){
    function createZoomLayer(){
        var zoomedhtml  = '<div id="enlargeImage">';
        zoomedhtml     += ' <div>';
        zoomedhtml     += '     <div class="close">Close</div>';
        zoomedhtml     += '     <div class="imageholder"><img src="" alt=""></div>';
        zoomedhtml     += ' </div>';
        zoomedhtml     += '</div>';
        return $('body').append(zoomedhtml)
            .find('#enlargeImage')
            .css({'display'       : 'none',
                  'position'      : 'absolute',
                  'left'          : '0px',
                  'top'           : '0px',
                  'z-index'       : 1000,
                  'padding-left'  : '3px',
                  'padding-bottom': '3px',
                  'background-color': '#ccc' })
            .find('> div')
            .css({'border'        : '1px solid #666',
                  'background-color': '#fff',
                  'padding'       : '10px',
                  'z-index'       : 1001 })
            .find('.close')
            .css({'margin-bottom'   : '5px',
                  'text-align'      : 'right',
                  'text-decoration' : 'underline',
                  'cursor'          : 'pointer' })
            .click(function(){
                $(this).parent().parent().css('display','none');
            })
            .end().end();
    }

    /*
        Also check out 'a[class^=imagepopup_]' further down.
    */
    $('a.imagezoom').click(function(){
        enlarged = $('#enlargeImage');
        if (!enlarged.size()) enlarged = createZoomLayer();
        enlarged
            .find('.imageholder img').attr('src',$(this).attr('href')).end()
            .css({
                'margin-top': $(window).scrollTop(),
                'display'   : 'block'
            });
        return false;
    })

    /*
        Used by 'a[class^=imagepopup_]' to position
        a popup image relative to the Mouse Pointer
    */
    function popupOfPointer(args) {
        var x   = args.event.pageX;
        var y   = args.event.pageY;
        var offset = 5;

        var popup_width = args.popup.width();
        var popup_height= args.popup.height();

        switch(args.posY) {
            case 'top':
                y = y - ( popup_height + offset );
                break;
            case 'bottom':
                y = y + offset;
        }

        switch(args.posX) {
            case 'left':
                x = x - ( popup_width + offset );
                break;
            case 'right':
                x = x + offset;
        }

        args.popup.offset( { top: y, left: x } );

        return false;
    }

    /*
        Also checkout 'a.imagezoom' further up.

        This function allows you to popup images relative to a
        place on the page, currently the following are implemented:
            * Mouse Pointer

        by specifying a 'class' starting with 'imagepopup_' you can
        then specify what to poistion it relative to and in which
        direction:
            imagepopup_top_left_of_pointer
            imagepopup_bottom_right_of_pointer

        the default will be top, left of the pointer
    */
    $('a[class^=imagepopup_]').click(function(e){
        var img_src = $(this).attr('href');

        // don't popup 'blank.gif'
        if ( img_src.match(/\/blank\.gif$/) )
            return false;

        /*
           matches the class to get where to popup to and for what
           e.g.: imagepopup_(top)_(left)_of_(pointer)
        */
        var class_regexp= /^imagepopup_(.*)_(.*)_of_(.*)$/;
        var classname   = $(this).attr('class');
        var opts        = class_regexp.exec(classname);

        var action      = 'pointer';    // default is 'pointer' and to the 'top' 'left' of it
        var posY        = 'top';
        var posX        = 'left';

        if ( opts ) {
            posY    = opts[1];
            posX    = opts[2];
            action  = opts[3];
        }

        popup = $('#enlargeImage');
        if (!popup.size()) popup = createZoomLayer();
        popup
            .find('.imageholder img').attr( 'src', img_src ).end()
            .css({
                'display'   : 'block'
            });

        // now move the popup where it's wanted
        switch(action) {
            // default to 'pointer' if action not found
            case 'pointer':
            default:
                popupOfPointer( {
                        popup: popup,
                        posX: posX,
                        posY: posY,
                        event: e
                } );
        }

        return false;
    })
});

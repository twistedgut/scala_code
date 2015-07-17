function init() {type = chk();}

function chk(){

   var brow = 0;

   if (document.getElementById){ brow = 0; } // dom
   else if (document.all) { brow = 2; } // ie < 6 + quirks
   else if (document.layers) { brow = 1; } // ns < 6 quirks
   else { brow = 0; }

   return brow;

}

init();
		
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



function showLayer(which, left_offset, top_offset, e){

	var evt = window.event ? window.event : e;

	layobj = new layObj(type,which);			

	var leftpos = evt.clientX + document.body.scrollLeft;
	var toppos =  evt.clientY + document.body.scrollTop;

	layobj.ref.left = leftpos + left_offset;
	layobj.ref.top = toppos + top_offset;


	layobj.ref.visibility = "visible";

}


function hideLayer(which){

	layobj = new layObj(type,which);	
	layobj.ref.visibility = "hidden";
}
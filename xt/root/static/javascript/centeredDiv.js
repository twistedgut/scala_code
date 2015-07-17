

function getStyleObj(id){

	var obj = null;

	if(document.getElementById){
		obj = document.getElementById(id);
	}
	else if(document.all){
		obj = document.all[id];
	}
	else if(document.layers){
		obj = document.layers[id];
	}

	return (obj && obj.style) || obj;
}



var windowState = (function(){
var readScroll = {scrollLeft:0,scrollTop:0};
var readSize = {clientWidth:0,clientHeight:0};
var readScrollX = 'scrollLeft';
var readScrollY = 'scrollTop';
var readWidth = 'clientWidth';
var readHeight = 'clientHeight';

function otherWindowTest(obj){
if((document.compatMode)&&
(document.compatMode == 'CSS1Compat')&&
(document.documentElement)){
return document.documentElement;
}else if(document.body){
return document.body;
}else{
return obj;
}
};
if((typeof this.innerHeight == 'number')&&
(typeof this.innerWidth == 'number')){
readSize = this;
readWidth = 'innerWidth';
readHeight = 'innerHeight';
}else{
readSize = otherWindowTest(readSize);
}
if((typeof this.pageYOffset == 'number')&&
(typeof this.pageXOffset == 'number')){
readScroll = this;
readScrollY = 'pageYOffset';
readScrollX = 'pageXOffset';
}else{
readScroll = otherWindowTest(readScroll);
}
return {
getScrollX:function(){
return (readScroll[readScrollX]||0);
},
getScrollY:function(){
return (readScroll[readScrollY]||0);
},
getWidth:function(){
return (readSize[readWidth]||0);
},
getHeight:function(){
return (readSize[readHeight]||0);
}
};
})();



function alignDivCenter(divName, divWidth, divHeight){

	// align response layer
	var viewPortWidth = windowState.getWidth();
	var viewPortHeight = windowState.getHeight();
	var horizontalScroll = windowState.getScrollX();
	var verticalScroll = windowState.getScrollY();

	var hPos = Math.round(horizontalScroll+((viewPortWidth - divWidth)/2));
	var vPos = Math.round(verticalScroll+((viewPortHeight - divHeight)/2));

	var divStyleRef = getStyleObj(divName);

	var positionMod = (typeof divStyleRef.top == 'string')?"px":0;

	divStyleRef.top = vPos + positionMod;
	divStyleRef.left = hPos + positionMod;

}


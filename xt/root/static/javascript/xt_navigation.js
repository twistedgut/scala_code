/*
 * DO NOT REMOVE THIS NOTICE
 *
 * PROJECT:   mygosuMenu
 * VERSION:   1.0.4
 * COPYRIGHT: (c) 2003,2004 Cezary Tomczak
 * LINK:      http://gosu.pl/software/mygosumenu.html
 * LICENSE:   BSD (revised)
 */

var menuTimeout = 400

var menuSections = new Array()
var menuCountHide = new Array()

var menuSectionCnt = 0
var menuBoxCnt = 0

function menuShow(section, elements) {
  for (var i = 0; i < menuSections.length; i++) {
    if (menuSections[i] != section) {
      menuHide(menuSections[i], menuCountNodes(menuSections[i]))
    }
  }
  for (var i = 1; i <= elements; i++) {
    document.getElementById(section + '-' + i).style.visibility = 'visible'
  }
}

function menuHide(section, elements) {
  for (var i = 1; i <= elements; i++) {
    document.getElementById(section + '-' + i).style.visibility = 'hidden'
  }
  document.getElementById(section).style.zIndex = -1
}

function menuTryHide(section, elements, countHide) {
  if (countHide != menuCountHide[section]) {
    return
  }
  menuHide(section, elements)
}

function menuCountNodes(element) {
  ret = 0
  nodes = document.getElementById(element).childNodes.length
  for (var i = 0; i < nodes; i++) {
    if (document.getElementById(element).childNodes[i].nodeType == 1) {
      ret++
    }
  }
  return ret
}

function menuInitSection(section) {
  var elements = menuCountNodes(section)
  for (var i = 0; i <= elements; i++) {
    var s = (i == 0 ? (section + '-top') : (section + '-' + i))
    if (i == 0) {
      document.getElementById(s).onmouseover = function() {
        menuShow(section, elements)
        menuCountHide[section]++
        for (var ii = 0; ii < menuSections.length; ii++) {
          document.getElementById(section).style.zIndex = 1
          if (menuSections[ii] != section) {
            document.getElementById(menuSections[ii]).style.zIndex = -1
          }
        }
      }
    } else {
      document.getElementById(s).onmouseover = function() {
        //menuShow(section, elements)
        menuCountHide[section]++
      }
    }
    document.getElementById(s).onmouseout = function() {
      setTimeout("menuTryHide('" + section + "', " + elements + ", " + menuCountHide[section] + ")", menuTimeout)
    }
  }
}

function menuMakeId(nodes) {
  for (var i = 0; i < nodes.length; i++) {
    switch (nodes[i].className) {
      case 'topLevel':
        menuSectionCnt++
        menuBoxCnt = 0
        nodes[i].id = 'menu-' + menuSectionCnt + '-top'
        break
      case 'lowerLevel':
        nodes[i].id = 'menu-' + menuSectionCnt
        menuSections[menuSections.length] = nodes[i].id
        break
      case 'box':
        menuBoxCnt++
        nodes[i].id = 'menu-' + menuSectionCnt + '-' + menuBoxCnt
        break
    }
    if (nodes[i].childNodes) {
      menuMakeId(nodes[i].childNodes)
    }
  }
}

function menuInit() {
  menuMakeId(document.getElementById('navigationBar').childNodes)
  for (var i = 0; i < menuSections.length; i++) {
    menuCountHide[menuSections[i]] = 0
  }
  for (var i = 0; i < menuSections.length; i++) {
    menuInitSection(menuSections[i])
  }
}


function MM_preloadImages() { //v3.0
  var d=document; if(d.images){ if(!d.MM_p) d.MM_p=new Array();
    var i,j=d.MM_p.length,a=MM_preloadImages.arguments; for(i=0; i<a.length; i++)
    if (a[i].indexOf("#")!=0){ d.MM_p[j]=new Image; d.MM_p[j++].src=a[i];}}
}

function MM_swapImage() { //v3.0
  var i,j=0,x,a=MM_swapImage.arguments; document.MM_sr=new Array; for(i=0;i<(a.length-2);i+=3)
   if ((x=MM_findObj(a[i]))!=null){document.MM_sr[j++]=x; if(!x.oSrc) x.oSrc=x.src; x.src=a[i+2];}
}

function MM_swapImgRestore() { //v3.0
  var i,x,a=document.MM_sr; for(i=0;a&&i<a.length&&(x=a[i])&&x.oSrc;i++) x.src=x.oSrc;
}

function MM_findObj(n, d) { //v4.0
  var p,i,x;  if(!d) d=document; if((p=n.indexOf("?"))>0&&parent.frames.length) {
    d=parent.frames[n.substring(p+1)].document; n=n.substring(0,p);}
  if(!(x=d[n])&&d.all) x=d.all[n]; for (i=0;!x&&i<d.forms.length;i++) x=d.forms[i][n];
  for(i=0;!x&&d.layers&&i<d.layers.length;i++) x=MM_findObj(n,d.layers[i].document);
  if(!x && document.getElementById) x=document.getElementById(n); return x;
}


var whichOn = "";
var touched = 0;

function switchNavOn(which){

	if (touched == 1){
		clearTimeout(navtime);
	}

	if (which == whichOn){
	
	}
	else{

		if (whichOn != ""){

			identity=document.getElementById(whichOn);
			identity.className='off';
		}

		identity=document.getElementById(which);
		identity.className='on';

		whichOn = which;
	}

	touched = 1;
}

function switchNavOff(which){

	navtime = setTimeout("NavOff('" + which + "')", 400);

}


function NavOff(which){

	whichOn = "";

	identity=document.getElementById(which);
	identity.className='off';

}
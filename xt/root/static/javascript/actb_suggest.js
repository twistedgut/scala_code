
/*    Caret Functions     */

function getCaretEnd(obj){
	if(typeof obj.selectionEnd != "undefined"){
		return obj.selectionEnd;
	}else if(document.selection&&document.selection.createRange){
		var M=document.selection.createRange();
		var Lp=obj.createTextRange();
		Lp.setEndPoint("EndToEnd",M);
		var rb=Lp.text.length;
		if(rb>obj.value.length){
			return -1;
		}
		return rb;
	}
}

function getCaretStart(obj){
	if(typeof obj.selectionStart != "undefined"){
		return obj.selectionStart;
	}else if(document.selection&&document.selection.createRange){
		var M=document.selection.createRange();
		var Lp=obj.createTextRange();
		Lp.setEndPoint("EndToStart",M);
		var rb=Lp.text.length;
		if(rb>obj.value.length){
			return -1;
		}
		return rb;
	}
}

function setCaret(obj,l){
	obj.focus();
	if (obj.setSelectionRange){
		obj.setSelectionRange(l,l);
	}else if(obj.createTextRange){
		m = obj.createTextRange();		
		m.moveStart('character',l);
		m.collapse();
		m.select();
	}
}
/* ----------------- */

/*    Escape function   */
String.prototype.addslashes = function(){
	return this.replace(/(["\\\.\|\[\]\^\*\+\?\$\(\)])/g, '\\$1');
}

String.prototype.trim = function () {
    return this.replace(/^\s*(\S*(\s+\S+)*)\s*$/, "$1");
}; 


function actb(obj,evt,ca,err){

	if (!err) { err = 'pressSearch';}
	
	/* ---- Variables ---- */
	var actb_timeOut = -1;             // Autocomplete Timeout in ms (-1: autocomplete never time out)
	var actb_lim = -1;                 // Number of elements autocomplete can show (-1: no limit)
	var actb_firstText = true;         // should the auto complete be limited to the beginning of keyword?
	var actb_mouse = true;             // Enable Mouse Support
	var actb_delimiter = new Array();  // Delimiter for multiple autocomplete. Set it to empty array for single autocomplete
	/* ---- Variables ---- */

	/* --- Styles --- */
	var actb_bgColor = '#fff';
	var actb_textColor = '#0b123f';
	var actb_hColor = '#aaacbc';
	var actb_fFamily = 'Arial, Helvetica, Verdana, sans-serif';
	var actb_fSize = '0.9em';
	var actb_hStyle = 'text-decoration:underline;font-weight="normal"';
	/* --- Styles --- */

	/* ---- Don't touch :P---- */
	var actb_delimwords = new Array();
	var actb_cdelimword = 0;
	var actb_delimchar = new Array();
	var actb_keywords = new Array();
	var actb_display = false;
	var actb_pos = 0;
	var actb_total = 0;
	var actb_curr = null;
	var actb_rangeu = 0;
	var actb_ranged = 0;
	var actb_bool = new Array();
	var actb_pre = 0;
	var actb_toid;
	var actb_tomake = false;
	var actb_getpre = "";
	var actb_mouse_on_list = true;
	var actb_kwcount = 0;
	var actb_caretmove = false;
	/* ---- "Constants" ---- */

	var cdoc = document;
	actb_keywords = ca;
	actb_curr = obj;
	
	var oldkeydownhandler = document.onkeydown;
	var oldblurhandler = obj.onblur;
	var oldkeypresshandler = obj.onkeypress;

	document.onkeydown = actb_checkkey;
	obj.onblur = actb_clear;
	obj.onkeypress = actb_keypress;
	
	function actb_clear(evt){
		if (!evt) evt = event;
		document.onkeydown = oldkeydownhandler;
		actb_curr.onblur = oldblurhandler;
		actb_curr.onkeypress = oldkeypresshandler;
		actb_removedisp();
	}

	function actb_parse(n){
		if (actb_delimiter.length > 0){
			var t = actb_delimwords[actb_cdelimword].trim().addslashes();
			var plen = actb_delimwords[actb_cdelimword].trim().length;
		}else{
			var t = actb_curr.value.addslashes();
			var plen = actb_curr.value.length;
		}
		var tobuild = '';
		var i;

		if (actb_firstText){
			// Highlight the first occurrence of the search text at the start of a word
			var re = new RegExp("^((.+ )*)" + t, "i");
			var m = n.match(re);
			// The underlined text should start at the character position 
			// following the second element of the returned array
			var p = RegExp.$2.length;
		}else{
			// Highlight the first occurrence of the search text
			var re = new RegExp(t, "i");
			var p = n.search(re);
		}
			
		for (i=0;i<p;i++){
			tobuild += n.substr(i,1);
		}
		tobuild += "<font style='"+(actb_hStyle)+"'>"
		for (i=p;i<plen+p;i++){
			tobuild += n.substr(i,1);
		}
		tobuild += "</font>";
		for (i=plen+p;i<n.length;i++){
			tobuild += n.substr(i,1);
		}
		return tobuild;
	}

	function curTop(){
		actb_toreturn = 0;
		obj = actb_curr;
		while(obj){
			actb_toreturn += obj.offsetTop;
			obj = obj.offsetParent;
		}
		return actb_toreturn;
	}

	function curLeft(){
		actb_toreturn = 0;
		obj = actb_curr;
		while(obj){
			actb_toreturn += obj.offsetLeft;
			obj = obj.offsetParent;
		}
		if (navigator.userAgent.indexOf("MSIE") >= 0) {
			// *Very* ugly hack to get around misplacement of text box
			// in IE. It thinks it's 17px further over than it should be 
			// due to a padding-left on #main further up in the document
			// if you can come up with a more appropriate fix please do!!
			actb_toreturn -= 17;
		}
		return actb_toreturn;
	}

	function actb_generate_iframe(a){
		// don't draw pointless iframe with nothing in it
		// See Chisel/Felix for further explanation
		return;
	}

	function actb_generate(){
		if (document.getElementById('tat_table'))  { document.body.removeChild(document.getElementById('tat_table')); actb_display = false; }
		if (document.getElementById('tat_iframe')) { document.body.removeChild(document.getElementById('tat_iframe')); }
		if (actb_kwcount == 0){
			actb_display = false;
			return;
		}
		a = document.createElement('table');
		a.cellSpacing='1px';
		a.cellPadding='1px';
		a.style.position='absolute';
		a.style.top = eval(curTop() + actb_curr.offsetHeight) + "px";
		a.style.left = curLeft() + "px";
		a.style.backgroundColor=actb_bgColor;
		a.id = 'tat_table';
		// Extra attributes added by Dave
		a.width = actb_curr.offsetWidth;
		a.style.borderStyle = "solid";
		a.style.borderWidth = "1px";
		// Extra attributes added by Matt
		a.style.borderColor = "#aaacbc";
		a.style.textAlign	= "left";

		document.body.appendChild(a);
		var i;
		var first = true;
		var j = 1;
		if (actb_mouse){
			a.onmouseout= actb_table_unfocus;
			a.onmouseover=actb_table_focus;
		}
		var counter = 0;
		for (key in actb_keywords) {
			if (actb_bool[key]){
				counter++;
				r = a.insertRow(-1);
				if (first && !actb_tomake){
					r.style.backgroundColor = actb_hColor;
					first = false;
					actb_pos = counter;
				}else if(actb_pre == i){
					r.style.backgroundColor = actb_hColor;
					first = false;
					actb_pos = counter;
				}else{
					r.style.backgroundColor = actb_bgColor;
				}
				r.id = 'tat_tr'+(j);
				c = r.insertCell(-1);
				c.style.color = actb_textColor;
				c.style.fontFamily = actb_fFamily;
				c.style.fontSize = actb_fSize;
				c.style.cursor = 'default';
				c.innerHTML = actb_parse(key);
				c.id = 'tat_td'+(j);
				c.setAttribute('pos',j);
				if (actb_mouse){
					c.onclick=actb_mouseclick;
					c.onmouseover = actb_table_highlight;
				}
				j++;
			}
			if (j - 1 == actb_lim && j < actb_total){
				r = a.insertRow(-1);
				r.style.backgroundColor = actb_bgColor;
				c = r.insertCell(-1);
				c.style.color = actb_textColor;
				c.style.fontFamily = 'arial narrow';
				c.style.fontSize = actb_fSize;
				c.style.cursor = 'default';
				c.align='center';
				c.innerHTML = '\\/';
				if (actb_mouse){
					c.onclick = actb_mouse_down;
				}
				break;
			}
		}

		actb_generate_iframe(a);

		actb_rangeu = 1;
		actb_ranged = j-1;
		actb_display = true;
		if (actb_pos <= 0) actb_pos = 1;
	}
    
	function actb_remake(){
		if (document.getElementById('tat_table'))  { document.body.removeChild(document.getElementById('tat_table')); }
		if (document.getElementById('tat_iframe')) { document.body.removeChild(document.getElementById('tat_iframe')); }
		a = document.createElement('table');
		a.cellSpacing='1px';
		a.cellPadding='2px';
		a.style.position='absolute';
		a.style.top = eval(curTop() + actb_curr.offsetHeight) + "px";
		a.style.left = curLeft() + "px";
		a.style.backgroundColor=actb_bgColor;
		a.id = 'tat_table';
		// Extra attributes added by Dave
		a.width = actb_curr.offsetWidth;
		a.style.borderStyle = "solid";
		a.style.borderWidth = "1px";
		// Extra attributes added by Matt
		a.style.borderColor = "#aaacbc";
		a.style.textAlign	= "left";
		
		if (actb_mouse){
			a.onmouseout= actb_table_unfocus;
			a.onmouseover=actb_table_focus;
		}
		document.body.appendChild(a);
		var i;
		var first = true;
		var j = 1;
		if (actb_rangeu > 1){
			r = a.insertRow(-1);
			r.style.backgroundColor = actb_bgColor;
			c = r.insertCell(-1);
			c.style.color = actb_textColor;
			c.style.fontFamily = 'arial narrow';
			c.style.fontSize = actb_fSize;
			c.style.cursor = 'default';
			c.align='center';
			c.innerHTML = '/\\';
			if (actb_mouse){
				c.onclick = actb_mouse_up;
			}
		}
		for (key in actb_keywords) {
			if (actb_bool[key]){
				if (j >= actb_rangeu && j <= actb_ranged){
					r = a.insertRow(-1);
					r.style.backgroundColor = actb_bgColor;
					r.id = 'tat_tr'+(j);
					c = r.insertCell(-1);
					c.style.color = actb_textColor;
					c.style.fontFamily = actb_fFamily;
					c.style.fontSize = actb_fSize;
					c.style.cursor = 'default';
					c.innerHTML = actb_parse(key);
					c.id = 'tat_td'+(j);
					c.setAttribute('pos',j);
					if (actb_mouse){
						c.onclick=actb_mouseclick;
						c.onmouseover = actb_table_highlight;
					}
					j++;
				}else{
					j++;
				}
			}
			if (j > actb_ranged) break;
		}
		if (j-1 < actb_total){
			r = a.insertRow(-1);
			r.style.backgroundColor = actb_bgColor;
			c = r.insertCell(-1);
			c.style.color = actb_textColor;
			c.style.fontFamily = 'arial narrow';
			c.style.fontSize = actb_fSize;
			c.style.cursor = 'default';
			c.align='center';
			c.innerHTML = '\\/';
			if (actb_mouse){
				c.onclick = actb_mouse_down;
			}
		}

		actb_generate_iframe(a);
	}

	function actb_goup(){
		if (!actb_display) return;
		if (actb_pos == 1) return;
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_bgColor;
		actb_pos--;
		if (actb_pos < actb_rangeu) actb_moveup();
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_hColor;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list=0;actb_removedisp();},actb_timeOut);
	}

	function actb_godown(){
		if (!actb_display) return;
		if (actb_pos == actb_total) return;
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_bgColor;
		actb_pos++;
		if (actb_pos > actb_ranged) actb_movedown();
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_hColor;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list=0;actb_removedisp();},actb_timeOut);
	}

	function actb_movedown(){
		actb_rangeu++;
		actb_ranged++;
		actb_remake();
	}

	function actb_moveup(){
		actb_rangeu--;
		actb_ranged--;
		actb_remake();
	}

	/* Mouse */
	function actb_mouse_down(){
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_bgColor;
		actb_pos++;
		actb_movedown();
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_hColor;
		actb_curr.focus();
		actb_mouse_on_list = 0;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list=0;actb_removedisp();},actb_timeOut);
	}
	function actb_mouse_up(evt){
		if (!evt) evt = event;
		if (evt.stopPropagation){
			evt.stopPropagation();
		}else{
			evt.cancelBubble = true;
		}
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_bgColor;
		actb_pos--;
		actb_moveup();
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_hColor;
		actb_curr.focus();
		actb_mouse_on_list = 0;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list=0;actb_removedisp();},actb_timeOut);
	}
	function actb_mouseclick(evt){
		if (!evt) evt = event;
		if (!actb_display) return;
		actb_mouse_on_list = 0;
		actb_pos = this.getAttribute('pos');
		actb_penter();
	}
	function actb_table_focus(){
		actb_mouse_on_list = 1;
	}
	function actb_table_unfocus(){
		actb_mouse_on_list = 0;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list = 0;actb_removedisp();},actb_timeOut);
	}
	function actb_table_highlight(){
		actb_mouse_on_list = 1;
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_bgColor;
		actb_pos = this.getAttribute('pos');
		while (actb_pos < actb_rangeu) actb_moveup();
		while (actb_pos > actb_ranged) actb_mousedown();
		document.getElementById('tat_tr'+actb_pos).style.backgroundColor = actb_hColor;
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list = 0;actb_removedisp();},actb_timeOut);
	}
	/* ---- */

	function actb_insertword(a){
		if (actb_delimiter.length > 0){
			str = '';
			l=0;
			for (i=0;i<actb_delimwords.length;i++){
				if (actb_cdelimword == i){
					str += a;
					l = str.length;
				}else{
					str += actb_delimwords[i];
				}
				if (i != actb_delimwords.length - 1){
					str += actb_delimchar[i];
				}
			}
			actb_curr.value = str;
			setCaret(actb_curr,l);
		}else{
			actb_curr.value = a;	
		}
		actb_mouse_on_list = 0;
		actb_removedisp();
	}
	function actb_penter(){
		if (!actb_display) return;
		actb_display = false;
		var word = '';
		var c = 0;
		for (key in actb_keywords) {
			if (actb_bool[key]) c++;
			if (c == actb_pos){
				word = key;
				break;
			}
		}
		actb_insertword(word);
	}
	function actb_removedisp(){
		if (!actb_mouse_on_list){
			actb_display = false;
			if (document.getElementById('tat_table'))  { document.body.removeChild(document.getElementById('tat_table')); }
			if (document.getElementById('tat_iframe')) { document.body.removeChild(document.getElementById('tat_iframe')); }
			if (actb_toid) clearTimeout(actb_toid);
		}
	}
	function actb_keypress(){
		return !actb_caretmove;
	}
	function actb_checkkey(evt){
		if (!evt) evt = event;
		a = evt.keyCode;
		caret_pos_start = getCaretStart(actb_curr);
		actb_caretmove = 0;
		switch (a){
			case 38:
				actb_goup();
				actb_caretmove = 1;
				return false;
				break;
			case 40:
				actb_godown();
				actb_caretmove = 1;
				return false;
				break;
			case 13: case 9:
				actb_penter();
				actb_caretmove = 1;
				return false;
				break;
			default:
				setTimeout(function(){actb_tocomplete(a)},50);
				break;
		}
	}

	function actb_tocomplete(kc){
		if (kc == 38 || kc == 40 || kc == 13) return;
		var i;
		if (actb_display){ 
			var word = 0;
			var c = 0;
			for (key in actb_keywords) { 
				if (actb_bool[key]) c++;
				if (c == actb_pos){
					word = actb_keywords[key];
					break;
				}
			}
			actb_pre = word;
		}
		else { 
			actb_pre = -1;
		}
		
		if (actb_curr.value == ''){
			actb_mouse_on_list = 0;
			actb_removedisp();
			return;
		}
		if (actb_delimiter.length > 0){
			caret_pos_start = getCaretStart(actb_curr);
			caret_pos_end = getCaretEnd(actb_curr);
			
			delim_split = '';
			for (i=0;i<actb_delimiter.length;i++){
				delim_split += actb_delimiter[i];
			}
			delim_split = delim_split.addslashes();
			delim_split_rx = new RegExp("(["+delim_split+"])");
			c = 0;
			actb_delimwords = new Array();
			actb_delimwords[0] = '';
			for (i=0,j=actb_curr.value.length;i<actb_curr.value.length;i++,j--){
				if (actb_curr.value.substr(i,j).search(delim_split_rx) == 0){
					ma = actb_curr.value.substr(i,j).match(delim_split_rx);
					actb_delimchar[c] = ma[1];
					c++;
					actb_delimwords[c] = '';
				}else{
					actb_delimwords[c] += actb_curr.value.charAt(i);
				}
			}

			var l = 0;
			actb_cdelimword = -1;
			for (i=0;i<actb_delimwords.length;i++){
				if (caret_pos_end >= l && caret_pos_end <= l + actb_delimwords[i].length){
					actb_cdelimword = i;
				}
				l+=actb_delimwords[i].length + 1;
			}
			var t = actb_delimwords[actb_cdelimword].addslashes().trim();
		}else{
			var t = actb_curr.value.addslashes();
		}
		if (actb_firstText){
			// Check whether the text entered matches the start of any of the words in the list
			var re = new RegExp("^(.+ )*" + t, "i");
		}else{
			// Check whether the text entered matches the start of any of the words in the list
			var re = new RegExp(t, "i");
		}
		
		actb_total = 0;
		actb_tomake = false;
		actb_kwcount = 0;
		for (key in actb_keywords) {
			actb_bool[key] = false;
			if (re.test(key)){
				actb_total++;
				actb_bool[key] = true;
				actb_kwcount++;
				if (actb_pre == actb_keywords[key]) actb_tomake = true;
			}
		}
		if (actb_toid) clearTimeout(actb_toid);
		if (actb_timeOut > 0) actb_toid = setTimeout(function(){actb_mouse_on_list = 0;actb_removedisp();},actb_timeOut);
		actb_generate();
	}
}

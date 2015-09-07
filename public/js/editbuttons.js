"use strict";
ffcdata.editbuttons = {};

ffcdata.editbuttons.init = function(){
    if ( ffcdata.utils.is_disabled() ) return;

    var tinput = document.getElementById('textinputiframe');
    if ( !tinput ) return;

    var switch2iframe = function() {
        var textarea = document.getElementById('textinput');
        var taclassName = textarea.className;
        textarea.className = 'nodisplay';
        tinput.className = taclassName;
        tinput.contentDocument.designMode = "on";
    };

    // Auswahltext ermitteln
    var selection = function() {
        var beg = tinput.selectionStart || 0;
        var end = tinput.selectionEnd   || 0;
        if ( beg > end ) return [end, beg];
        else             return [beg, end];
    };
    var position = function(pos) {
        tinput.selectionStart = pos;
        tinput.selectionEnd   = pos;
    }

    // Wörter auf einer Zeile inline mit einem Zeichen umrahmen
    var tagthat = function(str){
        // console.log('sourround selection with "' + str + '"');
        tinput.focus();
        var sel = selection();
        if ( sel[0] === sel[1] )
            return '';
        var txt0 = tinput.value.substr(0,sel[0]);
        var txt1 = tinput.value.substr(sel[0],sel[1] - sel[0] - 1);
        var txt2 = tinput.value.substring(sel[1],tinput.value.length);
        tinput.value =  txt0 + "<" + str + ">" + txt1 + "</" + str + ">" + txt2;
        position(sel[1] + (2 * str.length + 4));
    };

    tagthat = function(str, value){
        if ( ! value )
            value = null;
        if ( ! tinput.contentDocument.execCommand(str, false, value) )
            console.log("Could not add command '"+str+"'");
    };

    // Textfeld-Klappungen
    var tinputclass = tinput.className;
    var tap = document.getElementById('closetextap');
    var closetextarea = function(){ 
        // console.log('closetext');
        tinput.className = tinputclass;
        tap.className = 'textright nodisplay';
    };
    var opentextarea = function(){
        // console.log('opentext');
        if ( tap.className !== 'textright nodisplay' ) return;
        if ( !tinputclass )
            tinput.className = 'inedit';
        else
            tinput.className = tinputclass + ' inedit';
        tap.className = 'textright displayblock';
    };

    // Buttonereignisse registrieren
    document.getElementById('h1button').onclick            = function(){ tagthat( 'h3'    ) };
    document.getElementById('quotebutton').onclick         = function(){ tagthat( 'quote' ) };
    document.getElementById('unorderedlistbutton').onclick = function(){ tagthat( 'ul'    ) };
    document.getElementById('orderedlistbutton').onclick   = function(){ tagthat( 'ol'    ) };
    document.getElementById('listitembutton').onclick      = function(){ tagthat( 'li'    ) };
    document.getElementById('codebutton').onclick          = function(){ tagthat( 'code'  ) };
    document.getElementById('prebutton').onclick           = function(){ tagthat( 'pre'   ) };
    document.getElementById('underlinebutton').onclick     = function(){ tagthat( 'u'     ) };
    document.getElementById('boldbutton').onclick          = function(){ tagthat( 'b'     ) };
    document.getElementById('linethroughbutton').onclick   = function(){ tagthat( 'strike') };
    document.getElementById('italicbutton').onclick        = function(){ tagthat( 'i'     ) };
    document.getElementById('emotionalbutton').onclick     = function(){ tagthat( 'em'    ) };

    tinput.style.resize = 'none';
    if ( !tinput.className.match(/inedit/i) ) {
        document.getElementById('closetextabutton').onclick = closetextarea;
        tinput.onfocus = opentextarea;
    }

    document.getElementById('editbuttons').className = 'editbuttons';
    switch2iframe();
};


"use strict";
ffcdata.editbuttons = {};

ffcdata.editbuttons.init = function(){
    if ( ffcdata.utils.is_disabled() ) return;

    // Textfeld als Element bekannt machen
    var tinput = document.getElementById('textinput');
    if ( !tinput ) return;

    // Auswahltext ermitteln
    var selection = function() {
        var beg = tinput.selectionStart || 0;
        var end = tinput.selectionEnd   || 0;
        if ( beg > end ) return [end, beg];
        else             return [beg, end];
    };

    // Wörter auf einer Zeile inline mit einem Zeichen umrahmen
    var tagthat = function(str, br_o, br_i){
        // console.log('sourround selection with "' + str + '"');
        tinput.focus();

        // Textbestandteile der Markierung oder Cursorposition ermitteln
        var sel = selection();
        var txt0 = tinput.value.substr(0,sel[0]);
        var txt1 = tinput.value.substr(sel[0],sel[1] - sel[0]);
        var txt2 = tinput.value.substr(sel[1],tinput.value.length);

        // Neuen Textinhalt zusammenstellen
        var brstr_o = br_o ? '\n' : '';
        var brstr_i = br_i ? '\n' : '';
        tinput.value 
            = txt0 
                + brstr_o + "<" + str + ">" 
                    + brstr_i + txt1 + brstr_i 
                + "</" + str + ">" + brstr_o
            + txt2;

        // Textcursor an eine passende Stelle setzen
        var pos = sel[1] + str.length + 2;
        if ( br_o ) pos += 1;
        if ( br_i ) pos += 1;
        if ( sel[0] !== sel[1] ) {
            pos += str.length + 3;
            if ( br_o ) pos += 1;
            if ( br_i ) pos += 1;
        }
        tinput.selectionStart = pos;
        tinput.selectionEnd   = pos;
    };

    // Textfeld-Klappungen
    var tinputclass = tinput.className;
    var tap = document.getElementById('closetextap');
    // Textfeld öffnen
    var opentextarea = function(){
        // console.log('opentext');
        if ( tap.className !== 'textright nodisplay' ) return;
        if ( !tinputclass )
            tinput.className = 'inedit';
        else
            tinput.className = tinputclass + ' inedit';
        tap.className = 'textright displayblock';
    };
    // Textfeld schließen
    var closetextarea = function(){ 
        // console.log('closetext');
        tinput.className = tinputclass;
        tap.className = 'textright nodisplay';
    };

    // Formatierungsbuttonereignisse registrieren
    document.getElementById('h1button'           ).onclick=function(){tagthat('h3',    true, false)};
    document.getElementById('quotebutton'        ).onclick=function(){tagthat('quote', false,false)};
    document.getElementById('unorderedlistbutton').onclick=function(){tagthat('ul',    true, true )};
    document.getElementById('orderedlistbutton'  ).onclick=function(){tagthat('ol',    true, true )};
    document.getElementById('listitembutton'     ).onclick=function(){tagthat('li',    false,false)};
    document.getElementById('codebutton'         ).onclick=function(){tagthat('code',  false,false)};
    document.getElementById('prebutton'          ).onclick=function(){tagthat('pre',   true, true )};
    document.getElementById('underlinebutton'    ).onclick=function(){tagthat('u',     false,false)};
    document.getElementById('boldbutton'         ).onclick=function(){tagthat('b',     false,false)};
    document.getElementById('linethroughbutton'  ).onclick=function(){tagthat('strike',false,false)};
    document.getElementById('italicbutton'       ).onclick=function(){tagthat('i',     false,false)};
    document.getElementById('emotionalbutton'    ).onclick=function(){tagthat('em',    false,false)};

    // Textfeld-Klappung einrichten
    tinput.style.resize = 'none';
    if ( !tinput.className.match(/inedit/i) ) {
        document.getElementById('closetextabutton').onclick = closetextarea;
        tinput.onfocus = opentextarea;
    }

    // Formatierungsbuttons anzeigen
    document.getElementById('editbuttons').className = 'editbuttons';
};


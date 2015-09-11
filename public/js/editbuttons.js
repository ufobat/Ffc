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

    // Textfeld-Klappungen
    var tinputclass = tinput.className;
    var tap = document.getElementById('subtabuttonp');
    // Textfeld öffnen
    var opentextarea = function(){
        // console.log('opentext');
        if ( tap.className !== 'nodisplay' ) return;
        if ( ! tinputclass )
            tinput.className = 'inedit';
        else
            tinput.className = tinputclass + ' inedit';
        tap.className = 'textright subtabuttonp';
        // console.log('open');
    };
    // Textfeld schließen
    var closetextarea = function(){ 
        // console.log('closetext');
        tinput.className = tinputclass;
        tap.className = 'nodisplay';
        // console.log('close');
    };

    // Wörter auf einer Zeile inline mit einem Zeichen umrahmen
    var tagthat = function(itag, btag, iobr){
        // console.log('sourround selection with "' + str + '"');
        tinput.focus();

        // Textbestandteile der Markierung oder Cursorposition ermitteln
        var sel = selection();
        var txt0 = tinput.value.substr(0,sel[0]);
        var txt1 = tinput.value.substr(sel[0],sel[1] - sel[0]);
        var txt2 = tinput.value.substr(sel[1],tinput.value.length);

        // Gestaltung des Quelltextes ermitteln
        var block = ( ( btag && itag && txt1.match(/\n/) ) || ( btag && !itag ) ) 
            ? false : true;
        var tag   = block ? btag : itag;
        var s_br_o = '';
        var e_br_o = '';
        var s_br_i = '';
        var e_br_i = '';
        if ( block ) {
            if ( txt0.length > 0 && !txt0.match(/\n\s*$/) ) s_br_o = '\n';
            if ( txt2.length > 0 && !txt2.match(/^\s*\n/) ) e_br_o = '\n';
            if ( !itag && txt1.length > 0 ) {
                if ( !txt1.match(/^\s*\n/) ) s_br_i = '\n';
                if ( !txt1.match(/\n\s*$/) ) e_br_i = '\n';
            }
        }

        // Neuen Textinhalt zusammenstellen
        tinput.value 
            = txt0 
                + s_br_o + "<" + tag + ">" 
                    + s_br_i + txt1 + e_br_i
                + "</" + tag + ">" + e_br_o
            + txt2;

        // Textcursor an eine passende Stelle setzen
        var pos = sel[1] + tag.length + 2;
        if ( s_br_o ) pos++;
        if ( s_br_i ) pos++;
        if ( sel[0] !== sel[1] ) {
            pos += tag.length + 3;
            if ( e_br_i ) pos++;
            if ( e_br_o ) pos++;
        }
        tinput.selectionStart = pos;
        tinput.selectionEnd   = pos;
    };

    var show_formatbuttons = function(){
        // Formatierungsbuttons registrieren
        var buttons = [
            // ButtonId, Optional: InlineTag, Optional: BlockTag, InlineOuterBreak,
            ['h1button',            'h3',     false,        true ],
            ['quotebutton',         'quote',  'blockquote', false],
            ['unorderedlistbutton', false,    'ul',         false],
            ['orderedlistbutton',   false,    'ol',         false],
            ['listitembutton',      'li',     false,        true ],
            ['codebutton',          'code',   'pre',        false],
            ['underlinebutton',     'u',      false,        false],
            ['boldbutton',          'b',      false,        false],
            ['linethroughbutton',   'strike', false,        false],
            ['italicbutton',        'i',      false,        false],
            ['emotionalbutton',     'em',     false,        false],
        ];
        // Formatierungsbuttonereignisse registrieren
        for (var i=0; i<buttons.length; i++) {
            var button = document.getElementById(buttons[i][0]);
            var a1 = buttons[i][1];
            var a2 = buttons[i][2];
            var a3 = buttons[i][3];
            if ( button )
                button.onclick = function(){tagthat(a1,a2,a3)};
            else
                console.log('buttonid "'+buttons[0]+'" not found');
        }
    };

    // Textvorschau anzeigen
    var previewwindow = document.getElementById('textpreviewbox');
    var headboxbox = document.getElementById('headbox');
    var previewtextarea = document.getElementById('textpreviewarea');
    var show_preview = function(str) {
        // console.log('display preview');
        previewwindow.style.width = headboxbox.clientWidth + 'px';
        previewwindow.style.top = headboxbox.offsetTop + 'px'; 
        previewwindow.style.left = headboxbox.offsetLeft + 'px'; 
        previewtextarea.innerHTML = str;
        previewwindow.className = 'hovering';
    };
    // Textvorschau vom Server anfordern
    var get_preview = function(){
        // console.log('get preview');
        if ( tinput.value === '' )
            show_preview('');
        ffcdata.utils.request('POST', ffcdata.textpreviewurl, tinput.value, show_preview);
    };
    // Textvorschaufenster schließen
    var close_preview = function(){
        // console.log('close preview');
        previewwindow.className = 'nodisplay';
    };

    var showbuttons = function(){
        // Textfeld-Klappung einrichten
        tinput.style.resize = 'none';
        if ( tinput.className.match(/inedit/i) ) {
            opentextarea();
        }
        else {
            var closeb = document.getElementById('closetextabutton');
            closeb.onclick = closetextarea;
            closeb.className = '';
            tinput.onfocus = opentextarea;
        }

        // Formatierungsbuttons anzeigen
        document.getElementById('editbuttons').className = 'editbuttons';
        // Formatierungsbuttons aktivieren
        show_formatbuttons();

        // Vorschau-Button aktivieren
        document.getElementById('textpreviewtabutton').onclick = get_preview;
        document.getElementById('closetextpreviewareabutton').onclick = close_preview;
    };

    showbuttons();
};


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
    var tagthat = function(ntag, btag, obb, dout){
        tinput.focus();

        // Textbestandteile der Markierung oder Cursorposition ermitteln
        var sel = selection();
        var txt0 = tinput.value.substr(0,sel[0]);
        var txt1 = tinput.value.substr(sel[0],sel[1] - sel[0]);
        var txt2 = tinput.value.substr(sel[1],tinput.value.length);

        // Gestaltung des Quelltextes ermitteln

        var b_only  = ( btag && !ntag ) ? true : false; // Nur Block-Tag übergeben
        var n_only  = ( ntag && !btag ) ? true : false; // Nur Inline-Tag übergeben
        var n_and_b = ( ntag &&  btag ) ? true : false; // Block- und Inline-Tag beide übergeben

        var n_to_b  = ( n_and_b && txt1.match(/.\n./) ) ? true : false; // Block-Tag statt Inline-Tag wenn beide vorhande bei Zeilenumbrüchen im Textabschnitt
        var big_b   = ( b_only  || n_to_b             ) ? true : false; // Ein "großer" Block nur bei exklusivem Block oder Inline-Zu-Block-Umwandung wegen Zeilenumbruch im Textabschnitt und wenn beide Tags verfügbar sind

        var ibr =   big_b;                                       // Inner-Br nur bei exklusivem Block oder Inline-Tag-Umwandlung nach Zeilenumbruch
        var obr = ( big_b || ( obb && n_only ) ) ? true : false; // Outer-Br nur bei exklusiven Block, Inline-Tag-Umwandung nach Zeilenumbruch oder explizit angefordertem Outer-Br

        // Verwendeten Tag ermitteln
        var tag = ntag;
        if ( b_only || n_to_b ) tag = btag; // Block-Tag statt Inner-Tag verwenden, wenn Block-Tag exklusiv angegeben oder wenn wegen Zeilenumbüchen im Textabschnitt ein Inner- zu einem Outer-Tag umgewandelt wurde, wenn beide vorhanden sind

        console.log('----------------------------------------------');
        console.log('ntag: '+ntag+', btag: '+btag+', obr: '+obr+', dout: '+dout);
        console.log('Outer-Br: '+obr+', Inner-Br: '+ibr+', Tag: '+tag+', Dbl-Outer-Br: '+dout);

        // Auszählen der Zeilenumbrüche außerhalb der Markierung
        var get_outer_n = function(str1,str2,min){
            if ( !obr ) return '';
            var countn = function(str,front){
                if ( str.length === 0 ) return min;
                var match1 = front ? str.match(/^[\n\s]+/) : str.match(/[\n\s]+$/);
                var match2 = match1 ? match1[0].match(/\n/g) : "";
                return match2.length;
            };
            var num = countn(str1,false) + countn(str2,true);
            console.log('num1: '+num);
            if ( num < min ) num = min - num;
            else return '';
            console.log('num2: '+num);
            var str = '';
            for ( var i = 1; i <= num; i++){
                str += "\n";
            }
            console.log('str: '+JSON.stringify(str));
            return str;
        };

        // Zeilenumbrüche außerhalb der Tags ermitteln
        var s_br_o = get_outer_n(txt0,txt1,(dout ? 2 : 1));
        var e_br_o = get_outer_n(txt1,txt2,(dout ? 2 : 1));

        // Zeilenumbrüche innerhalb der Tags ermitteln
        var s_br_i = '', e_br_i = '';
        if ( ibr ) { s_br_i = "\n"; e_br_i = "\n"; }

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
        if ( txt1.length > 0 ) {
            pos += tag.length + 3;
            if ( e_br_i ) pos++;
            if ( e_br_o ) pos++;
        }
        tinput.selectionStart = pos;
        tinput.selectionEnd   = pos;
    };

    // Formatierungsbuttons definieren
    var buttons = [
        // ButtonId, Tag, BlockTag, OuterBlockBreaks, DoubleOuterBreak
        ['h1button',            'h3',     false,        true,  true ],
        ['quotebutton',         'quote',  'blockquote', true,  true ],
        ['unorderedlistbutton', false,    'ul',         true,  true ],
        ['orderedlistbutton',   false,    'ol',         true,  true ],
        ['listitembutton',      'li',     false,        true,  false],
        ['codebutton',          'code',   'pre',        true,  true ],
        ['underlinebutton',     'u',      false,        false, false],
        ['boldbutton',          'b',      false,        false, false],
        ['linethroughbutton',   'strike', false,        false, false],
        ['italicbutton',        'i',      false,        false, false],
        ['emotionalbutton',     'em',     false,        false, false],
    ];
    // Formatierungsbuttonereignisse registrieren
    var show_formatbuttons = function(){
        var register_one_button = function(b){
            document.getElementById(b[0]).onclick = function(){
                tagthat(b[1],b[2],b[3],b[4]);
            };
        };
        for (var j=0; j<buttons.length; j++){
            register_one_button(buttons[j]);
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
        document.getElementById('closetextabutton').onclick = close_preview;
    };

    showbuttons();
};


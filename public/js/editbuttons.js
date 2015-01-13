window.onload = function(){
    var tinput = document.getElementById('textinput');

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

    // Zeilen insgesamt markieren
    var linestarter = function(str){
        // console.log('mark linestart with "' + str + '"');
        var pos = selection()[0] || 0;
        position(pos);
        tinput.focus();
        var lio = tinput.value.substr(0,pos).lastIndexOf("\n");
        if ( lio == -1 ) lio = 0;
        else             lio = lio + 1;
        tinput.value = tinput.value.substr(0,lio) + str + tinput.value.substr(lio, tinput.value.length);
    };

    // Spezielle Escape-Funktionen
    var strngescape = function(str){
        // console.log('escape selection with "' + str + '"');
        var sel = selection();
        var txt = tinput.value.substr(sel[0], sel[1] - sel[0]);
        if ( !txt ) return;
        position(sel[1]);
        tinput.focus();

        var border = ['', ''];
        var mtch = txt.match(/^\W+/);
        if ( mtch && mtch.length > 0 ) {
            border[0] = mtch[0];
            txt = txt.substr(border[0].length, txt.length - border[0].length);
        }
        mtch = txt.match(/\W+$/);
        if ( mtch && mtch.length > 0 ) {
            border[1] = mtch[0];
            txt = txt.substr(0, txt.length - border[1].length - 1);
        }

        txt = border[0] + str + txt.replace(/\W+/g, str) + str + border[1];
        tinput.value = tinput.value.slice(0,sel[0]) + txt + tinput.value.slice(sel[1],tinput.value.length - 1);
    };

    // Buttonereignisse registrieren
    document.getElementById('h1button').onclick            = function(){ linestarter('= ') };
    document.getElementById('unorderedlistbutton').onclick = function(){ linestarter('- ') };
    document.getElementById('orderedlistbutton').onclick   = function(){ linestarter('# ') };
    document.getElementById('prebutton').onclick           = function(){ linestarter('  ') };
    document.getElementById('underlinebutton').onclick     = function(){ strngescape('_')  };
    document.getElementById('boldbutton').onclick          = function(){ strngescape('+')  };
    document.getElementById('linethroughtbutton').onclick  = function(){ strngescape('-')  };
    document.getElementById('italicbutton').onclick        = function(){ strngescape('~')  };
};

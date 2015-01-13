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
    var linestartpos = function(sel) {
        var lio = tinput.value.substr(0,sel[0]).lastIndexOf("\n");
        if ( lio == -1 ) lio = 0;
        return lio;
    };
    var wordboundaries = function(sel){
        var start = tinput.value.substr(0,sel[0]).match(/ /);
        if ( !start ) start = 0;
        else          start = tinput.value.substr(0,sel[0]).lastIndexOf(" ");

        var end = tinput.value.substr(sel[1] - 1, tinput.value.length).search(/\W/);
        if ( end === -1 ) end = tinput.value.length;

        return [start, end + sel[1]];
    };

    // Zeilen insgesamt markieren
    var linestarter = function(str){
        // console.log('mark linestart with "' + str + '"');
        tinput.focus();
        var sel = selection();
        var lio = linestartpos(sel);
        var txt = tinput.value.substr(lio, sel[1]);
        var txt2 = txt.replace(/\n/g, "\n"+str);
        if ( lio == 0 ) txt2 = str + txt2;
        tinput.value = tinput.value.substr(0,lio) + txt2 + tinput.value.substr(lio + txt.length, tinput.value.length);
        position(lio + txt2.length);
    };

    // Spezielle Escape-Funktionen
    var strngescape = function(str){
        // console.log('escape selection with "' + str + '"');
        tinput.focus();

        var sel = wordboundaries(selection());
        var txt = tinput.value.substr(sel[0], sel[1] - sel[0]);
        if ( !txt ) return;

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

        var cnt = txt.match(/\W+/g);
        if ( !cnt ) cnt = [];
        txt = border[0] + str + txt.replace(/\W+/g, str) + str + border[1];
        tinput.value = tinput.value.slice(0,sel[0]) + txt + tinput.value.slice(sel[1],tinput.value.length - 1);

        position(sel[1] + ( 2 * str.length ) + ( cnt.length * str.length ) + border[0].length);
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
    document.getElementById('attentionbutton').onclick     = function(){ strngescape('!')  };
    document.getElementById('emotionalbutton').onclick     = function(){ strngescape('*')  };
};

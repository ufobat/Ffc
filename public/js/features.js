ffcdata.features = {};

ffcdata.features.init = function(){

    // Aktualisierungszeitpunkt nach lokaler Uhrzeit in den Titel schreiben
    var set_titletime = function(){
        var mytitle = document.getElementsByTagName("title")[0].firstChild.data;
        var mytime  = new Date();
        var myh = mytime.getHours(), mym = mytime.getMinutes();
        document.getElementsByTagName("title")[0].firstChild.data
            = mytitle + ', zuletzt aktualisiert ' 
                      + ( myh < 10 ? '0'+myh : myh ) 
                      + ':' + ( mym < 10 ? '0'+mym : mym );
    };

    // Auto-Refresh einsetzen
    var set_autorefresh = function(){
        ffcdata.features.autorefresh_interval = window.setInterval(function(){
            ffcdata.utils.request('GET', ffcdata.counturl, null, function(res){ 
                if ( res > 0 )
                    location.reload();
                else
                    set_titletime();
            });
        }, ffcdata.autorefresh * 60000 );
    };
    
    // Weitere Feature-Operationen starten
    set_titletime();
    if ( ffcdata.autorefresh > 0
      && !ffcdata.utils.is_disabled()
      && !document.hasFocus() 
      && (!document.getElementById('textinput') 
        || document.getElementById('textinput').value === '') ) {
        set_autorefresh();
    }
};

ffcdata.utils = {
    features_disabled: undefined,
};

ffcdata.utils.is_disabled = function(){
    if ( ffcdata.utils.features_disabled !== undefined )
        return ffcdata.utils.features_disabled;

    if ( window.matchMedia('(max-device-width: 800px)').matches ) 
        ffcdata.utils.features_disabled = true;
    else
        ffcdata.utils.features_disabled = false;

    return ffcdata.utils.features_disabled;
}

ffcdata.utils.init = function(){
    // Browser-Shortcomings ausgleichen
    if ( !document.hasFocus ) {
        document.hasFocus = function() {
            var hfocus = true;
            window.onfocus = function() { hfocus = true;  };
            window.onblur  = function() { hfocus = false; };
            return function() { return hfocus; };
        }();
    }
}

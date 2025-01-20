var olay = (window.olay = {
    epoch: Date.now(),
    bufferedEvents: [],
    addEvent: function (type, metadata) {
        metadata = metadata || {};
        var localTime = Date.now() - olay.epoch;
        olay.bufferedEvents.push({ localTime: localTime, type: type, metadata: metadata });
    },
});

(function () {
    var scriptEl = document.createElement("script");
    scriptEl.type = "text/javascript";
    scriptEl.async = true;
    scriptEl.src = "https://deniz.co/olay/client-web.js?project=penc";

    var s = document.getElementsByTagName("script")[0];
    // @ts-ignore
    s.parentNode.insertBefore(scriptEl, s);
})();

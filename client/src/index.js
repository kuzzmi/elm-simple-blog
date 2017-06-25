require('normalize.css');
require('./style.scss');
require('./registerServiceWorker').default();

var hljs = require('highlight.js');
require('highlight.js/styles/tomorrow-night-eighties.css');

var Elm = require('./Main');

var disqusLoaded = false;
var a2a_config = a2a_config || {};
a2a_config.onclick = 1;

var apiUrl;

if (process.env.NODE_ENV === 'production') {
    apiUrl = '/api/';
} else {
    apiUrl = '//localhost:3000/api/';
}

var app = Elm.Main.embed(document.getElementById('root'), {
    accessToken: localStorage.getItem('access_token'),
    apiUrl: apiUrl
});

app.ports.saveAccessTokenToLocalStorage.subscribe(function(accessToken) {
    localStorage.setItem('access_token', accessToken);
});

app.ports.setDisqusIdentifier.subscribe(function(slug) {
    if (window.DISQUS) {
        window.DISQUS.reset();
    }

    setTimeout(function() {
        document.querySelectorAll('pre code').forEach(function(block) {
            hljs.highlightBlock(block);
        });
        if (disqusLoaded) {
            window.DISQUS.host._loadEmbed();
            a2a.init('page');
        }
   }, 100);

    var disqus_config = function() {
        this.page.url = window.location.href;
        this.page.identifier = slug;
    };

    a2a_config.linkurl = window.location.href;
    a2a_config.linkname = slug;

    if (!disqusLoaded) {
        var loadScript = function(url) {
            var d = document, s = d.createElement('script');
            s.src = url;
            s.setAttribute('data-timestamp', +new Date());
            s.setAttribute('async', true);
            disqusLoaded = true;
            (d.head || d.body).appendChild(s);
        };
        loadScript('https://kuzzmi.disqus.com/embed.js');
        // loadScript('https://kuzzmi.disqus.com/count.js');
        loadScript('//static.addtoany.com/menu/page.js');
    }
});

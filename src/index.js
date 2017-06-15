require('normalize.css');
require('./style.scss');
require('./registerServiceWorker').default();

var hljs = require('highlight.js');
require('highlight.js/styles/tomorrow-night-eighties.css');

var Elm = require('./Main');

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

// var disqus_config = function () {
//     this.page.url = PAGE_URL;  // Replace PAGE_URL with your page's canonical URL variable
//     this.page.identifier = PAGE_IDENTIFIER; // Replace PAGE_IDENTIFIER with your page's unique identifier variable
// };
//
// (function() { // DON'T EDIT BELOW THIS LINE
//     var d = document, s = d.createElement('script');
//     s.src = 'https://kuzzmi.disqus.com/embed.js';
//     s.setAttribute('data-timestamp', +new Date());
//     (d.head || d.body).appendChild(s);
// })();
//
//

app.ports.saveAccessTokenToLocalStorage.subscribe(function(accessToken) {
    console.log('GOT ACCESS TOKEN', accessToken);
    localStorage.setItem('access_token', accessToken);
});

app.ports.setDisqusIdentifier.subscribe(function(slug) {
    console.log('GOT NEW DISQUS SLUG', slug);
    setTimeout(function() {
        document.querySelectorAll('pre code').forEach(function(block) {
            hljs.highlightBlock(block);
        });
    }, 100);
});

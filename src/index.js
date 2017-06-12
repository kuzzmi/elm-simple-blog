require('normalize.css');
require('./style.scss');

var hljs = require('highlight.js');
require('highlight.js/styles/monokai.css');

var Elm = require('./Main');

var app = Elm.Main.embed(document.getElementById('root'));

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
app.ports.setDisqusIdentifier.subscribe(function(slug) {
    document.querySelectorAll('pre code').forEach(function(block) {
        hljs.highlightBlock(block);
    });
});

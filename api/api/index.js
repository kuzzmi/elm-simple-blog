const express = require('express');
const router = express.Router();

const posts = require('./posts');
const tags = require('./tags');
const users = require('./users');
const projects = require('./projects');
const auth = require('../auth');
const feed = require('./feed');

const Post = require('../models/post.js');

router.use('/posts', posts);
router.use('/tags', tags);
router.use('/users', users);
router.use('/projects', projects);
router.use('/auth', auth);
router.use('/feed', feed);

router.get('/sitemap', (req, res) => {
    req.query

    Post.find({ isPublished: true })
        .sort('-dateCreated')
        .exec(function(err, posts) {
            if (err) {
                res.send(err);
            }
            const sitemap = posts.map(post => `https://kuzzmi.com/blog/${post.slug}`);
            const fullSitemap = [
                'https://kuzzmi.com/',
                'https://kuzzmi.com/projects/list',
                'https://kuzzmi.com/about',
                ...sitemap,
            ].join('\r\n');
            res.set({
                'Content-Type': 'text/plain',
                'Content-Length': fullSitemap.length,
            });
            res.send(fullSitemap);
        });
});

module.exports = router;

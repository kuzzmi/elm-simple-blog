const webpack = require('webpack');
const path = require('path');

const ExtractTextPlugin = require('extract-text-webpack-plugin');
const ManifestPlugin = require('webpack-manifest-plugin');
const SWPrecacheWebpackPlugin = require('sw-precache-webpack-plugin');
const InterpolateHtmlPlugin = require('interpolate-html-plugin');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');

const IS_DIST = process.env.NODE_ENV === 'production';
const PUBLIC_URL = IS_DIST ? 'https://dev.kuzzmi.com/' : '/';
// kuzzmi.com: 'UA-51775404-4'
const GA_PROPERTY_ID = IS_DIST ? '' : 'UA-51775404-5';

const paths = {
    html: path.join(__dirname, './public/index.html'),
};

let plugins = [
    new ExtractTextPlugin('styles.[contenthash:8].css')
];

if (IS_DIST) {
    plugins = [
        ...plugins,
        new webpack.optimize.UglifyJsPlugin(),
        new InterpolateHtmlPlugin({
            PUBLIC_URL,
            GA_PROPERTY_ID
        }),
        new HtmlWebpackPlugin({
            inject: true,
            template: paths.html,
            minify: {
                removeComments: true,
                collapseWhitespace: true,
                removeRedundantAttributes: true,
                useShortDoctype: true,
                removeEmptyAttributes: true,
                removeStyleLinkTypeAttributes: true,
                keepClosingSlash: true,
                minifyJS: true,
                minifyCSS: true,
                minifyURLs: true,
            },
        }),
        new webpack.DefinePlugin({
            'process.env.NODE_ENV': JSON.stringify('production'),
            'process.env.PUBLIC_URL': JSON.stringify(PUBLIC_URL),
            'process.env.GA_PROPERTY_ID': JSON.stringify(GA_PROPERTY_ID),
        }),
        new webpack.LoaderOptionsPlugin({
            minimize: true,
            debug: false
        }),
        new ManifestPlugin({
            fileName: 'asset-manifest.json',
        }),
        new SWPrecacheWebpackPlugin({
            cacheId: 'kuzzmi-blog',
            dontCacheBustUrlsMatching: /\.\w{8}\./,
            filename: 'service-worker.js',
            minify: true,
            navigateFallback: PUBLIC_URL + 'index.html',
            staticFileGlobsIgnorePatterns: [/\.map$/, /asset-manifest\.json$/]
        }),
        new CopyWebpackPlugin([
            { from: './public/favicon.ico' },
            { from: './public/manifest.json' }
        ])
    ];
} else {
    plugins = [
        ...plugins,
        new InterpolateHtmlPlugin({
            PUBLIC_URL,
            GA_PROPERTY_ID
        }),
        new HtmlWebpackPlugin({
            inject: true,
            template: paths.html
        }),
        new CopyWebpackPlugin([
            { from: './public/favicon.ico' },
            { from: './public/manifest.json' }
        ])
    ];
}

module.exports = {
    entry: {
        app: './src/index.js'
    },

    output: {
        path: path.join(__dirname, './dist'),
        filename: '[name].[hash:8].js',
        chunkFilename: '[name].[chunkhash:8].js',
        publicPath: PUBLIC_URL,
    },

    resolve: {
        extensions: ['.js', '.elm']
    },

    module: {
        rules: [{
            test: /\.elm$/,
            exclude: [/elm-stuff/, /node_modules/],
            loader: 'elm-webpack-loader?maxInstances=2'
        }, {
            test: /\.scss/,
            use: ExtractTextPlugin.extract({
                use: 'css-loader!sass-loader'
            })
        }, {
            test: /\.css/,
            use: ExtractTextPlugin.extract({
                use: 'css-loader'
            })
        }],

        noParse: /\.elm$/
    },

    plugins,

    devServer: {
        inline: true,
        stats: 'errors-only',
        publicPath: '/',
        contentBase: path.join(__dirname, './src'),
        historyApiFallback: true
    }
};

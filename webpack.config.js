const path = require('path');

module.exports = {
  entry: './src/index.js',

  output: {
    path: path.join(__dirname, './dist'),
    filename: 'app.js'
  },

  resolve: {
    extensions: ['.js', '.elm']
  },

  module: {
    rules: [
      {
        test: /\.elm$/,
        exclude: [/elm-stuff/, /node_modules/],
        loader: 'elm-webpack-loader?maxInstances=2'
      },
      {
        test: /\.scss/,
        use: [
            'style-loader',
            'css-loader',
            'sass-loader'
        ]
      },
      {
        test: /\.css/,
        use: [
            'style-loader',
            'css-loader'
        ]
      }
    ],

    noParse: /\.elm$/
  },

  devServer: {
    inline: true,
    stats: 'errors-only',
    publicPath: '/',
    contentBase: path.join(__dirname, './src'),
    historyApiFallback: true
  }
};

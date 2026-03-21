const path = require('path');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

module.exports = {
  entry: './src/index.js',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: 'orchestrationEngine.js',
    // Expose as window.Drawflow so LWC can access it via `window.Drawflow`
    library: {
      name: 'Drawflow',
      type: 'umd',
      export: 'default',
    },
    globalObject: 'this',
    clean: true,
  },
  plugins: [
    new MiniCssExtractPlugin({
      filename: 'orchestrationEngine.css',
    }),
  ],
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, 'css-loader'],
      },
    ],
  },
};

const path = require('path')
const { rollup, watch: rollupWatch } = require('rollup')

const vuePlugin = require('rollup-plugin-vue')
const { terser } = require('rollup-plugin-terser')
const commonjs = require('@rollup/plugin-commonjs')
const nodeResolve = require('@rollup/plugin-node-resolve')
const entry = [path.join(__dirname, 'src/index.js')]

const inputOptions = {
  input: entry,
  plugins: [
    vuePlugin(),
    nodeResolve,
    commonjs()
  ]
}

const outputOptions = {
  format: 'iife',
  dir: __dirname,
}

async function build() {
  inputOptions.plugins.push(terser())
  const bundle = await rollup(inputOptions)
  await bundle.generate(outputOptions);
  await bundle.write(outputOptions)
  await bundle.close()
}

function watch() {
  const watcher = rollupWatch({
    ...inputOptions,
    output: outputOptions
  })

  watcher.on('event', (event) => {
    if (event.error) {
      console.error(event.error);
    }
    if (event.result) {
      event.result.close();
    }
  });
}

exports.build = build
exports.watch = watch

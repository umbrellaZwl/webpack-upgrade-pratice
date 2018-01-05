title: webpack-upgrade-pratice
speaker: yedi
transition: slide3
theme: dark

[slide]
# webpack-upgrade-pratice
## 演讲者：yedi

[slide]
# 引述
* webapck凭借其模块管理功能强大，自定义配置打包，文件名hash化，完善的开发工具以及其他很多的有点，成为很多公司的标配的前端工程化、自动化的工具了。 {:&.rollIn}
* 因此这次分享不会再继续赘述webpack当中主要角色的概念和使用
* 那么这次就一起来聊聊在这次webpack升级过程中，做了哪些策略调整，遇到了什么问题，以及效果

[slide]
# 我们关注什么
* 开发过程中打包效率 {:&.rollIn}
 	* 是否还能再提升？ {:&.fadeIn}
 	* 首次打包后之后再次打包能否提升？
* 打包后的文件
	* 文件大小能否更小？ {:&.fadeIn}
	* 命中缓存和更新？
[slide]
# DedupePlugin和OccurenceOrderPlugin
----
* 这是webpack1常用的两个插件 {:&.rollIn}
* 
```javascript
new webpack.optimize.DedupePlugin() // 删除重复数据
```
* 
```javascript
new webpack.optimize.OccurenceOrderPlugin() 
// webpack就能够比对id的使用频率和分布来得出最短的id分配给使用频率高的模块
```
* 怎么理解？

[slide]
# 从webpack1到webpack2
----
* 内置DedupePlugin和OccurenceOrderPlugin {:&.rollIn}
* 
```javascript
// .babelrc
{
    "presets": [
      ["env", {
        "targets": {
          "browsers": ["last 2 versions"]
        }
      }],
      ["es2015", {"modules": false}]
    ]
  }
```
* tree-shaking，树摇
* 利用es6的module特性将没有引用到的代码和文件摇掉

[slide]
# 配置resolve
----
* 配置resolve.alias定义别名，来减少文件的搜索路径，还可以增强代码易读性 {:&.rollIn}
* resolve.unsafeCache
* 
```javascript
resolve: {
    unsafeCache: true,
    alias: {
      c: path.join(srcPath, 'components'),
      common: path.join(srcPath, 'common'),
      components: path.join(srcPath, 'components'),
      util: path.join(srcPath, 'components/util/index.js')
    },
    modules: [
      srcPath,
      'components',
      'node_modules'
    ]
  }
```

[slide]
# 配置module.noParse
----
* 忽略匹配noParse的文件的解析和编译 {:&.rollIn}
* 
```javascript
module: {
	noParse: /jquery|lodash/, 
	noParse: function(content) {
	  return /jquery|lodash/.test(content);
	}
}
```

[slide]
# 配置externals
----
* 通过externals配置告诉webpack哪些变量名不用解析，而从外部变量读取。由于很多外部库，我们并不需要去调试它的源码，因此通过这个方案，省略部分依赖的解析和编译，能够很大地提升编译速度。配置好externals后，externals中依赖的库需要在模板文件中通过script外链引入 {:&.rollIn}
* 如果某个依赖没有cdn地址呢
* 每一个库都要去加一个script标签引入，是不是稍显麻烦，不利于维护
* 不利于资源共享
* 需要支持umd

[slide]
## 使用DllPlugin和DllReferencePlugin
----
* 使用DllPlugin和DllReferencePlugin其实跟external都是将一些不需要调试源码，对业务内部模块无依赖的库从打包过程中分离 {:&.rollIn}
* 先使用单独的webpack配置，使用DllPlugin提前编译这些库文件,生成一个js文件以及对应的一个manifest.json文件，
* 然后再项目中的webpack配置文件中通过DllReferencePlugin插件，引用manifest.json来即可

[slide]
<div class="columns-2">
    <pre style="height: 500px !important; overflow:auto"><code class="javascript">
// webpack.dll.config.js
const vendors = [
   'react',
   'react-router',
   'react-router-dom',
   'axios',
   'immutable',
   'jquery',
   'babel-polyfill',
   'bluebird',
   'fastclick'
]

const config = {
  entry: {
    'vendor': vendors
  },
  output: {
    pathinfo: true,
    path: buildPath,
    filename: '[name].js',
    chunkFilename: '[name].js',
    library: '[name]'
  },
  devtool: 'cheap-module-source-map',
  plugins: [
    new webpack.DllPlugin({
      path: path.resolve(__dirname, 'manifest.json'),
      name: '[name]',
      context: srcPath
    })
  ]
}
    </code></pre>
    <pre><code class="javascript">
    // webpack.config.js
    new webpack.DllReferencePlugin({
      context: srcPath,
      manifest: path.resolve(__dirname, 'manifest.json')
    })
    </code></pre>
</div>

[slide]
# 使用DllPlugin的优点
----
* 配置方式简单 {:&.rollIn}
* 提前预编译资源，之后打包不需要再对这些模块进行打包，打包效率提升
* 不依赖与外链，利于资源共享
* 管理集中，利于维护
* 分离打包，不需要每次都对这些文件进行打包，
* 可以起到CommonChunkPlugin的作用，抽取公共文件

[slide]
# 使用DllPlugin的缺点
----

* 需要额外一份webpack配置，进行一次编译 {:&.rollIn}
* 生成的文件需要手动插入模板文件或者使用AddAssetHtmlPlugin插件

* 思考：在我们的webpack配置中，哪些文件会被CommonChunkPlugin收取成一个公共js文件，有什么优缺点？
* 对外部依赖的公共库文件和业务公共文件进行分离，既可以利用用户浏览器缓存，又避免对没有改动过的外部依赖的公共库文件进行打包编译

[slide]
# 使用HappyPack并行编译
----
* happyPack利用多进程并行编译，同时还可以开启cache，从而提高编译效率 {:&.rollIn}
* happyPack开启cache之后，babel-loader编译js是否也能开启cacheDirectory提升效率?
* 
```javascript
new HappyPack({
      id: 'js',
      threadPool: happyThreadPool,
      loaders: [{
        loader: 'babel-loader',
        options: {
          cacheDirectory: path.resolve(root, 'babelCache')
        }
      }],
      verbose: true,
      verboseWhenProfiling: true
    })
```
[slide]
# PrefetchPlugin提前并行编译
----
* 当一个模块还未被require之前，提前解析和建立一个对该插件的请求 {:&.rollIn}
* 
```javascript
new webpack.PrefetchPlugin('babel-runtime/core-js),
new webpack.PrefetchPlugin('core-js/library')
```

[slide]
# 生产环境uglifyJsPlugin强化
* 将webpack.optimize.uplifyJsPlugin替换为uglifyjs-webpack-plugin或者webpack-uglify-parallel {:&.rollIn}
* 配置parallel参数可以进行多核压缩，提升压缩效率
* 开启cache，对于后续压缩会有极大提升
* 
```javascript
new UglifyJsPlugin({
 sourceMap: true,
 uglifyOptions: {
   output: {
     comments: false
   },
   compress: {
     warnings: false
   }
 },
 exclude: /\.min\.js$/,
 parallel: os.cpus().length,
 cache: true
})
```

[slide]
# webpack3的Scope Hoisting

* webpack打包后的文件会有自己的一套模块管理的方式，会将模块用函数包裹，分配Id，例如： {:&.rollIn}
* 
```javascript
/* 0 */
  function (module, exports, require) {
    var module_a = require(1)
    console.log(module_a['default'])
  },
  /* 1 */
  function (module, exports, require) {
    exports['default'] = 'module A'
  }
```

* webpack3提供ModuleConcatenationPlugin插件，将模块放在一个函数里 {:&.rollIn}
* 减少很多函数声明，减小文件大小，提升性能

[slide]
# 谢谢



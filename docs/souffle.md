# Souffle

## example

Souffle是款Datalog推理引擎，也是著名声明式分析框架Doop默认的引擎。

Datalog = data + logic ，也就是现有的事实加上推理逻辑可以推理出新的事实。
data可以理解为数据库，其中由一个个relation组成，relation可以理解为数据库中的表，表中一列数据表明满足他们满足某种关系。

```
.decl edge(x:number, y:number)
```

上面通过.decl声明了edge这个关系，可以理解为x有条指向y的边,x和y可以理解为变量名称，number理解为变量类型。
添加已有事实有两种方式，一种是通过

```
.decl edge(x:number, y:number)
edge(1, 2).
```

表明节点1到节点2有条边。也可以通过

```
.decl edge(x:number, y:number)
.input edge
```

通过从edge.facts中获取事实，如果edge.facts的内容如下

```
1	2
```

上面表达的效果就是一致的。
再接着看一个完整的例子，example.dl文件内容如下

```
// 声明 edge 表示 节点 x 到 y 有条边
.decl edge(x:number, y:number)
// 表示从edge.facts 读事实
.input edge

// 声明 path 表示 节点 x 到 y 有路径可达
.decl path(x:number, y:number)
// 表示将path的结果输出到path.csv
.output path

// 推理规则，如果x到y有边，那么x到y肯定有长度为1的路径，也就是如果x，y满足关系edge，也一定满足关系path
path(x, y) :- edge(x, y).
// 用到了递归推理，如果x到z有条路径，并且z到y有条边，那么就可以推理出x到y也有路径
path(x, y) :- path(x, z), edge(z, y).
```

如果edge.facts的内容如下

```
1	2
2	3
```
通过执行
```
souffle -F . -D . example.dl
```
- `-F` 指定了facts所在的目录
- `-D` 指定了输出目录
- `example.dl` 指定datalog文件名

最终得到的path.csv内容如下

```
1	2
1	3
2	3
```

表示节点1到节点2有路径，节点1到节点3有路径，节点2到节点3有路径。
上述内容主要来自 https://souffle-lang.github.io/simple

## Type

Souffle中类型除了number类型（和int类似）以外，还有symbol类型（和string类似），这两种都属于Primitive Type，还可以有

- Equivalence Types

    `.type <new-type> = <other-type>`

    ```
    .type myNumber = number
    ```
  
- SubTypes
  
    `type <new-type> <: <other-type>`
    ```
    .type myEvenNumber <: number
    ```
具体可参考 https://souffle-lang.github.io/types

## reference
- https://pascal-group.bitbucket.io/lectures/Datalog.pdf
- https://souffle-lang.github.io/simple
- https://souffle-lang.github.io/types